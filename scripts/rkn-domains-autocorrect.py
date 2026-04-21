#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
import socket
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Tuple

import yaml

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Default paths
DEFAULT_CONFIG_PATH = Path.home() / ".config" / "rkn-domains-fetcher" / "config.yaml"
DEFAULT_STATE_PATH = Path.home() / ".local" / "state" / "rkn-domains-fetcher" / "state.json"
DEFAULT_DOMAINS_FILE = Path.home() / ".local" / "state" / "rkn-domains-fetcher" / "rkn-domains.txt"
DEFAULT_HEALTH_FILE = Path.home() / ".local" / "state" / "rkn-domains-fetcher" / "health.json"

# Autocorrection constants
MAX_CONSECUTIVE_FAILURES = 3
HEALTH_CHECK_TIMEOUT = 10
CACHE_MAX_AGE_DAYS = 7


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
        logger.warning(f"Config file not found: {path}")
        return {}

    with open(path) as fh:
        return yaml.safe_load(fh.read()) or {}


def load_state(path: Path) -> dict:
    if not path.exists():
        return {
            "consecutive_failures": 0,
            "last_success": None,
            "last_attempt": None,
            "current_mode": "normal",
            "fallback_triggered": False,
            "health_checks": [],
        }

    with open(path) as fh:
        return json.load(fh)


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as fh:
        json.dump(state, fh, indent=2, sort_keys=True)


def load_health(path: Path) -> dict:
    if not path.exists():
        return {"last_check": None, "status": "unknown", "failures": 0, "checks": []}

    with open(path) as fh:
        return json.load(fh)


