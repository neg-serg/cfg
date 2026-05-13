"""Salt execution module: system service lifecycle.

Replaces _macros_service.jinja.
Each function returns a YAML STRING that templates inject via {{ }}.
"""

from __future__ import annotations
from _yaml_out import yaml_output, to_yaml as _to_yaml

from typing import Any

try:
    import yaml as _yaml
except ImportError:
    _yaml = None  # type: ignore[assignment]


def _to_yaml(obj: Any) -> str:
    """Convert Python dict to YAML string for inline injection in templates."""
    if _yaml is None:
        return str(obj)
    # Salt state YAML output — no document start marker, no flow style
    raw = _yaml.dump(obj, default_flow_style=False, allow_unicode=True)
    if raw.endswith("\n...\n"):
        raw = raw[:-4]
    return raw


def _host() -> dict[str, Any]:
    try:
        from _modules.common import get_host
        return get_host()
    except Exception:
        return {"user": "root", "home": "/root", "runtime_dir": "/run/user/1000"}


def _sysctl_env() -> list[str]:
    h = _host()
    return [
        f"XDG_RUNTIME_DIR: {h['runtime_dir']}",
        f"DBUS_SESSION_BUS_ADDRESS: unix:path={h['runtime_dir']}/bus",
    ]


def _render_env_block() -> str:
    env = _sysctl_env()
    return "".join(f"      - {e}\n" for e in env)


DEFAULT_RETRY = {"attempts": 3, "interval": 10}
DEFAULT_RETRY_ATTEMPTS = 3
DEFAULT_RETRY_INTERVAL = 10


def managed_resource_value(value: str) -> str:
    if value == "__CURRENT_USER__":
        return _host()["user"]
    return value


def env_block() -> str:
    return _render_env_block()


@yaml_output
def ensure_dir(name: str, path: str, mode: str | None = None,
               require: list[str] | None = None,
               user: str | None = None) -> str:
    u = user or _host().get("user", "root")
    obj = {
        name: {
            "file.directory": [
                {"name": path}, {"user": u}, {"group": u}, {"makedirs": True}
            ]
        }
    }
    args = obj[name]["file.directory"]
    if mode:
        args.append({"mode": mode})
    if require:
        args.append({"require": require})
    return _to_yaml(obj)


@yaml_output
def remove_native_unit(name: str, unit_path: str | None = None,
                       scope: str = "system") -> dict[str, Any]:
    home = _host().get("home", "/root")
    if unit_path is None:
        if scope == "user":
            unit_path = f"{home}/.config/systemd/user/{name}.service"
        else:
            unit_path = f"/etc/systemd/system/{name}.service"

    daemon_reload_onlyif = (
        "systemctl --user show-environment >/dev/null 2>&1"
        if scope == "user"
        else "test -e /run/systemd/system || test -e /etc/systemd/system"
    )

    daemon_reload = {
        f"{name}_native_unit_daemon_reload": {
            "cmd.run": [
                {"name": f"systemctl {'--user ' if scope == 'user' else ''}daemon-reload"},
                {"onlyif": daemon_reload_onlyif},
                {"onchanges": [{"file": f"{name}_native_unit_absent"}]},
            ]
        }
    }
    if scope == "user":
        daemon_reload[f"{name}_native_unit_daemon_reload"]["cmd.run"].append(
            {"runas": _host().get("user", "root")}
        )
        daemon_reload[f"{name}_native_unit_daemon_reload"]["cmd.run"].append(
            {"env": [e.split(": ", 1) for e in _sysctl_env()]}
        )

    return {
        f"{name}_native_unit_absent": {"file.absent": [{"name": unit_path}]},
        **daemon_reload,
    }


@yaml_output
@yaml_output
def remove_native_package(name: str, pkgs: list[str]) -> dict[str, Any]:
    return {
        f"{name}_native_package_removed": {
            "pkg.removed": [{"pkgs": list(pkgs)}]
        }
    }


