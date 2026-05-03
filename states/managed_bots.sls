{# Managed Telegram Bots: Bot API 9.6 manager bot state #}
{% from '_imports.jinja' import user, home, tg_secret, gopass_secret %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file %}
{% import_yaml 'data/telegram_managed_bots.yaml' as mbdata %}

{% set _telegram_token = tg_secret('api/opencode-telegram-bot', 'telegram-token', cred_base=home ~ '/.config/opencode-telegram-bot/credentials') %}
{% set _uid_levra = tg_secret('api/telegram-uid-levra', 'telegram-uid-levra') %}
{% set _uid_nanoclaw = tg_secret('api/nanoclaw-telegram-uid', 'telegram-uid') %}

{{ paru_install('managed_bots', pkg='python-telegram-bot') }}

{{ ensure_dir('managed_bots_config_dir', home ~ '/.config/opencode') }}

managed_bots_config:
  file.managed:
    - name: {{ home }}/.config/opencode/managed-bots.yaml
    - source: salt://states/configs/managed-bots.yaml.j2
    - template: jinja
    - mode: '0640'
    - context:
        telegram_token: {{ _telegram_token | tojson }}
        owner_uids: [{{ _uid_levra }}, {{ _uid_nanoclaw }}]
        allowlist_uids: {{ mbdata.allowlist_uids }}

managed_bots_script:
  file.managed:
    - name: {{ home }}/.local/bin/managed-bots-runner
    - source: salt://states/scripts/managed-bots-runner.py
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}

{{ user_service_file('managed_bots', 'managed-bots.service') }}

{{ user_service_enable('managed_bots_enabled',
    start_now=['managed-bots.service'],
    requires=['file: managed_bots_script']) }}
