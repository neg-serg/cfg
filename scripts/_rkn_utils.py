"""Shared RKN domain loading utilities for VPN/routing scripts."""

from pathlib import Path


def load_rkn_domains(
    domains_path: Path,
    limit: int | None = None,
    categories: list[str] | None = None,
) -> list[str]:
    """Load RKN domains from file with optional category filtering and limit.

    When categories is provided, prefers a categorized file
    (rkn-domains-categorized.txt) filtering by the given categories.
    Falls back to the raw domains file if no categorized matches found.
    """
    if not domains_path.exists():
        print(f"Warning: RKN domains file not found: {domains_path}")
        return []

    domains: list[str] = []

    if categories:
        categories_path = domains_path.parent / "rkn-domains-categorized.txt"
        if categories_path.exists():
            current_category = None
            with open(categories_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("#") and "category:" in line:
                        current_category = line.split("category:")[1].strip()
                    elif line and current_category in categories:
                        domains.append(line)

    if not domains:
        with open(domains_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    domains.append(line)

    if limit is not None and len(domains) > limit:
        domains = domains[:limit]

    print(f"Loaded {len(domains)} domains from {domains_path}")
    return domains
