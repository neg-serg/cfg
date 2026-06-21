# bluefin-custom-full — Status

**Image:** `localhost/bluefin-custom-full:latest` — 35.5 GB

## Coverage

| Metric | Count |
|--------|-------|
| Total packages (from packages.yaml) | 563 |
| Found via RPM | 374 |
| Found via host-built binaries | ~130 |
| Intentionally skipped | 31 |
| Unavailable | ~28 |

## Artifacts

| File | Purpose |
|------|---------|
| `Containerfile` | RPM layer (374 packages, clean, no duplicates) |
| `Containerfile.hyprland` | Host-built layer (ADD tar.gz + symlinks) |
| `hyprland-binaries.tar.gz` | Pre-built binaries + shared libs |
| `build-all.sh` | Reproducible rebuild from source |
| `generate-bluefin-image.py` | Generate Containerfile from packages.yaml |
| `mapping.yaml` | 363 Fedora→Arch package name mappings |
| `improvements.md` | Planned improvements (12 items) |

## Remaining issues

1. 76 packages show as "missing" in verification — mostly naming differences (binary≠package name)
2. `dosbox`, `httpie`, `gstreamer1-libav` — in Containerfile but not in Fedora repos
3. `build-all.sh` needs network for cargo/go/npm/git downloads
4. SOCKS5 proxy credentials needed for some downloads

## Build command

```bash
cd scripts/bluefin-migration
podman build -t bluefin-custom -f Containerfile .
podman build -t bluefin-custom-full -f Containerfile.hyprland .
```
