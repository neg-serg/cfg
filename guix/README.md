# Guix VM Packages

VM image: `/var/lib/libvirt/images/guix-eval-vm.qcow2` (100 GB)

## Files

- `channels.scm` — channel configuration (guix + nonguix)
- `packages/duf.scm` — duf 0.9.1 (Go, recursive import)
- `packages/rust-latest.scm` — rust-latest 1.95.0 (experimental)

## Build tools in VM

- rustc 1.95.0 via rustup (requires `LD_LIBRARY_PATH`)
- go 1.25.3
- cargo, python, pip

## Package counts

- Guix user profile: 161
- Guix system profile: 363
- /usr/local/bin: 20+ (built from source or static)

## Building Rust packages

```sh
env PATH="/root/.cargo/bin:/run/current-system/profile/bin" \
  LD_LIBRARY_PATH="/root/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib" \
  cargo install --root /usr/local --locked <package>
```
