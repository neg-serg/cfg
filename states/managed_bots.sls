{# Managed Telegram Bots: Bot API 9.6 manager bot state #}
{#- @state
   id: managed_bots
   purpose: "Managed Telegram Bots: Bot API 9.6 manager bot state."
   data_files: [data/telegram_managed_bots.yaml]
   services: [managed-bots.service]
   secrets: [api/nanoclaw-telegram-uid, api/opencode-telegram-bot, api/telegram-uid-levra]
#}
{% from '_imports.jinja' import user, home %}

{% import_yaml 'data/telegram_managed_bots.yaml' as mbdata %}

{% set _telegram_token = salt['secrets.tg_secret']('api/opencode-telegram-bot', 'telegram-token', cred_base=home ~ '/.config/opencode-telegram-bot/credentials') %}
{% set _uid_levra = salt['secrets.tg_secret']('api/telegram-uid-levra', 'telegram-uid-levra') %}
{% set _uid_nanoclaw = salt['secrets.tg_secret']('api/nanoclaw-telegram-uid', 'telegram-uid') %}

{% set _owner_uids = [] %}
{% if _uid_levra %}{% do _owner_uids.append(_uid_levra | int) %}{% endif %}
{% if _uid_nanoclaw %}{% do _owner_uids.append(_uid_nanoclaw | int) %}{% endif %}

managed_bots_deps:
  cmd.run:
    - name: pip install --break-system-packages {{ mbdata.pip_deps | join(' ') }}
    - runas: {{ user }}
    - unless: test -f {{ home }}/.local/lib/python3.14/site-packages/telegram/__init__.py
    - parallel: true

{{ salt['service.ensure_dir']('managed_bots_config_dir', home ~ '/.config/opencode', user=user) }}

managed_bots_config:
  file.managed:
    - name: {{ home }}/.config/opencode/managed-bots.yaml
    - source: salt://states/configs/managed-bots.yaml.j2
    - template: jinja
    - mode: '0640'
    - user: {{ user }}
    - context:
        telegram_token: {{ _telegram_token | tojson }}
        owner_uids: {{ _owner_uids | tojson }}
        allowlist_uids: {{ mbdata.allowlist_uids | tojson }}

managed_bots_script:
  file.managed:
    - name: {{ home }}/.local/bin/managed-bots-runner
    - source: salt://states/scripts/managed-bots-runner.py
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}

{{ salt['user_service.user_service_file']('managed_bots', 'managed-bots.service') }}

{{ salt['user_service.user_service_enable']('managed_bots_enabled',
    start_now=['managed-bots.service'],
    user=user,
    requires=['file: managed_bots_script']) }}
