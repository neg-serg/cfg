{# Windows 11 QEMU/KVM virtual machine with GPU passthrough and Looking Glass #}
{% import_yaml 'data/desktop.yaml' as desktop %}

win11_xml:
  file.managed:
    - name: /var/cache/salt/win11.xml
    - source: salt://configs/win11.xml
    - mode: '0644'

win11_defined:
  cmd.run:
    - name: virsh -c qemu:///system define /var/cache/salt/win11.xml
    - onchanges:
      - file: win11_xml
