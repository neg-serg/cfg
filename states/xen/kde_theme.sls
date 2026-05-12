{# Xen KDE Breeze Dark theme seed configs — data-driven from states/data/xen.yaml #}

{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/xen.yaml' as xen %}

{% set xen_user = xen.user.name %}
{% set xen_home = xen.user.home %}

{{ ensure_dir('xen_kde_config_dir', xen_home ~ '/.config', user=xen_user) }}

{% for filename, config in xen.kde_configs.items() %}
xen_kde_{{ filename }}:
  file.managed:
    - name: {{ xen_home }}/.config/{{ filename }}
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
{{ config | trim | indent(8, first=True) }}
    - require:
      - user: xen_user
      - file: xen_kde_config_dir
{% endfor %}

{{ ensure_dir('xen_konsole_dir', xen_home ~ '/.local/share/konsole', user=xen_user) }}

{% for filename, profile in xen.konsole_profiles.items() %}
xen_konsole_{{ filename | replace('.', '_') }}:
  file.managed:
    - name: {{ xen_home }}/.local/share/konsole/{{ filename }}
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
{{ profile | trim | indent(8, first=True) }}
    - require:
      - file: xen_konsole_dir
{% endfor %}
