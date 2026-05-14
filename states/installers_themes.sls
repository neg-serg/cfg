{# Theme and icon installers: GTK, Qt, cursor, and icon themes from git repos #}
{#- @state
   id: installers_themes
   purpose: "Theme and icon installers: GTK, Qt, cursor, and icon themes from git repos."
   data_files: [data/installers_themes.yaml]
   configs: [configs/vicinae/flight-dark.toml]
#}
{% from '_imports.jinja' import home, user %}
{% import_yaml 'data/installers_themes.yaml' as themes %}

{% for name, cfg in themes.git_clone_deploy.items() %}
{{ salt['installer.git_clone_deploy'](name, cfg.repo, cfg.dest, cfg.get('items'), creates=(home ~ cfg.creates) if cfg.get('creates') else None, user=user, home=home) }}

{% endfor %}

vicinae_theme:
  file.managed:
    - name: {{ home }}/.local/share/vicinae/themes/flight-dark.toml
    - source: salt://configs/vicinae/flight-dark.toml
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

alkano_aio_cursor:
  cmd.run:
    - name: |
        set -eo pipefail
        _td=$(mktemp -d)
        trap 'rm -rf "$_td"' EXIT
        git clone --depth=1 {{ themes.alkano.repo }} "$_td/alkano"
        sudo mkdir -p {{ themes.alkano.dest }}
        sudo cp -r "$_td/alkano/Alkano-aio"/* {{ themes.alkano.dest }}/
        sudo chmod 755 {{ themes.alkano.dest }}
        sudo chmod 755 {{ themes.alkano.dest }}/cursors
        sudo find {{ themes.alkano.dest }}/cursors -type f -exec chmod 644 {} +
    - creates: {{ themes.alkano.dest }}/cursor.theme
    - parallel: True
    - retry:
        attempts: 3
        interval: 5
