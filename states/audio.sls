{# PipeWire audio stack: ensures all runtime components (ALSA, JACK, Pulse) are installed #}
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