@yaml_output
def ensure_running(name: str, service: str | None = None,
                   watch: list[str] | None = None) -> dict[str, Any]:
    svc = service or name
    return {
        f"{name}_reset_failed": {
            "cmd.run": [
                {"name": f"systemctl reset-failed {svc} 2>/dev/null; true"},
                {"onlyif": f"systemctl is-failed {svc}"},
                {"require": [{"service": f"{name}_enabled"}]},
            ]
        },
        f"{name}_running": {
            "service.running": [
                {"name": svc},
                {"require": [
                    {"service": f"{name}_enabled"},
                    {"cmd": f"{name}_reset_failed"},
                ]},
                *([{"watch": [{"file": w} for w in watch]}] if watch else []),
            ]
        },
    }


@yaml_output
def service_stopped(name: str, svc: str, stop: bool = True,
                    requires: list[str] | None = None,
                    onlyif: str | None = None) -> dict[str, Any]:
    if stop:
        base: dict[str, list[dict[str, Any]]] = {
            "service.dead": [{"name": svc}, {"enable": False}]
        }
    else:
        base = {"service.disabled": [{"name": svc}]}

    if onlyif:
        list(base.values())[0].append({"onlyif": onlyif})
    if requires:
        list(base.values())[0].append({"require": [r for r in requires]})

    return {name: base}


@yaml_output
@yaml_output
def service_with_healthcheck(name: str, service: str,
                              check_cmd: str | None = None,
                              timeout: int = 30,
                              requires: list[str] | None = None,
                              catalog: dict[str, Any] | None = None,
                              user_scope: bool = False,
                              user: str | None = None) -> dict[str, Any]:
    """Resolve healthcheck command and emit cmd.run."""
    actual_cmd = check_cmd
    actual_timeout = timeout
    u = user or _host().get("user", "root")

    if actual_cmd is None and catalog is not None and service in catalog:
        entry = catalog[service]
        if entry.get("health_cmd"):
            actual_cmd = entry["health_cmd"]
        elif entry.get("port") and entry.get("health_path"):
            h = entry.get("health_host", "127.0.0.1")
            actual_cmd = (
                f"curl -sf http://{h}:{entry['port']}{entry['health_path']}"
                f" >/dev/null 2>&1"
            )
        if entry.get("timeout"):
            actual_timeout = entry["timeout"]

    if not actual_cmd:
        actual_cmd = "/usr/bin/true"

    shell_cmd = (
        f"set -euo pipefail\n"
        f"if ! systemctl {'--user ' if user_scope else ''}is-active --quiet {service}; then\n"
        f"  systemctl {'--user ' if user_scope else ''}daemon-reload\n"
        f"  systemctl {'--user ' if user_scope else ''}restart {service}\n"
        f"fi\n"
        f"for i in $(seq 1 {actual_timeout}); do\n"
        f"  {actual_cmd} && exit 0\n"
        f"  sleep 1\n"
        f"done\n"
        f"echo \"{service} failed to start within {actual_timeout}s\" >&2\n"
        f"exit 1"
    )

    ret: dict[str, Any] = {
        name: {
            "cmd.run": [
                {"name": shell_cmd},
                {"shell": "/bin/bash"},
                {"unless": actual_cmd},
            ]
        }
    }

    if user_scope:
        ret[name]["cmd.run"].append({"runas": u})
        ret[name]["cmd.run"].append({"env": [e.split(": ", 1) for e in _sysctl_env()]})

    if requires:
        ret[name]["cmd.run"].append({"require": [r for r in requires]})

    return ret


@yaml_output
def unit_override(name: str, service: str, source: str,
                  filename: str = "override.conf",
                  requires: list[str] | None = None) -> dict[str, Any]:
    ret: dict[str, Any] = {
        name: {
            "file.managed": [
                {"name": f"/etc/systemd/system/{service}.d/{filename}"},
                {"source": source},
                {"makedirs": True},
                {"mode": "0644"},
            ]
        },
        f"{name}_reload": {
            "cmd.run": [
                {"name": "systemctl daemon-reload"},
                {"onchanges": [{"file": name}]},
            ]
        },
    }
    if requires:
        ret[name]["file.managed"].append({"require": [r for r in requires]})
    return ret


