{# Flatpak sandboxed desktop applications with flathub remote setup #}
# Flatpak: sandboxed desktop apps + flathub remote.
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, retry_attempts, retry_interval %}
# Flatpak: install runtime + flathub remote + user-level apps
{% import_yaml 'data/flatpak.yaml' as flatpak %}

{{ salt['pkg.paru_install']('flatpak', 'flatpak') }}

flatpak_flathub_remote:
  cmd.run:
    - name: sudo -u {{ user }} flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    - unless: sudo -u {{ user }} flatpak remotes --user --columns=name | grep -qx 'flathub'
    - require:
      - cmd: install_flatpak
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

{% for app_id in flatpak.apps %}
{{ salt['pkg.flatpak_install'](app_id) }}
{% endfor %}
