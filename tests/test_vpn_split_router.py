import importlib.util
import json
from types import SimpleNamespace

from tests import REPO_ROOT_PATH as REPO_ROOT

MODULE_PATH = REPO_ROOT / "scripts" / "vpn_split_router.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("vpn_split_router", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_load_config_reads_seed_domains_and_settings(tmp_path):
    router = _load_module()
    config_path = tmp_path / "config.yaml"
    config_path.write_text(
        "settings:\n"
        "  seed_vpn_failure_threshold: 1\n"
        "  observed_vpn_failure_threshold: 2\n"
        "  direct_ttl_seconds: 60\n"
        "  vpn_ttl_seconds: 60\n"
        "  observed_stale_after_seconds: 300\n"
        "  probe_timeout_seconds: 3.0\n"
        "  probe_interval_seconds: 900\n"
        "seed_domains:\n"
        "  - claude.ai\n",
        encoding="utf-8",
    )

    config = router.load_config(config_path)

    assert config["seed_domains"] == ["claude.ai"]
    assert config["settings"]["observed_vpn_failure_threshold"] == 2


def test_apply_probe_result_keeps_observed_domain_out_of_vpn_after_single_failure():
    router = _load_module()
    config = {
        "settings": {
            "seed_vpn_failure_threshold": 1,
            "observed_vpn_failure_threshold": 2,
            "direct_ttl_seconds": 60,
            "vpn_ttl_seconds": 60,
        },
        "seed_domains": [],
    }
    record = {
        "domain": "example.com",
        "source": "observed",
        "route": "probing",
        "failure_count": 0,
        "success_count": 0,
    }

    updated = router.apply_probe_result(record, config, {"status": "timeout", "latency_ms": None})

    assert updated["route"] == "probing"
    assert updated["failure_count"] == 1


def test_apply_probe_result_moves_seed_domain_to_vpn_on_first_failure():
    router = _load_module()
    config = {
        "settings": {
            "seed_vpn_failure_threshold": 1,
            "observed_vpn_failure_threshold": 2,
            "direct_ttl_seconds": 60,
            "vpn_ttl_seconds": 60,
        },
        "seed_domains": ["claude.ai"],
    }
    record = {
        "domain": "claude.ai",
        "source": "seed",
        "route": "probing",
        "failure_count": 0,
        "success_count": 0,
    }

    updated = router.apply_probe_result(record, config, {"status": "timeout", "latency_ms": None})

    assert updated["route"] == "vpn"
    assert updated["reason"] == "probe_timeout"


def test_expire_routes_returns_domain_to_probing():
    router = _load_module()
    state = {
        "domains": {
            "claude.ai": {
                "domain": "claude.ai",
                "source": "seed",
                "route": "vpn",
                "ttl_until": "2000-01-01T00:00:00+00:00",
                "failure_count": 2,
                "success_count": 0,
            },
            "openrouter.ai": {
                "domain": "openrouter.ai",
                "source": "observed",
                "route": "direct",
                "ttl_until": "2026-04-18T00:00:00+00:00",
                "failure_count": 0,
                "success_count": 1,
            },
        }
    }

    router.expire_routes(state, now_iso="2026-04-17T12:00:00+00:00")

    assert state["domains"]["claude.ai"]["route"] == "probing"
    assert state["domains"]["claude.ai"]["reason"] == "ttl_expired"
    assert state["domains"]["openrouter.ai"] == {
        "domain": "openrouter.ai",
        "source": "observed",
        "route": "direct",
        "ttl_until": "2026-04-18T00:00:00+00:00",
        "failure_count": 0,
        "success_count": 1,
    }


def test_write_text_if_changed_detects_real_changes(tmp_path):
    router = _load_module()
    path = tmp_path / "vpn-domains.txt"

    first = router.write_text_if_changed(path, "claude.ai\n")
    second = router.write_text_if_changed(path, "claude.ai\n")
    third = router.write_text_if_changed(path, "claude.ai\nopenrouter.ai\n")

    assert first is True
    assert second is False
    assert third is True
    assert path.read_text(encoding="utf-8") == "claude.ai\nopenrouter.ai\n"


