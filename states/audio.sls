{# PipeWire audio stack: ensures all runtime components (ALSA, JACK, Pulse) are installed #}
{#- @state
   id: audio
   purpose: "PipeWire audio stack: ensures all runtime components (ALSA, JACK, Pulse) are installed."
   includes: [pacman_db_warmup]
   data_files: [data/audio.yaml]
   configs: [configs/pipewire-fmod-sink.conf]
   scripts: [scripts/fmod-link.sh.j2]
   services: [fmod-sink-link.service]
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

fmod_sink_config:
  file.managed:
    - name: {{ home }}/.config/pipewire/pipewire.conf.d/10-fmod-sink.conf
    - source: salt://configs/pipewire-fmod-sink.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True

fmod_link_script:
  file.managed:
    - name: {{ home }}/.local/bin/fmod-link.sh
    - source: salt://scripts/fmod-link.sh.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        rme_node: {{ audio.rme_node }}

{{ salt['user_service.user_service_file'](
    'fmod_sink_service',
    'fmod-sink-link.service',
    template='jinja',
    context={
        'home': home,
        'rme_node': audio.rme_node,
    },
) }}

{{ salt['user_service.user_service_enable'](
    'fmod_sink_enabled',
    services=['fmod-sink-link.service'],
    start_now=['fmod-sink-link.service'],
    check='active',
    requires=[
        'file: fmod_sink_service',
        'cmd: fmod_sink_service_daemon_reload',
        'file: fmod_link_script',
    ],
) }}
