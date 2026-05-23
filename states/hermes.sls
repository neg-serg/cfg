{#- @state
   id: hermes
   purpose: "hermes-agent (NousResearch): locally-run AI agent with tool use, web browsing, and automation."
   includes: [packages]
   data_files: []
#}
{% from '_imports.jinja' import user, home %}

include:
  - packages

hermes_home_dirs:
  file.directory:
    - names:
      - {{ home }}/.hermes
      - {{ home }}/.hermes/cron
      - {{ home }}/.hermes/sessions
      - {{ home }}/.hermes/logs
      - {{ home }}/.hermes/memories
      - {{ home }}/.hermes/skills
      - {{ home }}/.hermes/pairing
      - {{ home }}/.hermes/hooks
      - {{ home }}/.hermes/image_cache
      - {{ home }}/.hermes/audio_cache
      - {{ home }}/.hermes/whatsapp/session
      - {{ home }}/.hermes/skins
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

hermes_gateway_service:
  cmd.run:
    - name: hermes gateway install
    - creates: {{ home }}/.config/systemd/user/hermes-gateway.service
    - runas: {{ user }}
    - require:
      - file: hermes_home_dirs
