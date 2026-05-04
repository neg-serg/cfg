{# Xen user account: creation, groups, Steam library access, TTY #}

{% from '_imports.jinja' import user, home, gopass_secret %}
{% from '_macros_service.jinja' import ensure_dir %}

{% set xen_user = 'xen' %}
{% set xen_uid = 1100 %}
{% set xen_home = '/home/' ~ xen_user %}

# ── User account ────────────────────────────────────────────────────
xen_group:
  group.present:
    - name: {{ xen_user }}
    - gid: {{ xen_uid }}

xen_user:
  user.present:
    - name: {{ xen_user }}
    - shell: /usr/bin/zsh
    - uid: {{ xen_uid }}
    - gid: {{ xen_uid }}
    - home: {{ xen_home }}
    - createhome: True
    - failhard: True
    - require:
      - group: xen_group

{% set xen_hash = gopass_secret('host/xen-password-hash') %}
ensure_xen_user_password:
  user.present:
    - name: {{ xen_user }}
    - password: '{{ xen_hash }}'
    - require:
      - user: xen_user

# video+render: GPU access; input: VR controllers; uucp: Valve Index USB
xen_groups:
  cmd.run:
    - name: usermod -aG video,render,input,plugdev,uucp {{ xen_user }}
    - unless: id -nG {{ xen_user }} | grep -qw uucp
    - require:
      - user: xen_user
      - group: plugdev_group

# ── Shared Steam library access ────────────────────────────────────
# Add both users to a shared 'steam' group so xen can read neg's Steam files
xen_steam_group:
  group.present:
    - name: steam
    - members:
      - {{ user }}
      - {{ xen_user }}
    - require:
      - user: xen_user

# Symlink neg's Steam library into xen's home
{{ ensure_dir('xen_local_share', xen_home ~ '/.local/share', user=xen_user) }}

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

# Set group-readable permissions on neg's Steam directory
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

# ── TTY3 for xen login (emergency fallback) ───────────────────────
xen_getty_tty3:
  service.enabled:
    - name: getty@tty3
