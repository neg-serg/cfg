# Format /etc/fstab with aligned columns, preserving comments.
# Only non‑comment lines are reformatted.
# Dependencies are set via require_in in mount states.
{% from '_imports.jinja' import host %}

format_fstab:
  cmd.run:
    - name: python3 {{ host.project_dir }}/scripts/format-fstab.py
    - unless: python3 {{ host.project_dir }}/scripts/format-fstab.py --check
    - onlyif: test -f /etc/fstab