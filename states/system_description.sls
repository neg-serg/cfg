{# System description: /etc/os-release branding and feature-gated state orchestration. #}
{% from '_imports.jinja' import host, user %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/system.yaml' as system %}

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

system_locale_gen:
  file.replace:
    - name: /etc/locale.gen
    - pattern: {{ system.locale_pattern }}
    - repl: '\1'
    - show_changes: false

system_locale_generate:
  cmd.run:
    - name: locale-gen
    - onchanges:
      - file: system_locale_gen

system_keymap:
  cmd.run:
    - name: localectl set-x11-keymap {{ system.x11_keymap }}
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
  - zsh
  - mounts
  - bind_mounts
  - windows_mount
  - fstab_column
  - kernel_modules
  - mkinitcpio
  - sysctl
  - hardware
  - cachyos
  - audio
  - fonts
  - desktop
  - greetd
  - systemd_resources
  - dns
  - network
  - packages
  - installers
  - installers_mpv
  - installers_desktop
  - installers_themes
  - custom_pkgs
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
{% if host.features.network.get('hiddify', false) %}
  - hiddify
{% endif %}
{% if host.zen_profile %}
  - zen_browser
  - zen_profiles
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
{% if host.features.get('managed_bots', false) %}
  - managed_bots
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
{% if host.features.monitoring.loki and host.features.monitoring.alertmanager %}
  - monitoring_alertmanager
{% endif %}
{% if host.features.network.get('zapret2', false) %}
  - zapret2
{% endif %}
