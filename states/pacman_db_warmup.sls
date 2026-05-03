{# Pacman database warmup: ensures package databases are up to date before other states #}
# Warm up pacman package list cache
# Used by paru_install macro to detect installed packages.
# Must be included before any paru_install states.

{% from '_imports.jinja' import pkg_list %}

pacman_db_warmup:
  cmd.run:
    - name: |
        set -euo pipefail
        _tmp=$(mktemp)
        pacman -Qq > "$_tmp"
        if cmp -s "$_tmp" {{ pkg_list }}; then
          rm "$_tmp"
          echo "changed=no"
        else
          mv "$_tmp" {{ pkg_list }}
          echo "changed=yes"
        fi
    - onlyif: command -v pacman >/dev/null 2>&1
    - stateful: True
    - shell: /bin/bash
