import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace

REPO_ROOT = Path(__file__).resolve().parent.parent
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
    )

    assert router.command_recheck(args) == 0

    final_state = json.loads(state_path.read_text(encoding="utf-8"))
    assert "stale.example" not in final_state["domains"]
    assert observed_path.read_text(encoding="utf-8") == ""