def test_sync_runtime_config_injects_single_managed_rule(tmp_path):
    router = _load_module()
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "server": "vpn.example", "tag": "vpn"}],
                "route": {"rules": [{"outbound": "direct", "protocol": "dns"}]},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    changed = router.sync_runtime_config(config_path, ["claude.ai", "openrouter.ai"])
    payload = json.loads(config_path.read_text(encoding="utf-8"))

    managed_rules = [
        rule for rule in payload["route"]["rules"] if rule.get("tag") == "vpn-split-router-managed"
    ]
    assert changed is True
    assert len(managed_rules) == 1
    assert managed_rules[0]["domain_suffix"] == ["claude.ai", "openrouter.ai"]
    assert managed_rules[0]["outbound"] == "vpn"
    assert {"outbound": "direct", "protocol": "dns"} in payload["route"]["rules"]


def test_sync_runtime_config_replaces_existing_managed_rule_without_duplicates(tmp_path):
    router = _load_module()
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "server": "vpn.example", "tag": "vpn"}],
                "route": {
                    "rules": [
                        {
                            "tag": "vpn-split-router-managed",
                            "domain_suffix": ["old.example"],
                            "outbound": "vpn",
                        },
                        {"outbound": "direct", "protocol": "dns"},
                    ]
                },
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.sync_runtime_config(config_path, ["claude.ai"])
    payload = json.loads(config_path.read_text(encoding="utf-8"))

    managed_rules = [
        rule for rule in payload["route"]["rules"] if rule.get("tag") == "vpn-split-router-managed"
    ]
    assert len(managed_rules) == 1
    assert managed_rules[0]["domain_suffix"] == ["claude.ai"]
    assert {"outbound": "direct", "protocol": "dns"} in payload["route"]["rules"]


def test_sync_runtime_config_uses_explicit_vpn_outbound_tag_when_not_first(tmp_path):
    router = _load_module()
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "outbounds": [
                    {"type": "direct", "tag": "direct"},
                    {"type": "wireguard", "server": "vpn.example", "tag": "amnezia-vpn"},
                ],
                "route": {"rules": [{"outbound": "direct", "protocol": "dns"}]},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.sync_runtime_config(config_path, ["claude.ai"])
    payload = json.loads(config_path.read_text(encoding="utf-8"))

    managed_rule = next(
        rule for rule in payload["route"]["rules"] if rule.get("tag") == "vpn-split-router-managed"
    )
    assert managed_rule["outbound"] == "amnezia-vpn"


def test_refresh_outputs_excludes_expired_vpn_entries_from_generated_outputs(tmp_path):
    router = _load_module()
    state = {
        "domains": {
            "expired.example": {
                "domain": "expired.example",
                "source": "seed",
                "route": "vpn",
                "reason": "probe_timeout",
                "ttl_until": "2000-01-01T00:00:00+00:00",
                "failure_count": 1,
                "success_count": 0,
            },
            "active.example": {
                "domain": "active.example",
                "source": "seed",
                "route": "vpn",
                "reason": "probe_timeout",
                "ttl_until": "2099-01-01T00:00:00+00:00",
                "failure_count": 1,
                "success_count": 0,
            },
        }
    }
    config = {"settings": {"observed_stale_after_seconds": 3600}}
    observed_path = tmp_path / "observed-domains.txt"
    vpn_domains_path = tmp_path / "vpn-domains.txt"
    runtime_config_path = tmp_path / "config.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "server": "vpn.example", "tag": "vpn"}],
                "route": {"rules": []},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.refresh_outputs(
        state,
        config,
        observed_path,
        vpn_domains_path,
        runtime_config_path,
        now_value="2026-04-17T12:00:00+00:00",
    )

    payload = json.loads(runtime_config_path.read_text(encoding="utf-8"))
    managed_rule = next(
        rule for rule in payload["route"]["rules"] if rule.get("tag") == "vpn-split-router-managed"
    )
    assert state["domains"]["expired.example"]["route"] == "probing"
    assert vpn_domains_path.read_text(encoding="utf-8") == "active.example\n"
    assert managed_rule["domain_suffix"] == ["active.example"]