@yaml_output
def service_with_unit(name: str, source: str, unit_type: str = "service",
                      running: bool = False, enabled: bool = True,
                      requires: list[str] | None = None,
                      template: str | None = None,
                      context: dict[str, Any] | None = None,
                      onlyif: str | None = None,
                      companion: str | None = None,
                      watch: list[str] | None = None) -> dict[str, Any]:
    """Generate complete systemd unit + service lifecycle states."""
    ret: dict[str, Any] = {}

    # Unit file
    fargs: dict[str, Any] = {
        f"{name}_service": {
            "file.managed": [
                {"name": f"/etc/systemd/system/{name}.{unit_type}"},
                {"mode": "0644"},
                {"source": source},
            ]
        }
    }
    if template:
        list(fargs.values())[0]["file.managed"].append({"template": template})
    if context:
        ctx_list = [{"context": []}]
        for k, v in context.items():
            ctx_list[0]["context"].append({k: v})
        list(fargs.values())[0]["file.managed"].extend(ctx_list)
    ret.update(fargs)

    # Companion unit (timer+service pairs)
    if companion:
        comp_type = "service" if unit_type != "service" else "timer"
        ret[f"{name}_companion"] = {
            "file.managed": [
                {"name": f"/etc/systemd/system/{name}.{comp_type}"},
                {"mode": "0644"},
                {"source": companion},
            ]
        }

    # Daemon reload
    reload_requires = [{"file": f"{name}_service"}]
    if companion:
        reload_requires.append({"file": f"{name}_companion"})

    ret[f"{name}_daemon_reload"] = {
        "cmd.run": [
            {"name": "systemctl daemon-reload"},
            {"onlyif": "test -e /run/systemd/system || test -e /etc/systemd/system"},
            {"onchanges": reload_requires},
        ]
    }

    # Enable/disable
    if enabled is not None:
        svc_state = "enabled" if enabled else "disabled"
        svc_args: list[dict[str, Any]] = [
            {"name": f"{name}.{unit_type}"},
            {"require": [{"cmd": f"{name}_daemon_reload"}]},
        ]
        if onlyif and enabled:
            svc_args.append({"onlyif": onlyif})
        if requires:
            svc_args.append({"require": [{"cmd": f"{name}_daemon_reload"}, *requires]})
        ret[f"{name}_{svc_state}"] = {f"service.{svc_state}": svc_args}

    # Running
    if running:
        ret[f"{name}_reset_failed"] = {
            "cmd.run": [
                {"name": f"systemctl reset-failed {name}.{unit_type} 2>/dev/null; true"},
                {"onlyif": f"systemctl is-failed {name}.{unit_type}"},
                {"require": [{"service": f"{name}_enabled"}]},
            ]
        }

        running_args: list[dict[str, Any]] = [
            {"name": f"{name}.{unit_type}"},
            {"watch": [{"file": f"{name}_service"}, *[{"file": w} for w in (watch or [])]]},
            {"require": [
                {"service": f"{name}_enabled"},
                {"cmd": f"{name}_reset_failed"},
            ]},
        ]
        ret[f"{name}_running"] = {"service.running": running_args}

    return ret


