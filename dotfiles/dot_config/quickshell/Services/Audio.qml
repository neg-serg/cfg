pragma Singleton
import QtQuick
import "../Helpers/Utils.js" as Utils
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

Item {
    id: root

    readonly property string _pwRouteCommand: "PATH=\"$HOME/.local/bin:$PATH\" pw-route"

    property var defaultAudioSink: Pipewire.defaultAudioSink
    onDefaultAudioSinkChanged: syncFromSink()
    readonly property var _audio: (defaultAudioSink && defaultAudioSink.audio) ? defaultAudioSink.audio : null

    property var defaultAudioSource: Pipewire.defaultAudioSource
    onDefaultAudioSourceChanged: syncFromSource()
    readonly property var _micAudio: (defaultAudioSource && defaultAudioSource.audio) ? defaultAudioSource.audio : null

    property int volume: 0
    property bool muted: (_audio ? _audio.muted : false)
    readonly property bool isProAudioSink: _isProAudioSink()

    property int micVolume: 0
    property bool micMuted: (_micAudio ? _micAudio.muted : false)
    readonly property bool isProAudioSource: _isProAudioSource()

    property int step: 5

    function roundToStep(v) { return Math.round(v / step) * step }

    function _isProAudioSink() {
        if (!defaultAudioSink || !defaultAudioSink.properties) return false
        var val = defaultAudioSink.properties["device.profile.pro"]
        return val === true || val === "true"
    }

    function _isProAudioSource() {
        if (!defaultAudioSource || !defaultAudioSource.properties) return false
        var val = defaultAudioSource.properties["device.profile.pro"]
        return val === true || val === "true"
    }

    function syncFromSink() {
        if (_audio) {
            muted = _audio.muted
            volume = _audio.muted ? 0 : Math.round((_audio.volume || 0) * 100)
            // Pro-audio devices (RME AIO Pro) have no software volume
            // control; PipeWire may report 0 until fully initialised.
            // Clamp to 100 so the bar doesn't show a misleading "off" icon.
            if (_isProAudioSink() && !muted && volume === 0)
                volume = 100
        } else {
            muted = false
            volume = 0
        }
    }

    function syncFromSource() {
        if (_micAudio) {
            micMuted = _micAudio.muted
            micVolume = _micAudio.muted ? 0 : Math.round((_micAudio.volume || 0) * 100)
            if (_isProAudioSource() && !micMuted && micVolume === 0)
                micVolume = 100
        } else {
            micMuted = true
            micVolume = 0
        }
    }

    function setVolume(vol) {
        var clamped = Utils.clamp(Math.round(vol), 0, 100)
        var stepped = roundToStep(clamped)
        if (!_isProAudioSink() && _audio) {
            _audio.volume = stepped / 100.0
            if (_audio.muted && stepped > 0) _audio.muted = false
        }
        volume = stepped
    }

    function updateVolume(vol) { setVolume(vol) }
    function changeVolume(delta) { setVolume(volume + (Number(delta) || 0)) }

    function toggleMute() { if (!_isProAudioSink() && _audio) _audio.muted = !_audio.muted }

    function setMicVolume(vol) {
        var clamped = Utils.clamp(Math.round(vol), 0, 100)
        var stepped = roundToStep(clamped)
        if (!_isProAudioSource() && _micAudio) {
            _micAudio.volume = stepped / 100.0
            if (_micAudio.muted && stepped > 0) _micAudio.muted = false
        }
        micVolume = stepped
    }

    function updateMicVolume(vol) { setMicVolume(vol) }
    function changeMicVolume(delta) { setMicVolume(micVolume + (Number(delta) || 0)) }
    function toggleMicMute() { if (!_isProAudioSource() && _micAudio) _micAudio.muted = !_micAudio.muted }

    Connections {
        target: _audio
        function onVolumeChanged() { root.syncFromSink() }
        function onMutedChanged()  { root.syncFromSink() }
    }

    Connections {
        target: _micAudio
        function onVolumeChanged() { root.syncFromSource() }
        function onMutedChanged()  { root.syncFromSource() }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    Component.onCompleted: {
        syncFromSink()
        syncFromSource()
        // PipeWire may not have reported the real audio state during
        // initial QML evaluation (esp. after panel restart).  Re-sync
        // once after a short delay to catch the asynchronously
        // delivered initial volume / mute state.
        reSyncTimer.start()
    }

    Timer {
        id: reSyncTimer
        interval: 200
        onTriggered: {
            syncFromSink()
            syncFromSource()
        }
    }

    // ---- RME AIO Pro route detection ----

    property string currentRoute: "unknown"
    onCurrentRouteChanged: routeRefresh.restart()
    readonly property var routeNames: ({
        "an": "Speakers",
        "aes": "AES",
        "spdif": "SPDIF",
        "phones": "Headphones",
        "unknown": "Unknown"
    })
    readonly property string routeDisplayName: routeNames[currentRoute] || "Unknown"
    readonly property var routeKeys: ["an", "aes", "spdif", "phones"]

    function setRoute(name) {
        if (name === currentRoute || name === "unknown") return;
        Quickshell.execDetached(["sh", "-c", _pwRouteCommand + " " + name]);
    }

    function toggleRoute() {
        Quickshell.execDetached(["sh", "-c", _pwRouteCommand + " toggle"])
    }

    Timer {
        id: routeTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!routeProc.running) routeProc.running = true
        }
    }

    Timer {
        id: routeRefresh
        interval: 0
        repeat: false
        onTriggered: syncFromSink()
    }

    Process {
        id: routeProc
        command: ["sh", "-c", _pwRouteCommand + " current"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var route = text.trim()
                if (route && route.length > 0 && route !== root.currentRoute) {
                    root.currentRoute = route
                }
            }
        }
    }
}
