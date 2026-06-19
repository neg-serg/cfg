#!/usr/bin/env python3
"""Post-generate Containerfile fixes:
  1. Disable slow/broken repos (negativo17 multimedia)
  2. Add CachyOS kernel COPR if desired
  3. Other tweaks for buildability
"""
import sys
from pathlib import Path

CONTAINERFILE = Path(__file__).resolve().parent / "Containerfile"

def patch_containerfile():
    lines = open(CONTAINERFILE).readlines()
    
    new_lines = []
    skip_next = False
    for i, line in enumerate(lines):
        if skip_next:
            skip_next = False
            continue
        
        # Replace RPM Fusion curl block with proper rpm-ostree install
        if 'curl -sLo /etc/yum.repos.d/rpmfusion-free.repo' in line:
            new_lines.append("# ── Enable RPM Fusion ───────────────────────────────────────\n")
            new_lines.append("RUN rpm-ostree install -y \\\n")
            new_lines.append("    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \\\n")
            new_lines.append("    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \\\n")
            new_lines.append("    rpm-ostree cleanup -m\n")
            new_lines.append("\n")
            skip_next = True  # skip the next line (nonfree curl)
            continue
        
        new_lines.append(line)
        
        if 'FROM ghcr.io/ublue-os/bluefin-dx' in line:
            new_lines.append("\n")
            new_lines.append("# ── Disable broken/slow repos ────────────────────────────\n")
            new_lines.append("RUN rm -f /etc/yum.repos.d/*multimedia* /etc/yum.repos.d/*negativo* 2>/dev/null || true\n")
            new_lines.append("\n")
    
    if not new_lines:
        print("ERROR: Could not generate output")
        sys.exit(1)
    
    open(CONTAINERFILE, 'w').writelines(new_lines)
    print(f"Patched {CONTAINERFILE}")

if __name__ == "__main__":
    patch_containerfile()
