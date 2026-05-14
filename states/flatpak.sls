{# Flatpak sandboxed desktop applications with flathub remote setup #}
{#- @state
   id: flatpak
   purpose: "Flatpak sandboxed desktop applications with flathub remote setup."
   includes: [pacman_db_warmup]
   data_files: [data/flatpak.yaml]
#}
# Flatpak: sandboxed desktop apps + flathub remote.
include:
  - pacman_db_warmup

{% from '_imports.jinja' import host, user %}
{% import_yaml 'data/flatpak.yaml' as flatpak %}

# ── Flatpak temporarily disabled for debugging ──
# Re-enable by commenting out the onlyif:false guards below.
#
# Issues:
#   - flatpak install fails with "No remote refs found for 'flathub'"
#     when appstream data hasn't been fetched (missing update --appstream).
#   - Proxy (socks5h://127.0.0.1:10808) was added but may not be
#     reliably available during all phases of state.apply.
#   - See commits f4c7ee52 / ec081bdd for proxy + appstream fixes.
#
# To re-enable:
#   1. Remove the `- onlyif: false` line from paru_install below
#   2. Uncomment the app loop at the bottom
#   3. Ensure SOCKS5 proxy is running on 127.0.0.1:10808

{# Flatpak runtime package — disabled for now via onlyif:false #}
install_flatpak:
  cmd.run:
    - name: /bin/true
    - onlyif: false

{# Flatpak install of apps — disabled #}
{% for app_id in flatpak.apps %}
{# {{ salt['pkg.flatpak_install'](app_id) }} #}
{% endfor %}
