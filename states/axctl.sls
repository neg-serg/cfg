{# axctl: Axenide compositor control CLI — binary from GitHub releases #}
{#- @state
   id: axctl
   purpose: "Install axctl CLI from GitHub releases (compositor abstraction for Ambxst)."
   data_files: [data/axctl.yaml]
#}
{% import_yaml 'data/axctl.yaml' as axctl %}

axctl_bin_dir:
  file.directory:
    - name: {{ axctl.bin_dir }}
    - user: root
    - group: root
    - mode: '0755'

axctl_install:
  cmd.run:
    - name: |
        curl -sL -o {{ axctl.bin_path }} {{ axctl.download_url }}
        chmod +x {{ axctl.bin_path }}
    - unless: test -f {{ axctl.bin_path }} && {{ axctl.bin_path }} --version 2>&1 | grep -q "{{ axctl.version }}"
    - require:
      - file: axctl_bin_dir
