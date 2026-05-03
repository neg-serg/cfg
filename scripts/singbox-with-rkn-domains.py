#!/usr/bin/env python3
"""
Generate sing-box config with RKN domains integration.
"""

import argparse
import json
import sys
from pathlib import Path

from _rkn_utils import load_rkn_domains


def generate_singbox_config(
    base_config_path: Path,
    domains: list[str],
    output_path: Path,
    max_domains: int = 1000,
) -> None:
    """Generate sing-box config with RKN domains."""

    # Load base config
    with open(base_config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    # Limit domains for performance
    if len(domains) > max_domains:
        print(f"Limiting domains from {len(domains)} to {max_domains} for performance")
        domains = domains[:max_domains]

    # Add RKN domains rule to route section
    if "route" not in config:
        config["route"] = {}

    if "rules" not in config["route"]:
        config["route"]["rules"] = []

    # Create rule for RKN domains
    rkn_rule = {
        "domain": domains,
        "outbound": "proxy",
    }

    # Insert RKN rule after DNS rule but before catch-all
    rules = config["route"]["rules"]

    # Find position after DNS rule
    insert_pos = 0
    for i, rule in enumerate(rules):
        if rule.get("protocol") == "dns":
            insert_pos = i + 1
            break

    # Insert RKN rule
    rules.insert(insert_pos, rkn_rule)

    # Save config
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    print(f"Generated sing-box config with {len(domains)} RKN domains at {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate sing-box config with RKN domains")
    parser.add_argument(
        "--base-config",
        default="~/.config/sing-box-tun/config-no-auto-route.json",
        help="Base sing-box config path",
    )
    parser.add_argument(
        "--domains-file",
        default="~/.local/state/rkn-domains-fetcher/rkn-domains.txt",
        help="RKN domains file path",
    )
    parser.add_argument(
        "--output",
        default="~/.config/sing-box-tun/config-with-rkn.json",
        help="Output config path",
    )
    parser.add_argument(
        "--max-domains",
        type=int,
        default=1000,
        help="Maximum number of domains to include (for performance)",
    )

    args = parser.parse_args()

    # Resolve paths
    base_config_path = Path(args.base_config).expanduser()
    domains_path = Path(args.domains_file).expanduser()
    output_path = Path(args.output).expanduser()

    # Check if base config exists
    if not base_config_path.exists():
        print(f"Error: Base config not found: {base_config_path}")
        sys.exit(1)

    # Load domains
    domains = load_rkn_domains(domains_path)
    if not domains:
        print("No domains loaded. Creating config without RKN domains.")

    # Generate config
    generate_singbox_config(base_config_path, domains, output_path, args.max_domains)

    print("\nTo use this config:")
    print(f"  cp {output_path} ~/.config/sing-box-tun/config.json")
    print("  systemctl --user restart sing-box-tun")


if __name__ == "__main__":
    main()
