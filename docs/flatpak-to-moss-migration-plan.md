# Flatpak → Moss Migration Plan

VM: aerynos-gnome (192.168.122.167). SSH key auth works.

## Current state
- Only 1 flatpak app remains: `org.telegram.desktop`
- All other flatpaks were wiped by moss state changes
- Most apps already have non-flatpak alternatives installed

## Migration plan per package

### Already done (no action needed)

| Package | How installed |
|---------|--------------|
| telegram-desktop | `/usr/bin/telegram-desktop` (212MB binary from telegram.org) |
| gopass | moss `gopass` |
| zen-browser-bin | moss `zen-browser-bin` |
| zathura | built from source `/usr/bin/zathura` |
| zathura-pdf-poppler | part of zathura |
| sonic-visualiser | built from source `/usr/local/bin/sonic-visualiser` |
| supercollider | built from source |
| gnome-color-manager | in gnome-control-center (moss) |
| dosbox | moss `dosbox` |
| borg | moss `borg` |
| openrgb | moss `openrgb` |
| recoll | moss `recoll` |
| transmission-cli | moss `transmission-cli` |
| aria2 | moss `aria2` |
| adw-gtk-theme | moss |
| bazecor | moss |
| ddccontrol | moss |
| neovim | appimage `/usr/bin/nvim` |
| nethack | moss |

### Large GUI apps — build from source (complex)

| Package | Build approach | Estimated time |
|---------|---------------|----------------|
| blender | cmake, needs Python3, Boost, OpenImageIO | 30-60 min |
| gimp | meson, needs GEGL, babl, GTK3 | 20-40 min |
| chromium | HUGE (12M LOC), needs ninja+gn | 3-6 hours |
| firefox | already in moss | 0 min |
| epiphany | meson, needs WebKitGTK | 20-40 min |
| obsidian | Electron app, closed source | download binary |
| google-chrome | proprietary, download .deb and extract | download binary |
| rawtherapee | cmake, needs GTK3, lensfun | 15-30 min |
| simple-scan | meson, needs GTK3, sane | 10-20 min |
| lutris | Python app, needs PyGObject | pip install |
| bottles | Python app | pip install |
| localsend-bin | Rust/Flutter, use binary release | download binary |
| yandex-browser | proprietary, use binary | download binary |
| carla | audio plugin host, cmake | 15-30 min |
| picard | Python app, PyQt5 | pip install |
| nicotine+ | Python app, GTK3 | pip install |
| goverlay | meson, needs Qt5 | 10-15 min |
| throne | unknown, check source | TBD |
| corectrl | needs Qt5, mesa, libdrm | 10-15 min |
| gnome-tour | part of gnome-initial-setup | skip |
| opensoundmeter | simple audio meter, make | 5 min |
| otter-launcher | Qt6 browser | skip (use firefox) |
| pcmanfm | GTK file manager | skip (use nautilus) |
| gnome-connections | GNOME app, meson | 10 min |
| gnome-logs | GNOME app, meson | 5 min |
| gnome-maps | GNOME app, meson | 5 min |
| gnome-music | GNOME app, meson | 5 min |

## Automated build script

For each package, the procedure is:

```bash
# 1. Try moss first
moss install -y <pkg> && echo "✓ via moss" && continue

# 2. Try pip (Python apps)
pip install --break-system-packages <pkg> && echo "✓ via pip" && continue

# 3. Try boulder (source → moss package)
mkdir -p /root/recipes/<pkg> && cd /root/recipes/<pkg>
curl -sL -o source.tar.gz <url>
boulder recipe new "file://$(pwd)/source.tar.gz"
sed -i "s/UPDATE SUMMARY/.../" stone.yaml
# Add builddeps as needed
boulder build
cp *.stone /root/local_repo/
cd /root/local_repo && moss index . && moss repo update
moss install -y <pkg>

# 4. If boulder fails, build directly from source
./configure --prefix=/usr && make -j4 && make install
# OR: meson setup build --prefix=/usr && ninja -C build && ninja -C build install
# OR: cmake -B build -DCMAKE_INSTALL_PREFIX=/usr && make -C build -j4 && make -C build install

# 5. For proprietary apps, download binary
curl -sL -o /usr/bin/<app> <binary_url> && chmod +x /usr/bin/<app>
```

## Dependency resolution rules

1. **moss deps**: use `moss install -y <pkg>-devel` for build dependencies
2. **missing moss deps**: build from source following the same recipe pattern
3. **Python deps**: use `pip install --break-system-packages` as last resort
4. **C/C++ deps**: build from source with `./configure && make install` or cmake/meson
5. **libstdc++ symlink fix**: `ln -sf libstdc++.so.6.0.34 /usr/lib/libstdc++.so` before C++ builds
6. **slibtool issues**: use `LDFLAGS="-fuse-ld=bfd" make` or compile on CachyOS host and scp binary

## Priority order
1. Small Python apps (pip install) — 5 min each
2. Simple C apps (make) — 10 min each
3. GNOME apps (meson) — 10-20 min each
4. Large GUI apps (cmake/meson) — 20-60 min each
5. Chromium — skip (3-6 hours, use firefox)
6. Proprietary — download binary

## Removing flatpak after migration
```bash
flatpak uninstall --all -y
flatpak remote-delete flathub
```

## Self-contained prompt for independent execution

```
AerynOS VM at 192.168.122.167. SSH key auth works.
Local moss repo at /root/local_repo/stone.index, 52 stones already built.
Boulder works for Rust/Go/Python packages.
C++ fix: ln -sf libstdc++.so.6.0.34 /usr/lib/libstdc++.so

For each flatpak package, try in order:
1. moss install -y <pkg>
2. boulder build → local repo → moss install
3. pip install --break-system-packages
4. Build from source (./configure || cmake || meson)
5. Download binary

If a dependency is missing, resolve it using the same approach (recursively).
After everything is done, flatpak uninstall --all -y.
```
