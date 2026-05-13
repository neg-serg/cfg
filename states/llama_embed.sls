{# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan in Quadlet container #}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan.
# Pure Quadlet (Podman container). Service is NOT enabled at boot (manual_start).
{% from '_imports.jinja' import host, user %}



{% import_yaml 'data/llama_embed.yaml' as embed %}

{% import_yaml 'data/service_catalog.yaml' as catalog %}

{% import_yaml 'data/container_images.yaml' as image_registry %}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan.
# Pure Quadlet (Podman container). Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
{% set models_dir = host.mnt_one ~ '/llama-embed/models' %}
{% set model_path = models_dir ~ '/' ~ embed.file %}
{% set port = catalog.llama_embed.port %}

{{ salt['service.ensure_dir']('llama_embed_models_dir', models_dir, require=['mount: mount_one']) }}

# Model download — feeds the container via bind-mount.
{{ salt['installer.http_file']('llama_embed_model', 'https://huggingface.co/' ~ embed.repo ~ '/resolve/main/' ~ embed.file, model_path, user=user, require=['file: llama_embed_models_dir'], parallel=False, version=embed.file, cache=False) }}

{{ salt['service.remove_native_unit']('llama_embed') }}

# Remove native package (idempotent — no-op if already removed)
{{ salt['service.remove_native_package']('llama_embed', ['llama.cpp-vulkan']) }}

{{ salt['container.deploy']('llama_embed', catalog.llama_embed, image_registry,
    requires=['file: llama_embed_models_dir', 'cmd: llama_embed_model', 'cmd: llama_embed_native_unit_daemon_reload']) }}