def save_health(path: Path, health: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as fh:
        json.dump(health, fh, indent=2, sort_keys=True)


def check_network_connectivity(
    url: str = "https://httpbin.org/ip", timeout: int = 10
) -> Tuple[bool, str]:
    """Check if we can reach the internet"""
    try:
        import ssl
        import urllib.request

        # Create a custom context to avoid certificate issues
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        req = urllib.request.Request(url, headers={"User-Agent": "RKN-Domains-Autocorrect"})

        with urllib.request.urlopen(req, timeout=timeout, context=context) as response:
            if response.status == 200:
                return True, "Network connectivity OK"
            else:
                return False, f"HTTP {response.status}"

    except socket.timeout:
        return False, "Connection timeout"
    except urllib.error.URLError as e:
        return False, f"URL error: {e.reason}"
    except Exception as e:
        return False, f"Error: {str(e)}"


def check_dns_resolution(domain: str = "google.com") -> Tuple[bool, str]:
    """Check DNS resolution"""
    try:
        socket.gethostbyname(domain)
        return True, f"DNS resolution OK for {domain}"
    except socket.gaierror:
        return False, f"DNS resolution failed for {domain}"
    except Exception as e:
        return False, f"DNS error: {str(e)}"


def check_local_service(service: str = "sing-box") -> Tuple[bool, str]:
    """Check if local service is running"""
    try:
        result = subprocess.run(["pgrep", "-f", service], capture_output=True, text=True)
        if result.returncode == 0:
            return True, f"Service {service} is running"
        else:
            return False, f"Service {service} is not running"
    except Exception as e:
        return False, f"Service check error: {str(e)}"


def perform_health_check(config: dict) -> Tuple[bool, dict]:
    """Perform comprehensive health check"""
    settings = config.get("settings", {})
    autocorrection = settings.get("autocorrection", {})

    health_url = autocorrection.get("health_check_url", "https://httpbin.org/ip")
    timeout = autocorrection.get("health_check_timeout", HEALTH_CHECK_TIMEOUT)

    checks = []
    overall_healthy = True

    # 1. Network connectivity
    network_ok, network_msg = check_network_connectivity(health_url, timeout)
    checks.append(
        {
            "check": "network_connectivity",
            "status": "healthy" if network_ok else "unhealthy",
            "message": network_msg,
            "timestamp": now_iso(),
        }
    )
    if not network_ok:
        overall_healthy = False

    # 2. DNS resolution
    dns_ok, dns_msg = check_dns_resolution()
    checks.append(
        {
            "check": "dns_resolution",
            "status": "healthy" if dns_ok else "unhealthy",
            "message": dns_msg,
            "timestamp": now_iso(),
        }
    )
    if not dns_ok:
        overall_healthy = False

    # 3. Check local services
    services_to_check = ["sing-box", "xray"]
    for service in services_to_check:
        service_ok, service_msg = check_local_service(service)
        checks.append(
            {
                "check": f"service_{service}",
                "status": "healthy" if service_ok else "unhealthy",
                "message": service_msg,
                "timestamp": now_iso(),
            }
        )
        if not service_ok:
            overall_healthy = False

    # 4. Check domains file
    domains_file = DEFAULT_DOMAINS_FILE
    if domains_file.exists():
        file_age = now_utc() - datetime.fromtimestamp(domains_file.stat().st_mtime, timezone.utc)
        file_ok = file_age.days < CACHE_MAX_AGE_DAYS
        file_msg = f"Domains file age: {file_age.days}d {file_age.seconds // 3600}h"
    else:
        file_ok = False
        file_msg = "Domains file not found"

    checks.append(
        {
            "check": "domains_file",
            "status": "healthy" if file_ok else "unhealthy",
            "message": file_msg,
            "timestamp": now_iso(),
        }
    )
    if not file_ok:
        overall_healthy = False

    health_status = {
        "last_check": now_iso(),
        "status": "healthy" if overall_healthy else "unhealthy",
        "failures": 0 if overall_healthy else 1,
        "checks": checks,
        "overall_healthy": overall_healthy,
    }

    return overall_healthy, health_status


def activate_fallback_mode(config: dict, state: dict, reason: str) -> dict:
    """Activate fallback/emergency mode"""
    logger.warning(f"Activating fallback mode: {reason}")

    state.update(
        {
            "current_mode": "fallback",
            "fallback_triggered": True,
            "fallback_reason": reason,
            "fallback_activated": now_iso(),
            "consecutive_failures": state.get("consecutive_failures", 0) + 1,
        }
    )

    # Create emergency domains list if needed
    emergency_config = config.get("emergency", {})
    if emergency_config.get("enabled", True):
        create_emergency_domains_list(config)

    # Try to restore from cache
    if config.get("settings", {}).get("autocorrection", {}).get("fallback_to_cache", True):
        restore_from_cache(config)

    return state


def create_emergency_domains_list(config: dict) -> bool:
    """Create emergency essential domains list"""
    emergency_config = config.get("emergency", {})
    essential_domains = emergency_config.get("essential_domains", [])

    if not essential_domains:
        # Default essential domains
        essential_domains = [
            "twitter.com",
            "instagram.com",
            "facebook.com",
            "tiktok.com",
            "whatsapp.com",
            "discord.com",
            "telegram.org",
            "youtube.com",
            "twitch.tv",
            "reddit.com",
            "claude.ai",
            "openai.com",
            "chatgpt.com",
            "anthropic.com",
        ]

    output_file = DEFAULT_DOMAINS_FILE
    output_file.parent.mkdir(parents=True, exist_ok=True)

    content = "\n".join(sorted(set(essential_domains))) + "\n"
    output_file.write_text(content)

    logger.info(f"Created emergency domains list with {len(essential_domains)} domains")
    return True


def restore_from_cache(config: dict) -> bool:
    """Try to restore from cache or backup"""
    cache_locations = config.get("sources", {}).get("local_fallbacks", [])

    for cache_path_str in cache_locations:
        cache_path = Path(cache_path_str.replace("~", str(Path.home())))

        if cache_path.exists():
            try:
                content = cache_path.read_text()
                DEFAULT_DOMAINS_FILE.write_text(content)
                logger.info(f"Restored from cache: {cache_path}")
                return True
            except Exception as e:
                logger.error(f"Failed to restore from cache {cache_path}: {e}")

    logger.warning("No usable cache found")
    return False


def check_and_correct_singbox_config(config: dict) -> bool:
    """Check and correct sing-box configuration"""
    integration = config.get("integration", {}).get("singbox", {})

    if not integration.get("enabled", True):
        logger.info("sing-box integration disabled")
        return True

    config_path_str = integration.get(
        "config_path", "~/.config/sing-box-tun/config-no-auto-route.json"
    )
    config_path = Path(config_path_str.replace("~", str(Path.home())))

    if not config_path.exists():
        logger.warning(f"sing-box config not found: {config_path}")
        return False

    try:
        # Load current config
        with open(config_path) as fh:
            singbox_config = json.load(fh)

        # Check if RKN domains rule exists
        rules = singbox_config.get("route", {}).get("rules", [])
        rkn_rule_exists = any(rule.get("tag") == "rkn-blocked-domains" for rule in rules)

        if not rkn_rule_exists:
            logger.warning("RKN domains rule missing in sing-box config")

            # Try to add it
            domains_file = DEFAULT_DOMAINS_FILE
            if domains_file.exists():
                domains = [
                    line.strip() for line in domains_file.read_text().splitlines() if line.strip()
                ]

                # Limit domains for sing-box
                max_domains = integration.get("max_domains_per_rule", 1000)
                if len(domains) > max_domains:
                    domains = domains[:max_domains]
                    logger.info(f"Limited to {max_domains} domains for sing-box")

                # Add rule at beginning
                rkn_rule = {
                    "tag": "rkn-blocked-domains",
                    "domain_suffix": domains,
                    "outbound": "proxy",
                }

                rules.insert(0, rkn_rule)
                singbox_config.setdefault("route", {})["rules"] = rules

                # Save back
                with open(config_path, "w") as fh:
                    json.dump(singbox_config, fh, indent=2)

                logger.info(f"Added RKN domains rule with {len(domains)} domains")
                return True
            else:
                logger.error("No domains file to add to sing-box")
                return False

        logger.info("sing-box config OK")
        return True

    except Exception as e:
        logger.error(f"Error checking sing-box config: {e}")
        return False


def check_and_correct_vpn_split_router(config: dict) -> bool:
    """Check and correct VPN split router integration"""
    integration = config.get("integration", {}).get("vpn_split_router", {})

    if not integration.get("enabled", True):
        logger.info("VPN split router integration disabled")
        return True

    config_path = Path.home() / ".config" / "vpn-split-router" / "config.yaml"

    if not config_path.exists():
        logger.warning(f"VPN split router config not found: {config_path}")
        return False

    try:
        # Simple check - just verify file exists and has content
        with open(config_path) as fh:
            content = fh.read()

        if not content.strip():
            logger.error("VPN split router config is empty")
            return False

        logger.info("VPN split router config OK")
        return True

    except Exception as e:
        logger.error(f"Error checking VPN split router config: {e}")
        return False


def run_autocorrection(config: dict, state: dict, force: bool = False) -> dict:
    """Main autocorrection logic"""
    logger.info("Starting autocorrection check")

    # Update last attempt
    state["last_attempt"] = now_iso()

    # Perform health check
    healthy, health_status = perform_health_check(config)

    # Save health status
    save_health(DEFAULT_HEALTH_FILE, health_status)

    if not healthy:
        logger.warning("Health check failed")
        state["consecutive_failures"] = state.get("consecutive_failures", 0) + 1

        # Check if we should activate fallback
        max_failures = (
            config.get("settings", {})
            .get("autocorrection", {})
            .get("max_consecutive_failures", MAX_CONSECUTIVE_FAILURES)
        )

        if state["consecutive_failures"] >= max_failures:
            state = activate_fallback_mode(
                config, state, f"Too many consecutive failures: {state['consecutive_failures']}"
            )
    else:
        logger.info("Health check passed")
        state["consecutive_failures"] = 0

        # If we were in fallback mode, try to recover
        if state.get("current_mode") == "fallback":
            logger.info("Recovering from fallback mode")
            state["current_mode"] = "normal"
            state["fallback_recovered"] = now_iso()

    # Check and correct integrations
    if healthy or force:
        logger.info("Checking integrations...")

        # Check sing-box
        singbox_ok = check_and_correct_singbox_config(config)
        if not singbox_ok:
            logger.warning("sing-box integration needs attention")

        # Check VPN split router
        vpn_ok = check_and_correct_vpn_split_router(config)
        if not vpn_ok:
            logger.warning("VPN split router integration needs attention")

        state["integrations_ok"] = singbox_ok and vpn_ok

    # Update state
    state["last_health_check"] = now_iso()
    state["health_status"] = health_status["status"]

    save_state(DEFAULT_STATE_PATH, state)

    logger.info(f"Autocorrection completed. Mode: {state.get('current_mode', 'normal')}")
    return state


def command_check(args: argparse.Namespace) -> int:
    """Run autocorrection check"""
    config = load_config(args.config)
    state = load_state(args.state)

    new_state = run_autocorrection(config, state, force=args.force)

    # Print summary
    print("Autocorrection Check Summary")
    print("=" * 50)
    print(f"Status: {new_state.get('health_status', 'unknown')}")
    print(f"Mode: {new_state.get('current_mode', 'normal')}")
    print(f"Consecutive failures: {new_state.get('consecutive_failures', 0)}")

    if new_state.get("fallback_triggered"):
        print(f"Fallback active since: {new_state.get('fallback_activated')}")
        print(f"Reason: {new_state.get('fallback_reason')}")

    # Show health check results
    health = load_health(args.health)
    if health.get("checks"):
        print("\nHealth Checks:")
        for check in health["checks"][-5:]:  # Last 5 checks
            status_icon = "✓" if check["status"] == "healthy" else "✗"
            print(f"  {status_icon} {check['check']}: {check['message']}")

    return 0 if new_state.get("health_status") == "healthy" else 1


def command_force_fallback(args: argparse.Namespace) -> int:
    """Force fallback mode (for testing)"""
    config = load_config(args.config)
    state = load_state(args.state)

    state = activate_fallback_mode(config, state, "Manual trigger")
    save_state(args.state, state)

    print("Fallback mode activated")
    print(f"Emergency domains list created at: {DEFAULT_DOMAINS_FILE}")

    return 0


def command_recover(args: argparse.Namespace) -> int:
    """Force recovery from fallback mode"""
    state = load_state(args.state)

    if state.get("current_mode") == "fallback":
        logger.info("Forcing recovery from fallback mode")
        state["current_mode"] = "normal"
        state["consecutive_failures"] = 0
        state["fallback_recovered"] = now_iso()
        save_state(args.state, state)
        print("Recovered from fallback mode")
    else:
        print("Not in fallback mode")

    return 0


def command_status(args: argparse.Namespace) -> int:
    """Show detailed status"""
    state = load_state(args.state)
    health = load_health(args.health)

    print("RKN Domains Autocorrection Status")
    print("=" * 60)

    # System status
    print(f"Current mode: {state.get('current_mode', 'normal')}")
    print(f"Consecutive failures: {state.get('consecutive_failures', 0)}")
    print(f"Last success: {state.get('last_success', 'Never')}")
    print(f"Last attempt: {state.get('last_attempt', 'Never')}")

    if state.get("fallback_triggered"):
        print("\n⚠️  FALLBACK ACTIVE")
        print(f"   Activated: {state.get('fallback_activated')}")
        print(f"   Reason: {state.get('fallback_reason')}")
        if state.get("fallback_recovered"):
            print(f"   Recovered: {state.get('fallback_recovered')}")

    # Health status
    print(f"\nHealth status: {health.get('status', 'unknown')}")
    print(f"Last check: {health.get('last_check', 'Never')}")

    # Integration status
    print("\nIntegrations:")
    print(f"  sing-box: {'OK' if state.get('integrations_ok', False) else 'Needs attention'}")
    print(
        f"  VPN split router: {'OK' if state.get('integrations_ok', False) else 'Needs attention'}"
    )

    # Domains file
    domains_file = DEFAULT_DOMAINS_FILE
    if domains_file.exists():
        file_age = now_utc() - datetime.fromtimestamp(domains_file.stat().st_mtime, timezone.utc)
        domain_count = sum(1 for _ in domains_file.open() if _.strip())
        print(f"\nDomains file: {domains_file}")
        print(f"  Domains: {domain_count}")
        print(f"  Age: {file_age.days}d {file_age.seconds // 3600}h")

        if file_age.days > CACHE_MAX_AGE_DAYS:
            print(f"  ⚠️  File is stale (>{CACHE_MAX_AGE_DAYS} days)")
    else:
        print("\nDomains file: NOT FOUND")

    # Recent health checks
    if health.get("checks"):
        print("\nRecent health checks:")
        for check in health["checks"][-3:]:  # Last 3 checks
            status = check["status"]
            timestamp = parse_iso(check["timestamp"])
            if timestamp:
                age = now_utc() - timestamp
                age_str = f"{age.seconds // 60}m ago"
            else:
                age_str = ""

            icon = "✓" if status == "healthy" else "✗"
            print(f"  {icon} {check['check']}: {check['message']} ({age_str})")

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="RKN Domains Autocorrection System")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Check command
    check_parser = subparsers.add_parser("check", help="Run autocorrection check")
    check_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    check_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    check_parser.add_argument("--health", type=Path, default=DEFAULT_HEALTH_FILE)
    check_parser.add_argument("--force", action="store_true", help="Force corrections")
    check_parser.set_defaults(func=command_check)

    # Force fallback command
    fallback_parser = subparsers.add_parser("force-fallback", help="Force fallback mode")
    fallback_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    fallback_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    fallback_parser.set_defaults(func=command_force_fallback)

    # Recover command
    recover_parser = subparsers.add_parser("recover", help="Recover from fallback")
    recover_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    recover_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    recover_parser.set_defaults(func=command_recover)

    # Status command
    status_parser = subparsers.add_parser("status", help="Show detailed status")
    status_parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    status_parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    status_parser.add_argument("--health", type=Path, default=DEFAULT_HEALTH_FILE)
    status_parser.set_defaults(func=command_status)

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
