#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import logging
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.pretty import pretty

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Default paths
DEFAULT_CONFIG_PATH = Path.home() / ".config" / "rkn-domains-fetcher" / "config.yaml"
DEFAULT_STATE_PATH = Path.home() / ".local" / "state" / "rkn-domains-fetcher" / "state.json"
DEFAULT_OUTPUT_PATH = Path.home() / ".local" / "state" / "rkn-domains-fetcher" / "rkn-domains.txt"
DEFAULT_VPN_SPLIT_ROUTER_CONFIG = Path.home() / ".config" / "vpn-split-router" / "config.yaml"

# RKN domains source
RKN_DOMAINS_URL = "https://raw.githubusercontent.com/EikeiDev/domains/main/domains.lst"
BACKUP_SOURCES = [
    "https://raw.githubusercontent.com/zapret-info/z-i/master/dump.csv",
    "https://raw.githubusercontent.com/antifilter/filterlist/master/antifilter.list",
]

# Domain validation regex
DOMAIN_REGEX = re.compile(
    r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*"
    r"\.[a-zA-Z]{2,}$"
)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def now_iso() -> str:
    return now_utc().isoformat()


def parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value)


def load_config(path: Path) -> dict:
    if not path.exists():
        logger.warning(f"Config file not found: {path}, using defaults")
        return {
            "settings": {
                "update_interval_hours": 24,
                "max_domains": 100000,
                "domain_validation": True,
                "exclude_patterns": [
                    r"^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$",  # IP addresses
                    r"^[0-9]+$",  # Just numbers
                    r"^[a-f0-9]{32}$",  # MD5 hashes
                    r"\.(onion|i2p)$",  # Tor/I2P
                ],
                "include_patterns": [
                    r"\.(com|org|net|ru|info|biz|online|site|xyz|top|club|shop|store|app|dev|ai|io)$",
                ],
                "fallback_enabled": True,
                "fallback_retry_count": 3,
                "fallback_retry_delay_seconds": 5,
            },
            "sources": {
                "primary": RKN_DOMAINS_URL,
                "backups": BACKUP_SOURCES,
            },
            "integration": {
                "vpn_split_router": {
                    "enabled": True,
                    "auto_mark_vpn": True,
                    "categories": {
                        "social_media": ["twitter", "facebook", "instagram", "tiktok", "whatsapp"],
                        "ai_services": ["claude", "openai", "chatgpt", "anthropic"],
                        "video": ["youtube", "twitch", "reddit"],
                        "torrents": ["1337x", "piratebay", "rutracker", "rutor"],
                        "porn": ["pornhub", "xvideos", "xhamster", "onlyfans", "nhentai", "hentai"],
                        "drugs": ["weed", "cocaine", "drugs"],
                        "gambling": ["gambling", "casino", "bet"],
                        "vpn_proxy": ["vpn", "proxy"],
                    },
                }
            },
        }
    with open(path) as fh:
        return yaml.safe_load(fh.read()) or {}


def load_state(path: Path) -> dict:
    if not path.exists():
        return {
            "last_update": None,
            "last_success": None,
            "last_hash": None,
            "error_count": 0,
            "source_used": None,
            "domains_count": 0,
            "stats": {"total_fetched": 0, "valid_domains": 0, "filtered_out": 0, "by_category": {}},
        }
    with open(path) as fh:
        return json.load(fh)


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as fh:
        json.dump(state, fh, indent=2, sort_keys=True)


def download_with_wget2(url: str, timeout: int = 30) -> Optional[str]:
    """Download content using wget2 (faster, handles large files better)"""
    import subprocess

    try:
        logger.info(f"Downloading from {url}")
        result = subprocess.run(
            ["wget2", "-q", "-O-", "--timeout", str(timeout), url],
            capture_output=True,
            text=True,
            timeout=timeout + 5,
        )

        if result.returncode == 0:
            return result.stdout
        else:
            logger.error(f"wget2 failed with code {result.returncode}: {result.stderr}")
            return None

    except subprocess.TimeoutExpired:
        logger.error(f"Download timeout for {url}")
        return None
    except FileNotFoundError:
        logger.error("wget2 not found, falling back to requests")
        return download_with_requests(url, timeout)
    except Exception as e:
        logger.error(f"Download error: {e}")
        return None


