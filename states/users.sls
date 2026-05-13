{# User account management: PAM sudo, SSH agent auth, and authorized keys #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import host, user, home, sudo_timeout_minutes %}
{% import_yaml 'data/users.yaml' as users %}
{% set uid = host.uid %}

user_root:
  user.present:
    - name: root
    - shell: /usr/bin/zsh

user_neg:
  user.present:
    - name: {{ user }}
    - shell: /usr/bin/zsh
    - uid: {{ uid }}
    - gid: {{ uid }}
    - failhard: True

plugdev_group:
  group.present:
    - name: plugdev
    - system: True

{{ salt['pkg.paru_install']('realtime-privileges', 'realtime-privileges') }}

neg_groups:
  cmd.run:
    - name: usermod -aG {{ users.groups | join(',') }} {{ user }}
    - unless: id -nG {{ user }} | grep -qw realtime
    - require:
      - group: plugdev_group
      - cmd: install_realtime_privileges

sudo_timeout:
  file.managed:
    - name: {{ users.sudoers_timeout }}
    - contents: |
        Defaults timestamp_timeout={{ sudo_timeout_minutes }}
        Defaults !tty_tickets
        Defaults passprompt="{{ '\uf023' }} "
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-{{ user }}-nopasswd
    - source: salt://configs/sudoers-nopasswd.j2
    - template: jinja
    - context:
        user: {{ user }}
        home: {{ home }}
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

{% if host.features.sudo_ssh_agent %}
{{ salt['pkg.paru_install']('pam_ssh_agent_auth', 'pam_ssh_agent_auth') }}

sudo_pam_config:
  file.managed:
    - name: /etc/pam.d/sudo
    - source: salt://configs/pam-sudo.j2
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: install_pam_ssh_agent_auth

sudo_ssh_agent_env_keep:
  file.managed:
    - name: /etc/sudoers.d/ssh-agent-auth
    - source: salt://configs/sudoers-ssh-agent-auth.j2
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_ssh_agent_authorized_keys:
  file.managed:
    - name: /etc/ssh/sudo_authorized_keys
    - source: salt://configs/sudo-authorized-keys.j2
    - user: root
    - group: root
    - mode: '0644'
{% else %}
sudo_pam_config:
  file.managed:
    - name: /etc/pam.d/sudo
    - contents: |
        #%PAM-1.0
        auth      include     system-auth
        account   include     system-auth
        session   include     system-auth
    - user: root
    - group: root
    - mode: '0644'

sudo_ssh_agent_env_keep:
  file.absent:
    - name: /etc/sudoers.d/ssh-agent-auth
{% endif %}

{{ salt['user_service.user_linger']('user_lingering') }}
