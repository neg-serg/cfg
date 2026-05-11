{# Services group: systemd services, user services, and monitoring alerts #}
# Group: system services, monitoring, user units
# Usage: just apply group/services

include:
  - services
  - monitoring_alerts
  - user_services
  - pacman_db_warmup
