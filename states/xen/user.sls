{# Xen user account: creation, groups, Steam library access, TTY #}

{% from '_imports.jinja' import user, home, gopass_secret %}

{% import_yaml 'data/xen.yaml' as xen %}

{% set xen_user = xen.user.name %}
{% set xen_uid = xen.user.uid %}
{% set xen_home = xen.user.home %}

xen_group:
  group.present:
    - name: {{ xen_user }}
    - gid: {{ xen_uid }}

xen_user:
  user.present:
    - name: {{ xen_user }}
    - shell: {{ xen.user.shell }}
    - uid: {{ xen_uid }}
    - gid: {{ xen_uid }}
    - home: {{ xen_home }}
    - createhome: True
    - failhard: True
    - require:
      - group: xen_group

{% set xen_hash = salt['secrets.get']('host/xen-password-hash') %}
ensure_xen_user_password:
  user.present:
    - name: {{ xen_user }}
    - password: '{{ xen_hash }}'
    - require:
      - user: xen_user

xen_groups:
  cmd.run:
    - name: usermod -aG {{ xen.user.groups | join(',') }} {{ xen_user }}
    - unless: id -nG {{ xen_user }} | grep -qw uucp
    - require:
      - user: xen_user
      - group: plugdev_group

xen_steam_group:
  group.present:
    - name: steam
    - members:
      - {{ user }}
      - {{ xen_user }}
    - require:
      - user: xen_user

{{ salt['service.ensure_dir']('xen_local_share', xen_home ~ '/.local/share', user=xen_user) }}

xen_steam_symlink:
  file.symlink:
    - name: {{ xen_home }}/.local/share/Steam
    - target: {{ home }}/.local/share/Steam
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - force: True
    - require:
      - file: xen_local_share
      - user: xen_user

xen_steam_acl:
  cmd.run:
    - name: |
        set -euo pipefail
        setfacl -R -m g:steam:rX {{ home }}/.local/share/Steam 2>/dev/null || true
        setfacl -R -d -m g:steam:rX {{ home }}/.local/share/Steam 2>/dev/null || true
    - unless: getfacl {{ home }}/.local/share/Steam 2>/dev/null | grep -q 'group:steam:r'
    - require:
      - group: xen_steam_group
    - onlyif: test -d {{ home }}/.local/share/Steam

xen_getty_tty3:
  service.enabled:
    - name: {{ xen.user.tty }}
