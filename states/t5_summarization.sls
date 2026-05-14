{# T5 text summarization server: safetensors to GGUF conversion via Quadlet container #}
{#- @state
   id: t5_summarization
   purpose: "T5 text summarization server: safetensors to GGUF conversion via Quadlet container."
   data_files: [data/t5_summarization.yaml]
   services: [t5_summarization.container]
#}
{% from '_imports.jinja' import host, user %}

{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/t5_summarization.yaml' as t5 %}
# llama.cpp T5 summarization server: UrukHan/t5-russian-summarization via Vulkan.
# Downloads safetensors from HuggingFace, converts to GGUF, serves via llama-server.
# Pure Quadlet (Podman container). Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
{% set models_dir = host.mnt_one ~ '/t5-summarization/models' %}
{% set hf_path = models_dir ~ '/hf' %}
{% set hf_file = t5.hf_file %}
{% set gguf_path = models_dir ~ '/' ~ t5.gguf_file %}
{% set port = catalog.t5_summarization.port %}

{{ salt['service.ensure_dir']('t5_summarization_models_dir', models_dir, require=['mount: mount_one']) }}
{{ salt['service.ensure_dir']('t5_summarization_hf_dir', hf_path, require=['mount: mount_one']) }}

# python-transformers is needed for convert_hf_to_gguf.py (runs on host during build)
{{ salt['pkg.paru_install']('python_transformers', 'python-transformers') }}

# Download model + tokenizer files from HuggingFace (unconditional — feeds container via bind-mount)
{{ salt['installer.huggingface_file']('t5_summarization_model', t5.hf_repo, hf_file, hf_path ~ '/' ~ hf_file, user=user, require=['file: t5_summarization_hf_dir'], parallel=False, version=hf_file, cache=False) }}
{% for fname in t5.tokenizer_files %}
{{ salt['installer.huggingface_file']('t5_summarization_' ~ fname | replace('.', '_'), t5.hf_repo, fname, hf_path ~ '/' ~ fname, user=user, require=['file: t5_summarization_hf_dir'], parallel=False, cache=False) }}
{% endfor %}

# Convert safetensors → GGUF (requires convert_hf_to_gguf.py from llama.cpp)
t5_summarization_convert:
  cmd.run:
    - name: |
        set -euo pipefail
        cd {{ hf_path }}
        /usr/bin/convert_hf_to_gguf.py {{ hf_path }} --outfile {{ gguf_path }} --outtype q5_k_m 2>&1
    - shell: /bin/bash
    - runas: {{ user }}
    - creates: {{ gguf_path }}
    - onlyif: test -x /usr/bin/convert_hf_to_gguf.py
    - require:
      - cmd: t5_summarization_model
{%- for fname in t5.tokenizer_files %}
      - cmd: t5_summarization_{{ fname | replace('.', '_') }}
{%- endfor %}
      - cmd: install_python_transformers

# In-place cutover: remove the native systemd unit file
{{ salt['service.remove_native_unit']('t5_summarization') }}

# Remove native package (idempotent — no-op if already removed)
{{ salt['service.remove_native_package']('t5_summarization', ['llama.cpp-vulkan']) }}

{{ salt['container.deploy']('t5_summarization',
    requires=['file: t5_summarization_hf_dir', 'cmd: t5_summarization_convert', 'cmd: t5_summarization_native_unit_daemon_reload']) }}
