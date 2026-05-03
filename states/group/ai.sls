{# AI group: llama_embed, ollama, nanoclaw, opencode, telethon_bridge, video_ai, image_gen #}
# Group: AI/ML services — agents, LLM inference, image generation, summarization
# Usage: just apply group/ai
{% from '_imports.jinja' import host %}

include:
{% if host.features.get('ollama', False) %}
  - ollama
{% endif %}
{% if host.features.get('llama_embed', False) %}
  - llama_embed
{% endif %}
{% if host.features.get('nanoclaw', False) %}
  - nanoclaw
{% endif %}
{% if host.features.get('telethon_bridge', False) %}
  - telethon_bridge
{% endif %}
{% if host.features.get('image_gen', True) %}
  - image_generation
{% endif %}
{% if host.features.get('opencode', False) %}
  - opencode
{% endif %}
{% if host.features.get('opencode_telegram', False) %}
  - opencode_telegram
{% endif %}
{% if host.features.get('video_ai', False) %}
  - video_ai
{% endif %}
{% if host.features.get('t5_summarization', False) %}
  - t5_summarization
{% endif %}
