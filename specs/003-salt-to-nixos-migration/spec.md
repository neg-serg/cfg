---
name: spec-template
version: 1.0
description: "Specification for migrating from Salt/CachyOS to NixOS — bare-metal deployment with graphics testing and one-action deploy"

document:
  metadata:
    feature_name: "Salt to NixOS Migration — Bare-Metal Deployment"
    feature_branch: "003-salt-to-nixos-migration"
    created: "2026-05-24"
    status: "Draft"
    input_description: |
      Перенести всё добро с Salt на NixOS. Тестирование графики должно быть нормальным.
      Деплой должен проходить в одно действие. Поэтапный подход: сначала довести VM, потом bare-metal.

  sections:
    - name: User Stories
      items:
        - title: "Operator deploys NixOS on real hardware with a single command"
          priority: P1
          description: |
            As an operator, I want to run a single command that:
            1. Builds the NixOS closure from flake
            2. Creates disk partitions via disko (btrfs + LUKS + subvolumes)
            3. Installs the system onto the target disk
            4. Configures bootloader (systemd-boot)
            5. Sets up secrets via age/ragenix
            6. Provisions dotfiles (chezmoi), gopass, and user config
            — producing a fully functional workstation equivalent to my current
            Salt-managed CachyOS system.
          why_priority: |
            One-action deploy is the core value: replacing a multi-phase Salt provisioning
            (base → packages → desktop → services → security) with a single deterministic
            NixOS `nixos-rebuild switch` or equivalent.
          independent_test: |
            Wipe a test machine, run the deploy command, reboot — verify all 560+ packages,
            15+ containerized services, desktop environment, VPN, and custom tooling work.
          acceptance_scenarios:
            - given: "A machine with no prior NixOS install"
              when: "The operator runs the deployment command"
              then: "All partitions are created, packages installed, services running, desktop functional"
            - given: "An already-deployed machine with no config drift"
              when: "The operator runs the deployment command"
              then: "System reports zero changes in under 30 seconds"

        - title: "Operator tests desktop graphics (Hyprland, GPU drivers, compositor) in a controlled VM"
          priority: P1
          description: |
            As an operator, I want to deploy the exact same NixOS configuration to a
            QEMU/KVM virtual machine with GPU acceleration (virgl/SPICE) so I can
            verify that the desktop environment, compositor, greeter, and GPU driver
            stack work correctly before touching bare metal.
          why_priority: |
            Graphics is the hardest part to get right — GPU drivers, compositor config,
            display manager, and session setup must work together. Testing in a VM
            first prevents bricking the main display on real hardware.
          independent_test: |
            Run deploy against VM with virgl GPU, connect via SPICE client, verify
            quickshell greeter renders, log in, Hyprland compositor works, GPU detection
            reports virgl or virtio-gpu.
          acceptance_scenarios:
            - given: "A VM with virtio-vga-gl GPU"
              when: "NixOS deployment completes and VM boots"
              then: "greetd + quickshell greeter visible in SPICE viewer, login works, Hyprland starts"
            - given: "The user logs into Hyprland in the VM"
              when: "GPU is queried via glxinfo or lspci"
              then: "virgl or virtio-gpu is detected as the renderer"

        - title: "Operator transitions VM-verified config to bare-metal with minimal changes"
          priority: P2
          description: |
            As an operator, I want to reuse the modular NixOS configuration developed
            and tested in the VM (vms/nixos/modules/) on my actual hardware with only
            hardware-specific overrides (disk layout, GPU drivers, kernel modules, boot).
          why_priority: |
            Code reuse between VM and bare-metal reduces duplication and ensures
            the VM-tested config is what runs on hardware.
          independent_test: |
            Build both vm.nix and hardware-flake.nix from the same module set; verify
            the only differences are disk config, GPU drivers, and bootloader.
          acceptance_scenarios:
            - given: "The VM flake and bare-metal flake share the same modules/"
              when: "A diff is taken between the two flakes (excluding hardware config)"
              then: "The core modules are identical"
            - given: "A user story 1 test passes in VM"
              when: "The same modules are deployed on bare metal"
              then: "The same packages, services, and desktop are present"

        - title: "Operator benchmarks NixOS deploy vs Salt for comparison"
          priority: P3
          description: |
            As an operator, I want automated timing measurements of NixOS deployment
            (fresh and no-change) in a format comparable with existing Salt benchmarks
            so I can quantify the performance difference.
          why_priority: |
            Timing data justifies the migration investment and identifies bottlenecks.
          independent_test: |
            Run benchmark.sh fresh and no-change, verify JSON output matches
            state-profiler.py format.
          acceptance_scenarios:
            - given: "A fresh NixOS install"
              when: "benchmark.sh fresh runs"
              then: "JSON timing report is produced with phase breakdown"
            - given: "A fully deployed system with no changes"
              when: "benchmark.sh nochange runs"
              then: "Zero rebuilds reported, evaluation under 30s"

    - name: Edge Cases
      items:
        - scenario: "Hardware-specific GPU failure on bare metal"
          description: |
            AMD GPU driver (amdgpu) works in VM (virgl) but the actual AMD GPU on
            bare metal has different firmware requirements, kernel parameters, or
            PowerPlay tables. Must have fallback: boot with nomodeset, diagnose via
            dmesg, and deploy an updated GPU config.
        - scenario: "LUKS passphrase recovery"
          description: |
            If the LUKS-encrypted root cannot be unlocked at boot (lost passphrase,
            hardware TPM change), the operator must have a recovery path via
            age-encrypted fallback key or physical access recovery shell.
        - scenario: "Migration from existing btrfs Salt install"
          description: |
            The machine currently runs CachyOS with btrfs subvolumes. The NixOS
            disko config must coexist or replace the existing layout. A dual-boot
            transition period or nixos-anywhere deployment on a separate disk
            is the safest approach.
        - scenario: "Build failure due to network restrictions"
          description: |
            Nix builds fetch from cache.nixos.org and GitHub. Behind Russia's
            network restrictions, builds may fail. Must reuse SOCKS5 proxy
            passthrough from US-002 (proxy.nix module).
        - scenario: "Custom package source changes"
          description: |
            Custom packages (zen-browser, vicinae, proxypilot) depend on upstream
            git repos or release artifacts. A broken CI/CD or deleted release
            breaks the build. Pinned hashes in derivations prevent surprise changes
            but require manual bumps.
        - scenario: "Rollback on failed activation"
          description: |
            If `nixos-rebuild switch` produces a broken system (no graphics, no
            network, no boot), NixOS's boot menu generation mechanism must allow
            selecting the previous generation at GRUB/systemd-boot.

    - name: Functional Requirements
      items:
        - id: FR-001
          description: "One-command deploy: `./deploy.sh` builds closure, partitions disk, installs system, provisions data"
          must: true
        - id: FR-002
          description: "Bare-metal flake reuses all VM modules from vms/nixos/modules/ without modification"
          must: true
        - id: FR-003
          description: "Bare-metal flake adds only hardware-specific config: disk layout, GPU drivers, bootloader"
          must: true
        - id: FR-004
          description: "Graphics stack (Hyprland, drm, GPU drivers) testable in VM via virgl/SPICE before bare-metal"
          must: true
        - id: FR-005
          description: "disko partition layout for bare metal: btrfs + LUKS + subvolumes (@, @home, @nix, @snapshots)"
          must: true
        - id: FR-006
          description: "Secrets managed via ragenix (age-encrypted), using same age key as gopass setup"
          must: true
        - id: FR-007
          description: "GPU drivers: amdgpu with amdvlk + rocm for compute, Vulkan, VA-API"
          must: true
        - id: FR-008
          description: "Boot: systemd-boot with signed binaries (sbctl or lanzaboote for Secure Boot)"
          must: false
          clarification_needed: true
        - id: FR-009
          description: "Migration path: nixos-anywhere onto separate disk/partition, keep CachyOS as fallback"
          must: true
        - id: FR-010
          description: "Benchmarking script produces JSON comparable with salt state-profiler.py output"
          must: false
        - id: FR-011
          description: "GPU testing in VM: virgl/virtio-gpu with SPICE display for greeter + Hyprland verification"
          must: true
        - id: FR-012
          description: "Flatpak service enabled with flathub remote on bare metal"
          must: true
        - id: FR-013
          description: "Systemd user services migrated from Salt user_services module"
          must: true
        - id: FR-014
          description: "MPD service with Last.fm scrobbling migrated from Salt mpd module"
          must: true
        - id: FR-015
          description: "Proxypilot systemd service (binary exists in pkgs/, service missing)"
          must: true
        - id: FR-016
          description: "Windows 11 GPU passthrough VM definition migrated from desktop.vm_win11"
          must: false
          clarification_needed: true

    - name: Success Criteria
      items:
        - id: SC-001
          metric: |
            One-command deploy on bare metal produces a fully functional workstation
            with all packages, services, desktop, and secrets.
          type: quality
        - id: SC-002
          metric: |
            Graphics testing in VM (virgl+SPICE): greetd + Hyprland visible and
            interactive via SPICE client before bare-metal deployment.
          type: quality
        - id: SC-003
          metric: "No-change deploy on bare metal: zero rebuilds, evaluation <30s"
          type: performance
        - id: SC-004
          metric: "All 88 Salt states have a NixOS module equivalent covering the same functionality"
          type: quality
        - id: SC-005
          metric: "Bare-metal flake differs from VM flake only in hardware-specific modules (disk, gpu, boot)"
          type: quality
        - id: SC-006
          metric: "Rollback via systemd-boot boot menu works: select previous generation"
          type: performance