def download_with_requests(url: str, timeout: int = 30) -> Optional[str]:
    """Fallback download using requests"""
    try:
        import requests

        response = requests.get(url, timeout=timeout)
        response.raise_for_status()
        return response.text
    except ImportError:
        logger.error("requests module not available")
        return None
    except Exception as e:
        logger.error(f"Requests download error: {e}")
        return None


def validate_domain(domain: str, config: dict) -> bool:
    """Validate and filter domain"""
    domain = domain.strip().lower()

    # Basic validation
    if not domain:
        return False

    # Check if it looks like a domain
    if not DOMAIN_REGEX.match(domain):
        return False

    # Apply exclude patterns
    settings = config.get("settings", {})
    for pattern in settings.get("exclude_patterns", []):
        if re.search(pattern, domain, re.IGNORECASE):
            return False

    # Apply include patterns (if any)
    include_patterns = settings.get("include_patterns", [])
    if include_patterns:
        matches_any = False
        for pattern in include_patterns:
            if re.search(pattern, domain, re.IGNORECASE):
                matches_any = True
                break
        if not matches_any:
            return False

    return True


def categorize_domain(domain: str, config: dict) -> list[str]:
    """Categorize domain for statistics"""
    categories = []
    integration = config.get("integration", {}).get("vpn_split_router", {})
    domain_categories = integration.get("categories", {})

    domain_lower = domain.lower()

    for category, keywords in domain_categories.items():
        for keyword in keywords:
            if keyword.lower() in domain_lower:
                categories.append(category)
                break

    return categories if categories else ["uncategorized"]


def process_domains(content: str, config: dict) -> tuple[list[str], dict]:
    """Process raw domains list"""
    lines = content.splitlines()
    logger.info(f"Processing {len(lines)} raw domains")

    settings = config.get("settings", {})
    max_domains = settings.get("max_domains", 100000)
    validate = settings.get("domain_validation", True)

    valid_domains = []
    stats = {"total_fetched": len(lines), "valid_domains": 0, "filtered_out": 0, "by_category": {}}

    for line in lines:
        domain = line.strip()

        if validate and not validate_domain(domain, config):
            stats["filtered_out"] += 1
            continue

        valid_domains.append(domain)
        stats["valid_domains"] += 1

        # Categorize for statistics
        categories = categorize_domain(domain, config)
        for category in categories:
            stats["by_category"][category] = stats["by_category"].get(category, 0) + 1

        # Limit if needed
        if len(valid_domains) >= max_domains:
            logger.warning(f"Reached max domains limit: {max_domains}")
            break

    logger.info(
        f"Processed: {stats['valid_domains']} valid domains, {stats['filtered_out']} filtered out"
    )
    return valid_domains, stats


def save_domains_file(domains: list[str], output_path: Path) -> bool:
    """Save domains to file, only if changed"""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    content = "\n".join(sorted(set(domains))) + "\n"
    content_hash = hashlib.sha256(content.encode()).hexdigest()

    # Check if file exists and has same content
    if output_path.exists():
        existing_content = output_path.read_text()
        existing_hash = hashlib.sha256(existing_content.encode()).hexdigest()
        if existing_hash == content_hash:
            logger.info("Domains file unchanged, skipping write")
            return False

    # Write to temp file first
    temp_path = output_path.with_suffix(output_path.suffix + ".tmp")
    temp_path.write_text(content)
    temp_path.replace(output_path)

    logger.info(f"Saved {len(domains)} domains to {output_path}")
    return True


