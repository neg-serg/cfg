{# Fallback installers: tools built from GitHub releases, pip, cargo, go, or raw HTTP #}
{#- @state
   id: installers
   purpose: "Fallback installers: tools built from GitHub releases, pip, cargo, go, or raw HTTP."
   includes: [pacman_db_warmup]
   data_files: [data/installers.yaml, data/versions.yaml]
#}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

{{ salt['installer.install_catalog'](tools.curl_bin, ver, 'curl_bin') }}
{{ salt['installer.install_catalog'](tools.github_tar, ver, 'curl_extract_tar') }}

{% for name, opts in tools.pip_pkg.items() %}
{{ salt['installer.pip_pkg'](name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

{% for name, opts in tools.cargo_pkg.items() %}
{{ salt['installer.cargo_pkg'](name, pkg=opts.get('pkg'), bin=opts.get('bin'), git=opts.get('git')) }}
{% endfor %}

{% for name, opts in tools.get('go_pkg', {}).items() %}
{{ salt['installer.go_pkg'](name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

{{ salt['installer.install_catalog'](tools.curl_extract_zip, ver, 'curl_extract_zip') }}
{{ salt['installer.install_catalog'](tools.get('curl_extract_tar', {}), ver, 'curl_extract_tar', exclude=['essentia']) }}

# ── AUR package installs ────────────────────────────────────────────
{{ salt['pkg.paru_install']('tdl', 'tdl-bin') }}

tdl_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/tdl
    - onlyif: test -f {{ home }}/.local/bin/tdl

nyxt_system_cleanup:
  pkg.removed:
    - name: nyxt

# ── Custom installs (data-driven from data/installers.yaml custom_section) ──
{{ salt['installer.git_clone_deploy']('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

{{ salt['installer.curl_extract_tar']('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

{{ salt['installer.pip_pkg']('dr14_tmeter', pkg='git+https://github.com/simon-r/dr14_t.meter.git', env='GIT_CONFIG_GLOBAL=/dev/null') }}

qmk_udev_rules:
  cmd.run:
    - name: |
        set -eo pipefail
        url='https://raw.githubusercontent.com/qmk/qmk_firmware/refs/heads/master/util/udev/50-qmk.rules'
        cache='/var/cache/salt/downloads/qmk_udev_rules'
        mkdir -p "$(dirname "$cache")"
        if ! curl -fsL "$url" -o "$cache"; then
          if [ -f /etc/udev/rules.d/50-qmk.rules ]; then
            exit 0
          fi
          # File unavailable and never installed — non-fatal
          touch /var/cache/salt/downloads/qmk_udev_rules_missing
          exit 0
        fi
        install -m 0644 -D "$cache" '/etc/udev/rules.d/50-qmk.rules'
        rm -f /var/cache/salt/downloads/qmk_udev_rules_missing
    - shell: /bin/bash
    - unless: test -f /etc/udev/rules.d/50-qmk.rules -o -f /var/cache/salt/downloads/qmk_udev_rules_missing

qmk_udev_rules_reload:
  cmd.run:
    - name: udevadm control --reload-rules
    - onlyif: command -v udevadm >/dev/null 2>&1
    - onchanges:
      - cmd: qmk_udev_rules

{{ salt['installer.git_clone_deploy']('termcell', 'https://github.com/xqtr/termcell.git', '~/.local/share/termcell', creates=home ~ '/.local/share/termcell/termcell.py', user=user, home=home) }}

termcell_wrapper:
  file.managed:
    - name: {{ home }}/.local/bin/termcell
    - contents: |
        #!/bin/bash
        exec python3 ~/.local/share/termcell/termcell.py "$@"
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: install_termcell

{{ salt['installer.http_file']('fzf_navigator', 'https://raw.githubusercontent.com/benward2301/fzf-navigator/main/fzf-navigator.sh', home ~ '/.config/fzf-navigator.sh', user=user) }}

{{ salt['installer.git_clone_build']('nface', 'https://github.com/tomScheers/nFace.git', 'make', 'bin/nface') }}

{{ salt['installer.git_clone_build']('termmark', 'https://github.com/ishanawal/TermMark.git', 'cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && make -C build', 'build/termmark') }}

{{ salt['installer.curl_extract_tar']('blesh', 'https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz', archive_ext='tar.xz', dest='~/.local/share', strip_components=1, creates=home ~ '/.local/share/ble.sh', user=user, home=home) }}
