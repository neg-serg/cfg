{# Music analysis pipeline: BPM/key detection, fingerprinting, and indexing #}
# Music analysis: Python dependencies for Annoy-based scripts + Essentia audio extractor.
include:
  - pacman_db_warmup

{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service_user.jinja' import user_service_file, user_service_enable %}
{% from '_macros_install.jinja' import install_catalog %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/installers.yaml' as tools %}

# Python dependencies for Annoy-based analysis scripts

{{ paru_install('python_annoy', 'python-annoy') }}

# Essentia streaming extractor (binary tarball, data-driven via installers.yaml)
{% if tools.get('curl_extract_tar', {}).get('essentia') %}
{{ install_catalog({'essentia': tools.curl_extract_tar.essentia}, ver, 'curl_extract_tar') }}
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