def integrate_with_vpn_split_router(domains: list[str], config: dict, state: dict) -> None:
    """Integrate with vpn-split-router"""
    integration = config.get("integration", {}).get("vpn_split_router", {})
    if not integration.get("enabled", True):
        logger.info("VPN split router integration disabled")
        return

    vpn_config_path = DEFAULT_VPN_SPLIT_ROUTER_CONFIG
    if not vpn_config_path.exists():
        logger.warning(f"VPN split router config not found: {vpn_config_path}")
        return

    # Load VPN split router config
    with open(vpn_config_path) as fh:
        vpn_config = yaml.safe_load(fh.read()) or {}

    # Get current seed domains
    current_seed = set(vpn_config.get("seed_domains", []))

    # Add domains from specific categories if auto_mark_vpn is enabled
    if integration.get("auto_mark_vpn", True):
        important_categories = ["ai_services", "social_media", "video"]

        for domain in domains:
            domain_categories = categorize_domain(domain, config)
            # Add domain if it belongs to important category
            for category in domain_categories:
                if category in important_categories:
                    current_seed.add(domain)
                    break

        # Update config
        vpn_config["seed_domains"] = sorted(current_seed)

        # Save back
        with open(vpn_config_path, "w") as fh:
            yaml.dump(vpn_config, fh, default_flow_style=False)

        logger.info(f"Updated VPN split router with {len(current_seed)} seed domains")
        state["vpn_integration"] = {"updated": now_iso(), "seed_domains_count": len(current_seed)}


def fetch_domains(config: dict, state: dict, force: bool = False) -> tuple[bool, dict, list]:
    """Main fetch logic with fallback"""
    settings = config.get("settings", {})

    # Check if update is needed
    if not force:
        last_update = parse_iso(state.get("last_update"))
        update_interval = timedelta(hours=settings.get("update_interval_hours", 24))

        if last_update and (now_utc() - last_update) < update_interval:
            logger.info("Skipping update, not enough time passed")
            return False, state, []

    sources = config.get("sources", {})
    primary_url = sources.get("primary", RKN_DOMAINS_URL)
    backup_urls = sources.get("backups", BACKUP_SOURCES)

    all_sources = [primary_url] + backup_urls
    content = None
    source_used = None

    # Try all sources
    for i, url in enumerate(all_sources):
        logger.info(f"Trying source {i + 1}/{len(all_sources)}: {url}")
        content = download_with_wget2(url)

        if content:
            source_used = url
            logger.info(f"Successfully downloaded from {url}")
            break

        if i < len(all_sources) - 1:  # Not the last source
            retry_delay = settings.get("fallback_retry_delay_seconds", 5)
            logger.info(f"Waiting {retry_delay}s before trying next source...")
            time.sleep(retry_delay)

    if not content:
        state["error_count"] = state.get("error_count", 0) + 1
        logger.error("All sources failed")
        return False, state, []

    # Process domains
    domains, stats = process_domains(content, config)

    # Update state
    state.update(
        {
            "last_update": now_iso(),
            "last_success": now_iso(),
            "last_hash": hashlib.sha256(content.encode()).hexdigest(),
            "error_count": 0,
            "source_used": source_used,
            "domains_count": len(domains),
            "stats": stats,
        }
    )

    return True, state, domains


def command_fetch(args: argparse.Namespace) -> int:
    """Fetch and process domains"""
    config = load_config(args.config)
    state = load_state(args.state)

    success, new_state, domains = fetch_domains(config, state, force=args.force)

    if not success:
        logger.error("Failed to fetch domains")
        return 1

    # Save domains to file
    if domains:
        save_domains_file(domains, args.output)
    else:
        logger.warning("No domains to save")

    save_state(args.state, new_state)

    # Integrate with VPN split router
    if args.integrate and domains:
        integrate_with_vpn_split_router(domains, config, new_state)

    logger.info("Fetch completed successfully")
    return 0


