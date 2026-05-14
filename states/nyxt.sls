{# Nyxt browser: extensible Lisp-powered web browser managed as system package #}
{#- @state
   id: nyxt
   purpose: "Nyxt browser: extensible Lisp-powered web browser managed as system package."
#}
{% from '_imports.jinja' import user, home %}
# Nyxt browser: dark theme configuration
nyxt_init:
  file.managed:
    - name: {{ home }}/.config/nyxt/init.lisp
    - source: salt://dotfiles/dot_config/nyxt/init.lisp
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
