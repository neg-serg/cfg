{# Steam gaming platform: multilib, drivers, gamemode, and controller support #}
{#- @state
   id: steam
   purpose: "Steam gaming platform: multilib, drivers, gamemode, and controller support."
   includes: [pacman_db_warmup]
   data_files: [data/steam.yaml]
   configs: [configs/gamemode.ini]
#}
{% from '_imports.jinja' import host, user %}

{% import_yaml 'data/steam.yaml' as steam %}

include:
  - pacman_db_warmup

{{ salt['cfg.config_file_edit']('multilib_repo',
    cmd=steam.multilib_repo.cmd,
    check_pattern=steam.multilib_repo.check_pattern,
    check_file=steam.multilib_repo.check_file,
    retry=True) }}

{% for id, pkgs in {
    'vulkan_radeon': steam.vulkan_packages,
    'steam': steam.steam_packages,
    'lib32_audio': steam.lib32_audio_packages,
}.items() %}
{{ salt['pkg.paru_install'](id, pkgs | join(' '), requires=['cmd: multilib_repo']) }}
{% endfor %}

{{ salt['service.ensure_dir']('steam_library_dir', host.mnt_zero ~ '/steam/steamapps', require=['mount: mount_zero']) }}
{{ salt['pkg.paru_install']('p7zip', '7zip') }}

gamemode_config:
  file.managed:
    - name: {{ steam.gamemode_config }}
    - source: salt://configs/gamemode.ini
    - mode: '0644'
    - require:
      - cmd: install_steam

gamemode_start_script:
  file.managed:
    - name: {{ steam.gamemode_start_script }}
    - source: salt://scripts/gamemode-start.sh
    - mode: '0755'
    - require:
      - cmd: install_steam

gamemode_end_script:
  file.managed:
    - name: {{ steam.gamemode_end_script }}
    - source: salt://scripts/gamemode-end.sh
    - mode: '0755'
    - require:
      - cmd: install_steam

dxvk_resolution_fix:
  cmd.script:
    - source: salt://scripts/dxvk-resolution-fix.sh
    - shell: /bin/bash
    - runas: {{ user }}
{%- if host.display %}
    - env:
      - DXVK_RESOLUTION: "{{ host.display.split('@')[0] }}"
{%- endif %}
    - unless: |
        for prefix in ~/.steam/root/steamapps/compatdata/*/pfx; do
          [ -d "$prefix" ] && [ ! -f "$prefix/dxvk.conf" ] && exit 1
        done
        exit 0
    - require:
      - cmd: install_steam
