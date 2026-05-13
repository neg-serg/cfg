{# NanoClaw AI coding agent: git clone, npm install, Quadlet container deployment #}
{% from '_imports.jinja' import user, home, retry_attempts, retry_interval %}




{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/nanoclaw.yaml' as nanoclaw %}


{% import_yaml 'data/service_catalog.yaml' as catalog %}

{% import_yaml 'data/container_images.yaml' as image_registry %}
{% set _proxy_key = salt['secrets.proxypilot_key']() %}
{% set _telegram_token = salt['secrets.tg_secret']('api/nanoclaw-telegram', 'telegram-token') %}
{% set _telegram_uid = salt['secrets.tg_secret']('api/nanoclaw-telegram-uid', 'telegram-uid') %}

{% set _nanoclaw_dir = home ~ '/.local/share/nanoclaw' %}
{% set _nanoclaw_config = home ~ '/.config/nanoclaw' %}

nanoclaw_clone:
  cmd.run:
    - name: git clone --depth=1 {{ nanoclaw.repo }} {{ _nanoclaw_dir }}
    - runas: {{ user }}
    - creates: {{ _nanoclaw_dir }}/package.json
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

{{ salt['installer.npm_build_workflow']('nanoclaw', dir=_nanoclaw_dir, version=ver.nanoclaw, require=['cmd: nanoclaw_clone']) }}

{{ salt['service.ensure_dir']('nanoclaw_config_dir', _nanoclaw_config) }}
{{ salt['service.ensure_dir']('nanoclaw_store_dir', _nanoclaw_dir ~ '/store') }}
{{ salt['service.ensure_dir']('nanoclaw_data_dir', _nanoclaw_dir ~ '/data') }}
{{ salt['service.ensure_dir']('nanoclaw_groups_dir', _nanoclaw_dir ~ '/groups') }}

nanoclaw_env:
  file.managed:
    - name: {{ _nanoclaw_dir }}/.env
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        # NanoClaw environment — managed by Salt (initial seed only)
        ANTHROPIC_API_KEY={{ _proxy_key }}
        ANTHROPIC_BASE_URL={{ nanoclaw.api_base_url }}
        ASSISTANT_NAME=NanoClaw
        CONTAINER_IMAGE=nanoclaw-agent:latest
        TZ={{ nanoclaw.tz }}
{%- if _telegram_token %}
        TELEGRAM_BOT_TOKEN={{ _telegram_token }}
{%- endif %}
    - require:
      - cmd: nanoclaw_clone

nanoclaw_sender_allowlist:
  file.managed:
    - name: {{ _nanoclaw_config }}/sender-allowlist.json
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        {
          "mode": "allowlist",
          "logDenied": true,
          "groups": {
            "*": {
              "allowed": [{{ _telegram_uid | tojson }}]
            }
          }
        }
    - require:
      - file: nanoclaw_config_dir

nanoclaw_mount_allowlist:
  file.managed:
    - name: {{ _nanoclaw_config }}/mount-allowlist.json
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        {
          "allowedMounts": []
        }
    - require:
      - file: nanoclaw_config_dir

{{ salt['service.remove_native_unit']('nanoclaw', scope='user') }}

{{ salt['container.deploy']('nanoclaw', catalog.nanoclaw, image_registry,
    quadlet_unit_name='nanoclaw-container',
    user_scope=True,
    requires=['cmd: nanoclaw_version', 'file: nanoclaw_env', 'file: nanoclaw_sender_allowlist', 'file: nanoclaw_mount_allowlist', 'cmd: nanoclaw_native_unit_daemon_reload']) }}

{{ salt['user_service.user_service_restart']('restart_nanoclaw_on_env_change', 'nanoclaw-container.service',
    onlyif='systemctl --user is-active nanoclaw-container.service >/dev/null 2>&1',
    onchanges=['file: nanoclaw_env']) }}
