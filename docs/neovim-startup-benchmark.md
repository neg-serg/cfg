# Neovim Startup Benchmark

- Date: 2026-04-17
- Command: `zsh dotfiles/dot_local/bin/executable_nvim-bench 8 40`
- Baseline median: `120.482ms`
- Current result:
  - `min: 120.027ms`
  - `median: 120.790ms`
  - `p95: 121.649ms`
  - `max: 121.649ms`
  - `FAIL: median 120.790ms >= 40ms threshold`
- Note: Startup stayed roughly flat, with a slight regression versus baseline.
