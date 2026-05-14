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
    - recurse:
      - user
      - group

{% for plugin in desktop.hyprland_plugins %}
hyprpm_repo_cache_{{ plugin.id }}:
  file.directory:
    - name: {{ hyprpm_cache }}/{{ plugin.dir }}
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hyprpm_cache_dir
{% endfor %}

{{ salt['desktop.hyprpm_update']('hyprpm_headers_update',
    check_plugins=desktop.hyprland_check_plugins,
    require=['cmd: install_hyprland_desktop', 'file: hyprpm_cache_dir']) }}

{% for plugin in desktop.hyprland_plugins %}
{{ salt['desktop.hyprpm_add']('hyprpm_add_' ~ plugin.id,
    plugin.repo,
    'Repository ' ~ plugin.dir,
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_' ~ plugin.id]) }}
{% endfor %}

{% for plugin in desktop.hyprland_plugins %}
{% for ep in plugin.enable %}
{{ salt['desktop.hyprpm_enable']('hyprpm_enable_' ~ ep.name | lower | replace('-', '_'),
    ep.name,
    require=['cmd: hyprpm_add_' ~ plugin.id]) }}
{% endfor %}
{% endfor %}
