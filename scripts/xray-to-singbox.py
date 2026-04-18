#!/usr/bin/env python3
"""
Convert Xray configuration to sing-box configuration.
Usage: xray-to-singbox.py <input.json> <output.json>
"""

import json
import sys


def convert_xray_to_singbox(xray_config):
    """Convert Xray config to sing-box config (TUN + SOCKS)."""
    sb_config = {
        "log": {"level": "info"},
        "dns": {
            "servers": [
                {"type": "tls", "tag": "google", "server": "1.1.1.1"},
                {"type": "udp", "tag": "local", "server": "223.5.5.5"},
            ],
            "strategy": "ipv4_only",
        },
        "inbounds": [],
        "outbounds": [],
        "route": {
            "rules": [
                {"protocol": "dns", "outbound": "direct"},
                {"ip_is_private": True, "outbound": "direct"},
                {"domain": ["geosite:category-ads-all"], "action": "reject"},
            ],
            "auto_detect_interface": True,
            "final": "proxy",
        },
        "experimental": {},
    }

    # Add TUN inbound (for split routing)
    sb_config["inbounds"].append(
        {
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "sb0",
            "address": ["172.19.0.1/30", "fd00::1/126"],
            "mtu": 1500,
            "stack": "mixed",
            "auto_route": True,
            "strict_route": False,
            "endpoint_independent_nat": True,
        }
    )

    # Also keep SOCKS inbound from Xray config for testing
    for inbound in xray_config.get("inbounds", []):
        if inbound.get("protocol") == "socks":
            sb_inbound = {
                "type": "socks",
                "tag": "socks-in",
                "listen": inbound.get("listen", "127.0.0.1"),
                "listen_port": inbound.get("port", 10808),
            }
            sb_config["inbounds"].append(sb_inbound)
            break  # only first SOCKS inbound

    # Convert outbounds
    for outbound in xray_config.get("outbounds", []):
        if outbound.get("protocol") == "vless":
            vnext = outbound.get("settings", {}).get("vnext", [])
            if not vnext:
                continue
            server = vnext[0]
            users = server.get("users", [])
            if not users:
                continue
            user = users[0]

            stream_settings = outbound.get("streamSettings", {})
            reality_settings = stream_settings.get("realitySettings", {})

            # Map fingerprint
            fingerprint = reality_settings.get("fingerprint", "chrome")
            if fingerprint == "random":
                fingerprint = "randomized"

            sb_outbound = {
                "type": "vless",
                "tag": "proxy",
                "server": server.get("address", ""),
                "server_port": server.get("port", 443),
                "uuid": user.get("id", ""),
                "flow": user.get("flow", ""),
                "tls": {
                    "enabled": True,
                    "server_name": reality_settings.get("serverName", ""),
                    "utls": {"enabled": True, "fingerprint": fingerprint},
                    "reality": {
                        "enabled": True,
                        "public_key": reality_settings.get("publicKey", ""),
                        "short_id": reality_settings.get("shortId", ""),
                    },
                },
            }

            # Map network type to transport
            network = stream_settings.get("network", "tcp")
            if network == "xhttp":
                # Xray's xhttp transport -> sing-box http transport
                http_settings = stream_settings.get("httpSettings", {})
                host = http_settings.get("host", [])
                # Xray may use string host, convert to list
                if isinstance(host, str):
                    host = [host] if host else []
                path = http_settings.get("path", "/")
                # Ensure path ends with / for stream-one mode (REALITY)
                security = stream_settings.get("security", "none")
                method = http_settings.get("method", "GET")
                headers = http_settings.get("headers", {})
                if security == "reality":
                    # stream-one mode uses POST and gRPC content-type
                    method = "POST"
                    if not path.endswith("/"):
                        path += "/"
                    headers["Content-Type"] = "application/grpc"
                sb_outbound["transport"] = {
                    "type": "http",
                    "host": host,
                    "path": path,
                    "method": method,
                    "headers": headers,
                    "idle_timeout": "15s",
                    "ping_timeout": "15s",
                }
            elif network == "ws":
                sb_outbound["transport"] = {
                    "type": "ws",
                    "path": stream_settings.get("wsSettings", {}).get("path", "/"),
                    "headers": stream_settings.get("wsSettings", {}).get("headers", {}),
                }
            elif network == "grpc":
                sb_outbound["transport"] = {
                    "type": "grpc",
                    "service_name": stream_settings.get("grpcSettings", {}).get("serviceName", ""),
                }
            else:
                sb_outbound["transport"] = {"type": "tcp"}

            sb_config["outbounds"].append(sb_outbound)
            break  # only first vless outbound

    # Add direct outbound
    sb_config["outbounds"].append({"type": "direct", "tag": "direct"})

    # Add sniff rule for socks inbound
    sb_config["route"]["rules"].append({"inbound": "socks-in", "action": "sniff", "timeout": "1s"})
    # Add sniff rule for tun inbound
    sb_config["route"]["rules"].append({"inbound": "tun-in", "action": "sniff", "timeout": "1s"})

    # Add default domain resolver to avoid deprecation warning
    sb_config["route"]["default_domain_resolver"] = "local"

    return sb_config


def main():
    if len(sys.argv) != 3:
        print("Usage: xray-to-singbox.py <input.json> <output.json>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    try:
        with open(input_path, "r", encoding="utf-8") as f:
            xray_config = json.load(f)
    except Exception as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        sys.exit(1)

    sb_config = convert_xray_to_singbox(xray_config)

    try:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(sb_config, f, indent=2, ensure_ascii=False)
        print(f"Converted configuration written to {output_path}")
    except Exception as e:
        print(f"Error writing output file: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
