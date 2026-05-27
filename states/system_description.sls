{# System description: /etc/os-release branding and feature-gated state orchestration. #}
{#- @state
   id: system_description
   purpose: "System description: /etc/os-release branding and feature-gated state orchestration."
   data_files: [data/system.yaml]
   configs: [configs/os-release.j2]
   feature_gate: [amnezia, dns.adguardhome, espanso, flatpak, floorp, image_gen, kanata, llama_embed, managed_bots, monitoring, mpd, music_analysis, network.hiddify, network.zapret2, nyxt, ollama, proxypilot, services.bitcoind, services.duckdns, services.jellyfin, services.transmission, steam, t5_summarization, telethon_bridge, tidal, vaultwarden, video_ai, xen_vr]
#}
{% from '_imports.jinja' import host, user %}

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

{{ salt['service.ensure_dir']('user_version_cache_dir', host.home ~ '/.cache/salt-versions', mode='0755', user=user) }}
{{ salt['service.ensure_dir']('system_version_cache_dir', '/var/cache/salt/versions', mode='0755', user='root') }}
{{ salt['service.ensure_dir']('download_cache_dir', '/var/cache/salt/downloads', mode='0755', user='root') }}

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
  - quickshell
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
{% if host.features.get('vaultwarden', false) %}
  - vaultwarden
{% endif %}
{% if host.features.dns.get('adguardhome', false) %}
  - adguardhome
{% endif %}
{% if host.features.get('proxypilot', True) %}
  - proxypilot
{% endif %}

{% if host.features.get('amnezia', false) %}
  - amnezia
{% endif %}
{% if host.features.get('flatpak', true) %}
  - flatpak
{% endif %}
{% if host.features.get('espanso', false) %}
  - espanso
{% endif %}
{% if host.features.get('floorp', false) and host.floorp_profile %}
  - floorp
{% endif %}
{% if host.features.get('nyxt', false) %}
  - nyxt
{% endif %}
{% if host.features.network.get('hiddify', false) %}
  - hiddify
{% endif %}
{% if host.zen_profile %}
  - zen_browser
  - zen_profiles
{% endif %}
{% if host.features.get('kanata', true) %}
  - kanata
{% endif %}
{% if host.features.get('mpd', true) %}
  - mpd
{% endif %}
{% if host.features.get('music_analysis', false) %}
  - music_analysis
{% endif %}
{% if host.features.get('tidal', false) %}
  - tidal
{% endif %}
{% if host.features.get('ollama', true) %}
  - ollama
{% endif %}
{% if host.features.get('llama_embed', true) %}
  - llama_embed
{% endif %}
{% if host.features.get('telethon_bridge', false) %}
  - telethon_bridge
{% endif %}
{% if host.features.get('managed_bots', false) %}
  - managed_bots
{% endif %}
{% if host.features.get('image_gen', true) %}
  - image_generation
{% endif %}
{% if host.features.get('video_ai', true) %}
  - video_ai
{% endif %}
{% if host.features.get('t5_summarization', true) %}
  - t5_summarization
{% endif %}
{% if host.features.get('steam', true) %}
  - steam
{% endif %}
{% if host.features.get('xen_vr', false) %}
  - xen
{% endif %}
{% if host.features.get('monitoring', {}).get('loki', false) %}
  - monitoring_loki
{% endif %}
{% if host.features.get('monitoring', {}).get('loki', false) and host.features.get('monitoring', {}).get('alertmanager', false) %}
  - monitoring_alertmanager
{% endif %}
{% if host.features.network.get('zapret2', false) %}
  - zapret2
{% endif %}
