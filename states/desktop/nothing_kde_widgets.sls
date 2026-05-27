{# Nothing KDE Widgets — deploy Nothing OS themed plasmoids #}
{#- @state
   id: desktop.nothing_kde_widgets
   purpose: "Deploy Nothing OS themed KDE Plasma widgets from jaxparrow07/nothing-kde-widgets."
   data_files: [data/nothing_kde_widgets.yaml]
   secrets: []
   services: []
   configs: []
#}
{% from '_imports.jinja' import home, user %}
{% import_yaml 'data/nothing_kde_widgets.yaml' as cfg %}
{% set clone_dest = home ~ '/' ~ cfg.clone_dir %}
{% set plasmoid_home = home ~ '/.local/share/plasma/plasmoids' %}

{# --- Clone / update the upstream repo --- #}
nothing_kde_clone_repo:
  git.latest:
    - name: {{ cfg.repo_url }}
    - rev: {{ cfg.repo_branch }}
    - target: {{ clone_dest }}
    - user: {{ user }}
    - force_reset: true

{# --- Install each widget via kpackagetool6 as the user --- #}
{% for widget in cfg.widgets %}
nothing_kde_install_{{ widget }}:
  cmd.run:
    - name: |
        set -euo pipefail
        cd {{ clone_dest }}
        dir="packages/{{ widget }}"
        test -d "$dir" || { echo "ERROR: widget directory not found: $dir" >&2; exit 1; }
        widget_id=$(jq -r '.KPlugin.Id' "$dir/metadata.json")
        installed_dir="{{ plasmoid_home }}/$widget_id"
        if test -d "$installed_dir"; then
          echo "[*] Widget already installed, updating: $widget_id"
          kpackagetool6 --type=Plasma/Applet -u "$dir"
        else
          echo "[*] Installing widget: $widget_id"
          kpackagetool6 --type=Plasma/Applet -i "$dir"
        fi
    - shell: /bin/bash
    - runas: {{ user }}
    - require:
      - git: nothing_kde_clone_repo
    - unless: test -d {{ plasmoid_home }}/$(jq -r '.KPlugin.Id' {{ clone_dest }}/packages/{{ widget }}/metadata.json)
{% endfor %}

{# --- Restart plasmashell if it's running (post-install hook) --- #}
nothing_kde_restart_plasmashell:
  cmd.run:
    - name: |
        if pgrep -x plasmashell >/dev/null 2>&1; then
          echo "[*] Restarting plasmashell..."
          killall plasmashell || true
          sleep 1
          kstart plasmashell &
          echo "[+] plasmashell restarted"
        else
          echo "[*] plasmashell not running, skipping restart"
        fi
    - shell: /bin/bash
    - onchanges:
{% for widget in cfg.widgets %}
      - cmd: nothing_kde_install_{{ widget }}
{% endfor %}
