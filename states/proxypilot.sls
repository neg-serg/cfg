{#- @state
   id: proxypilot
   purpose: "Secret resolution."
   data_files: [data/free_providers.yaml]
   configs: [configs/proxypilot.yaml.j2]
   services: [proxypilot.container]
   secrets: [api/proxypilot-management]
#}
{% from '_imports.jinja' import user, home %}

{% import_yaml 'data/free_providers.yaml' as free_providers_data %}

# ProxyPilot LLM proxy — pure Quadlet (Podman container).
# Replaces native pacman package (proxypilot) + user systemd service.

{# ── Secret resolution ── #}
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% if salt['file.file_exists'](_proxypilot_cfg) %}
{% set _pp_raw = salt['file.read'](_proxypilot_cfg).strip() %}
{% else %}
{% set _pp_raw = '' %}
{% endif %}
{% set _pp = (_pp_raw | load_yaml) if _pp_raw else {} %}
{% set _existing_mgmt = _pp.get('remote-management', {}).get('secret-key', '') | string %}
{% set _existing_mgmt_clean = _existing_mgmt | replace('"', '') | replace("'", '') %}

{% set _proxypilot_api_key = salt['secrets.proxypilot_key']() %}
{% set _mgmt_fallback = "echo '" ~ _existing_mgmt_clean ~ "'" %}
{% set _mgmt_raw = salt['secrets.gopass_secret']('api/proxypilot-management', _mgmt_fallback) %}
{% set _proxypilot_mgmt_key = _mgmt_raw if _mgmt_raw else _existing_mgmt_clean %}
{% if _existing_mgmt.startswith('$2') %}
{% set _proxypilot_mgmt_key = _existing_mgmt %}
{% endif %}

{% set _free_providers = [] %}
{% for p in free_providers_data.get('providers', []) %}
  {% if p.gopass_key is defined %}
    {% set _pf_config = _pp.get('openai-compatibility', []) | selectattr('name', 'equalto', p.name) | list %}
    {% set _pf_entry = _pf_config[0] if _pf_config else {} %}
    {% set _pfkey = _pf_entry.get('api-key-entries', [{}])[0].get('api-key', '') %}
    {% set _key = salt['secrets.gopass_secret'](p.gopass_key, "echo '" ~ _pfkey ~ "'") %}
  {% else %}
    {% set _key = p.get('dummy_key', '') %}
  {% endif %}
  {% if _key %}
    {% do _free_providers.append({'name': p.name, 'base_url': p.base_url, 'api_key': _key, 'models': p.models}) %}
  {% endif %}
{% endfor %}

{# ── Config directory + config file ── #}
{{ salt['service.ensure_dir']('proxypilot_config_dir', home ~ '/.config/proxypilot', user=user) }}

proxypilot_config:
  file.managed:
    - name: {{ home }}/.config/proxypilot/config.yaml
    - source: salt://configs/proxypilot.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        user: {{ user }}
        home: {{ home }}
        api_key: {{ _proxypilot_api_key }}
        mgmt_key: {{ _proxypilot_mgmt_key }}
        free_providers: {{ _free_providers | tojson }}
    - require:
      - file: proxypilot_config_dir

{# ── In-place cutover: remove native user unit ── #}
{{ salt['service.remove_native_unit']('proxypilot', scope='user') }}

{# ── Container deployment ── #}
{{ salt['container.deploy']('proxypilot',
    quadlet_unit_name='proxypilot-container',
    user_scope=True,
    requires=['file: proxypilot_config', 'cmd: proxypilot_native_unit_daemon_reload']) }}

{# ── Restart on config change ── #}
{{ salt['user_service.user_service_restart']('restart_proxypilot_on_config_change', 'proxypilot-container.service',
    onchanges=['file: proxypilot_config']) }}
