# bluefin-custom-full — Status

**Image:** `localhost/bluefin-custom-full:latest` — **17.3 GB** (-50% from original 34.4)

## Coverage

| Metric | Count |
|--------|-------|
| Base image | Fedora Silverblue 44 (5.87 GB) |
| RPM packages (explicit) | 336 |
| RPM total (with deps) | ~2900 |
| Host-built binaries | ~156 |
| Verified working | ✅ Hyprland, Steam, Cargo, Go, Node |

## Build time

- RPM layer: ~3.5 min
- Full image (with squash): ~1.5 min
- Full rebuild (build-all.sh): ~13 min CPU

## Artifacts

| File | Purpose |
|------|---------|
| `Containerfile` | RPM layer (336 packages) |
| `Containerfile.hyprland` | Host-built layer (squash + symlinks + cleanup) |
| `hyprland-binaries.tar.gz` | Pre-built binaries (869 MB) |
| `build-all.sh` | Reproducible rebuild from source |
| `mapping.yaml` | Fedora→Arch package name mappings |
| `verify-image.sh` | In-container package verification |
| `symlinks.txt` | Binary name aliases |
| `improvements.md` | 12/12 done ✅ |

## Size optimization history

| Step | Size | Delta |
|------|------|-------|
| Original (Bluefin DX base) | 34.4 GB | — |
| Remove DE packages | 30.8 GB | -3.6 GB |
| Remove chromium+gimp+rawtherapee | 27.9 GB | -2.9 GB |
| Remove firefox | 27.6 GB | -0.3 GB |
| Remove telegram+pandoc | 27.4 GB | -0.2 GB |
| Remove wine+lutris | 25.2 GB | -2.2 GB |
| Remove ollama+ROCm | 22.2 GB | -3.0 GB |
| Switch to Silverblue base | 17.3 GB | -4.9 GB |
| **Total saved** | | **-17.1 GB (-50%)** |

## Build command

```bash
cd scripts/bluefin-migration
podman build -t bluefin-custom -f Containerfile .
podman build -t bluefin-custom-full -f Containerfile.hyprland .
```
