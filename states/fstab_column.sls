{# Format /etc/fstab with aligned columns, preserving comments and blank lines #}
{#- @state
   id: fstab_column
   purpose: "Format /etc/fstab with aligned columns, preserving comments and blank lines."
#}
# Format /etc/fstab with aligned columns, preserving comments.
# Only non‑comment lines are reformatted.
# Script deployed to system path to decouple from repo location.

format_fstab_deploy:
  file.managed:
    - name: /usr/local/bin/format-fstab
    - source: salt://scripts/format-fstab.py
    - mode: '0755'
    - user: root
    - group: root

format_fstab:
  cmd.run:
    - name: python3 /usr/local/bin/format-fstab
    - unless: python3 /usr/local/bin/format-fstab --check
    - onlyif: test -f /etc/fstab
    - require:
      - file: format_fstab_deploy