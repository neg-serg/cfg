{# Video AI runners: inference server and processing daemon management #}
{#- @state
   id: video_ai.runners
   purpose: "Video AI runners: inference server and processing daemon management."
   data_files: [data/video_ai.yaml]
#}
{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/video_ai.yaml' as video_ai %}
{% set base_dir = host.mnt_one ~ '/video-ai' %}

video_ai_generate_script:
  file.managed:
    - name: {{ base_dir }}/{{ video_ai.runners.generate }}
    - source: salt://scripts/video-ai-generate.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - cmd: video_ai_comfyui_setup

video_ai_generate_image_script:
  file.managed:
    - name: {{ base_dir }}/{{ video_ai.runners.generate_image }}
    - source: salt://scripts/video-ai-generate-image.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - cmd: video_ai_comfyui_setup

video_ai_gen_video_script:
  file.managed:
    - name: {{ home }}/.local/bin/{{ video_ai.runners.gen_video }}
    - source: salt://scripts/gen-video
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - file: video_ai_generate_script
