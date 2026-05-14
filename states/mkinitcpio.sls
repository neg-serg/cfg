{# mkinitcpio initramfs configuration: hooks, modules, and compression settings #}
{#- @state
   id: mkinitcpio
   purpose: "mkinitcpio initramfs configuration: hooks, modules, and compression settings."
   configs: [configs/mkinitcpio.conf.j2]
#}
# mkinitcpio: manage initramfs configuration (compression, hooks)
{{ salt['service.config_and_reload']('mkinitcpio_config', '/etc/mkinitcpio.conf', 'mkinitcpio -P',
    source='salt://configs/mkinitcpio.conf.j2', template='jinja',
    onlyif='command -v mkinitcpio >/dev/null 2>&1') }}
