#!/usr/bin/env python3
"""
Integrate RKN domains with vpn-split-router.
"""

import argparse
import sys
from pathlib import Path

import yaml


def load_rkn_domains(domains_path: Path, limit: int = 100) -> list[str]:
    """Load important RKN domains (AI, social media, etc.)."""
    if not domains_path.exists():
        print(f"Warning: RKN domains file not found: {domains_path}")
        return []

    important_domains = []
    categories = ["ai_services", "social_media", "vpn_proxy"]

    # Try to load categorized domains first
    categories_path = domains_path.parent / "rkn-domains-categorized.txt"
    if categories_path.exists():
        with open(categories_path, "r", encoding="utf-8") as f:
            current_category = None
            for line in f:
                line = line.strip()
                if line.startswith("#"):
                    # Extract category from comment
                    if "category:" in line:
                        current_category = line.split("category:")[1].strip()
                elif line and current_category in categories:
                    important_domains.append(line)

    # Fallback to all domains
    if not important_domains:
        with open(domains_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    important_domains.append(line)

    # Limit for seed domains
    if len(important_domains) > limit:
        important_domains = important_domains[:limit]

    print(f"Loaded {len(important_domains)} important domains from {domains_path}")
    return important_domains


def update_vpn_split_router_config(config_path: Path, domains: list[str]) -> bool:
    """Update vpn-split-router config with RKN domains."""

    # Create config directory if it doesn't exist
    config_path.parent.mkdir(parents=True, exist_ok=True)

    # Load existing config or create default
    if config_path.exists():
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}
    else:
        state_dir = Path.home() / ".local" / "state" / "vpn-split-router"
        config = {
            "seed_domains": [],
            "observation_window_hours": 24,
            "min_observations": 2,
            "vpn_domains_file": str(state_dir / "vpn-domains.txt"),
            "observed_domains_file": str(state_dir / "observed-domains.txt"),
            "state_file": str(state_dir / "state.json"),
            "runtime_config_path": str(Path.home() / ".config" / "sing-box-tun" / "config.json"),
            "check_interval_seconds": 300,
            "enable_auto_update": True,
        }

    # Update seed domains
    if "seed_domains" not in config:
        config["seed_domains"] = []

    # Add new domains
    existing_domains = set(config["seed_domains"])
    new_domains = [d for d in domains if d not in existing_domains]

    if new_domains:
        config["seed_domains"].extend(new_domains)
        print(f"Added {len(new_domains)} new domains to seed_domains")
    else:
        print("No new domains to add")

    # Save config
    with open(config_path, "w", encoding="utf-8") as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

    print(f"Updated vpn-split-router config at {config_path}")
    return bool(new_domains)


def main() -> None:
    parser = argparse.ArgumentParser(description="Integrate RKN domains with vpn-split-router")
    parser.add_argument(
        "--domains-file",
        default="~/.local/state/rkn-domains-fetcher/rkn-domains.txt",
        help="RKN domains file path",
    )
    parser.add_argument(
        "--config-path",
        default="~/.config/vpn-split-router/config.yaml",
        help="vpn-split-router config path",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=100,
        help="Maximum number of domains to add as seed",
    )

    args = parser.parse_args()

    # Resolve paths
    domains_path = Path(args.domains_file).expanduser()
    config_path = Path(args.config_path).expanduser()

    # Load domains
    domains = load_rkn_domains(domains_path, args.limit)
    if not domains:
        print("No domains loaded. Exiting.")
        sys.exit(0)

    # Update config
    updated = update_vpn_split_router_config(config_path, domains)

    if updated:
        helper_script = Path.home() / "src" / "cfg" / "scripts" / "vpn_split_router.py"
        print("\nTo apply changes:")
        print("  systemctl --user restart vpn-split-router")
        print(f"  Or run: python3 {helper_script} --daemon")
    else:
        print("No changes made to config")


if __name__ == "__main__":
    main()