def render_service(name: str, opts: dict[str, Any], feature_flag: bool,
                   section_label: str, known_vars: dict[str, Any]) -> dict[str, Any]:
    """Data-driven service renderer — replaces render_service() macro."""
    if not feature_flag:
        return {}

    ret: dict[str, Any] = {}

    # Cleanup
    if "cleanup" in opts:
        ret[f"{name}_cleanup"] = {
            "file.absent": [
                {"names": list(opts["cleanup"]["paths"])},
                {"onlyif": opts["cleanup"]["onlyif"]},
            ]
        }

    # Packages (skip if simple_service handles it)
    if "packages" in opts and not ("service" in opts and "unit" not in opts):
        pkg_name = name.replace("-", "_")
        pkgs = opts["packages"]
        ret[f"install_{pkg_name}"] = {
            "cmd.run": [
                {"name": f"paru -S --noconfirm --needed {pkgs}"},
                {"require": [{"cmd": "pacman_db_warmup"}]},
            ]
        }

    # Dirs
    if "dirs" in opts:
        for i, d in enumerate(opts["dirs"]):
            ret.update(ensure_dir(f"{name}_dir_{i}", d["path"], mode=d.get("mode"),
                                  require=d.get("require")))

    # Configs
    if "config_templates" in opts:
        for i, ct in enumerate(opts["config_templates"]):
            ctx = {}
            for k, v in ct.get("context", {}).items():
                ctx[k] = known_vars.get(v, v)
            ct_req = []
            if "packages" in opts:
                ct_req.append(f"cmd: install_{name.replace('-', '_')}")
            ct_req.extend(ct.get("require", []))
            cfg = {
                f"{name}_config_{i}": {
                    "file.managed": [
                        {"name": ct["dest"]},
                        {"source": ct["source"]},
                        {"mode": ct.get("mode", "0644")},
                    ]
                }
            }
            if ct.get("makedirs"):
                cfg[f"{name}_config_{i}"]["file.managed"].append({"makedirs": True})
            if ct.get("template", "jinja"):
                cfg[f"{name}_config_{i}"]["file.managed"].append({"template": "jinja"})
            if ctx:
                cfg[f"{name}_config_{i}"]["file.managed"].append({"context": [ctx]})
            if ct_req:
                cfg[f"{name}_config_{i}"]["file.managed"].append({"require": ct_req})
            ret.update(cfg)

    # Unit
    if "unit" in opts:
        u = opts["unit"]
        unit_ctx = {}
        for k, v in u.get("unit_context", {}).items():
            unit_ctx[k] = known_vars.get(v, v)
        unit_req = []
        if "packages" in opts:
            unit_req.append(f"cmd: install_{name.replace('-', '_')}")
        unit_req.extend(u.get("requires", []))
        ret.update(service_with_unit(
            name, u["source"],
            unit_type=u.get("type", "service"),
            enabled=u.get("enabled", True),
            running=u.get("running", False),
            companion=u.get("companion"),
            template=u.get("template"),
            context=unit_ctx if unit_ctx else None,
            requires=unit_req if unit_req else None,
        ))

    return ret