def test_prune_stale_observed_domains_removes_old_observed_entries(tmp_path):
    router = _load_module()
    state = {
        "domains": {
            "old.example": {
                "domain": "old.example",
                "source": "observed",
                "route": "probing",
                "last_seen": "2026-04-01T00:00:00+00:00",
                "ttl_until": None,
            },
            "seed.example": {
                "domain": "seed.example",
                "source": "seed",
                "route": "vpn",
                "last_seen": "2026-04-01T00:00:00+00:00",
                "ttl_until": "2099-01-01T00:00:00+00:00",
            },
            "fresh.example": {
                "domain": "fresh.example",
                "source": "observed",
                "route": "direct",
                "last_seen": "2026-04-17T11:59:00+00:00",
                "ttl_until": "2099-01-01T00:00:00+00:00",
            },
        }
    }
    config = {"settings": {"observed_stale_after_seconds": 3600}}

    router.prune_stale_observed_domains(state, config, now_value="2026-04-17T12:00:00+00:00")

    assert "old.example" not in state["domains"]
    assert "seed.example" in state["domains"]
    assert "fresh.example" in state["domains"]


def test_command_recheck_clears_observed_queue_and_prunes_stale_state(tmp_path):
    router = _load_module()
    state = {
        "domains": {
            "stale.example": {
                "domain": "stale.example",
                "source": "observed",
                "route": "probing",
                "reason": "new_candidate",
                "last_seen": "2026-04-01T00:00:00+00:00",
                "ttl_until": None,
                "failure_count": 0,
                "success_count": 0,
            },
            "fresh.example": {
                "domain": "fresh.example",
                "source": "observed",
                "route": "direct",
                "reason": "probe_ok",
                "last_seen": "2026-04-17T11:59:00+00:00",
                "ttl_until": "2099-01-01T00:00:00+00:00",
                "failure_count": 0,
                "success_count": 1,
            },
        }
    }
    config_path = tmp_path / "config.yaml"
    config_path.write_text(
        "settings:\n"
        "  seed_vpn_failure_threshold: 1\n"
        "  observed_vpn_failure_threshold: 2\n"
        "  direct_ttl_seconds: 60\n"
        "  vpn_ttl_seconds: 60\n"
        "  observed_stale_after_seconds: 3600\n"
        "  probe_timeout_seconds: 3.0\n"
        "  probe_interval_seconds: 900\n"
        "seed_domains: []\n",
        encoding="utf-8",
    )
    state_path = tmp_path / "state.json"
    state_path.write_text(json.dumps(state) + "\n", encoding="utf-8")
    observed_path = tmp_path / "observed-domains.txt"
    observed_path.write_text("new.example\n", encoding="utf-8")
    vpn_domains_path = tmp_path / "vpn-domains.txt"
    runtime_config_path = tmp_path / "config.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "server": "vpn.example", "tag": "vpn"}],
                "route": {"rules": []},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.now_iso = lambda: "2026-04-17T12:00:00+00:00"
    router.probe_domain = lambda domain, timeout_seconds: {"status": "ok", "latency_ms": 10}

    args = SimpleNamespace(
        config=config_path,
        state=state_path,
        observed=observed_path,
        vpn_domains=vpn_domains_path,
        runtime_config=runtime_config_path,
        policy=tmp_path / "policy.yaml",
        policy_rollback=tmp_path / "policy.yaml.rollback",
    )

    assert router.command_recheck(args) == 0

    final_state = json.loads(state_path.read_text(encoding="utf-8"))
    assert "stale.example" not in final_state["domains"]
    assert observed_path.read_text(encoding="utf-8") == ""


# ── Policy layer ─────────────────────────────────────────────────


def test_load_policy_returns_defaults_when_file_missing(tmp_path):
    router = _load_module()
    policy = router.load_policy(tmp_path / "nonexistent.yaml")
    assert policy == {"always_direct": {"domains": []}, "always_vpn": {"domains": []}}


def test_save_policy_idempotent_no_write(tmp_path):
    router = _load_module()
    path = tmp_path / "policy.yaml"
    policy = {"always_direct": {"domains": ["x.com"]}, "always_vpn": {"domains": []}}
    assert router.save_policy(path, policy) is True
    assert router.save_policy(path, policy) is False


