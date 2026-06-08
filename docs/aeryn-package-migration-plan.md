# AerynOS Package Migration — Execution Plan

VM: `aerynos-gnome` (192.168.122.167, root@)

## Status: 93 remaining `[ ]` from migration doc

## Phase 1: Flatpak installs (29 → ~20 available)
Flathub remote already configured.

Known FlatHub IDs to try:
| Package | FlatHub ID |
|---------|-----------|
| blender | org.blender.Blender |
| bottles | com.usebottles.bottles |
| chromium | org.chromium.Chromium |
| gimp | org.gimp.GIMP |
| google-chrome | com.google.Chrome |
| lutris | net.lutris.Lutris |
| obsidian | md.obsidian.Obsidian |
| rawtherapee | com.rawtherapee.RawTherapee |
| simple-scan | org.gnome.SimpleScan |
| carla | studio.kx.carla |
| goverlay | io.github.benjamimgois.goverlay |
| nicotine+ | org.nicotine_plus.Nicotine |
| picard | org.musicbrainz.Picard |
| throne | com.mercury.Throne |

Also try (may not exist): epiphany, gnome-*, localsend-bin, yandex-browser, corectrl, gnome-tour, opensoundmeter, otter-launcher, pcmanfm, sonic-visualiser, supercollider

## Phase 2: pip/pipx installs (11)
- beets, cmake-language-server, geoip2, jupyterlab, liquidctl, neovim-remote, pgcli, pre-commit, proton-vpn-cli, proxypilot, transformers

## Phase 3: cargo installs (4)
- sidecar, tabiew, taoup, wl

## Phase 4: cabal (1)
- haskell-tidal → `cabal update && cabal install tidal`

## Phase 5: System/N/A + Manual (document, skip impractical)
Packages genuinely not available on AerynOS or very low priority.
