{# Fallback installers: tools built from GitHub releases, pip, cargo, go, or raw HTTP #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}
{% from '_macros_install.jinja' import cargo_pkg, curl_bin, curl_extract_tar, curl_extract_zip, git_clone_build, git_clone_deploy, go_pkg, http_file, install_catalog, pip_pkg %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

{{ install_catalog(tools.curl_bin, ver, 'curl_bin') }}
{{ install_catalog(tools.github_tar, ver, 'curl_extract_tar') }}

{% for name, opts in tools.pip_pkg.items() %}
{{ pip_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

{% for name, opts in tools.cargo_pkg.items() %}
{{ cargo_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin'), git=opts.get('git')) }}
{% endfor %}

{% for name, opts in tools.get('go_pkg', {}).items() %}
{{ go_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

{{ install_catalog(tools.curl_extract_zip, ver, 'curl_extract_zip') }}
{{ install_catalog(tools.get('curl_extract_tar', {}), ver, 'curl_extract_tar', exclude=['essentia']) }}

# ── AUR package installs ────────────────────────────────────────────
{{ paru_install('tdl', 'tdl-bin') }}

tdl_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/tdl
    - onlyif: test -f {{ home }}/.local/bin/tdl

nyxt_system_cleanup:
  pkg.removed:
    - name: nyxt

# ── Custom installs (data-driven from data/installers.yaml custom_section) ──
{{ git_clone_deploy('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

{{ curl_extract_tar('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

{{ pip_pkg('dr14_tmeter', pkg='git+https://github.com/simon-r/dr14_t.meter.git', env='GIT_CONFIG_GLOBAL=/dev/null') }}

qmk_udev_rules:
  cmd.run:
    - name: |
        set -eo pipefail
        url='https://raw.githubusercontent.com/qmk/qmk_firmware/refs/heads/master/util/udev/50-qmk.rules'
        cache='/var/cache/salt/downloads/qmk_udev_rules'
        mkdir -p "$(dirname "$cache")"
        curl -fsSL "$url" -o "$cache"
        install -m 0644 -D "$cache" '/etc/udev/rules.d/50-qmk.rules'
    - shell: /bin/bash
    - creates: /etc/udev/rules.d/50-qmk.rules

qmk_udev_rules_reload:
  cmd.run:
    - name: udevadm control --reload-rules
    - onlyif: command -v udevadm >/dev/null 2>&1
    - onchanges:
      - cmd: qmk_udev_rules

{{ git_clone_deploy('termcell', 'https://github.com/xqtr/termcell.git', '~/.local/share/termcell', creates=home ~ '/.local/share/termcell/termcell.py', user=user, home=home) }}

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

{{ http_file('fzf_navigator', 'https://raw.githubusercontent.com/benward2301/fzf-navigator/main/fzf-navigator.sh', home ~ '/.config/fzf-navigator.sh', user=user) }}

{{ git_clone_build('nface', 'https://github.com/tomScheers/nFace.git', 'make', 'bin/nface') }}

{{ git_clone_build('termmark', 'https://github.com/ishanawal/TermMark.git', 'cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && make -C build', 'build/termmark') }}

{{ curl_extract_tar('blesh', 'https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz', archive_ext='tar.xz', dest='~/.local/share', strip_components=1, creates=home ~ '/.local/share/ble.sh', user=user, home=home) }}
