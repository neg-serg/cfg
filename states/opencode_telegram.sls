{% from '_imports.jinja' import user, home, tg_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_install.jinja' import curl_bin %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service, user_service_enable, user_service_file %}
{% import_yaml 'data/versions.yaml' as ver %}

# ── Secret resolution ─────────────────────────────────────────────────
{% set _telegram_token_otb = tg_secret('api/opencode-telegram-bot', 'telegram-token', cred_base=home ~ '/.config/opencode-telegram-bot/credentials') %}
{% set _telegram_token_tc = tg_secret('api/telecode-telegram', 'telegram-token', cred_base=home ~ '/.telecode/credentials') %}
{% set _telegram_uid = tg_secret('api/nanoclaw-telegram-uid', 'telegram-uid') %}

# Guards: deploy configs only when tokens are available.
{% set _has_otb_token = _telegram_token_otb | length > 0 %}
{% set _has_tc_token = _telegram_token_tc | length > 0 %}

# ══════════════════════════════════════════════════════════════════════
# 1. OpenCode Telegram Bot (npm, requires opencode serve)
# ══════════════════════════════════════════════════════════════════════

{{ npm_pkg('opencode_telegram', pkg='@grinev/opencode-telegram-bot', bin='opencode-telegram') }}

# ── Config directory + credentials fallback ────────────────────────────
{{ ensure_dir('opencode_telegram_bot_config_dir', home ~ '/.config/opencode-telegram-bot') }}
{{ ensure_dir('opencode_telegram_bot_credentials_dir', home ~ '/.config/opencode-telegram-bot/credentials', mode='0700') }}

opencode_telegram_auth_patch:
  file.replace:
    - name: {{ home }}/.local/lib/node_modules/@grinev/opencode-telegram-bot/dist/bot/middleware/auth.js
    - pattern: 'if \(userId && userId === config\.telegram\.allowedUserId\) \{'
    - repl: 'if (userId && userId === config.telegram.allowedUserId && ctx.chat?.type === "private") {'
    - count: 1
    - require:
      - cmd: install_opencode_telegram

opencode_telegram_auth_bot_guard_patch:
  file.replace:
    - name: {{ home }}/.local/lib/node_modules/@grinev/opencode-telegram-bot/dist/bot/middleware/auth.js
    - pattern: 'const userId = ctx\.from\?\.id;'
    - repl: 'const userId = ctx.from?.id;\n    if (ctx.from?.is_bot) {\n        return;\n    }'
    - count: 1
    - require:
      - file: opencode_telegram_auth_patch

{% if _has_otb_token %}
opencode_telegram_bot_env:
  file.managed:
    - name: {{ home }}/.config/opencode-telegram-bot/.env
    - source: salt://configs/opencode-telegram-bot.env.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        telegram_token: {{ _telegram_token_otb | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
    - require:
      - file: opencode_telegram_bot_config_dir
{% endif %}

# ── OpenCode serve + bot (direct user services) ───────────────────────
{{ user_service_file('opencode_serve_service', 'opencode-serve.service') }}
{{ user_service_file('opencode_telegram_bot_service', 'opencode-telegram-bot.service') }}

{{ user_service_enable('opencode_telegram_services_enabled',
    start_now=['opencode-serve.service', 'opencode-telegram-bot.service'],
    requires=[
        'cmd: install_opencode_telegram',
        'file: opencode_telegram_auth_patch',
        'file: opencode_telegram_auth_bot_guard_patch',
        'file: opencode_serve_service',
        'cmd: opencode_serve_service_daemon_reload',
        'file: opencode_telegram_bot_service',
        'cmd: opencode_telegram_bot_service_daemon_reload',
    ] + (['file: opencode_telegram_bot_env'] if _has_otb_token else []),
) }}

# ══════════════════════════════════════════════════════════════════════
# 2. Telecode (Go binary, spawns CLI directly) — containerized
# ══════════════════════════════════════════════════════════════════════

{{ curl_bin('telecode',
    'https://github.com/futureCreator/telecode/releases/download/v' ~ ver.telecode ~ '/telecode-linux-amd64',
    version=ver.telecode) }}

# ── Config directory + credentials fallback ────────────────────────────
{{ ensure_dir('telecode_config_dir', home ~ '/.telecode') }}
{{ ensure_dir('telecode_credentials_dir', home ~ '/.telecode/credentials', mode='0700') }}

{% if _has_tc_token %}
telecode_config:
  file.managed:
    - name: {{ home }}/.telecode/config.yml
    - source: salt://configs/telecode.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        home: {{ home }}
        bot_token: {{ _telegram_token_tc | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
    - require:
      - file: telecode_config_dir
{% endif %}

# ── Telecode container ───────────────────────────────────────────────
{{ container_service('telecode', catalog.telecode, image_registry,
    user_scope=True) }}
