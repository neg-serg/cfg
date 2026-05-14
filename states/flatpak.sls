{# Flatpak sandboxed desktop applications with flathub remote setup #}
# Flatpak: sandboxed desktop apps + flathub remote.
include:
  - pacman_db_warmup

{% from '_imports.jinja' import host, user %}
# Flatpak: install runtime + flathub remote + user-level apps
{% import_yaml 'data/flatpak.yaml' as flatpak %}

{{ salt['pkg.paru_install']('flatpak', 'flatpak') }}

flatpak_flathub_remote:
  cmd.run:
    - name: flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    - runas: {{ user }}
    - env:
      - HOME: {{ host.home }}
    - require:
      - cmd: install_flatpak

{% for app_id in flatpak.apps %}
{{ salt['pkg.flatpak_install'](app_id) }}
{% endfor %}
