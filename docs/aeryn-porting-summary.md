# AerynOS Porting — Final Summary

## Final State
- **Packages installed**: 1622 (was ~870, **+752 new**)
- **Stone files in local repo**: 336 (including -dbginfo)
- **Stone recipes created**: 253

## What was ported

| Category | Count | Examples |
|----------|-------|---------|
| C/Makefile/autotools | ~80 | abduco, atop, advancecomp, aria2, tcpdump, tig, ... |
| Rust/Cargo | ~40 | bandwhich, broot, ruff, television, tokei, resvg, ... |
| Python/PEP517 | ~35 | beets, httpie, jupyterlab, pipx, textual, ... |
| Go | ~15 | age, cliphist, ctop, gitleaks, sops, vale, ... |
| Fonts | 12 | ttf-jetbrains-mono-nerd, noto-fonts, otf-font-awesome, ... |
| npm/other | 4 | claude-code, tessen, neg-pretty-printer, diff-so-fancy |

## Not ported (needs more work)
- **Python ML libs**: transformers (huge)
- **Complex C++**: neovim, nethack, nmap (missing dep libs)
- **System packages**: amd-ucode, linux-*, base, base-devel
- **AUR binaries**: act-bin, amdvlk-bin, zen-browser-bin, etc.
- **Haskell**: haskell-tidal, shellcheck

