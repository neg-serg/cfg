{# Desktop group: audio, compositor, fonts, display manager, and user session #}
{#- @state
   id: group.desktop
   purpose: "Desktop group: audio, compositor, fonts, display manager, and user session."
   includes: [audio, desktop, fonts, greetd, pacman_db_warmup]
#}
# Group: desktop environment — audio, compositor, fonts, login
# Usage: just apply group/desktop

include:
  - audio
  - fonts
  - desktop
  - greetd
  - pacman_db_warmup
