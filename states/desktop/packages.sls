{# Desktop application packages: browsers, terminals, media, productivity tools #}
{#- @state
   id: desktop.packages
   purpose: "Desktop application packages: browsers, terminals, media, productivity tools."
   includes: [pacman_db_warmup]
   data_files: [data/desktop.yaml]
#}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import home, user %}
{% import_yaml 'data/desktop.yaml' as desktop %}

{{ salt['pkg.paru_install']('hyprland_desktop', desktop.hyprland_packages | join(' ')) }}
{{ salt['pkg.paru_install']('screenshot_tools', desktop.screenshot_packages | join(' ')) }}

{% for name, pkg in desktop.desktop_packages.items() %}
{{ salt['pkg.paru_install'](name, pkg) }}
{% endfor %}

swayimg_local_link_absent:
  file.absent:
    - name: {{ home }}/.local/bin/swayimg

swayimg_local_checkout_build:
  cmd.run:
    - name: |
        set -euo pipefail
        src="{{ home }}/src/1st-level/swayimg"
        test -d "$src"
        su - {{ user }} -c 'cd "{{ home }}/src/1st-level/swayimg" && git checkout master && git pull --ff-only'
        su - {{ user }} -c 'cd "{{ home }}/src/1st-level/swayimg" && meson setup build-salt --wipe && meson compile -C build-salt'
        meson install -C "$src/build-salt"
        su - {{ user }} -c 'git -C "{{ home }}/src/1st-level/swayimg" describe --tags --long --always' > /usr/local/share/.swayimg-build-version
    - shell: /bin/bash
    - onlyif: test -d "{{ home }}/src/1st-level/swayimg"
    - unless: test -f /usr/local/bin/swayimg && test -f /usr/local/share/.swayimg-build-version && test "$(cat /usr/local/share/.swayimg-build-version)" = "$(su - {{ user }} -c 'git -C {{ home }}/src/1st-level/swayimg describe --tags --long --always' 2>/dev/null)"
    - require:
      - file: swayimg_local_link_absent
