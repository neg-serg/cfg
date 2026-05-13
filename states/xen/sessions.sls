{# Xen X11 session configs: .xinitrc, i3 config, greetd .desktop entries #}


{% import_yaml 'data/xen.yaml' as xen %}

{% set xen_user = xen.user.name %}
{% set xen_home = xen.user.home %}

xen_xinitrc:
  file.managed:
    - name: {{ xen_home }}/.xinitrc
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0755'
    - contents: |
        #!/bin/sh
        # Valve Index VR session — i3 + SteamVR
        export XDG_SESSION_TYPE=x11

        # AMD GPU: use RADV Vulkan driver
        export AMD_VULKAN_ICD=RADV
        export RADV_PERFTEST=gpl

        exec i3
    - require:
      - user: xen_user

{{ salt['service.ensure_dir']('xen_i3_config_dir', xen_home ~ '/.config/i3', user=xen_user) }}

xen_i3_config:
  file.managed:
    - name: {{ xen_home }}/.config/i3/config
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - contents: |
        # i3 config for VR session (xen user)
        set $mod Mod4

        # Basic keybindings
        bindsym $mod+Return exec xterm
        bindsym $mod+Shift+q kill
        bindsym $mod+Shift+e exec i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'

        # Launch Steam on startup
        exec --no-startup-id steam -bigpicture
    - require:
      - file: xen_i3_config_dir

xen_vr_session_desktop:
  file.managed:
    - name: /usr/share/xsessions/xen-vr.desktop
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        [Desktop Entry]
        Name=Xorg VR (i3 + SteamVR)
        Comment=X11 session for Valve Index VR with i3
        Exec=startx
        Type=XSession
        DesktopNames=i3

xen_plasma_x11_session_desktop:
  file.managed:
    - name: /usr/share/xsessions/plasma-x11.desktop
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        [Desktop Entry]
        Name=Plasma (X11)
        Comment=KDE Plasma Desktop on Xorg
        Exec=startx /usr/bin/startplasma-x11
        TryExec=startplasma-x11
        Type=XSession
        DesktopNames=KDE
