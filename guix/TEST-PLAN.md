# Guix VM Testing Plan
# Generated: 2026-05-27

## 1. Smoke Tests — Basic VM Health
| Test | Command | Expected |
|------|---------|----------|
| SSH access | `ssh neg@<ip> -p 2222` | Connected, password auth works |
| Hostname | `hostname` | guix-eval |
| Disk space | `df -h /` | >5G free |
| Memory | `free -h` | ~8G total |
| Uptime | `uptime` | Fresh boot |
| Load average | `uptime` | <1.0 |

## 2. Package Verification — Key Tools
| Category | Packages | Test |
|----------|----------|------|
| Shell | zsh, tmux | `zsh --version`, `tmux -V` |
| Editor | neovim (nvim) | `nvim --version` |
| Git | git, gh, lazygit | `git --version`, `gh --version`, `lazygit --version` |
| Python | python3, pip, uv | `python3 --version`, `uv --version` |
| Go | go | `go version` |
| C/C++ | gcc, clang, gdb, cmake | `gcc --version`, `clang --version` |
| Rust | cargo, rustc | `cargo --version`, `rustc --version` (note: may need fix) |
| Node | node | `node --version` |
| Network | curl, wget, nmap, iperf | `curl --version`, `wget --version` |
| System | htop, btop, strace, lsof | `htop --version`, `btop --version` |
| Search | fd, ripgrep, fzf, jq | `fd --version`, `rg --version` |
| Media | ffmpeg, mpv, imagemagick | `ffmpeg -version`, `mpv --version` |
| Containers | podman, distrobox | `podman --version` |
| Secrets | gopass, age, age-plugin-yubikey | `gopass version`, `age --version` |
| VPN | tailscale | `tailscale version` |
| LLM | ollama | `ollama --version` (or `ollama serve` check) |
| Display | hyprland, greetd | Check systemctl/shepherd status |

## 3. Service Verification
| Service | Command | Expected |
|---------|---------|----------|
| SSH | `sudo herd status ssh-daemon` | Running |
| greetd | `sudo herd status greetd` | Running |
| MPD | `sudo herd status mpd` | Running (needs config) |
| tailscaled | `sudo herd status tailscaled` | Stopped (manual start) |
| ollama | `sudo herd status ollama` | Stopped (manual start) |
| dhcpcd | `sudo herd status dhcpcd` | Running |
| unbound | Check DNS resolution | Working |

## 4. Config Deployment Verification
| Config | Path | Check |
|--------|------|-------|
| greetd | `/etc/greetd/config.toml` | `cat /etc/greetd/config.toml` |
| MPD | `~/.config/mpd/mpd.conf` | `cat ~/.config/mpd/mpd.conf` |
| sudo | `/run/setuid-programs/sudo` | `sudo whoami` returns root |
| SSH | Port 2222 | `ss -tlnp | grep 2222` |
| MOTD | `/etc/motd` | Shows chezmoi instructions |

## 5. Guix-specific Verification
| Test | Command | Expected |
|------|---------|----------|
| Guix version | `guix --version` | 1.5.0 |
| Package count | `guix package -A | wc -l` | ~30000 |
| Search speed | `time guix search python` | <2s |
| Build dry-run | `guix build --dry-run hello` | <1s |
| Channel config | `guix describe` | Shows guix channel |
| Substitutes | `guix build --dry-run python` | Uses yandex mirror |

## 6. Benchmark Comparison (vs NixOS host)
| Operation | Guix VM | NixOS host |
|----------|---------|------------|
| search python | <2s | >120s |
| search all | <25s | >180s |
| build --dry-run | <1s | >60s |
| install 1 pkg | <30s | 10-60s |

## 7. Known Issues / WIP
| Issue | Status | Fix |
|-------|--------|-----|
| cargo/rustc not in profile | `rust:cargo` spec may need fix | Add to packages list |
| ~15 missing NixOS packages | WIP | DEB/single-binary packaging |
| sudo setuid in VM image | May not work in qcow2 | Works after reconfigure |
| greetd autologin | Not configured | Add autologin to greetd config |
| pipewire user service | Not running | Started by Hyprland session |
| chezmoi dotfiles | Need manual apply | `chezmoi init --source ~/cfg && chezmoi apply` |

## 8. One-Command Deploy Test
```bash
# Full deployment from scratch:
git clone https://github.com/neg-serg/cfg.git ~/cfg
chezmoi init --source ~/cfg && chezmoi apply
sudo -i guix system reconfigure ~/cfg/guix/system-config-minimal.scm -L ~/cfg/guix/channel
sudo herd restart greetd  # or reboot
```

Expected: All packages installed, all services running, all configs deployed, Hyprland session available.
