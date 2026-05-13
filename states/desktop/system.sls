{# System-wide desktop configuration: fonts, themes, input methods, power management #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}

{% import_yaml 'data/desktop.yaml' as desktop %}

{{ salt['service.ensure_dir']('pacman_hooks_dir', '/etc/pacman.d/hooks', mode='0755', user='root') }}

pacman_salt_pkglist_hook:
  file.managed:
    - name: /etc/pacman.d/hooks/salt-pkglist.hook
    - source: salt://configs/pacman-salt-cache.hook
    - mode: '0644'
    - require:
      - file: pacman_hooks_dir

{{ salt['service.ensure_dir']('pacman_salt_cache_dir', '/var/cache/salt', mode='0755', user='root') }}

faillock_config:
  file.replace:
    - name: /etc/security/faillock.conf
    - pattern: '^#?\s*deny\s*=\s*\d+'
    - repl: 'deny = {{ desktop.faillock_deny }}'

etckeeper_init:
  cmd.run:
    - name: etckeeper init && etckeeper commit "Initial commit"
    - unless: test -d /etc/.git
    - onlyif: command -v etckeeper

desktop_services_enabled:
  service.running:
    - names:
{% for svc in desktop.running_services %}
      - {{ svc }}
{% endfor %}
    - enable: True

sshd_hardening:
  file.managed:
    - name: /etc/ssh/sshd_config.d/10-hardening.conf
    - source: salt://configs/sshd-hardening.conf
    - mode: '0644'

sshd_authorized_keys:
  cmd.run:
    - name: |
        install -m 0600 -o {{ user }} -g {{ user }} /dev/null {{ home }}/.ssh/authorized_keys
        cat {{ home }}/.ssh/id_ed25519.pub > {{ home }}/.ssh/authorized_keys
    - unless: test -s {{ home }}/.ssh/authorized_keys && grep -qF "$(cat {{ home }}/.ssh/id_ed25519.pub)" {{ home }}/.ssh/authorized_keys
    - onlyif: test -f {{ home }}/.ssh/id_ed25519.pub
    - require:
      - file: ssh_dir

sshd_restart:
  service.running:
    - name: sshd
    - watch:
      - file: sshd_hardening

{% for name, pkg in desktop.system_packages.items() %}
{{ salt['pkg.paru_install'](name, pkg) }}
{% endfor %}

libvirtd_service_disabled:
  service.disabled:
    - name: libvirtd
    - require:
      - cmd: install_libvirt

libvirtd_socket_enabled:
  service.enabled:
    - name: libvirtd.socket
    - require:
      - cmd: install_libvirt
      - service: libvirtd_service_disabled

{{ salt['service.config_and_reload']('looking_glass_shm', '/etc/tmpfiles.d/10-looking-glass.conf',
    'systemd-tmpfiles --create /etc/tmpfiles.d/10-looking-glass.conf',
    contents='f /dev/shm/looking-glass 0660 ' ~ user ~ ' kvm -') }}

pcscd_socket_enabled:
  service.enabled:
    - name: pcscd.socket
    - require:
      - cmd: install_pcsclite

{{ salt['service.service_stopped']('tuned_stopped', 'tuned', onlyif='systemctl list-unit-files tuned.service 2>/dev/null | grep -q tuned') }}

cpu_balanced_epp_script:
  file.managed:
    - name: /usr/local/bin/cpu-balanced-epp
    - source: salt://scripts/cpu-balanced-epp.sh
    - mode: '0755'

{{ salt['service.service_with_unit']('cpu-balanced-epp', 'salt://units/cpu-balanced-epp.service', requires=['file: cpu_balanced_epp_script']) }}
