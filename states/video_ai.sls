{# Video AI pipeline: includes base, models, runners, and workflow definitions #}
{#- @state
   id: video_ai
   purpose: "Video AI pipeline: includes base, models, runners, and workflow definitions."
   includes: [video_ai.base, video_ai.models, video_ai.runners, video_ai.workflows]
#}
# =============================================================================
# Video AI — includes base, models, workflows, runners
# =============================================================================
include:
  - video_ai.base
  - video_ai.models
  - video_ai.workflows
  - video_ai.runners
