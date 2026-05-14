{# Music analysis pipeline: BPM/key detection, fingerprinting, and indexing #}
{#- @state
   id: music_analysis
   purpose: "Music analysis pipeline: BPM/key detection, fingerprinting, and indexing."
   includes: [pacman_db_warmup]
   data_files: [data/installers.yaml, data/versions.yaml]
   services: [music-index.service, music-index.timer]
   tests: [tests/test_music_analysis.py]
#}
# Music analysis: Python dependencies for Annoy-based scripts + Essentia audio extractor.
include:
  - pacman_db_warmup

{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/installers.yaml' as tools %}

# Python dependencies for Annoy-based analysis scripts

{{ salt['pkg.paru_install']('python_annoy', 'python-annoy') }}

# Essentia streaming extractor (binary tarball, data-driven via installers.yaml)
{% if tools.get('curl_extract_tar', {}).get('essentia') %}
{{ salt['installer.install_catalog']({'essentia': tools.curl_extract_tar.essentia}, ver, 'curl_extract_tar') }}
{% endif %}

essentia_validate:
  cmd.run:
    - name: essentia_streaming_extractor_music --help > /dev/null 2>&1
    - onlyif: test -f ~/.local/bin/essentia_streaming_extractor_music
    - onchanges:
      - cmd: install_essentia

# User systemd units (timer + service)
{{ salt['user_service.user_service_file']('music_index_service', 'music-index.service') }}
{{ salt['user_service.user_service_file']('music_index_timer', 'music-index.timer') }}
{{ salt['user_service.user_service_enable']('music_index_enabled',
    start_now=['music-index.timer'],
    requires=[
        'file: music_index_service',
        'cmd: music_index_service_daemon_reload',
        'file: music_index_timer',
        'cmd: music_index_timer_daemon_reload',
    ],
) }}