def test_policy_sync_to_routing_injects_direct_and_vpn_rules(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    policy_path.write_text(
        "always_direct:\n  domains:\n    - direct.example\n"
        "always_vpn:\n  domains:\n    - vpn.example\n",
        encoding="utf-8",
    )
    runtime_path = tmp_path / "config.json"
    runtime_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "tag": "vpn"}],
                "route": {"rules": [{"outbound": "direct", "protocol": "dns"}]},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.policy_sync_to_routing(policy_path, runtime_path)
    payload = json.loads(runtime_path.read_text(encoding="utf-8"))
    rules = payload["route"]["rules"]

    direct_rule = next(r for r in rules if r["tag"] == "vpn-policy-direct")
    assert direct_rule["domain_suffix"] == ["direct.example"]
    assert direct_rule["outbound"] == "direct"

    vpn_rule = next(r for r in rules if r["tag"] == "vpn-policy-vpn")
    assert vpn_rule["domain_suffix"] == ["vpn.example"]
    assert vpn_rule["outbound"] == "vpn"

    # original non-managed rule survives
    assert {"outbound": "direct", "protocol": "dns"} in rules
    # policy rules before original
    assert rules.index(direct_rule) < rules.index({"outbound": "direct", "protocol": "dns"})


def test_policy_sync_to_routing_priority_order(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    policy_path.write_text(
        "always_direct:\n  domains:\n    - a.example\nalways_vpn:\n  domains:\n    - b.example\n",
        encoding="utf-8",
    )
    runtime_path = tmp_path / "config.json"
    runtime_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "tag": "vpn"}],
                "route": {"rules": []},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.policy_sync_to_routing(policy_path, runtime_path, probe_vpn_domains=["c.example"])
    payload = json.loads(runtime_path.read_text(encoding="utf-8"))
    rules = payload["route"]["rules"]
    tags = [r["tag"] for r in rules]
    # order: probe → policy-vpn → policy-direct (inserted at head in reverse)
    assert tags == ["vpn-split-router-managed", "vpn-policy-vpn", "vpn-policy-direct"]


def test_policy_sync_to_routing_removes_stale_policy_rules(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    policy_path.write_text(
        "always_direct:\n  domains:\n    - new.example\nalways_vpn:\n  domains: []\n",
        encoding="utf-8",
    )
    runtime_path = tmp_path / "config.json"
    runtime_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "tag": "vpn"}],
                "route": {
                    "rules": [
                        {
                            "tag": "vpn-policy-direct",
                            "domain_suffix": ["old.example"],
                            "outbound": "direct",
                        },
                        {
                            "tag": "vpn-policy-vpn",
                            "domain_suffix": ["old-vpn.example"],
                            "outbound": "vpn",
                        },
                        {
                            "tag": "vpn-split-router-managed",
                            "domain_suffix": ["survivor.example"],
                            "outbound": "vpn",
                        },
                    ]
                },
            }
        )
        + "\n",
        encoding="utf-8",
    )

    router.policy_sync_to_routing(policy_path, runtime_path, probe_vpn_domains=["survivor.example"])
    payload = json.loads(runtime_path.read_text(encoding="utf-8"))
    rules = payload["route"]["rules"]
    tags = [r["tag"] for r in rules]
    assert "vpn-policy-vpn" not in tags
    assert tags == ["vpn-split-router-managed", "vpn-policy-direct"]
    direct_rule = next(r for r in rules if r["tag"] == "vpn-policy-direct")
    assert direct_rule["domain_suffix"] == ["new.example"]


