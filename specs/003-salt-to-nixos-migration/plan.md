---
name: plan-template
version: 1.0
description: "Implementation plan for Salt to NixOS Migration — Bare-Metal Deployment"

document:
  metadata:
    branch: "003-salt-to-nixos-migration"
    date: "2026-05-24"
    spec_ref: "specs/003-salt-to-nixos-migration/spec.md"
    input_description: |
      Перенести всё добро с Salt на NixOS. Тестирование графики должно быть нормальным.
      Деплой должен проходить в одно действие. Поэтапный подход: сначала довести VM, потом bare-metal.

  sections:
    - name: Summary
      content: |
        Migrate the current Salt-managed CachyOS workstation to NixOS in two phases.

        **Phase 1 — Complete the VM** (incremental, weeks): Fill remaining gaps in the
        existing NixOS VM configuration (flatpak, mpd, proxypilot service, user services,
        espanso, installers, image_gen). Test the VM with virgl GPU + SPICE display to
        verify the desktop stack (greetd → Hyprland) works in a graphical VM before
        touching real hardware.

        **Phase 2 — Bare-metal deploy** (one-shot, after Phase 1 is stable): Create a
        bare-metal flake reusing all VM modules, add hardware-specific config (disko
        with btrfs+LUKS for actual NVMe/SSD, amdgpu GPU drivers, systemd-boot), and
        deploy via nixos-anywhere onto a separate disk. Keep existing CachyOS disk
        as fallback during transition.

        The output is:
        1. A completed NixOS VM at `vms/nixos/` that passes `deploy-vm.sh --graphical`
           with greetd + Hyprland rendering over SPICE
        2. A bare-metal NixOS flake at `vms/nixos/baremetal/` that is deployable via
           `vms/nixos/scripts/deploy-baremetal.sh` in a single command
        3. A migration period where both CachyOS (Salt) and NixOS coexist on separate
           disks, with the user switching between them via UEFI boot menu

    - name: Technical Context
      fields:
        language_version: "Nix expression language (nixpkgs unstable, NixOS 25.05)"
        primary_dependencies: |
          nixpkgs (nixos-unstable), nixos-anywhere, disko, ragenix, QEMU/KVM,
          nixos-generators, Podman, SPDX tooling
        storage: "btrfs + LUKS (bare metal), ext4 + VFAT (VM), disko-managed"
        testing: "VM (virgl/SPICE) for graphics; bare-metal for hardware validation"
        target_platform: "x86_64-linux — CachyOS host → NixOS bare metal"
        project_type: "NixOS system configuration (flake-based declarative deployment)"
        performance_goals: |
          Fresh deploy: one command, under 1 hour (most time is nix build).
          No-change deploy: evaluation <30s, zero rebuilds.
        constraints: |
          Must work through SOCKS5 proxy (Russia network restrictions).
          Must coexist with existing Salt config in same repo during migration.
          Must reuse VM-tested modules for bare metal.
        scale_scope: "Single workstation: 88 Salt states → NixOS equivalent"

    - name: Constitution Check
      gates:
        - name: "I. Idempotency"
          passed: true
          notes: |
            Nix guarantees idempotency. All states are pure functions of the Nix
            expression. No-change = zero side effects.

        - name: "II. Network Resilience"
          passed: true
          notes: |
            Nix binary caches handle most downloads. SOCKS5 proxy passthrough
            from US-002 (proxy.nix module) is already in place for restricted networks.

        - name: "III. Secrets Isolation"
          passed: true
          notes: |
            ragenix (age-based) matches existing gopass+age workflow. Secrets
            encrypted in repo, decrypted at build time into /run/secrets/ tmpfs.

        - name: "IV. Macro-First"
          passed: true
          notes: |
            N/A to Nix. NixOS modules + overlays replace Salt's Jinja macros.

        - name: "V. Minimal Change"
          passed: true
          notes: |
            No changes to Salt states. Nix config lives in vms/nixos/ — same repo,
            separate directory. Salt remains bootable as fallback on CachyOS disk.

        - name: "VI. Convention Adherence"
          passed: true
          notes: |
            Follows Nix community conventions: flake.nix entry point, module-based
            config, disko for partitioning, ragenix for secrets.

        - name: "VII. Verification Gate"
          passed: true
          notes: |
            nix flake check + nixos-rebuild dry-build for compile-time verification.
            VM deploy for runtime verification before bare metal.

    - name: Project Structure
      docs_layout:
        path: "specs/003-salt-to-nixos-migration/"
        files:
          - {name: "spec.md", type: "feature specification"}
          - {name: "plan.md", type: "implementation plan"}
          - {name: "research.yaml", type: "Phase 0 research output"}
          - {name: "tasks.md", type: "Phase 2 task list (created by speckit.tasks)"}
      source_layout:
        description: "NixOS configuration extending existing vms/nixos/ structure"
        options: []
        selected: |
          vms/nixos/                      ← Existing (unchanged structure)
          ├── modules/                    ← Shared modules (VM + bare metal)
          │   ├── base.nix               ✓
          │   ├── packages.nix           ✓
          │   ├── desktop.nix            ✓ (needs flatpak)
          │   ├── audio.nix              ✓
          │   ├── network.nix            ✓
          │   ├── containers.nix         ✓
          │   ├── ai.nix                 ✓ (needs image_gen)
          │   ├── monitoring.nix         ✓
          │   ├── steam.nix              ✓
          │   ├── dev.nix                ✓
          │   ├── proxy.nix              ✓
          │   ├── zsh.nix                ✓
          │   ├── greetd-greeter.nix     ✓
          │   ├── flatpak.nix             ✗ NEW
          │   ├── mpd.nix                 ✗ NEW
          │   ├── proxypilot-service.nix  ✗ NEW
          │   ├── espanso.nix             ✗ NEW
          │   ├── user-services.nix       ✗ NEW
          │   └── installers.nix          ✗ NEW
          ├── pkgs/                      ← Custom derivations
          │   ├── default.nix            ✓
          │   └── *.nix (18 files)       ✓
          ├── scripts/
          │   ├── deploy-vm.sh           ✓ (exists, may need minor updates)
          │   ├── deploy-baremetal.sh     ✗ NEW
          │   ├── benchmark.sh           ✓
          │   └── decrypt-secrets.sh     ✓
          ├── baremetal/                  ✗ NEW directory
          │   ├── flake.nix               ✗ NEW
          │   ├── disk-config.nix         ✗ NEW
          │   ├── hardware-configuration.nix  ✗ NEW (nixos-generate-config output)
          │   └── gpu.nix                 ✗ NEW
          ├── disk-config.nix            ✓ (VM layout)
          ├── age.secrets.nix            ✓
          ├── flake.nix                  ✓ (VM flake)
          ├── vm.nix                     ✓
          └── secrets/                   ✓ (age-encrypted)
        decision_rationale: |
          Shared modules in vms/nixos/modules/ are used by both VM and bare-metal flakes.
          The bare-metal config adds only hardware-specific files in vms/nixos/baremetal/.
          New modules (flatpak, mpd, etc.) are added to vms/nixos/modules/ — tested in
          VM first. This structure ensures the VM-tested config is guaranteed to match
          what runs on hardware.

    - name: Complexity Tracking
      items: []