@yaml_output
def render_service_yaml(name: str, opts: dict, feature_flag: bool,
                        section_label: str, known_vars: dict) -> str:
    """Public entry — data-driven service renderer.

    Replaces render_service() macro. Returns YAML string for {{ }} injection.
    """
    if not feature_flag:
        return ""

    ret: dict = {}

    # Cleanup
    if "cleanup" in opts:
        ret[f"{name}_cleanup"] = {
            "file.absent": [
                {"names": list(opts["cleanup"]["paths"])},
                {"onlyif": opts["cleanup"]["onlyif"]},
            ]
        }

    # Packages
    if "packages" in opts and not ("service" in opts and "unit" not in opts):
        safe = name.replace("-", "_")
        ret[f"install_{safe}"] = {
            "cmd.run": [
                {"name": f"paru -S --noconfirm --needed {opts['packages']}"},
                {"require": [{"cmd": "pacman_db_warmup"}]},
            ]
        }

    # Dirs
    if "dirs" in opts:
        for i, d in enumerate(opts["dirs"]):
            u = d.get("user", "root")
            args: list = [{"name": d["path"]}, {"user": u}, {"group": u}, {"makedirs": True}]
            if d.get("mode"):
                args.append({"mode": d["mode"]})
            if d.get("require"):
                args.append({"require": d["require"]})
            ret[f"{name}_dir_{i}"] = {"file.directory": args}

    # Scripts
    if "scripts" in opts:
        for i, s in enumerate(opts["scripts"]):
            ret[f"{name}_script_{i}"] = {
                "file.managed": [
                    {"name": s["dest"]}, {"mode": "0755"}, {"source": s["source"]},
                ]
            }

    # Config templates
    if "config_templates" in opts:
        for i, ct in enumerate(opts["config_templates"]):
            ctx = {}
            for k, v in ct.get("context", {}).items():
                ctx[k] = known_vars.get(v, v)
            reqs = list(ct.get("require", []))
            if "packages" in opts:
                reqs.insert(0, f"cmd: install_{name.replace('-', '_')}")
            cfg: dict = {f"{name}_config_{i}": {"file.managed": [
                {"name": ct["dest"]}, {"source": ct["source"]}, {"mode": ct.get("mode", "0644")},
            ]}}
            if ct.get("makedirs"):
                cfg[f"{name}_config_{i}"]["file.managed"].append({"makedirs": True})
            if ct.get("template", "jinja"):
                cfg[f"{name}_config_{i}"]["file.managed"].append({"template": "jinja"})
            if ctx:
                cfg[f"{name}_config_{i}"]["file.managed"].append({"context": [ctx]})
            if reqs:
                cfg[f"{name}_config_{i}"]["file.managed"].append({"require": reqs})
            ret.update(cfg)

    # Setup commands
    if "setup_commands" in opts:
        for i, sc in enumerate(opts["setup_commands"]):
            sc_args: list = [{"name": sc["name"]}]
            if sc.get("creates"):
                sc_args.append({"creates": sc["creates"]})
            elif sc.get("onlyif"):
                sc_args.append({"onlyif": sc["onlyif"]})
            else:
                sc_args.append({"creates": f"/var/cache/salt/setup-{name}-{i}.stamp"})
            if "packages" in opts:
                sc_args.append({"require": [{"cmd": f"install_{name.replace('-', '_')}"}]})
            ret[f"{name}_setup_{i}"] = {"cmd.run": sc_args}

    # Unit
    if "unit" in opts:
        u = opts["unit"]
        uctx = {}
        for k, v in u.get("unit_context", {}).items():
            uctx[k] = known_vars.get(v, v)
        ureqs = list(u.get("requires", []))
        if "packages" in opts:
            ureqs.insert(0, f"cmd: install_{name.replace('-', '_')}")
        ret.update(_yaml_unit(name, u, template_ctx=uctx, requires=ureqs))

    # Simple service fallback
    if "service" in opts and "unit" not in opts and "packages" in opts:
        svc = opts["service"]
        ret.update(_yaml_simple_service(name, svc))

    # Manual start
    if "manual_start" in opts:
        ms = opts["manual_start"]
        ms_reqs = []
        if "config_templates" in opts:
            for ci in range(len(opts["config_templates"])):
                ms_reqs.append(f"file: {name}_config_{ci}")
        ret.update(_yaml_stopped(f"{name}_not_enabled", ms["service"],
                                 stop=ms.get("stop", False), requires=ms_reqs or None))

    # Unit override
    if "unit_override" in opts:
        uo = opts["unit_override"]
        ret.update(_yaml_unit_overlay(uo["name"], uo["service"], uo["source"],
                                      requires=[f"cmd: install_{name.replace('-', '_')}"]))

    # Ensure running
    if "ensure_running" in opts:
        er = opts["ensure_running"]
        ret.update(_yaml_run(name, er["service"], watch=er.get("watch")))

    # Logrotate
    if "logrotate" in opts:
        ret[f"{name}_logrotate"] = {
            "file.managed": [{"name": f"/etc/logrotate.d/{name}"}, {"mode": "0644"}, {"source": opts["logrotate"]["source"]}]
        }

    # Healthcheck
    if "healthcheck" in opts:
        hc = opts["healthcheck"]
        ret.update(_yaml_healthcheck(f"{name}_start", name, hc["command"], requires=hc.get("requires")))

    return _to_yaml(ret)


# ── Internal dict-level helpers for render_service_yaml ──────────────

