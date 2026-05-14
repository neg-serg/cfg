"""Salt execution module: IPv6 tunnel deployment.

Replaces _macros_ipv6_tunnel.jinja.
Generates nftables firewall + sysctl + systemd unit states.
"""

from __future__ import annotations

from typing import Any

try:
    from _yaml_out import to_yaml as _to_yaml
except ImportError:

    def _to_yaml(obj: Any) -> str:
        return str(obj)


try:
    from _modules.common import _parse_requires
except ImportError:

    def _parse_requires(requires):
        if not requires:
            return []
        parsed = []
        for r in requires:
            if isinstance(r, str) and ": " in r:
                typ, rid = r.split(": ", 1)
                parsed.append({typ: rid})
            elif isinstance(r, dict):
                parsed.append(r)
            else:
                parsed.append(r)
        return parsed


def _host() -> dict[str, Any]:
    try:
        return __salt__["common.get_host"]()
    except (NameError, KeyError):
        try:
            from _modules.common import get_host

            return get_host()
        except Exception:
            return {
                "user": "root",
                "home": "/root",
                "systemd_unit_dir": "/etc/systemd/system/",
                "nftables_dir": "/etc/nftables/",
                "sysctl_dir": "/etc/sysctl.d/",
            }


def deploy(
    name: str,
    interface: str,
    service_name: str,
    service_template: str,
    service_context: dict[str, Any] | None = None,
    firewall_table: str = "ipv6-tunnel",
    firewall_rules: str = "",
    sysctl_config: str = "",
    enable_healthcheck: bool = False,
) -> str:
    """Deploy IPv6 tunnel: nftables + sysctl + systemd unit."""
    h = _host()
    parts: list[str] = []

    fw_path = f"{h.get('nftables_dir', '/etc/nftables/')}{firewall_table}.conf"
    has_fw = len(firewall_rules) > 0
    has_sys = len(sysctl_config) > 0
    svc_req: list[str] = []
    svc_watch: list[str] = []

    if has_fw:
        svc_req.append({"cmd": f"{name}_firewall_apply"})
        parts.append(
            _to_yaml(
                {
                    f"{name}_firewall": {
                        "file.managed": [
                            {"name": fw_path},
                            {"mode": "0644"},
                            {"makedirs": True},
                            {"contents": firewall_rules.strip()},
                        ]
                    },
                    f"{name}_firewall_apply": {
                        "cmd.run": [
                            {
                                "name": (
                                    "set -euo pipefail\n"
                                    "if command -v nft &>/dev/null; then\n"
                                    f"  nft -f {fw_path} 2>/dev/null || "
                                    f"{{ nft delete table inet {firewall_table}"
                                    f" 2>/dev/null || true; "
                                    f"nft -f {fw_path}; }}\n"
                                    f"elif command -v ip6tables &>/dev/null; then\n"
                                    f"  ip6tables -I INPUT -i {interface} "
                                    f"-p icmpv6 -j ACCEPT 2>/dev/null || true\n"
                                    f"  ip6tables -I FORWARD -i {interface} "
                                    f"-p icmpv6 -j ACCEPT 2>/dev/null || true\n"
                                    f"  ip6tables -I INPUT -i {interface} -m state --state "
                                    f"ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true\n"
                                    f"  ip6tables -I FORWARD -i {interface} -m state --state "
                                    f"ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true\n"
                                    "fi"
                                )
                            },
                            {"shell": "/bin/bash"},
                            {"onchanges": [{"file": f"{name}_firewall"}]},
                        ]
                    },
                }
            )
        )

    if has_sys:
        svc_watch = [{"file": f"{name}_sysctl"}]
        sysctl_path = f"{h.get('sysctl_dir', '/etc/sysctl.d/')}99-{name}.conf"
        parts.append(
            _to_yaml(
                {
                    f"{name}_sysctl": {
                        "file.managed": [
                            {"name": sysctl_path},
                            {"mode": "0644"},
                            {"contents": sysctl_config.strip()},
                        ]
                    },
                    f"{name}_sysctl_apply": {
                        "cmd.run": [
                            {"name": "sysctl --system"},
                            {"onchanges": [{"file": f"{name}_sysctl"}]},
                        ]
                    },
                }
            )
        )

    # Service unit via service_with_unit (already Python-powered)
    svc_parts = _service_with_unit(
        service_name,
        service_template,
        running=True,
        enabled=True,
        template="jinja",
        context=service_context or {},
        requires=svc_req if svc_req else None,
        watch=svc_watch if svc_watch else None,
    )
    parts.append(_to_yaml(svc_parts))

    if enable_healthcheck:
        parts.append(
            _to_yaml(
                {
                    f"{name}_healthcheck": {
                        "cmd.run": [
                            {
                                "name": (
                                    "set -euo pipefail\n"
                                    f"for i in $(seq 1 30); do\n"
                                    f"  ip -6 addr show {interface} 2>/dev/null"
                                    f" | grep -q 'inet6' && exit 0\n"
                                    "  sleep 1\n"
                                    "done\n"
                                    f'echo "Tunnel {name}: no IPv6 address after 30s" >&2\n'
                                    "exit 1"
                                )
                            },
                            {"shell": "/bin/bash"},
                            {
                                "unless": (
                                    f"ip -6 addr show {interface} 2>/dev/null | grep -q 'inet6'"
                                )
                            },
                            {"require": [{"service": f"{service_name}_enabled"}]},
                        ]
                    }
                }
            )
        )

    return "\n".join(parts)


