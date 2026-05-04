{# Xen X11 session configs: .xinitrc, i3 config, greetd .desktop entries #}

{% from '_macros_service.jinja' import ensure_dir %}

{% set xen_user = 'xen' %}
{% set xen_home = '/home/' ~ xen_user %}

# ── .xinitrc: start i3 on startx ───────────────────────────────────
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

# ── Minimal i3 config (auto-launch Steam) ──────────────────────────
{{ ensure_dir('xen_i3_config_dir', xen_home ~ '/.config/i3', user=xen_user) }}

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

# ── Session .desktop files for greetd ──────────────────────────────
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

# plasma-workspace only ships wayland session; add X11 variant for xen
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
