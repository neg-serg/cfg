{# Oomox theme generation — declarative GTK theme management via themix/oomox #}
{#- @state
   id: desktop.themes
   purpose: "Declarative GTK theme generation via oomox/themix from palette configs."
   includes: [desktop.packages]
   data_files: [data/desktop.yaml]
#}
# =============================================================================
# Oomox theme generation — generates GTK2/GTK3 themes from palette data
# =============================================================================
include:
  - desktop.packages

{% from '_imports.jinja' import home %}
{% import_yaml 'data/desktop.yaml' as desktop %}

{% for name, conf in desktop.oomox_themes.items() %}
{% set safe_name = name | replace('-', '_') %}
{{ salt['desktop.generate_oomox_theme'](
    'oomox_theme_' ~ safe_name,
    theme_name=name,
    palette=conf.palette,
    hidpi=conf.get('hidpi', False),
    require=['cmd: oomox']
) }}
{% endfor %}
