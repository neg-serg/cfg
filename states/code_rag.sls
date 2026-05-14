{# code-rag: hybrid text+code RAG with AST-aware chunking and LanceDB vector search. #}
{#- @state
   id: code_rag
   purpose: "code-rag: hybrid text+code RAG with AST-aware chunking and LanceDB vector search."
   includes: [pacman_db_warmup]
   data_files: [data/code_rag.yaml]
#}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}
{% import_yaml 'data/code_rag.yaml' as code_rag %}

{% set _rag_shared = home ~ code_rag.rag_shared | replace('~/', '/') %}
{{ salt['installer.pip_pkg']('code_rag', pkg=home ~ code_rag.code_rag | replace('~/', '/'), bin='code-rag-index', preinstall=_rag_shared, user=user, home=home) }}

replace_mandb_with_mandoc:
  cmd.run:
    - name: pacman -S --noconfirm --needed {{ code_rag.mandoc }}
    - unless: pacman -Qi {{ code_rag.mandoc }}
    - require:
      - cmd: pacman_db_warmup

{{ salt['pkg.paru_install']('mandoc', code_rag.mandoc) }}
{{ salt['installer.pip_pkg']('docs_rag', pkg=home ~ code_rag.docs_rag | replace('~/', '/'), bin='docs-import', preinstall=_rag_shared, user=user, home=home) }}
