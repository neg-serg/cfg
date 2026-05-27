{# Quickshell overview patches: fix missing colLayer2Border + defensive applyAlpha #}
{#- @state
   id: quickshell
   purpose: "Patch quickshell-overview-git system files to fix missing colLayer2Border property and add defensive applyAlpha guard."
   data_files: [data/packages.yaml]
#}
{% from '_imports.jinja' import host %}

{# ── Patch 1: Add missing colLayer2Border to Appearance.qml ── #}
quickshell_fix_colLayer2Border:
  file.replace:
    - name: /etc/xdg/quickshell/overview/common/Appearance.qml
    - pattern: |
        (        property color colLayer2Active: ColorUtils\.mix\(colLayer2, colOnLayer2, 0\.80\)\n)(        property color colPrimary: m3colors\.m3primary)
    - repl: |-
        \1        property color colLayer2Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer2, 0.4)\n\2
    - show_changes: true
    - onlyif: test -f /etc/xdg/quickshell/overview/common/Appearance.qml

{# ── Patch 2: Defensive guard in ColorUtils.applyAlpha ── #}
quickshell_fix_applyAlpha:
  file.replace:
    - name: /etc/xdg/quickshell/overview/common/functions/ColorUtils.qml
    - pattern: |
        (    function applyAlpha\(color, alpha\) \{\n)(        var c = Qt\.color\(color\);)
    - repl: |-
        \1        if (!color || color === '') return Qt.rgba(0, 0, 0, 0);\n\2
    - show_changes: true
    - onlyif: test -f /etc/xdg/quickshell/overview/common/functions/ColorUtils.qml
