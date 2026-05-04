{# Music analysis pipeline: BPM/key detection, fingerprinting, and indexing #}
# Music analysis: Python dependencies for Annoy-based scripts + Essentia audio extractor.
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import user_service_file, user_service_enable %}
{% from '_macros_install.jinja' import curl_extract_tar %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/installers.yaml' as tools %}

# Python dependencies for Annoy-based analysis scripts

{{ paru_install('python_annoy', 'python-annoy') }}

# Essentia streaming extractor (binary tarball)
{% set tar_defs = tools.get('curl_extract_tar', {}) %}
{% set essentia = tar_defs.get('essentia') %}
{% if essentia %}
{% set _ver = ver.get('essentia', '') %}
{% set resolved_url = essentia.url | replace('${VER}', _ver) %}
{{ curl_extract_tar('essentia', resolved_url, binary_pattern=essentia.binary_pattern, bin=essentia.get('bin'), hash=essentia.get('hash'), version=_ver if _ver else None) }}
{% endif %}

essentia_validate:
  cmd.run:
    - name: essentia_streaming_extractor_music --help > /dev/null 2>&1
    - onlyif: test -f ~/.local/bin/essentia_streaming_extractor_music
    - onchanges:
      - cmd: install_essentia

# User systemd units (timer + service)
{{ user_service_file('music_index_service', 'music-index.service') }}
{{ user_service_file('music_index_timer', 'music-index.timer') }}
{{ user_service_enable('music_index_enabled',
    start_now=['music-index.timer'],
    requires=[
        'file: music_index_service',
        'cmd: music_index_service_daemon_reload',
        'file: music_index_timer',
        'cmd: music_index_timer_daemon_reload',
    ],
) }}
