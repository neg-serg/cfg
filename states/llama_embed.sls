{# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan in Quadlet container #}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan.
# Pure Quadlet (Podman container). Service is NOT enabled at boot (manual_start).
{% from '_imports.jinja' import host, user %}
{% from '_macros_service.jinja' import ensure_dir, remove_native_unit, remove_native_package %}
{% from '_macros_container.jinja' import container_service, catalog, image_registry %}
{% from '_macros_install.jinja' import http_file %}
{% import_yaml 'data/llama_embed.yaml' as embed %}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan.
# Pure Quadlet (Podman container). Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
{% set models_dir = host.mnt_one ~ '/llama-embed/models' %}
{% set model_path = models_dir ~ '/' ~ embed.file %}
{% set port = catalog.llama_embed.port %}

{{ ensure_dir('llama_embed_models_dir', models_dir, require=['mount: mount_one']) }}

# Model download — feeds the container via bind-mount.
{{ http_file('llama_embed_model', 'https://huggingface.co/' ~ embed.repo ~ '/resolve/main/' ~ embed.file, model_path, user=user, require=['file: llama_embed_models_dir'], parallel=False, version=embed.file, cache=False) }}

{{ remove_native_unit('llama_embed') }}

# Remove native package (idempotent — no-op if already removed)
{{ remove_native_package('llama_embed', ['llama.cpp-vulkan']) }}

{{ container_service('llama_embed', catalog.llama_embed, image_registry,
    requires=['file: llama_embed_models_dir', 'cmd: llama_embed_model', 'cmd: llama_embed_native_unit_daemon_reload']) }}
