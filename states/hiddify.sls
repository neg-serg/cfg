{# Hiddify VPN client: local AppImage wrapper with legacy shadow handler cleanup #}
{% from '_imports.jinja' import user, home %}
{% import_yaml 'data/hiddify.yaml' as hiddify %}

hiddify_legacy_cleanup:
  file.absent:
    - names:
      - {{ home }}/.local/bin/Hiddify.AppImage
      - {{ home }}/.local/share/applications/hiddify-official.desktop
      - {{ home }}/.local/share/applications/hiddify-official-root.desktop
      - {{ home }}/.cache/hiddify

hiddify_next_default_handlers:
  cmd.run:
    - name: |
        set -euo pipefail
{% for scheme in hiddify.xdg_schemes %}
        xdg-mime default hiddify.desktop x-scheme-handler/{{ scheme }}
{% endfor %}
    - runas: {{ user }}
    - shell: /bin/bash
    - onlyif: test -f /usr/share/applications/hiddify.desktop -o -f {{ home }}/.local/share/applications/hiddify.desktop
    - unless: >-
        grep -q 'x-scheme-handler/hiddify=hiddify.desktop' {{ home }}/.config/mimeapps.list &&
        grep -q 'x-scheme-handler/clashmeta=hiddify.desktop' {{ home }}/.config/mimeapps.list
    - require:
      - file: hiddify_legacy_cleanup

hiddify_gui_capabilities:
  cmd.run:
    - name: setcap {{ hiddify.caps }} {{ hiddify.gui }}
    - runas: root
    - onlyif: test -x {{ hiddify.gui }}
    - unless: getcap {{ hiddify.gui }} 2>/dev/null | grep -q 'cap_net_bind_service.*cap_net_admin.*cap_net_raw'

hiddify_core_cli_capabilities:
  cmd.run:
    - name: setcap {{ hiddify.caps }} {{ hiddify.cli }}
    - runas: root
    - onlyif: test -x {{ hiddify.cli }}
    - unless: getcap {{ hiddify.cli }} 2>/dev/null | grep -q 'cap_net_bind_service.*cap_net_admin.*cap_net_raw'