def _service_with_unit(
    name: str,
    source: str,
    unit_type: str = "service",
    running: bool = False,
    enabled: bool = True,
    requires: list[str] | None = None,
    template: str | None = None,
    context: dict[str, Any] | None = None,
    watch: list[str] | None = None,
) -> dict[str, Any]:
    """Generate systemd unit states (inline to avoid circular imports)."""
    h = _host()
    sysd_dir = h.get("systemd_unit_dir", "/etc/systemd/system/")
    ret: dict[str, Any] = {
        f"{name}_service": {
            "file.managed": [
                {"name": f"{sysd_dir}{name}.{unit_type}"},
                {"mode": "0644"},
                {"source": source},
            ]
        }
    }
    if template:
        list(ret.values())[0]["file.managed"].append({"template": template})
    if context:
        list(ret.values())[0]["file.managed"].append({"context": context})

    ret[f"{name}_daemon_reload"] = {
        "cmd.run": [
            {"name": "systemctl daemon-reload"},
            {"onlyif": "test -e /run/systemd/system || test -e /etc/systemd/system"},
            {"onchanges": [{"file": f"{name}_service"}]},
        ]
    }

    if enabled is not None:
        svc_state = "enabled" if enabled else "disabled"
        svc_args: list[dict[str, Any]] = [
            {"name": f"{name}.{unit_type}"},
            {"require": [{"cmd": f"{name}_daemon_reload"}]},
        ]
        ret[f"{name}_{svc_state}"] = {f"service.{svc_state}": svc_args}

    if running:
        ret[f"{name}_reset_failed"] = {
            "cmd.run": [
                {"name": f"systemctl reset-failed {name}.{unit_type} 2>/dev/null; true"},
                {"onlyif": f"systemctl is-failed {name}.{unit_type}"},
                {"require": [{"service": f"{name}_enabled"}]},
            ]
        }
        run_args: list[dict[str, Any]] = [
            {"name": f"{name}.{unit_type}"},
            {"watch": [{"file": f"{name}_service"}, *(watch or [])]},
            {
                "require": [
                    {"service": f"{name}_enabled"},
                    {"cmd": f"{name}_reset_failed"},
                ]
            },
        ]
        if requires:
            run_args[2]["require"].extend(_parse_requires(requires))
        ret[f"{name}_running"] = {"service.running": run_args}

    return ret
