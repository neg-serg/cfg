{# Ambxst: Axtremely customizable Hyprland shell by Axenide #}
{#- @state
   id: ambxst
   purpose: "Clone Ambxst repository and install system-wide launcher."
   data_files: [data/ambxst.yaml]
#}
{% from '_imports.jinja' import home, user %}

{% import_yaml 'data/ambxst.yaml' as ambxst %}

ambxst_repo:
  git.latest:
    - name: {{ ambxst.repo_url }}
    - target: {{ ambxst.install_path }}
    - user: {{ user }}
    - force_reset: true
    - rev: main

ambxst_launcher:
  file.managed:
    - name: {{ ambxst.bin_path }}
    - contents: |
        #!/usr/bin/env bash
        export PATH="{{ home }}/.local/bin:$PATH"
        export QML2_IMPORT_PATH="{{ home }}/.local/lib/qml:$QML2_IMPORT_PATH"
        export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
        exec "{{ ambxst.install_path }}/cli.sh" "$@"
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - git: ambxst_repo