def _yaml_unit(name: str, u: dict, template_ctx: dict | None = None,
               requires: list[str] | None = None) -> dict:
    ret = {f"{name}_service": {"file.managed": [
        {"name": f"/etc/systemd/system/{name}.{u.get('type', 'service')}"},
        {"mode": "0644"}, {"source": u["source"]},
    ]}}
    if u.get("template"):
        ret[f"{name}_service"]["file.managed"].append({"template": u["template"]})
    if template_ctx:
        ret[f"{name}_service"]["file.managed"].append({"context": [template_ctx]})

    w = [{"file": f"{name}_service"}]
    comp = u.get("companion")
    if comp:
        ct = "service" if u.get("type", "service") != "service" else "timer"
        ret[f"{name}_companion"] = {"file.managed": [
            {"name": f"/etc/systemd/system/{name}.{ct}"}, {"mode": "0644"}, {"source": comp},
        ]}
        w.append({"file": f"{name}_companion"})

    ret[f"{name}_daemon_reload"] = {"cmd.run": [
        {"name": "systemctl daemon-reload"},
        {"onlyif": "test -e /run/systemd/system || test -e /etc/systemd/system"},
        {"onchanges": w},
    ]}

    en = u.get("enabled", True)
    if en is not None:
        s = "enabled" if en else "disabled"
        ret[f"{name}_{s}"] = {f"service.{s}": [
            {"name": f"{name}.{u.get('type', 'service')}"},
            {"require": [{"cmd": f"{name}_daemon_reload"}]},
        ]}

    if u.get("running"):
        ret[f"{name}_reset_failed"] = {"cmd.run": [
            {"name": f"systemctl reset-failed {name}.{u.get('type', 'service')} 2>/dev/null; true"},
            {"onlyif": f"systemctl is-failed {name}.{u.get('type', 'service')}"},
            {"require": [{"service": f"{name}_enabled"}]},
        ]}
        ret[f"{name}_running"] = {"service.running": [
            {"name": f"{name}.{u.get('type', 'service')}"},
            {"watch": w + [{"file": ww} for ww in (u.get("watch") or [])]},
            {"require": [{"service": f"{name}_enabled"}, {"cmd": f"{name}_reset_failed"}]},
        ]}

    return ret


def _yaml_simple_service(name: str, service_name: str) -> dict:
    safe = name.replace("-", "_")
    return {f"{name}_enabled": {
        "service.enabled": [
            {"name": service_name},
            {"require": [{"cmd": f"install_{safe}"}]},
        ]
    }}


def _yaml_stopped(name: str, svc: str, stop: bool = True,
                  requires: list[str] | None = None) -> dict:
    key = "service.dead" if stop else "service.disabled"
    args: list = [{"name": svc}]
    if stop:
        args.append({"enable": False})
    if requires:
        args.append({"require": requires})
    return {name: {key: args}}


def _yaml_unit_overlay(name: str, service: str, source: str,
                       requires: list[str] | None = None) -> dict:
    ret = {name: {"file.managed": [
        {"name": f"/etc/systemd/system/{service}.d/override.conf"},
        {"source": source}, {"makedirs": True}, {"mode": "0644"},
    ]}, f"{name}_reload": {"cmd.run": [
        {"name": "systemctl daemon-reload"},
        {"onchanges": [{"file": name}]},
    ]}}
    if requires:
        ret[name]["file.managed"].append({"require": requires})
    return ret


def _yaml_run(name: str, service: str | None = None,
              watch: list[str] | None = None) -> dict:
    svc = service or name
    return {f"{name}_reset_failed": {"cmd.run": [
        {"name": f"systemctl reset-failed {svc} 2>/dev/null; true"},
        {"onlyif": f"systemctl is-failed {svc}"},
        {"require": [{"service": f"{name}_enabled"}]},
    ]}, f"{name}_running": {"service.running": [
        {"name": svc},
        {"watch": [{"file": w} for w in (watch or [])]},
        {"require": [{"service": f"{name}_enabled"}, {"cmd": f"{name}_reset_failed"}]},
    ]}}


