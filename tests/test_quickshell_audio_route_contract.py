from tests import REPO_ROOT_PATH


def read(path: str) -> str:
    return (REPO_ROOT_PATH / path).read_text()


def test_audio_service_polls_pw_route_current_and_has_fast_route_toggle():
    text = read("dotfiles/dot_config/quickshell/Services/Audio.qml")

    assert 'readonly property string _pwRouteCommand:' in text
    assert 'PATH=\\"$HOME/.local/bin:$PATH\\" pw-route' in text
    assert 'command: ["sh", "-c", _pwRouteCommand + " current"]' in text
    assert 'function toggleRoute()' in text
    assert 'Quickshell.execDetached(["sh", "-c", _pwRouteCommand + " toggle"])' in text
    assert 'onCurrentRouteChanged: routeRefresh.restart()' in text


def test_volume_module_shows_route_state_instead_of_volume_hints_for_pro_audio():
    text = read("dotfiles/dot_config/quickshell/Bar/Modules/Volume.qml")

    assert 'tooltipTitle: "Output"' in text
    assert '"Mirror: " + (Services.Audio ? Services.Audio.routeDisplayName : "?")' in text
    assert '"Left click to toggle AES / Analog."' in text
    assert 'labelText: (Services.Audio && Services.Audio.isProAudioSink) ?' in text
    assert '"AES"' in text
    assert '"AN"' in text
    assert '"?"' in text
    assert 'wheelEnabled: !(Services.Audio && Services.Audio.isProAudioSink)' in text


def test_audio_endpoint_tile_supports_custom_tooltip_value():
    text = read("dotfiles/dot_config/quickshell/Bar/Modules/AudioEndpointTile.qml")

    assert 'property string tooltipValue: ""' in text
    assert 'readonly property string _computedValue: (function() {' in text
    assert 'if (tooltipValue.length)' in text
    assert 'return tooltipValue;' in text


def test_audio_endpoint_capsule_refreshes_on_route_state_changes():
    text = read("dotfiles/dot_config/quickshell/Components/AudioEndpointCapsule.qml")

    assert 'function onCurrentRouteChanged() { root.refreshFromService(); }' in text
    assert 'function onIsProAudioSinkChanged() { root.refreshFromService(); }' in text


def test_audio_level_capsule_supports_label_override_and_wheel_disable():
    text = read("dotfiles/dot_config/quickshell/Components/AudioLevelCapsule.qml")

    assert 'property string labelText: ""' in text
    assert 'property bool wheelEnabled: true' in text
    assert 'pillIndicator.text = labelText.length ? labelText : clamped + labelSuffix' in text
    assert 'if (!root.wheelEnabled || wheel.angleDelta.y === 0)' in text


def test_state_cache_persists_audio_off_reminder_timestamp():
    text = read("dotfiles/dot_config/quickshell/Settings/StateCache.qml")

    assert 'property double audioOffReminderLastShownAt: 0' in text


def test_theme_exposes_default_audio_off_reminder_cooldown():
    text = read("dotfiles/dot_config/quickshell/Settings/Theme.qml")

    assert "'panel.volume.offReminderCooldownMs': 'panelVolumeOffReminderCooldownMs'" in text
    assert "property int panelVolumeOffReminderCooldownMs: val('panel.volume.offReminderCooldownMs', 86400000)" in text


def test_settings_exposes_audio_off_reminder_cooldown_override():
    text = read("dotfiles/dot_config/quickshell/Settings/Settings.qml")

    assert 'property int audioOffReminderCooldownMs: -1' in text


def test_audio_level_capsule_uses_timestamp_cooldown_for_off_reminders():
    text = read("dotfiles/dot_config/quickshell/Components/AudioLevelCapsule.qml")

    assert 'property string _prevCategory: ""' in text
    assert 'property int offReminderCooldownMs: 24 * 60 * 60 * 1000' not in text
    assert 'readonly property int effectiveOffReminderCooldownMs:' in text
    assert 'Settings.settings.audioOffReminderCooldownMs' in text
    assert 'Theme.panelVolumeOffReminderCooldownMs' in text
    assert 'function shouldShowOffReminder(category)' in text
    assert 'StateCache.state[offReminderStateKey]' in text
    assert 'const enteringOff = category === "off" && _prevCategory !== "off";' in text
