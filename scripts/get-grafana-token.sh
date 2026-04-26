#!/bin/bash
# Print Grafana API token from gopass for QML sysmon popup usage.
set -euo pipefail
gopass show monitoring/grafana-sysmon-token 2>/dev/null || echo ""
