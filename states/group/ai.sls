{# AI group: llama_embed, ollama, nanoclaw, opencode, telethon_bridge, video_ai, image_gen #}
# Group: AI/ML services — agents, LLM inference, image generation, summarization
# Usage: just apply group/ai
{% from '_imports.jinja' import host %}

include:
{% if host.features.get('ollama', true) %}
  - ollama
{% endif %}
{% if host.features.get('llama_embed', true) %}
  - llama_embed
{% endif %}
{% if host.features.get('nanoclaw', false) %}
  - nanoclaw
{% endif %}
{% if host.features.get('telethon_bridge', false) %}
  - telethon_bridge
{% endif %}
{% if host.features.get('image_gen', true) %}
  - image_generation
{% endif %}
{% if host.features.get('opencode', false) %}
  - opencode
{% endif %}
{% if host.features.get('managed_bots', false) %}
  - managed_bots
{% endif %}
{% if host.features.get('video_ai', true) %}
  - video_ai
{% endif %}
{% if host.features.get('t5_summarization', true) %}
  - t5_summarization
{% endif %}
  - code_rag
  - pacman_db_warmup
