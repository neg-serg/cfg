{# Zsh shell environment: prezto framework, plugins, completions, and prompt configuration #}
{% from '_imports.jinja' import user %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/zsh.yaml' as zsh %}

{{ ensure_dir('zsh_config_dir', '/etc/zsh', mode='0755', user='root') }}

zsh_system_env:
  file.managed:
    - name: /etc/zsh/zshenv
    - contents: |
        {{ zsh.zshenv }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

zsh_system_rc:
  file.managed:
    - name: /etc/zsh/zshrc
    - contents: |
        {{ zsh.zshrc }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir
