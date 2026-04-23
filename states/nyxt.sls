{% from '_imports.jinja' import user, home %}
# Nyxt browser: dark theme configuration
nyxt_init:
  file.managed:
    - name: {{ home }}/.config/nyxt/init.lisp
    - source: salt://dotfiles/dot_config/nyxt/init.lisp
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
