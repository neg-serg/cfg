{# Video AI models: HuggingFace model downloads and safetensors management #}
{#- @state
   id: video_ai.models
   purpose: "Video AI models: HuggingFace model downloads and safetensors management."
   data_files: [data/video_ai.yaml]
#}
{% from '_imports.jinja' import host, user %}
{% import_yaml 'data/video_ai.yaml' as video_ai %}
{% set base_dir = host.mnt_one ~ '/video-ai' %}
{% set comfyui_dir = base_dir ~ '/comfyui' %}
{% set models_dir = base_dir ~ '/models' %}

# ── Model downloads ──────────────────────────────────────────────────
{% for model in video_ai.get('models', []) %}
{% if model.enabled %}
{{ salt['service.ensure_dir']('video_ai_model_dir_' ~ model.id | replace('-', '_'), models_dir ~ '/' ~ model.id, user=user, require=['file: video_ai_models_dir']) }}

{% for file in model.files %}
{{ salt['installer.huggingface_file'](
    'video_ai_download_' ~ model.id | replace('-', '_') ~ '_' ~ loop.index,
    model.repo,
    file,
    models_dir ~ '/' ~ model.id ~ '/' ~ file,
    user=user,
    require=['file: video_ai_model_dir_' ~ model.id | replace('-', '_')]
) }}
{% endfor %}

video_ai_symlink_{{ model.id | replace('-', '_') }}:
  file.symlink:
    - name: {{ comfyui_dir }}/models/checkpoints/{{ model.id }}
    - target: {{ models_dir }}/{{ model.id }}
    - user: {{ user }}
    - force: True
    - makedirs: True
    - require:
      - cmd: video_ai_comfyui_setup
      {% for file in model.files %}
      - cmd: video_ai_download_{{ model.id | replace('-', '_') }}_{{ loop.index }}
      {% endfor %}
{% endif %}
{% endfor %}

# ── Shared text encoders ────────────────────────────────────────────
{% for te in video_ai.get('text_encoders', []) %}
{{ salt['installer.huggingface_file'](
    'video_ai_text_encoder_' ~ te.id | replace('-', '_'),
    te.repo,
    te.file,
    comfyui_dir ~ '/models/' ~ te.dir ~ '/' ~ te.file,
    user=user,
    require=['cmd: video_ai_comfyui_setup']
) }}
{% endfor %}

# ── Shared VAE models ──────────────────────────────────────────────
{% for vae in video_ai.get('vaes', []) %}
{{ salt['installer.huggingface_file'](
    'video_ai_vae_' ~ vae.id | replace('-', '_'),
    vae.repo,
    vae.file,
    comfyui_dir ~ '/models/' ~ vae.dir ~ '/' ~ vae.file,
    user=user,
    require=['cmd: video_ai_comfyui_setup']
) }}
{% endfor %}

# ── Image model downloads ──────────────────────────────────────────
{% for model in video_ai.get('image_models', []) %}
{% if model.enabled %}
{{ salt['installer.huggingface_file'](
    'video_ai_image_download_' ~ model.id | replace('-', '_'),
    model.repo,
    model.file,
    comfyui_dir ~ '/models/diffusion_models/' ~ model.file,
    user=user,
    require=['cmd: video_ai_comfyui_setup']
) }}
{% endif %}
{% endfor %}
