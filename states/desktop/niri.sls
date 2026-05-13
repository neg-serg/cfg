{# Niri scrolling-tiling Wayland compositor: package install and session setup #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}


{% import_yaml 'data/desktop.yaml' as desktop %}

{% set niri_pkgs = desktop.niri_packages %}
{% for pkg in niri_pkgs %}
{% set safe_id = pkg | replace('xdg-desktop-portal-', '') | replace('-', '_') %}
{{ salt['pkg.paru_install']('niri_' ~ safe_id, pkg) }}
{% endfor %}

{{ salt['service.ensure_dir']('niri_config_dir', home ~ '/.config/niri', mode='0700', user=user) }}

niri_config_file:
  file.managed:
    - name: {{ home }}/.config/niri/config.kdl
    - source: salt://dotfiles/dot_config/niri/config.kdl
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: true
    - require:
      - file: niri_config_dir

niri_session_entry:
  file.managed:
    - name: /usr/share/wayland-sessions/niri.desktop
    - source: salt://desktop/niri.desktop
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true
