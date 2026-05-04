{# Zen Browser Profiles: multi-profile management with isolated storage #}
{% from '_imports.jinja' import user, home %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/zen_profiles.yaml' as zpdata %}
{% import_yaml 'data/hosts.yaml' as hosts %}

{% set _zen_dir = home ~ '/.config/zen' %}

{{ ensure_dir('zen_profiles_dir', _zen_dir, user=user) }}

zen_profile_script:
  file.managed:
    - name: {{ home }}/.local/bin/zen-profile
    - source: salt://states/scripts/zen-profile
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}

{% for profile in zpdata.profiles %}
{% set _prof_name = profile.name %}
{% set _prof_path = profile.path %}

zen_profile_create_{{ _prof_path }}:
  cmd.run:
    - name: "zen-browser -CreateProfile '{{ _prof_name }} {{ _zen_dir }}/{{ _prof_path }}'"
    - onlyif: "command -v zen-browser"
    - runas: {{ user }}
    - creates: {{ _zen_dir }}/{{ _prof_path }}
    - unless: "grep -qF 'Name={{ _prof_name }}' {{ _zen_dir }}/profiles.ini"
{% endfor %}