def _yaml_healthcheck(name: str, svc: str, cmd: str,
                      requires: list[str] | None = None,
                      timeout: int = 30) -> dict:
    ret = {name: {"cmd.run": [
        {"name": f"set -euo pipefail\nif ! systemctl is-active --quiet {svc}; then\n"
                f"  systemctl daemon-reload\n  systemctl restart {svc}\nfi\n"
                f"for i in $(seq 1 {timeout}); do\n"
                f"  {cmd} && exit 0\n  sleep 1\ndone\n"
                f'echo "{svc} failed to start within {timeout}s" >&2\nexit 1'},
        {"shell": "/bin/bash"}, {"unless": cmd},
    ]}}
    if requires:
        ret[name]["cmd.run"].append({"require": requires})
    return ret


@yaml_output
def ipv6_tunnel(name: str,
                interface: str,
                service_name: str,
                service_template: str,
                service_context: dict | None = None,
                firewall_table: str = "ipv6-tunnel",
                firewall_rules: str = "",
                sysctl_config: str = "",
                enable_healthcheck: bool = False) -> str:
    """Deploy IPv6 tunnel — replaces ipv6_tunnel() macro."""
    ret: dict = {}
    ctx = service_context or {}
    fw = len(firewall_rules) > 0
    sc = len(sysctl_config) > 0
    svc_requires: list[str] = []
    svc_watch: list[str] = []

    if fw:
        svc_requires.append(f"cmd: {name}_firewall_apply")
        ret[f"{name}_firewall"] = {"file.managed": [
            {"name": f"/etc/nftables/{firewall_table}.conf"}, {"mode": "0644"},
            {"makedirs": True}, {"contents": firewall_rules},
        ]}
        ret[f"{name}_firewall_apply"] = {"cmd.run": [
            {"name": f"set -euo pipefail\nif command -v nft &>/dev/null; then\n"
                    f"  nft -f /etc/nftables/{firewall_table}.conf 2>/dev/null || "
                    f"{{ nft delete table inet {firewall_table} 2>/dev/null || true; "
                    f"nft -f /etc/nftables/{firewall_table}.conf; }}\n"
                    f"elif command -v ip6tables &>/dev/null; then\n"
                    f"  ip6tables -I INPUT -i {interface} -p icmpv6 -j ACCEPT 2>/dev/null || true\nfi"},
            {"shell": "/bin/bash"},
            {"onchanges": [{"file": f"{name}_firewall"}]},
        ]}

    if sc:
        svc_watch.append(f"file: {name}_sysctl")
        ret[f"{name}_sysctl"] = {"file.managed": [
            {"name": f"/etc/sysctl.d/99-{name}.conf"}, {"mode": "0644"}, {"contents": sysctl_config},
        ]}
        ret[f"{name}_sysctl_apply"] = {"cmd.run": [
            {"name": "sysctl --system"},
            {"onchanges": [{"file": f"{name}_sysctl"}]},
        ]}

    # Unit
    u_data = _yaml_unit(service_name, {
        "source": service_template, "type": "service", "template": "jinja",
        "unit_context": ctx, "enabled": True, "running": True,
        "watch": svc_watch or None, "requires": svc_requires or None,
    })
    ret.update(u_data)

    if enable_healthcheck:
        ret[f"{name}_healthcheck"] = {"cmd.run": [
            {"name": f"set -euo pipefail\nfor i in $(seq 1 30); do\n"
                    f"  ip -6 addr show {interface} 2>/dev/null | grep -q 'inet6' && exit 0\n"
                    f"  sleep 1\n"
                    f"done\n"
                    f'echo "Tunnel {name}: no IPv6 address after 30s" >&2\nexit 1'},
            {"shell": "/bin/bash"},
            {"unless": f"ip -6 addr show {interface} 2>/dev/null | grep -q 'inet6'"},
            {"require": [{"service": f"{service_name}_enabled"}]},
        ]}

    return _to_yaml(ret)
