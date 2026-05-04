{% from '_imports.jinja' import user, home, proxypilot_key, gopass_secret %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, user_service_restart, remove_native_unit %}
{% from '_macros_container.jinja' import container_service %}
{% import_yaml 'data/free_providers.yaml' as free_providers_data %}

# ProxyPilot LLM proxy — pure Quadlet (Podman container).
# Replaces native pacman package (proxypilot) + user systemd service.

{# ── Secret resolution ── #}
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _pp_raw = salt['cmd.run_stdout']('cat ' ~ _proxypilot_cfg ~ ' 2>/dev/null || true', runas=user, python_shell=True).strip() %}
{% set _pp = (_pp_raw | load_yaml) if _pp_raw else {} %}
{% set _existing_mgmt = _pp.get('remote-management', {}).get('secret-key', '') %}

{% set _proxypilot_api_key = proxypilot_key() %}
{% set _mgmt_fallback = "echo '" ~ (_existing_mgmt if _existing_mgmt else '') ~ "'" %}
{% set _mgmt_raw = gopass_secret('api/proxypilot-management', _mgmt_fallback) %}
{% set _proxypilot_mgmt_key = _mgmt_raw if _mgmt_raw else _existing_mgmt %}

{% set _free_providers = [] %}
{% for p in free_providers_data.get('providers', []) %}
  {% if p.gopass_key is defined %}
    {% set _pf_config = _pp.get('openai-compatibility', []) | selectattr('name', 'equalto', p.name) | list %}
    {% set _pf_entry = _pf_config[0] if _pf_config else {} %}
    {% set _pfkey = _pf_entry.get('api-key-entries', [{}])[0].get('api-key', '') %}
    {% set _key = gopass_secret(p.gopass_key, "echo '" ~ _pfkey ~ "'") %}
  {% else %}
    {% set _key = p.get('dummy_key', '') %}
  {% endif %}
  {% if _key %}
    {% do _free_providers.append({'name': p.name, 'base_url': p.base_url, 'api_key': _key, 'models': p.models}) %}
  {% endif %}
{% endfor %}

{# ── Config directory + config file ── #}
{{ ensure_dir('proxypilot_config_dir', home ~ '/.config/proxypilot') }}

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
        api_key: {{ _proxypilot_api_key | tojson }}
        mgmt_key: {{ _proxypilot_mgmt_key | tojson }}
        free_providers: {{ _free_providers | tojson }}
    - require:
      - file: proxypilot_config_dir

{# ── In-place cutover: remove native user unit ── #}
{{ remove_native_unit('proxypilot', scope='user') }}

{# ── Container deployment ── #}
{{ container_service('proxypilot', catalog.proxypilot, image_registry,
    quadlet_unit_name='proxypilot-container',
    user_scope=True,
    requires=['file: proxypilot_config', 'cmd: proxypilot_native_unit_daemon_reload']) }}

{# ── Restart on config change ── #}
{{ user_service_restart('restart_proxypilot_on_config_change', 'proxypilot-container.service',
    onlyif='systemctl --user is-active proxypilot-container.service >/dev/null 2>&1',
    onchanges=['file: proxypilot_config']) }}
