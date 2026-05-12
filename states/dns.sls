{# DNS services: unbound recursive resolver, AdGuard Home filtering, avahi mDNS, DoT #}
{% from '_imports.jinja' import host %}
{% set dns = host.features.dns %}

# DNS-over-TLS via systemd-resolved drop-in
dns_over_tls_dropin_dir:
  file.directory:
    - name: /etc/systemd/resolved.conf.d
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

dns_over_tls_config:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/dns-over-tls.conf
    - source: salt://configs/resolved-dns-over-tls.conf
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: dns_over_tls_dropin_dir

dns_over_tls_restart:
  service.running:
    - name: systemd-resolved
    - enable: True
    - watch:
      - file: dns_over_tls_config

# Reusable restart target for external configs (e.g. tailscale DNS stub)
# that drop files into unbound.conf.d/ and need unbound to pick them up.
{% if dns.unbound %}
unbound_restart_or_reload:
  cmd.run:
    - name: unbound-control reload 2>/dev/null || systemctl restart unbound 2>/dev/null || true
    - onlyif: command -v unbound-control >/dev/null 2>&1 || systemctl cat unbound >/dev/null 2>&1
{% endif %}
