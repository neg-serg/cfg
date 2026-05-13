{# mkinitcpio initramfs configuration: hooks, modules, and compression settings #}
# mkinitcpio: manage initramfs configuration (compression, hooks)
{% from '_macros_service.jinja' import config_and_reload %}

{{ config_and_reload('mkinitcpio_config', '/etc/mkinitcpio.conf', 'mkinitcpio -P',
    source='salt://configs/mkinitcpio.conf.j2', template='jinja',
    onlyif='command -v mkinitcpio >/dev/null 2>&1') }}
