{# TidalCycles live coding environment: Haskell, SuperDirt, and SuperCollider setup #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home, retry_attempts, retry_interval %}

{% import_yaml 'data/tidal.yaml' as tidal %}

{% for pkg in tidal.packages %}
{{ salt['pkg.paru_install'](pkg, pkg) }}
{% endfor %}

superdirt_quark_install:
  cmd.script:
    - source: salt://scripts/superdirt-install.sh
    - shell: /bin/bash
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/SuperCollider/downloaded-quarks/SuperDirt
    - timeout: 1200
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: install_supercollider
