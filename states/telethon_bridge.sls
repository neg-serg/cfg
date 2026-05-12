{# Telethon Bridge: Telegram MTProto relay to HTTP for LLM bot integration #}
{% from '_imports.jinja' import user, home, proxypilot_key, tg_secret %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/telethon_bridge.yaml' as tb %}
{% set _tb_config_dir = home ~ '/.config/telethon-bridge' %}
{% set _tb_state_dir = home ~ '/.local/state/telethon-bridge' %}
{% set _proxy_key = proxypilot_key() %}
{% set _tb_creds = _tb_config_dir ~ '/credentials' %}
{% set _api_id_raw = tg_secret('api/telegram-telethon-id', 'api-id', cred_base=_tb_creds) %}
{% set _api_id = _api_id_raw if (_api_id_raw | length > 0) else '1' %}
{% set _api_hash_raw = tg_secret('api/telegram-telethon-hash', 'api-hash', cred_base=_tb_creds) %}
{% set _api_hash = _api_hash_raw if (_api_hash_raw | length > 0) else 'b6b154c370b1b2a2e8f7e0a1c1a0b0a0' %}
{% set _telegram_uid = tg_secret('api/nanoclaw-telegram-uid', 'telegram-uid') %}
{% set _telegram_uid_levra = tg_secret('api/telegram-uid-levra', 'telegram-uid-levra') %}
{% set _telegram_uid_guest2 = tg_secret('api/telegram-uid-guest2', 'telegram-uid-guest2') %}

include:
  - pacman_db_warmup

{{ paru_install('python_telethon', tb.packages | join(' '), check='__ALL__', version=ver.telethon) }}

{{ ensure_dir('telethon_bridge_config_dir', _tb_config_dir) }}
{{ ensure_dir('telethon_bridge_credentials_dir', _tb_creds, mode='0700') }}
{{ ensure_dir('telethon_bridge_state_dir', _tb_state_dir, mode='0700') }}
{{ ensure_dir('telethon_bridge_media_dir', _tb_state_dir ~ '/media') }}

telethon_bridge_config:
  file.managed:
    - name: {{ _tb_config_dir }}/config.yaml
    - source: salt://configs/telethon-bridge.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        home: {{ home }}
        api_id: {{ _api_id | tojson }}
        api_hash: {{ _api_hash | tojson }}
        proxy_key: {{ _proxy_key | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
        telegram_uid_levra: {{ _telegram_uid_levra | tojson }}
        telegram_uid_guest2: {{ _telegram_uid_guest2 | tojson }}
    - require:
      - file: telethon_bridge_config_dir
      - file: telethon_bridge_state_dir

telethon_bridge_script:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge
    - source: salt://scripts/telethon-bridge.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

telethon_bridge_init_script:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge-init
    - source: salt://scripts/telethon-bridge-init.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - file: telethon_bridge_config

telethon_bridge_react_helper:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge-react
    - source: salt://scripts/telethon-bridge-react.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

{{ user_service_file('telethon_bridge_react_service', 'telethon-bridge-react.service') }}
{{ user_service_file('telethon_bridge_react_path', 'telethon-bridge-react.path') }}

{{ user_service_enable(
    'telethon_bridge_react_enabled',
    start_now=['telethon-bridge-react.path'],
    check='active',
    requires=[
        'file: telethon_bridge_react_helper',
        'file: telethon_bridge_react_service',
        'cmd: telethon_bridge_react_service_daemon_reload',
        'file: telethon_bridge_react_path',
        'cmd: telethon_bridge_react_path_daemon_reload',
    ],
) }}

{{ user_service_file('telethon_bridge_service', 'telethon-bridge.service') }}

{{ user_service_enable('telethon_bridge_enabled',
    start_now=['telethon-bridge.service'],
    requires=[
        'cmd: install_python_telethon',
        'file: telethon_bridge_config',
        'file: telethon_bridge_service',
        'cmd: telethon_bridge_service_daemon_reload',
    ],
) }}
