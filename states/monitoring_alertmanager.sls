{# Alertmanager: Telegram webhook alerts from Loki log rules #}
# Alertmanager — containerised alert routing for Loki → Telegram.
# Gated on loki && alertmanager features (two independent feature flags).
{% from '_imports.jinja' import host, user, home, tg_secret %}

{% if host.features.monitoring.loki and host.features.monitoring.alertmanager %}

# ── Telegram credentials (same token as salt-alert) ──────────────────
{% set _telegram_token = tg_secret('api/nanoclaw-telegram', 'telegram-token') %}
{% set _telegram_uid = tg_secret('api/nanoclaw-telegram-uid', 'telegram-uid') %}


# ── Webhook bridge script ────────────────────────────────────────────
alertmanager_webhook_script:
  file.managed:
    - name: {{ home }}/.local/bin/alertmanager-webhook
    - source: salt://scripts/alertmanager-webhook
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        telegram_token: {{ _telegram_token | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}


# ── Webhook bridge systemd user unit ─────────────────────────────────
{{ salt['user_service.user_service_file']('alertmanager_webhook_unit', 'alertmanager-webhook.service', template='jinja') }}


# ── Alertmanager config ──────────────────────────────────────────────
alertmanager_config:
  file.managed:
    - name: /etc/alertmanager/alertmanager.yml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/alertmanager.yml.j2
    - template: jinja


# ── Alertmanager Quadlet container ───────────────────────────────────
{{ salt['container.deploy']('alertmanager', catalog.alertmanager, image_registry,
    quadlet_unit_name='alertmanager-container',
    requires=['file: alertmanager_config']) }}


# ── Enable services ─────────────────────────────────────────────────
{{ salt['user_service.user_service_enable']('alertmanager_webhook_enabled',
    start_now=['alertmanager-webhook.service'],
    requires=['file: alertmanager_webhook_script', 'file: alertmanager_webhook_unit']) }}

{% endif %}
