{# Music Player Daemon: audio playback server with Last.fm scrobbling #}
{% from '_imports.jinja' import host, user, home, pkg_list, gopass_secret %}


{% import_yaml 'data/mpd.yaml' as mpd %}
include:
  - bind_mounts

{% set mpdris2_installed = salt['file.search'](pkg_list, '^mpdris2$', flags='m') %}
{% set mpdas_installed = salt['file.search'](pkg_list, '^mpdas$', flags='m') %}
{%- set companion_units = [] -%}
{%- if mpdris2_installed -%}
{%-   do companion_units.append('mpDris2.service') -%}
{%- endif -%}
{%- if mpdas_installed -%}
{%-   do companion_units.append('mpdas.service') -%}
{%- endif -%}
{%- set companion_reqs = ['cmd: mpd_enabled', 'file: mpdas_config'] -%}
{%- if mpdris2_installed -%}
{%-   do companion_reqs.append('cmd: mpdris2_user_service_daemon_reload') -%}
{%- endif -%}
{%- if mpdas_installed -%}
{%-   do companion_reqs.append('file: mpdas_service_file') -%}
{%-   do companion_reqs.append('cmd: mpdas_service_file_daemon_reload') -%}
{%- endif -%}

mpd_directories:
  file.directory:
    - names:
      - {{ home }}/.local/share/mpd
      - {{ home }}/.config/mpd/playlists
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ salt['installer.cargo_pkg']('wiremix', env=mpd.wiremix_env) }}

mpd_config:
  file.managed:
    - name: {{ home }}/.config/mpd/mpd.conf
    - source: salt://dotfiles/dot_config/mpd/mpd.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True

{{ salt['user_service.user_service_enable']('mpd_enabled', start_now=['mpd.service'], check='active', onlyif='grep -qxF mpd ' ~ pkg_list, requires=['file: mpd_config', 'file: mpd_directories', 'cmd: music_mount', 'cmd: managed_service_paths_ensure']) }}

{%- set lastfm_user = salt['secrets.get']('lastfm/username') | trim %}
{%- set lastfm_pass = salt['secrets.get']('lastfm/password') | trim %}
mpdas_config:
  file.managed:
    - name: {{ home }}/.config/mpdasrc
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        host = {{ mpd.mpdas_config.host }}
        port = {{ mpd.mpdas_config.port }}
        service = {{ mpd.mpdas_config.service }}
        username = {{ lastfm_user }}
        password = {{ lastfm_pass }}

{{ salt['user_service.user_service_file']('mpdas_service_file', 'mpdas.service', source='salt://dotfiles/dot_config/systemd/user/mpdas.service') }}

{% if companion_units %}
{{ salt['user_service.user_service_enable']('mpd_companion_services', start_now=companion_units, check='active', requires=companion_reqs) }}
{% endif %}
