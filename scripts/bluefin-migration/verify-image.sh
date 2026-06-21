#!/bin/bash
# verify-image.sh — check all 563 packages from packages.yaml against the image
# Usage: ./verify-image.sh [image_name]
set -euo pipefail
IMAGE="${1:-bluefin-custom-full:latest}"

echo "=== Verifying $IMAGE ==="
echo ""

# Run verification in container
podman run --rm "$IMAGE" python3 << 'PYEOF' 2>/dev/null
import yaml, subprocess, sys

with open('/usr/share/bluefin/packages.yaml') as f:
    pkgs = yaml.safe_load(f)
all_pkgs = sorted(set(p for cat in pkgs for p in pkgs[cat] if isinstance(p, str)))

with open('/usr/share/bluefin/mapping.yaml') as f:
    arch_to_fedora = {v: k for k, v in yaml.safe_load(f)['rpm_to_arch'].items()}

bin_aliases = {
    'bucklespring':'buckle','neo-matrix':'neo','zapret2':'ip2net','oyo':'oy',
    'epr-git':'epr','no-more-secrets':'nms','ripgrep':'rg','bottom':'btm',
    'television':'tv','erdtree':'erd','difftastic':'difft','jujutsu':'jj',
    'git-delta':'delta','babashka-bin':'bb','advancecomp':'advdef',
    'hypridle':'hypridle','hyprlock':'hyprlock','hyprpicker':'hyprpicker',
    'hyprpolkitagent':'hyprpolkitagent','uwsm':'uwsm',
}

skip = {'base','base-devel','linux','linux-headers','linux-cachyos-headers',
    'limine','pacman-contrib','paru','paru-debug','yay','rebuild-detector',
    'mkinitcpio','systemd-resolvconf'}

rpm_ok = bin_ok = skip_cnt = miss = 0
missing = []

for pkg in all_pkgs:
    if pkg in skip:
        skip_cnt += 1; continue
    fedora = arch_to_fedora.get(pkg)
    if fedora and subprocess.run(['rpm','-q',fedora],capture_output=True).returncode == 0:
        rpm_ok += 1; continue
    bin_name = bin_aliases.get(pkg, pkg)
    if subprocess.run(['command','-v',bin_name],capture_output=True).returncode == 0:
        bin_ok += 1; continue
    miss += 1
    missing.append(f'{pkg} (tried: {fedora or bin_name})')

print(f'Total:    {len(all_pkgs)}')
print(f'RPM:      {rpm_ok}')
print(f'Binary:   {bin_ok}')
print(f'Skipped:  {skip_cnt}')
print(f'Missing:  {miss}')
print(f'Coverage: {(rpm_ok+bin_ok)*100//len(all_pkgs)}%')
if missing:
    print(f'\nMissing ({miss}):')
    for m in missing[:20]:
        print(f'  ❌ {m}')
    if len(missing) > 20:
        print(f'  ... +{len(missing)-20}')
PYEOF
