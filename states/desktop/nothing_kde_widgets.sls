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

{# --- Clone / update the upstream repo --- #}
nothing_kde_clone_repo:
  git.latest:
    - name: {{ cfg.repo_url }}
    - rev: {{ cfg.repo_branch }}
    - target: {{ cfg.clone_dest }}
    - user: {{ user }}
    - force_reset: true

{# --- Install each widget via kpackagetool6 --- #}
{% for widget in cfg.widgets %}
nothing_kde_install_{{ widget }}:
  cmd.run:
    - name: |
        set -euo pipefail
        cd {{ cfg.clone_dest }}
        dir="packages/{{ widget }}"
        if ! test -d "$dir"; then
          echo "ERROR: widget directory not found: $dir" >&2
          exit 1
        fi
        widget_id=$(jq -r '.KPlugin.Id' "$dir/metadata.json")
        installed_dir="$HOME/.local/share/plasma/plasmoids/$widget_id"
        install_cmd="kpackagetool6 --type=Plasma/Applet -i"
        if test -d "$installed_dir"; then
          echo "[*] Widget already installed, updating: $widget_id"
          install_cmd="kpackagetool6 --type=Plasma/Applet -u"
        else
          echo "[*] Installing widget: $widget_id"
        fi
        $install_cmd "$dir"
    - shell: /bin/bash
    - require:
      - git: nothing_kde_clone_repo
    - unless: test -d {{ cfg.clone_dest }}/packages/{{ widget }} && \
              widget_id=$(jq -r '.KPlugin.Id' {{ cfg.clone_dest }}/packages/{{ widget }}/metadata.json) && \
              test -d "$HOME/.local/share/plasma/plasmoids/$widget_id"
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
