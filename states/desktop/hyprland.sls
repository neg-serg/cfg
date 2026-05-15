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
    - require:
      - cmd: install_hyprland_desktop
      - file: hyprpm_cache_dir

{% for plugin in desktop.hyprland_plugins %}
{% set _a = salt['desktop.hyprpm_add_data'](plugin.repo, 'Repository ' ~ plugin.dir) %}
hyprpm_add_{{ plugin.id }}:
  cmd.run:
    - name: |
        {{ _a.cmd }}
    - runas: '{{ _a.runas }}'
    - onlyif: |
        {{ _a.onlyif }}
    - env:
        HOME: '{{ _a.home }}'
        XDG_RUNTIME_DIR: '/run/user/{{ _a.uid }}'
    - timeout: 300
    - retry:
        attempts: 3
        interval: 10
    - require:
      - cmd: install_hyprland_desktop
      - cmd: hyprpm_headers_update
      - file: hyprpm_repo_cache_{{ plugin.id }}
{% endfor %}

{% for plugin in desktop.hyprland_plugins %}
{% for ep in plugin.enable %}
{% set _e = salt['desktop.hyprpm_enable_data'](ep.name) %}
hyprpm_enable_{{ ep.name | lower | replace('-', '_') }}:
  cmd.run:
    - name: |
        {{ _e.cmd }}
    - runas: '{{ _e.runas }}'
    - onlyif: |
        {{ _e.onlyif }}
    - env:
        HOME: '{{ _e.home }}'
        XDG_RUNTIME_DIR: '/run/user/{{ _e.uid }}'
    - require:
      - cmd: hyprpm_add_{{ plugin.id }}
{% endfor %}
{% endfor %}
