{# Services group: systemd services, user services, and monitoring alerts #}
{#- @state
   id: group.services
   purpose: "Services group: systemd services, user services, and monitoring alerts."
   includes: [monitoring_alerts, pacman_db_warmup, services, user_services]
#}
# Group: system services, monitoring, user units
# Usage: just apply group/services

include:
  - services
  - monitoring_alerts
  - user_services
  - pacman_db_warmup
