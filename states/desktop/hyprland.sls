{# Hyprland Wayland compositor: plugins, config, and session management #}
{#- @state
   id: desktop.hyprland
   purpose: "Hyprland Wayland compositor: plugins, config, and session management."
   data_files: [data/desktop.yaml]
   configs: [configs/hyprpm-update.hook.j2]
#}
{% from '_imports.jinja' import user %}

{% import_yaml 'data/desktop.yaml' as desktop %}

{{ salt['service.ensure_dir']('pacman_hooks_dir_hyprpm', '/etc/pacman.d/hooks', mode='0755', user='root') }}

hyprpm_update_pacman_hook:
  file.managed:
    - name: /etc/pacman.d/hooks/hyprpm-update.hook
    - source: salt://configs/hyprpm-update.hook.j2
    - template: jinja
    - mode: '0644'
    - require:
      - file: pacman_hooks_dir_hyprpm

{% set hyprpm_cache = '/var/cache/hyprpm/' ~ user %}

hyprpm_cache_dir:
  file.directory:
    - name: {{ hyprpm_cache }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{% for plugin in desktop.hyprland_plugins %}
hyprpm_repo_cache_{{ plugin.id }}:
  file.directory:
    - name: {{ hyprpm_cache }}/{{ plugin.dir }}
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hyprpm_cache_dir
{% endfor %}

{% set _h = salt['desktop.hyprpm_data'](check_plugins=desktop.hyprland_check_plugins) %}
hyprpm_headers_update:
  cmd.run:
    - name: |
        {{ _h.cmd }}
    - runas: '{{ _h.runas }}'
    - onlyif: |
        {{ _h.onlyif }}
    - env:
        HOME: '{{ _h.home }}'
        XDG_RUNTIME_DIR: '/run/user/{{ _h.uid }}'
    - retry:
        attempts: 3
        interval: 10
    - timeout: 300
    - stateful: True
    - unless: test -f {{ _h.stamp }}
    - require:
      - cmd: install_hyprland_desktop
      - file: hyprpm_cache_dir

{# ── Hyprpm plugin add (batch) ── #}
{% set _add_script = [] %}
{% for plugin in desktop.hyprland_plugins %}
{% set _chk = 'Repository ' ~ plugin.dir %}
{% do _add_script.append(
  'if (hyprpm list 2>&1 | grep -q "' ~ _chk ~ '"); then '
  'echo "[skip] ' ~ plugin.id ~ ' already added" >&2; '
  'else '
  'yes | hyprpm add ' ~ plugin.repo ~ ' 2>/dev/null && { echo "[ok] ' ~ plugin.id ~ ' added" >&2; _changed=yes; } || true; '
  'fi'
) %}
{% endfor %}
hyprpm_plugins_add:
  cmd.run:
    - name: |
        set -euo pipefail
        SIG=$(ls -d /run/user/{{ _h.uid }}/hypr/*/.socket.sock 2>/dev/null | head -1 | xargs dirname | xargs basename)
        export HYPRLAND_INSTANCE_SIGNATURE=$SIG
        _changed=no
        {{ _add_script | join('\n        ') }}
        if [ "$_changed" = "no" ]; then
          echo '{"changed": false, "comment": "plugin repos already added"}'
        else
          echo '{"changed": true}'
        fi
    - runas: {{ user }}
    - onlyif: ss -xl 2>/dev/null | grep -q /run/user/{{ _h.uid }}/hypr/
    - env:
        HOME: {{ _h.home }}
        XDG_RUNTIME_DIR: /run/user/{{ _h.uid }}
    - timeout: 300
    - retry:
        attempts: 3
        interval: 10
    - stateful: True
    - require:
      - cmd: install_hyprland_desktop
      - cmd: hyprpm_headers_update
      - file: hyprpm_cache_dir

{# ── Hyprpm plugin enable (batch) ── #}
{% set _enable_script = [] %}
{% for plugin in desktop.hyprland_plugins %}
{% for ep in plugin.enable %}
{% do _enable_script.append(
  'if (hyprpm list 2>&1 | grep -A1 "' ~ ep.name ~ '" | grep -q "enabled:.*true"); then '
  'echo "[skip] ' ~ ep.name ~ ' already enabled" >&2; '
  'else '
  'hyprpm enable ' ~ ep.name ~ ' 2>/dev/null && { echo "[ok] ' ~ ep.name ~ ' enabled" >&2; _changed=yes; } || true; '
  'fi'
) %}
{% endfor %}
{% endfor %}
hyprpm_plugins_enable:
  cmd.run:
    - name: |
        set -euo pipefail
        SIG=$(ls -d /run/user/{{ _h.uid }}/hypr/*/.socket.sock 2>/dev/null | head -1 | xargs dirname | xargs basename)
        export HYPRLAND_INSTANCE_SIGNATURE=$SIG
        _changed=no
        {{ _enable_script | join('\n        ') }}
        if [ "$_changed" = "no" ]; then
          echo '{"changed": false, "comment": "all plugins already enabled"}'
        else
          echo '{"changed": true}'
        fi
    - runas: {{ user }}
    - onlyif: ss -xl 2>/dev/null | grep -q /run/user/{{ _h.uid }}/hypr/
    - env:
        HOME: {{ _h.home }}
        XDG_RUNTIME_DIR: /run/user/{{ _h.uid }}
    - stateful: True
    - require:
      - cmd: install_hyprland_desktop
      - cmd: hyprpm_plugins_add
