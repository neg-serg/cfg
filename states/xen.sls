{# Xen VR session — thin include hub. Sub-states split across xen/ directory. #}
{#- @state
   id: xen
   purpose: "Xen VR session — thin include hub. Sub-states split across xen/ directory."
   includes: [users, xen.kde_theme, xen.sessions, xen.user]
#}

include:
  - users
  - xen.user
  - xen.sessions
  - xen.kde_theme
