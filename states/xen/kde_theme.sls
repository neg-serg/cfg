{# Xen KDE Breeze Dark theme seed configs — data-driven from states/data/xen.yaml #}

{% from '_macros_service.jinja' import ensure_dir %}

{% set xen_user = 'xen' %}
{% set xen_home = '/home/' ~ xen_user %}
{% set xen_data = salt.cp.get_file_str('salt://data/xen.yaml') | load_yaml %}

# ── KDE Breeze Dark theme for xen ─────────────────────────────────
{{ ensure_dir('xen_kde_config_dir', xen_home ~ '/.config', user=xen_user) }}

# KDE Breeze Dark seed configs (initial deploy only)
{% for filename, config in xen_data.kde_configs.items() %}
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

# Konsole: dark profile
{{ ensure_dir('xen_konsole_dir', xen_home ~ '/.local/share/konsole', user=xen_user) }}

{% for filename, profile in xen_data.konsole_profiles.items() %}
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
