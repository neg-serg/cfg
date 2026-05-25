{# PipeWire audio stack: ensures all runtime components (ALSA, JACK, Pulse) are installed #}
{#- @state
   id: audio
   purpose: "PipeWire audio stack: ensures all runtime components (ALSA, JACK, Pulse) are installed."
   includes: [pacman_db_warmup]
   data_files: [data/audio.yaml]
   configs: [configs/pipewire-game-output.conf]
   scripts: [scripts/game-audio-bridge.sh.j2]
   services: [game-audio-bridge.service]
#}
{% from '_imports.jinja' import user, home %}

include:
  - pacman_db_warmup

{% import_yaml 'data/audio.yaml' as audio %}

{% for pkg in audio.packages %}
{{ salt['pkg.paru_install'](pkg, pkg) }}
{% endfor %}

snd_aloop_strip_droidcam:
  file.replace:
    - name: {{ audio.droidcam_modules_conf }}
    - pattern: {{ audio.snd_aloop_pattern }}
    - repl: ''
    - onlyif: test -f {{ audio.droidcam_modules_conf }}

game_output_sink_config:
  file.managed:
    - name: {{ home }}/.config/pipewire/pipewire.conf.d/10-game-audio.conf
    - source: salt://configs/pipewire-game-output.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True

game_audio_bridge_script:
  file.managed:
    - name: {{ home }}/.local/bin/game-audio-bridge
    - source: salt://scripts/game-audio-bridge.sh.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        rme_node: {{ audio.rme_node }}

{{ salt['user_service.user_service_file'](
    'game_audio_bridge_service',
    'game-audio-bridge.service',
    template='jinja',
    context={
        'home': home,
        'rme_node': audio.rme_node,
    },
) }}

{{ salt['user_service.user_service_enable'](
    'game_audio_bridge_enabled',
    services=['game-audio-bridge.service'],
    start_now=['game-audio-bridge.service'],
    check='active',
    requires=[
        'file: game_audio_bridge_service',
        'cmd: game_audio_bridge_service_daemon_reload',
        'file: game_audio_bridge_script',
    ],
) }}
