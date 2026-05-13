{# Steam gaming platform: multilib, drivers, gamemode, and controller support #}
{% from '_imports.jinja' import host, user, pkg_list %}



{% import_yaml 'data/steam.yaml' as steam %}

include:
  - pacman_db_warmup

{{ salt['config.config_file_edit']('multilib_repo',
    cmd=steam.multilib_repo.cmd,
    check_pattern=steam.multilib_repo.check_pattern,
    check_file=steam.multilib_repo.check_file,
    retry=True) }}

vulkan_radeon_pkg:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 {{ steam.vulkan_packages | join(' ') }}
    - unless: grep -qxF 'vulkan-radeon' {{ pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: multilib_repo

steam_pkg:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 {{ steam.steam_packages | join(' ') }}
    - unless: grep -qxF 'steam' {{ pkg_list }}
    - require:
      - cmd: vulkan_radeon_pkg

steam_lib32_audio:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 {{ steam.lib32_audio_packages | join(' ') }}
    - unless: pacman -Qi lib32-pipewire-jack >/dev/null 2>&1
    - require:
      - cmd: steam_pkg

{{ salt['service.ensure_dir']('steam_library_dir', host.mnt_zero ~ '/steam/steamapps', require=['mount: mount_zero']) }}
{{ salt['pkg.paru_install']('p7zip', '7zip') }}

gamemode_config:
  file.managed:
    - name: {{ steam.gamemode_config }}
    - source: salt://configs/gamemode.ini
    - mode: '0644'
    - require:
      - cmd: steam_pkg

gamemode_start_script:
  file.managed:
    - name: {{ steam.gamemode_start_script }}
    - source: salt://scripts/gamemode-start.sh
    - mode: '0755'
    - require:
      - cmd: steam_pkg

gamemode_end_script:
  file.managed:
    - name: {{ steam.gamemode_end_script }}
    - source: salt://scripts/gamemode-end.sh
    - mode: '0755'
    - require:
      - cmd: steam_pkg

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
      - cmd: steam_pkg
