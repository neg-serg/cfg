{% from '_imports.jinja' import user, home, tg_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file %}

# ── Secret resolution ─────────────────────────────────────────────────
{% set _telegram_token_otb = tg_secret('api/opencode-telegram-bot', 'telegram-token', cred_base=home ~ '/.config/opencode-telegram-bot/credentials') %}
{% set _telegram_uid = tg_secret('api/nanoclaw-telegram-uid', 'telegram-uid') %}
{% set _telegram_uid_levra = tg_secret('api/telegram-uid-levra', 'telegram-uid-levra') %}

# Guard: deploy config only when token is available.
{% set _has_otb_token = _telegram_token_otb | length > 0 %}

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
    - repl: 'if (userId && (Array.isArray(config.telegram.allowedUserIds) ? config.telegram.allowedUserIds.includes(userId) : userId === config.telegram.allowedUserId) && ctx.chat?.type === "private") {'
    - count: 1
    - require:
      - cmd: install_opencode_telegram

opencode_telegram_auth_bot_guard_patch:
  file.replace:
    - name: {{ home }}/.local/lib/node_modules/@grinev/opencode-telegram-bot/dist/bot/middleware/auth.js
    - pattern: 'const userId = ctx\.from\?\.id;\n(?:    if \(ctx\.from\?\.is_bot\) \{\n        return;\n    \}\n)?'
    - repl: 'const userId = ctx.from?.id;\n    if (ctx.from?.is_bot) {\n        return;\n    }\n'
    - count: 1
    - require:
      - file: opencode_telegram_auth_patch

opencode_telegram_config_allowlist_patch:
  file.replace:
    - name: {{ home }}/.local/lib/node_modules/@grinev/opencode-telegram-bot/dist/config.js
    - pattern: '        allowedUserId: parseInt\(getEnvVar\("TELEGRAM_ALLOWED_USER_ID"\), 10\),\n'
    - repl: '        allowedUserId: parseInt(getEnvVar("TELEGRAM_ALLOWED_USER_ID"), 10),\n        allowedUserIds: getOptionalAllowedUserIdsEnvVar("TELEGRAM_ALLOWED_USER_IDS", parseInt(getEnvVar("TELEGRAM_ALLOWED_USER_ID"), 10)),\n'
    - count: 1
    - unless: 'grep -qF "getOptionalAllowedUserIdsEnvVar" {{ home }}/.local/lib/node_modules/@grinev/opencode-telegram-bot/dist/config.js'
    - require:
      - cmd: install_opencode_telegram

opencode_telegram_model_whitelist_patch:
  file.replace:
    - name: {{ home }}/.local/lib/node_modules/@grinev/opencode-telegram-bot/dist/model/manager.js
    - pattern: 'function filterModelsByCatalog\(models, validModelKeys\) \{\n    if \(!validModelKeys\) \{\n        return models;\n    \}\n    return models\.filter\(\(model\) => validModelKeys\.has\(getModelKey\(model\.providerID, model\.modelID\)\)\);\n\}'
    - repl: 'function filterModelsByCatalog(models, validModelKeys) {\n    const deepseekWhitelist = new Set(["deepseek/deepseek-chat", "deepseek/deepseek-reasoner"]);\n    const catalogFiltered = !validModelKeys\n        ? models\n        : models.filter((model) => validModelKeys.has(getModelKey(model.providerID, model.modelID)));\n    return catalogFiltered.filter((model) => deepseekWhitelist.has(getModelKey(model.providerID, model.modelID)));\n}'
    - count: 1
    - require:
      - cmd: install_opencode_telegram

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
        telegram_uid_levra: {{ _telegram_uid_levra | tojson }}
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
        'file: opencode_telegram_model_whitelist_patch',
        'file: opencode_serve_service',
        'cmd: opencode_serve_service_daemon_reload',
        'file: opencode_telegram_bot_service',
        'cmd: opencode_telegram_bot_service_daemon_reload',
    ] + (['file: opencode_telegram_bot_env'] if _has_otb_token else []),
) }}
