{% from '_imports.jinja' import host, user %}
{% from '_macros_service.jinja' import ensure_dir %}
# Salt state for CachyOS workstation — top-level orchestrator
# Packages managed via packages.sls (data/packages.yaml) + domain-specific states

# ── Distro identity (was os_release.sls) ──────────────────────────────
system_os_release:
  file.managed:
    - name: /etc/os-release
    - source: salt://configs/os-release.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

system_timezone:
  timezone.system:
    - name: {{ host.timezone }}

system_locale:
  file.managed:
    - name: /etc/locale.conf
    - contents: 'LANG={{ host.locale }}'

system_keymap:
  cmd.run:
    - name: localectl set-x11-keymap ru,us
    - unless: grep -q 'ru' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null

system_hostname:
  file.managed:
    - name: /etc/hostname
    - contents: {{ host.hostname }}

{{ ensure_dir('user_version_cache_dir', host.home ~ '/.cache/salt-versions', mode='0755') }}
{{ ensure_dir('system_version_cache_dir', '/var/cache/salt/versions', mode='0755', user='root') }}
{{ ensure_dir('download_cache_dir', '/var/cache/salt/downloads', mode='0755') }}

include:
  - pacman_db_warmup

  # ── Core (always included) ──────────────────────────────────────────
  # User accounts, shell, disk mounts — foundations for everything else
  - users
  - zsh
  - mounts
  - bind_mounts
  - fstab_column

  # Kernel tuning, hardware, sysctl
  - kernel_modules
  - kernel_params_limine
  - mkinitcpio
  - sysctl
  - hardware

  # Desktop: audio stack, DE config, login manager, fonts
  - audio
  - desktop
  - fonts
  - greetd

  # Shared systemd-managed service identities and paths
  - systemd_resources

  # Network: DNS
  - dns
  - network

  # Packages: base system, CLI tools, desktop apps, themes, custom PKGBUILDs
  - packages
  - installers
  - installers_mpv
  - installers_desktop
  - installers_themes
  - custom_pkgs

  # Services, monitoring, user units
  - services
  - monitoring_alerts
  - user_services
  - code_rag

{% if host.features.services.get('jellyfin', false) %}
  - jellyfin
{% endif %}
{% if host.features.services.get('transmission', false) %}
  - transmission
{% endif %}
{% if host.features.services.get('bitcoind', false) %}
  - bitcoind
{% endif %}
{% if host.features.services.get('duckdns', false) %}
  - duckdns
{% endif %}
{% if host.features.dns.get('adguardhome', false) %}
  - adguardhome
{% endif %}
{% if host.features.get('proxypilot', True) %}
  - proxypilot
{% endif %}

  # ── Feature-gated (skipped entirely when disabled) ──────────────────
{% if host.features.amnezia %}
  - amnezia
{% endif %}
{% if host.features.flatpak %}
  - flatpak
{% endif %}
{% if host.features.get('espanso', false) %}
  - espanso
{% endif %}
{% if host.features.floorp and host.floorp_profile %}
  - floorp
{% endif %}
  - nyxt
{% if host.features.network.get('hiddify', True) %}
  - hiddify
{% endif %}
{% if host.zen_profile %}
  - zen_browser
{% endif %}
{% if host.features.kanata %}
  - kanata
{% endif %}
{% if host.features.mpd %}
  - mpd
{% endif %}
{% if host.features.get('music_analysis') %}
  - music_analysis
{% endif %}
{% if host.features.tidal %}
  - tidal
{% endif %}
{% if host.features.ollama %}
  - ollama
{% endif %}
{% if host.features.llama_embed %}
  - llama_embed
{% endif %}
{% if host.features.opencode %}
  - opencode
{% endif %}
{% if host.features.get('nanoclaw', false) %}
  - nanoclaw
{% endif %}
{% if host.features.get('telethon_bridge', false) %}
  - telethon_bridge
{% endif %}
{% if host.features.get('opencode_telegram', false) %}
  - opencode_telegram
{% endif %}
{% if host.features.get('image_gen', True) %}
  - image_generation
{% endif %}
{% if host.features.get('video_ai', False) %}
  - video_ai
{% endif %}
{% if host.features.steam %}
  - steam
{% endif %}
{% if host.features.get('xen_vr', false) %}
  - xen
{% endif %}
  - monitoring_loki
{% if host.features.network.get('zapret2', false) %}
  - zapret2
{% endif %}