def command_status(args: argparse.Namespace) -> int:
    """Show status"""
    state = load_state(args.state)

    pretty.header("RKN Domains Fetcher Status")

    if state.get("last_success"):
        last_success = parse_iso(state["last_success"])
        age = now_utc() - last_success
        age_str = f"{last_success} ({age.days}d {age.seconds // 3600}h ago)"
        pretty.key_value({"Last successful fetch": age_str})
    else:
        pretty.key_value({"Last successful fetch": "Never"})

    pretty.key_value(
        {
            "Domains count": str(state.get("domains_count", 0)),
            "Source used": str(state.get("source_used", "None")),
            "Error count": str(state.get("error_count", 0)),
        }
    )

    stats = state.get("stats", {})
    if stats:
        pretty.section("Statistics")
        pretty.key_value(
            {
                "Total fetched": str(stats.get("total_fetched", 0)),
                "Valid domains": str(stats.get("valid_domains", 0)),
                "Filtered out": str(stats.get("filtered_out", 0)),
            }
        )

        by_category = stats.get("by_category", {})
        if by_category:
            sorted_cats = sorted(by_category.items(), key=lambda x: x[1], reverse=True)
            cat_pairs = {f"  {c}": str(n) for c, n in sorted_cats}
            pretty.key_value(cat_pairs)

    # Check output file
    output_path_str = pretty.filepath(str(args.output))
    if args.output.exists():
        with open(args.output) as fh:
            file_count = sum(1 for line in fh if line.strip())
        pretty.key_value({"Output file": f"{output_path_str} ({file_count} domains)"})
    else:
        pretty.key_value({"Output file": f"{output_path_str} (not found)"})

    return 0


def command_manual_update(args: argparse.Namespace) -> int:
    """Manual update from specific source"""
    config = load_config(args.config)
    state = load_state(args.state)

    logger.info(f"Manual update from: {args.url}")

    content = download_with_wget2(args.url)
    if not content:
        logger.error(f"Failed to download from {args.url}")
        return 1

    domains, stats = process_domains(content, config)

    # Save to file
    save_domains_file(domains, args.output)

    # Update state
    state.update(
        {
            "last_update": now_iso(),
            "last_success": now_iso(),
            "last_hash": hashlib.sha256(content.encode()).hexdigest(),
            "source_used": args.url,
            "domains_count": len(domains),
            "stats": stats,
            "manual_update": True,
        }
    )

    save_state(args.state, state)
    logger.info(f"Manual update completed: {len(domains)} domains")
    return 0


def command_validate(args: argparse.Namespace) -> int:
    """Validate existing domains file"""
    if not args.input.exists():
        logger.error(f"Input file not found: {args.input}")
        return 1

    config = load_config(args.config)

    with open(args.input) as fh:
        domains = [line.strip() for line in fh if line.strip()]

    logger.info(f"Validating {len(domains)} domains")

    valid_count = 0
    invalid_count = 0

    for domain in domains:
        if validate_domain(domain, config):
            valid_count += 1
        else:
            invalid_count += 1
            if args.show_invalid:
                print(f"Invalid: {domain}")

    pretty.key_value(
        {
            "Valid domains": str(valid_count),
            "Invalid domains": str(invalid_count),
            "Total": str(len(domains)),
        }
    )

    if invalid_count > 0 and args.clean:
        logger.info("Cleaning invalid domains...")
        valid_domains = [d for d in domains if validate_domain(d, config)]
        save_domains_file(valid_domains, args.input)
        pretty.ok(f"Saved {len(valid_domains)} valid domains")

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="RKN Blocked Domains Fetcher with Autocorrection")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Fetch command
    fetch_parser = subparsers.add_parser("fetch", help="Fetch and process domains")
    fetch_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    fetch_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    fetch_parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    fetch_parser.add_argument("--force", action="store_true", help="Force update")
    fetch_parser.add_argument(
        "--integrate",
        action="store_true",
        help="Integrate with VPN split router",
    )
    fetch_parser.set_defaults(func=command_fetch)

    # Status command
    status_parser = subparsers.add_parser("status", help="Show status")
    status_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    status_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    status_parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    status_parser.set_defaults(func=command_status)

    # Manual update command
    manual_parser = subparsers.add_parser("manual", help="Manual update from URL")
    manual_parser.add_argument("url", help="URL to fetch from")
    manual_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    manual_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    manual_parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    manual_parser.set_defaults(func=command_manual_update)

    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate domains file")
    validate_parser.add_argument("--input", type=Path, required=True, help="Input domains file")
    validate_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    validate_parser.add_argument("--show-invalid", action="store_true", help="Show invalid domains")
    validate_parser.add_argument("--clean", action="store_true", help="Remove invalid domains")
    validate_parser.set_defaults(func=command_validate)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        return args.func(args)
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
