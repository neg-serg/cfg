# Salt Configuration Documentation

Generated documentation for all project entities — states, macros, scripts, and data files.

.. toctree::
   :maxdepth: 1
   :glob:

   states/*
   macros/*
   scripts/*
   data-files/*

Salt States
===========

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - ID
     - Source
     - Purpose

   * - :salt:state:`adguardhome`
     - ``states/adguardhome.sls``
     - Cleanup legacy binary.

   * - :salt:state:`amnezia`
     - ``states/amnezia.sls``
     - Amnezia VPN: builds AmneziaWG kernel module and Amnezia VPN desktop client from source.

   * - :salt:state:`audio`
     - ``states/audio.sls``
     - PipeWire audio stack: ensures all runtime components (ALSA, JACK, Pulse) are installed.

   * - :salt:state:`bind_mounts`
     - ``states/bind_mounts.sls``
     - Bind mounts for user directories on external storage devices.

   * - :salt:state:`bitcoind`
     - ``states/bitcoind.sls``
     - Data directory for blockchain state.

   * - :salt:state:`cachyos`
     - ``states/cachyos.sls``
     - CachyOS kernel packages, boot configuration, and kernel cmdline management.

   * - :salt:state:`code_rag`
     - ``states/code_rag.sls``
     - code-rag: hybrid text+code RAG with AST-aware chunking and LanceDB vector search.

   * - :salt:state:`custom_pkgs`
     - ``states/custom_pkgs.sls``
     - Build and install custom packages from local PKGBUILDs not in official repos or AUR.

   * - :salt:state:`desktop`
     - ``states/desktop.sls``
     - Desktop environment: top-level include for compositor, packages, portal, and user session.

   * - :salt:state:`desktop.hyprland`
     - ``states/desktop/hyprland.sls``
     - Hyprland Wayland compositor: plugins, config, and session management.

   * - :salt:state:`desktop.niri`
     - ``states/desktop/niri.sls``
     - Niri scrolling-tiling Wayland compositor: package install, session setup, config, scratchpad support.

   * - :salt:state:`desktop.packages`
     - ``states/desktop/packages.sls``
     - Desktop application packages: browsers, terminals, media, productivity tools.

   * - :salt:state:`desktop.portal`
     - ``states/desktop/portal.sls``
     - XDG Desktop Portal: screen sharing, file chooser, and sandboxing backends.

   * - :salt:state:`desktop.system`
     - ``states/desktop/system.sls``
     - System-wide desktop configuration: fonts, themes, input methods, power management.

   * - :salt:state:`desktop.user`
     - ``states/desktop/user.sls``
     - User-level desktop configuration: dotfiles, services, and session autostart.

   * - :salt:state:`desktop.vm_win11`
     - ``states/desktop/vm_win11.sls``
     - Windows 11 QEMU/KVM virtual machine with GPU passthrough and Looking Glass.

   * - :salt:state:`dns`
     - ``states/dns.sls``
     - DNS services: unbound recursive resolver, AdGuard Home filtering, avahi mDNS, DoT.

   * - :salt:state:`duckdns`
     - ``states/duckdns.sls``
     - (no documentation)

   * - :salt:state:`espanso`
     - ``states/espanso.sls``
     - Espanso text expander: wayland variant with systemd user service and health check.

   * - :salt:state:`flatpak`
     - ``states/flatpak.sls``
     - Flatpak sandboxed desktop applications with flathub remote setup.

   * - :salt:state:`floorp`
     - ``states/floorp.sls``
     - Floorp browser: user.js, userChrome.css, extensions, and profile configuration.

   * - :salt:state:`fonts`
     - ``states/fonts.sls``
     - Font installation: pacman, AUR, downloaded, and custom PKGBUILD builds.

   * - :salt:state:`fstab_column`
     - ``states/fstab_column.sls``
     - Format /etc/fstab with aligned columns, preserving comments and blank lines.

   * - :salt:state:`greetd`
     - ``states/greetd.sls``
     - greetd display manager with Hyprland compositor and quickshell greeter.

   * - :salt:state:`group.ai`
     - ``states/group/ai.sls``
     - AI group: llama_embed, ollama, nanoclaw, opencode, telethon_bridge, video_ai, image_gen.

   * - :salt:state:`group.core`
     - ``states/group/core.sls``
     - Core group: users, shell, mounts, kernel modules, sysctl, systemd resources.

   * - :salt:state:`group.desktop`
     - ``states/group/desktop.sls``
     - Desktop group: audio, compositor, fonts, display manager, and user session.

   * - :salt:state:`group.network`
     - ``states/group/network.sls``
     - Network group: VPN, firewall, DNS, IPv6 tunnels, and routing.

   * - :salt:state:`group.packages`
     - ``states/group/packages.sls``
     - Packages group: system packages, AUR installers, mpv scripts, themes.

   * - :salt:state:`group.services`
     - ``states/group/services.sls``
     - Services group: systemd services, user services, and monitoring alerts.

   * - :salt:state:`hardware`
     - ``states/hardware.sls``
     - Hardware-specific configuration: udev rules, fan control, WiFi drivers.

   * - :salt:state:`hiddify`
     - ``states/hiddify.sls``
     - Hiddify VPN client: local AppImage wrapper with legacy shadow handler cleanup.

   * - :salt:state:`image_generation`
     - ``states/image_generation.sls``
     - Resolve image provider API keys from gopass (free-tier providers).

   * - :salt:state:`installers`
     - ``states/installers.sls``
     - Fallback installers: tools built from GitHub releases, pip, cargo, go, or raw HTTP.

   * - :salt:state:`installers_desktop`
     - ``states/installers_desktop.sls``
     - Desktop application installers: data-driven AUR package installation.

   * - :salt:state:`installers_mpv`
     - ``states/installers_mpv.sls``
     - MPV media player: scripts, plugins, and shaders for enhanced playback.

   * - :salt:state:`installers_themes`
     - ``states/installers_themes.sls``
     - Theme and icon installers: GTK, Qt, cursor, and icon themes from git repos.

   * - :salt:state:`ipv6`
     - ``states/ipv6.sls``
     - IPv6 diagnostics: connectivity check, firewall rules, and health monitoring.

   * - :salt:state:`ipv6_6to4`
     - ``states/ipv6_6to4.sls``
     - (no documentation)

   * - :salt:state:`ipv6_tunnel`
     - ``states/ipv6_tunnel.sls``
     - (no documentation)

   * - :salt:state:`jellyfin`
     - ``states/jellyfin.sls``
     - In-place cutover: remove native systemd unit file so Quadlet-generated unit is not shadowed.

   * - :salt:state:`kanata`
     - ``states/kanata.sls``
     - Kanata keyboard remapper: advanced key remapping daemon configuration.

   * - :salt:state:`kernel_modules`
     - ``states/kernel_modules.sls``
     - Kernel module blacklisting and loading for hardware and virtualization.

   * - :salt:state:`llama_embed`
     - ``states/llama_embed.sls``
     - llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan in Quadlet container.

   * - :salt:state:`managed_bots`
     - ``states/managed_bots.sls``
     - Managed Telegram Bots: Bot API 9.6 manager bot state.

   * - :salt:state:`mkinitcpio`
     - ``states/mkinitcpio.sls``
     - mkinitcpio initramfs configuration: hooks, modules, and compression settings.

   * - :salt:state:`monitoring_alertmanager`
     - ``states/monitoring_alertmanager.sls``
     - Alertmanager: Telegram webhook alerts from Loki log rules.

   * - :salt:state:`monitoring_alerts`
     - ``states/monitoring_alerts.sls``
     - Monitoring alerts: service watchdog timers and Loki alert rule deployment.

   * - :salt:state:`monitoring_loki`
     - ``states/monitoring_loki.sls``
     - Loki: log aggregation.

   * - :salt:state:`mounts`
     - ``states/mounts.sls``
     - Filesystem mounts: external drives, network shares, and special filesystems.

   * - :salt:state:`mpd`
     - ``states/mpd.sls``
     - Music Player Daemon: audio playback server with Last.fm scrobbling.

   * - :salt:state:`music_analysis`
     - ``states/music_analysis.sls``
     - Music analysis pipeline: BPM/key detection, fingerprinting, and indexing.

   * - :salt:state:`network`
     - ``states/network.sls``
     - (no documentation)

   * - :salt:state:`network.vm_bridge`
     - ``states/network/vm_bridge.sls``
     - (no documentation)

   * - :salt:state:`network.vpn_hybrid`
     - ``states/network/vpn_hybrid.sls``
     - (no documentation)

   * - :salt:state:`network.vpn_split_router`
     - ``states/network/vpn_split_router.sls``
     - (no documentation)

   * - :salt:state:`nyxt`
     - ``states/nyxt.sls``
     - Nyxt browser: extensible Lisp-powered web browser managed as system package.

   * - :salt:state:`ollama`
     - ``states/ollama.sls``
     - Resolve manifest path: "model:tag" → library/model/tag, "ns/model:tag" → ns/model/tag.

   * - :salt:state:`packages`
     - ``states/packages.sls``
     - - pacman -Qq checks ALL packages — fails if ANY is missing, triggering install.

   * - :salt:state:`pacman_db_warmup`
     - ``states/pacman_db_warmup.sls``
     - Pacman database warmup: ensures package databases are up to date before other states.

   * - :salt:state:`proxypilot`
     - ``states/proxypilot.sls``
     - Secret resolution.

   * - :salt:state:`services`
     - ``states/services.sls``
     - Complex services.

   * - :salt:state:`steam`
     - ``states/steam.sls``
     - Steam gaming platform: multilib, drivers, gamemode, and controller support.

   * - :salt:state:`sysctl`
     - ``states/sysctl.sls``
     - Kernel sysctl parameters: custom tuning for networking, filesystems, and security.

   * - :salt:state:`system_description`
     - ``states/system_description.sls``
     - System description: /etc/os-release branding and feature-gated state orchestration.

   * - :salt:state:`systemd_resources`
     - ``states/systemd_resources.sls``
     - Systemd resource management: sysusers, tmpfiles, and service account provisioning.

   * - :salt:state:`t5_summarization`
     - ``states/t5_summarization.sls``
     - T5 text summarization server: safetensors to GGUF conversion via Quadlet container.

   * - :salt:state:`telethon_bridge`
     - ``states/telethon_bridge.sls``
     - Telethon Bridge: Telegram MTProto relay to HTTP for LLM bot integration.

   * - :salt:state:`tidal`
     - ``states/tidal.sls``
     - TidalCycles live coding environment: Haskell, SuperDirt, and SuperCollider setup.

   * - :salt:state:`transmission`
     - ``states/transmission.sls``
     - In-place cutover: remove native systemd unit so Quadlet-generated unit is not shadowed.

   * - :salt:state:`user_services`
     - ``states/user_services.sls``
     - User-scoped systemd services: mail sync, backups, and auxiliary daemons.

   * - :salt:state:`users`
     - ``states/users.sls``
     - User account management: PAM sudo, SSH agent auth, and authorized keys.

   * - :salt:state:`vaultwarden`
     - ``states/vaultwarden.sls``
     - Vaultwarden Bitwarden server: Quadlet container, backup timers, and bw-sync.

   * - :salt:state:`video_ai`
     - ``states/video_ai.sls``
     - Video AI pipeline: includes base, models, runners, and workflow definitions.

   * - :salt:state:`video_ai.base`
     - ``states/video_ai/base.sls``
     - Video AI base: Python environment, dependencies, and shared utilities.

   * - :salt:state:`video_ai.models`
     - ``states/video_ai/models.sls``
     - Video AI models: HuggingFace model downloads and safetensors management.

   * - :salt:state:`video_ai.runners`
     - ``states/video_ai/runners.sls``
     - Video AI runners: inference server and processing daemon management.

   * - :salt:state:`video_ai.workflows`
     - ``states/video_ai/workflows.sls``
     - Video AI workflows: automated processing pipelines and job scheduling.

   * - :salt:state:`windows_mount`
     - ``states/windows_mount.sls``
     - Windows NTFS partition mount with proper permissions and fstab integration.

   * - :salt:state:`xen`
     - ``states/xen.sls``
     - Xen VR session — thin include hub. Sub-states split across xen/ directory.

   * - :salt:state:`xen.kde_theme`
     - ``states/xen/kde_theme.sls``
     - Xen KDE Breeze Dark theme seed configs — data-driven from states/data/xen.yaml.

   * - :salt:state:`xen.sessions`
     - ``states/xen/sessions.sls``
     - Xen X11 session configs: .xinitrc, i3 config, greetd .desktop entries.

   * - :salt:state:`xen.user`
     - ``states/xen/user.sls``
     - Xen user account: creation, groups, Steam library access, TTY.

   * - :salt:state:`zapret2`
     - ``states/zapret2.sls``
     - Zapret2 DPI bypass: nfqueue-based traffic filter with domain-specific rules.

   * - :salt:state:`zen_browser`
     - ``states/zen_browser.sls``
     - Zen Browser: Firefox-based browser with extensions, proxy switching, and VPN integration.

   * - :salt:state:`zen_profiles`
     - ``states/zen_profiles.sls``
     - Zen Browser Profiles: multi-profile management with isolated storage.

   * - :salt:state:`zsh`
     - ``states/zsh.sls``
     - Zsh shell environment: path setup, plugins, completions, and prompt configuration.
Jinja2 Macros
=============

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - ID
     - Source
     - Purpose

   * - :salt:macro:`_cs_fail`
     - ``states/_macros_container.jinja``
     - (no documentation)

   * - :salt:macro:`_macros_registry`
     - ``states/_macros_registry.jinja``
     - (no documentation)

   * - :salt:macro:`_tilde_expand`
     - ``states/_macros_container.jinja``
     - (no documentation)

   * - :salt:macro:`browser_extensions`
     - ``states/_macros_desktop.jinja``
     - (no documentation)

   * - :salt:macro:`cargo_pkg`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`config_and_reload`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`config_file_edit`
     - ``states/_macros_config.jinja``
     - (no documentation)

   * - :salt:macro:`container_service`
     - ``states/_macros_container.jinja``
     - (no documentation)

   * - :salt:macro:`curl_bin`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`curl_extract_tar`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`curl_extract_zip`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`dconf_settings`
     - ``states/_macros_desktop.jinja``
     - (no documentation)

   * - :salt:macro:`download_cached`
     - ``states/_macros_common.jinja``
     - (no documentation)

   * - :salt:macro:`download_font_zip`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`ensure_dir`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`ensure_running`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`env_block`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`firefox_extension`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`flatpak_install`
     - ``states/_macros_pkg.jinja``
     - (no documentation)

   * - :salt:macro:`git_clone_build`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`git_clone_deploy`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`github_release_to`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`go_pkg`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`gopass_secret`
     - ``states/_macros_common.jinja``
     - (no documentation)

   * - :salt:macro:`http_file`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`huggingface_file`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`hyprpm_add`
     - ``states/_macros_desktop.jinja``
     - (no documentation)

   * - :salt:macro:`hyprpm_enable`
     - ``states/_macros_desktop.jinja``
     - (no documentation)

   * - :salt:macro:`hyprpm_update`
     - ``states/_macros_desktop.jinja``
     - (no documentation)

   * - :salt:macro:`install_catalog`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`ipv6_tunnel`
     - ``states/_macros_ipv6_tunnel.jinja``
     - (no documentation)

   * - :salt:macro:`managed_mode_value`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`managed_path_guard`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`managed_resource_value`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`managed_sysusers_line`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`managed_tmpfiles_line`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`npm_build_workflow`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`paru_install`
     - ``states/_macros_pkg.jinja``
     - (no documentation)

   * - :salt:macro:`pip_pkg`
     - ``states/_macros_install.jinja``
     - (no documentation)

   * - :salt:macro:`pkgbuild_install`
     - ``states/_macros_pkg.jinja``
     - (no documentation)

   * - :salt:macro:`proxypilot_key`
     - ``states/_macros_common.jinja``
     - (no documentation)

   * - :salt:macro:`remove_native_package`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`remove_native_unit`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`render_service`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`service_stopped`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`service_with_healthcheck`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`service_with_unit`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`simple_service`
     - ``states/_macros_pkg.jinja``
     - (no documentation)

   * - :salt:macro:`tg_secret`
     - ``states/_macros_common.jinja``
     - (no documentation)

   * - :salt:macro:`udev_rule`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`unit_override`
     - ``states/_macros_service.jinja``
     - (no documentation)

   * - :salt:macro:`user_linger`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`user_service_disable`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`user_service_enable`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`user_service_file`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`user_service_restart`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`user_service_with_unit`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`user_unit_override`
     - ``states/_macros_service_user.jinja``
     - (no documentation)

   * - :salt:macro:`ver_stamp`
     - ``states/_macros_common.jinja``
     - (no documentation)
Python Scripts
==============

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - ID
     - Source
     - Purpose

   * - ``cleanup-logs``
     - ``scripts/cleanup-logs.py``
     - Delete Salt log files older than the given number of days.

   * - ``dep-graph``
     - ``scripts/dep-graph.py``
     - Generate dependency graph of Salt states (include/require/watch/onchanges).

   * - ``drift_state``
     - ``scripts/drift_state.py``
     - (no documentation)

   * - ``extract-inline-docs``
     - ``scripts/extract-inline-docs.py``
     - (no documentation)

   * - ``format-fstab``
     - ``scripts/format-fstab.py``
     - Format /etc/fstab with aligned columns, preserving comments and blank lines.

   * - ``generate-boot-splash``
     - ``scripts/generate-boot-splash.py``
     - Generate a minimal dark boot splash BMP for systemd-boot UKI embedding.

   * - ``generate_hypr_shortcuts``
     - ``scripts/generate_hypr_shortcuts.py``
     - Generate Hyprland shortcut search data and wlr-which-key config.

   * - ``host_model``
     - ``scripts/host_model.py``
     - Shared host model builder — single source of truth for Python tooling.

   * - ``index-qml``
     - ``scripts/index-qml.py``
     - Generate QML component and JS helper indexes for Claude Code memory.

   * - ``index-salt``
     - ``scripts/index-salt.py``
     - Generate Salt state, macro, and data indexes for Claude Code memory.

   * - ``inject-doc-blocks``
     - ``scripts/inject-doc-blocks.py``
     - (no documentation)

   * - ``lint-docs``
     - ``scripts/lint-docs.py``
     - Lint documentation: language consistency only (Russian docs discontinued).

   * - ``lint-dotfiles``
     - ``scripts/lint-dotfiles.py``
     - Lint dotfiles: shebang conventions, XDG path usage, zsh syntax.

   * - ``lint-jinja``
     - ``scripts/lint-jinja.py``
     - Lint Salt state files: Jinja2 syntax, YAML validity, duplicate state IDs,

   * - ``lint-ownership``
     - ``scripts/lint-ownership.py``
     - Lint file ownership: detect salt://dotfiles/ refs not covered by .chezmoiignore.

   * - ``lint-qml``
     - ``scripts/lint-qml.py``
     - Lint QML files via qmllint with QuickShell type info.

   * - ``lint-sysctl``
     - ``scripts/lint-sysctl.py``
     - lint-sysctl: two-part sysctl hygiene check.

   * - ``lint-units``
     - ``scripts/lint-units.py``
     - Lint systemd unit files via systemd-analyze verify.

   * - ``migrate-sls-to-python``
     - ``scripts/migrate-sls-to-python.py``
     - Mechanically replace Jinja macro calls with salt['module.func'] in .sls files.

   * - ``pretty``
     - ``scripts/lib/pretty.py``
     - pretty.py — unified terminal aesthetics for all Python scripts.

   * - ``proxypilot_recover``
     - ``scripts/proxypilot_recover.py``
     - Recover ProxyPilot free-provider config from gopass-backed provider data.

   * - ``render-matrix``
     - ``scripts/render-matrix.py``
     - Render Salt states for each feature-matrix host scenario.

   * - ``rkn-domains-fetcher``
     - ``scripts/rkn-domains-fetcher.py``
     - (no documentation)

   * - ``salt-daemon``
     - ``scripts/salt-daemon.py``
     - salt-daemon.py — pre-loaded Salt Caller daemon for faster state.apply

   * - ``salt_audit``
     - ``scripts/salt_audit.py``
     - Runtime data audit — tracks which `states/data/*.yaml` files are consumed during salt-apply.

   * - ``salt_compat``
     - ``scripts/salt_compat.py``
     - Python 3.13+ compatibility shims for Salt (PEP 594 module removals).

   * - ``salt_contracts``
     - ``scripts/salt_contracts.py``
     - Explicit contract checks for Salt inventory data.

   * - ``salt_debug_report``
     - ``scripts/salt_debug_report.py``
     - Write structured Salt debug bundles for failure analysis.

   * - ``salt_impact``
     - ``scripts/salt_impact.py``
     - Conservative impact planner for Salt auto-plan preview.

   * - ``salt_provenance``
     - ``scripts/salt_provenance.py``
     - Query minimal provenance for Salt states and imported data files.

   * - ``salt_runner``
     - ``scripts/salt_runner.py``
     - Salt-call wrapper with compatibility shims for Python 3.13+.

   * - ``salt_show``
     - ``scripts/salt_show.py``
     - Show which states a Salt SLS would apply, without executing anything.

   * - ``salt_source_model``
     - ``scripts/salt_source_model.py``
     - Shared discovery helpers for Salt source analysis.

   * - ``state-profiler``
     - ``scripts/state-profiler.py``
     - Parse salt-apply logs and print the slowest states with include context.

   * - ``update-tools``
     - ``scripts/update-tools.py``
     - Update tools defined in data/installers.yaml.

   * - ``vpn_split_router``
     - ``scripts/vpn_split_router.py``
     - DNS-based VPN split routing: observe, learn, and route domains through VPN/proxy.
Shell Scripts
=============

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - ID
     - Source
     - Purpose

   * - ``amnezia-import-tun-config``
     - ``scripts/amnezia-import-tun-config.sh``
     - Source: ~/.config/AmneziaVPN.ORG/AmneziaVPN.conf

   * - ``bootstrap-cachyos``
     - ``scripts/bootstrap-cachyos.sh``
     - Bootstrap CachyOS (Zen4/5 optimized) rootfs via Podman + Arch container.

   * - ``cache-cleanup``
     - ``scripts/cache-cleanup.sh``
     - Periodic cache cleanup for user-level caches not covered by paccache.timer.

   * - ``cachyos-packages``
     - ``scripts/cachyos-packages.sh``
     - Install all user packages on CachyOS after bootstrap

   * - ``check-ipv6``
     - ``scripts/check-ipv6.sh``
     - IPv6 diagnostics script

   * - ``check-vpn-status``
     - ``scripts/check-vpn-status.sh``
     - VPN Status Check Script

   * - ``drift-notify``
     - ``scripts/drift-notify.sh``
     - drift-notify.sh — run full drift check via drift_state.py and notify on drift

   * - ``enable-vpn-hybrid``
     - ``scripts/enable-vpn-hybrid.sh``
     - Enable hybrid VPN (Xray + sing-box TUN) via Salt states

   * - ``health-check``
     - ``scripts/health-check.sh``
     - health-check.sh — check health of all Salt-managed services

   * - ``kvm-network-rc-local``
     - ``scripts/kvm-network-rc-local.sh``
     - kvm-network-rc-local.sh — boot-time network setup for KVM test VMs

   * - ``lint-all``
     - ``scripts/lint-all.sh``
     - Run all lint checks: ruff, shellcheck, yamllint, salt-lint, taplo, doc-blocks validation; orchestrates the full lint pipeline for pre-commit and CI.

   * - ``manual-tun-routes``
     - ``scripts/manual-tun-routes.sh``
     - Manual TUN interface setup for sing-box when auto_route fails

   * - ``migrate-floorp-to-zen-profile``
     - ``scripts/migrate-floorp-to-zen-profile.sh``
     - Copy user data from Floorp browser profile into a Zen browser profile without overwriting Salt-managed Zen files. One-shot operation guarded by a marker stamp.

   * - ``pkg-drift``
     - ``scripts/pkg-drift.zsh``
     - pkg-drift.zsh — Compare declared packages against actual system state

   * - ``pkg-snapshot``
     - ``scripts/pkg-snapshot.zsh``
     - pkg-snapshot.zsh — Capture current system packages into states/data/packages.yaml

   * - ``rkn-domains-integration``
     - ``scripts/rkn-domains-integration.sh``
     - RKN Domains Integration Script

   * - ``salt-apply``
     - ``scripts/salt-apply.sh``
     - salt-apply.sh — apply Salt states (daemon-aware)

   * - ``salt-runtime``
     - ``scripts/salt-runtime.sh``
     - Generate Salt minion runtime configuration: reads file_roots from states/file_roots.yaml, creates minion config, and manages runtime directories. Called by salt-apply.sh.

   * - ``salt-validate``
     - ``scripts/salt-validate.sh``
     - Validate all Salt state files render without errors.

   * - ``start-hybrid-vpn``
     - ``scripts/start-hybrid-vpn.sh``
     - Hybrid VPN setup: Xray handles XHTTP transport, sing-box handles TUN interface

   * - ``telethon-bridge-react``
     - ``scripts/telethon-bridge-react.sh``
     - Reactive path-triggered launcher for telethon-bridge service: checks for existing session file and starts telethon-bridge.service via a .path systemd unit.

   * - ``test-browser-vpn``
     - ``scripts/test-browser-vpn.sh``
     - Test browser VPN integration

   * - ``test-kvm-deploy``
     - ``scripts/test-kvm-deploy.sh``
     - test-kvm-deploy.sh — KVM/QEMU Salt deployment test runner

   * - ``test-kvm-deploy-lib``
     - ``scripts/test-kvm-deploy-lib.sh``
     - test-kvm-deploy-lib.sh — shared functions for KVM deployment testing

   * - ``vm-smoke``
     - ``scripts/vm-smoke.sh``
     - vm-smoke.sh — run CachyOS VM deployment test inside a Podman container

   * - ``zapret2-rollout``
     - ``scripts/zapret2-rollout.sh``
     - Safe rollout workflow for zapret2 DPI bypass configuration changes: staged approval, policy review, expiration, and rollback. Enables operator-reviewed config deployment.

   * - ``zen-vpn``
     - ``scripts/zen-vpn.sh``
     - Launch zen-browser with VPN SOCKS5 proxy
Data Files
==========

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - ID
     - Source
     - Purpose

   * - :salt:data:`data/amnezia`
     - ``states/data/amnezia.yaml``
     - Data file consumed by amnezia

   * - :salt:data:`data/audio`
     - ``states/data/audio.yaml``
     - Data file consumed by audio

   * - :salt:data:`data/bind_mounts`
     - ``states/data/bind_mounts.yaml``
     - Data file consumed by bind_mounts

   * - :salt:data:`data/cachyos`
     - ``states/data/cachyos.yaml``
     - Data file consumed by cachyos

   * - :salt:data:`data/code_rag`
     - ``states/data/code_rag.yaml``
     - Data file consumed by code_rag

   * - :salt:data:`data/container_images`
     - ``states/data/container_images.yaml``
     - Data file consumed by _macros_container

   * - :salt:data:`data/custom_pkgs`
     - ``states/data/custom_pkgs.yaml``
     - Data file consumed by custom_pkgs

   * - :salt:data:`data/desktop`
     - ``states/data/desktop.yaml``
     - Data file consumed by desktop/hyprland, desktop/niri, desktop/packages, desktop/portal, desktop/system, desktop/user, desktop/vm_win11

   * - :salt:data:`data/espanso`
     - ``states/data/espanso.yaml``
     - Data file consumed by espanso

   * - :salt:data:`data/feature_matrix`
     - ``states/data/feature_matrix.yaml``
     - (no documentation)

   * - :salt:data:`data/feature_registry`
     - ``states/data/feature_registry.yaml``
     - Data file consumed by _macros_registry

   * - :salt:data:`data/flatpak`
     - ``states/data/flatpak.yaml``
     - Data file consumed by flatpak

   * - :salt:data:`data/floorp`
     - ``states/data/floorp.yaml``
     - Data file consumed by floorp

   * - :salt:data:`data/fonts`
     - ``states/data/fonts.yaml``
     - Data file consumed by fonts

   * - :salt:data:`data/free_providers`
     - ``states/data/free_providers.yaml``
     - Data file consumed by proxypilot

   * - :salt:data:`data/greetd`
     - ``states/data/greetd.yaml``
     - Data file consumed by greetd

   * - :salt:data:`data/hardware`
     - ``states/data/hardware.yaml``
     - Data file consumed by hardware

   * - :salt:data:`data/hiddify`
     - ``states/data/hiddify.yaml``
     - Data file consumed by hiddify

   * - :salt:data:`data/hosts`
     - ``states/data/hosts.yaml``
     - Data file consumed by cachyos, zen_profiles

   * - :salt:data:`data/image_providers`
     - ``states/data/image_providers.yaml``
     - Data file consumed by image_generation

   * - :salt:data:`data/installers`
     - ``states/data/installers.yaml``
     - Data file consumed by installers, music_analysis

   * - :salt:data:`data/installers_desktop`
     - ``states/data/installers_desktop.yaml``
     - Data file consumed by installers_desktop

   * - :salt:data:`data/installers_themes`
     - ``states/data/installers_themes.yaml``
     - Data file consumed by installers_themes

   * - :salt:data:`data/ipv6`
     - ``states/data/ipv6.yaml``
     - Data file consumed by ipv6, ipv6_tunnel

   * - :salt:data:`data/kanata`
     - ``states/data/kanata.yaml``
     - Data file consumed by kanata

   * - :salt:data:`data/kernel_params`
     - ``states/data/kernel_params.yaml``
     - Data file consumed by cachyos, kernel_modules

   * - :salt:data:`data/llama_embed`
     - ``states/data/llama_embed.yaml``
     - Data file consumed by llama_embed

   * - :salt:data:`data/managed_resources`
     - ``states/data/managed_resources.yaml``
     - Data file consumed by systemd_resources

   * - :salt:data:`data/monitored_services`
     - ``states/data/monitored_services.yaml``
     - Data file consumed by monitoring_alerts

   * - :salt:data:`data/mounts`
     - ``states/data/mounts.yaml``
     - Data file consumed by mounts

   * - :salt:data:`data/mpd`
     - ``states/data/mpd.yaml``
     - Data file consumed by mpd

   * - :salt:data:`data/mpv_scripts`
     - ``states/data/mpv_scripts.yaml``
     - Data file consumed by installers_mpv

   * - :salt:data:`data/nanoclaw`
     - ``states/data/nanoclaw.yaml``
     - Data file consumed by nanoclaw

   * - :salt:data:`data/network`
     - ``states/data/network.yaml``
     - Data file consumed by network/vm_bridge

   * - :salt:data:`data/ollama`
     - ``states/data/ollama.yaml``
     - Data file consumed by ollama

   * - :salt:data:`data/packages`
     - ``states/data/packages.yaml``
     - Data file consumed by packages

   * - :salt:data:`data/service_catalog`
     - ``states/data/service_catalog.yaml``
     - Data file consumed by _macros_container

   * - :salt:data:`data/services`
     - ``states/data/services.yaml``
     - Data file consumed by services

   * - :salt:data:`data/steam`
     - ``states/data/steam.yaml``
     - Data file consumed by steam

   * - :salt:data:`data/system`
     - ``states/data/system.yaml``
     - Data file consumed by system_description

   * - :salt:data:`data/t5_summarization`
     - ``states/data/t5_summarization.yaml``
     - Data file consumed by t5_summarization

   * - :salt:data:`data/telegram_managed_bots`
     - ``states/data/telegram_managed_bots.yaml``
     - Data file consumed by managed_bots

   * - :salt:data:`data/telethon_bridge`
     - ``states/data/telethon_bridge.yaml``
     - Data file consumed by telethon_bridge

   * - :salt:data:`data/tidal`
     - ``states/data/tidal.yaml``
     - Data file consumed by tidal

   * - :salt:data:`data/user_services`
     - ``states/data/user_services.yaml``
     - Data file consumed by user_services

   * - :salt:data:`data/users`
     - ``states/data/users.yaml``
     - Data file consumed by users

   * - :salt:data:`data/versions`
     - ``states/data/versions.yaml``
     - Data file consumed by amnezia, fonts, installers, installers_mpv, music_analysis, nanoclaw, telethon_bridge

   * - :salt:data:`data/video_ai`
     - ``states/data/video_ai.yaml``
     - Data file consumed by video_ai/base, video_ai/models, video_ai/runners, video_ai/workflows

   * - :salt:data:`data/vpn`
     - ``states/data/vpn.yaml``
     - Data file consumed by ipv6_6to4, network/vpn_hybrid, network/vpn_split_router

   * - :salt:data:`data/windows_mount`
     - ``states/data/windows_mount.yaml``
     - Data file consumed by windows_mount

   * - :salt:data:`data/xen`
     - ``states/data/xen.yaml``
     - Data file consumed by xen/kde_theme, xen/sessions, xen/user

   * - :salt:data:`data/zapret2`
     - ``states/data/zapret2.yaml``
     - Data file consumed by zapret2

   * - :salt:data:`data/zen_browser`
     - ``states/data/zen_browser.yaml``
     - Data file consumed by zen_browser

   * - :salt:data:`data/zen_profiles`
     - ``states/data/zen_profiles.yaml``
     - Data file consumed by zen_profiles
