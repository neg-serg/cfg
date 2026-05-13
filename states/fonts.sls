{# Font installation: pacman, AUR, downloaded, and custom PKGBUILD builds #}
# All font installs: pacman, AUR, downloaded, custom PKGBUILD builds
# Run: sudo salt-call --local state.apply fonts
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}


{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/fonts.yaml' as fonts %}

# ===================================================================
# Pacman fonts
# ===================================================================

{% for name, pkg in fonts.pacman.items() %}
{{ salt['pkg.paru_install'](name, pkg) }}
{% endfor %}

# ===================================================================
# AUR fonts
# ===================================================================

{% for name, pkg in fonts.paru.items() %}
{{ salt['pkg.paru_install'](name, pkg) }}
{% endfor %}

# ===================================================================
# PKGBUILD fonts (custom builds)
# ===================================================================

# Iosevka with custom glyph variants, patched with Nerd Font icons
{{ salt['pkg.pkgbuild_install']('iosevka-neg-fonts', 'salt://build/pkgbuilds/iosevka-neg-fonts', user=user, timeout=7200) }}

# ===================================================================
# Downloaded fonts (not in repos)
# ===================================================================

{% for name, opts in fonts.download_zip.items() %}
{% set _v = ver.get(name, '') %}
{% set url = opts.url | replace('${VER}', _v) %}
{{ salt['installer.download_font_zip'](name, url, opts.subdir, hash=opts.get('hash'), version=_v if _v else None, user=user, home=home) }}
{% endfor %}
