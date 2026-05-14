{# Kanata keyboard remapper: advanced key remapping daemon configuration #}
{#- @state
   id: kanata
   purpose: "Kanata keyboard remapper: advanced key remapping daemon configuration."
   includes: [pacman_db_warmup]
   data_files: [data/kanata.yaml]
   configs: [configs/kanata.kbd]
#}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}

{% import_yaml 'data/kanata.yaml' as kanata %}

{{ salt['pkg.paru_install']('kanata', kanata.package) }}

kanata_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/kanata
    - onlyif: test -f {{ home }}/.local/bin/kanata

kanata_uinput_module:
  file.managed:
    - name: {{ kanata.uinput_conf }}
    - contents: uinput
    - mode: '0644'

kanata_load_uinput:
  kmod.present:
    - name: uinput
    - persist: False
    - require:
      - file: kanata_uinput_module

{{ salt['service.udev_rule']('kanata_udev_rule', kanata.uinput_rule_path, contents=kanata.uinput_rule) }}

uinput_group:
  group.present:
    - name: uinput
    - system: True

kanata_user_groups:
  cmd.run:
    - name: usermod -aG {{ kanata.groups | join(',') }} {{ user }}
    - onlyif: id -u {{ user }} >/dev/null 2>&1 && command -v usermod >/dev/null 2>&1 && id -nG {{ user }} | grep -qw input && ! id -nG {{ user }} | grep -qw uinput
    - require:
      - group: uinput_group

{{ salt['service.ensure_dir']('kanata_config_dir', home ~ '/.config/kanata') }}
kanata_config:
  file.managed:
    - name: {{ home }}/.config/kanata/config.kbd
    - source: salt://configs/kanata.kbd
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - replace: False
    - require:
      - file: kanata_config_dir

{{ salt['user_service.user_service_with_unit']('kanata', 'kanata.service', requires=['cmd: install_kanata', 'file: kanata_config', 'cmd: kanata_user_groups', 'kmod: kanata_load_uinput']) }}