def test_refresh_outputs_with_policy_injects_policy_rules(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    policy_path.write_text(
        "always_direct:\n  domains:\n    - policy-direct.example\n",
        encoding="utf-8",
    )
    runtime_config_path = tmp_path / "config.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "tag": "vpn"}],
                "route": {"rules": []},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    state = {
        "domains": {
            "probe-vpn.example": {
                "domain": "probe-vpn.example",
                "source": "seed",
                "route": "vpn",
                "ttl_until": "2099-01-01T00:00:00+00:00",
            }
        }
    }
    config = {"settings": {}}
    observed_path = tmp_path / "observed.txt"
    vpn_path = tmp_path / "vpn-domains.txt"

    router.refresh_outputs(
        state,
        config,
        observed_path,
        vpn_path,
        runtime_config_path,
        policy_path=policy_path,
    )
    payload = json.loads(runtime_config_path.read_text(encoding="utf-8"))
    tags = [r["tag"] for r in payload["route"]["rules"]]
    assert "vpn-policy-direct" in tags
    assert "vpn-split-router-managed" in tags


def test_command_policy_add_direct(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    args = SimpleNamespace(policy=policy_path, targets=["google.com", "youtube.com"])
    assert router.command_policy_add_direct(args) == 0
    policy = router.load_policy(policy_path)
    assert "google.com" in policy["always_direct"]["domains"]
    assert "youtube.com" in policy["always_direct"]["domains"]


def test_command_policy_add_vpn(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    args = SimpleNamespace(policy=policy_path, targets=["netflix.com"])
    assert router.command_policy_add_vpn(args) == 0
    policy = router.load_policy(policy_path)
    assert "netflix.com" in policy["always_vpn"]["domains"]


def test_command_policy_remove(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    policy_path.write_text(
        "always_direct:\n  domains:\n    - a.example\nalways_vpn:\n  domains:\n    - a.example\n",
        encoding="utf-8",
    )
    args = SimpleNamespace(policy=policy_path, targets=["a.example"])
    assert router.command_policy_remove(args) == 0
    policy = router.load_policy(policy_path)
    assert "a.example" not in policy["always_direct"]["domains"]
    assert "a.example" not in policy["always_vpn"]["domains"]


def test_command_policy_apply_creates_rollback_and_starts_timer(tmp_path, monkeypatch):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    rollback_path = tmp_path / "policy.yaml.rollback"
    policy_path.write_text("always_direct:\n  domains:\n    - x.example\n", encoding="utf-8")
    runtime_path = tmp_path / "config.json"
    runtime_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "tag": "vpn"}],
                "route": {"rules": []},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    subprocess_called = []
    monkeypatch.setattr(router.subprocess, "run", lambda *a, **kw: subprocess_called.append(a[0]))

    args = SimpleNamespace(
        policy=policy_path,
        policy_rollback=rollback_path,
        runtime_config=runtime_path,
    )
    assert router.command_policy_apply(args) == 0

    assert rollback_path.exists()
    assert rollback_path.read_text(encoding="utf-8") == policy_path.read_text(encoding="utf-8")
    assert any("vpn-policy-rollback.timer" in str(c) for c in subprocess_called)


def test_command_policy_apply_rejects_empty_policy(tmp_path):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    policy_path.write_text(
        "always_direct:\n  domains: []\nalways_vpn:\n  domains: []\n",
        encoding="utf-8",
    )
    args = SimpleNamespace(
        policy=policy_path,
        policy_rollback=tmp_path / "rollback.yaml",
        runtime_config=tmp_path / "cfg.json",
    )
    assert router.command_policy_apply(args) == 1


def test_command_policy_confirm_removes_backup_and_stops_timer(tmp_path, monkeypatch):
    router = _load_module()
    rollback_path = tmp_path / "policy.yaml.rollback"
    rollback_path.write_text("dummy\n", encoding="utf-8")

    subprocess_called = []
    monkeypatch.setattr(router.subprocess, "run", lambda *a, **kw: subprocess_called.append(a[0]))

    args = SimpleNamespace(policy=tmp_path / "policy.yaml", policy_rollback=rollback_path)
    assert router.command_policy_confirm(args) == 0

    assert not rollback_path.exists()
    assert any("stop" in str(c) for c in subprocess_called)


def test_command_policy_rollback_restores_from_backup(tmp_path, monkeypatch):
    router = _load_module()
    policy_path = tmp_path / "policy.yaml"
    rollback_path = tmp_path / "policy.yaml.rollback"
    policy_path.write_text("corrupted\n", encoding="utf-8")
    rollback_path.write_text("always_direct:\n  domains:\n    - saved.example\n", encoding="utf-8")
    runtime_path = tmp_path / "config.json"
    runtime_path.write_text(
        json.dumps(
            {
                "outbounds": [{"type": "wireguard", "tag": "vpn"}],
                "route": {"rules": []},
            }
        )
        + "\n",
        encoding="utf-8",
    )

    subprocess_called = []
    monkeypatch.setattr(router.subprocess, "run", lambda *a, **kw: subprocess_called.append(a[0]))

    args = SimpleNamespace(
        policy=policy_path,
        policy_rollback=rollback_path,
        runtime_config=runtime_path,
    )
    assert router.command_policy_rollback(args) == 0

    assert "saved.example" in policy_path.read_text(encoding="utf-8")
    assert not rollback_path.exists()
    assert any("stop" in str(c) for c in subprocess_called)


def test_command_policy_rollback_fails_without_backup(tmp_path):
    router = _load_module()
    args = SimpleNamespace(
        policy=tmp_path / "policy.yaml",
        policy_rollback=tmp_path / "nonexistent.rollback",
        runtime_config=tmp_path / "cfg.json",
    )
    assert router.command_policy_rollback(args) == 1
