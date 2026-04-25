import QtQuick
import qs.Settings
import qs.Components
import qs.Services as Services
import "." as LocalMods

LocalMods.AudioEndpointTile {
    id: volumeDisplay
    settingsKey: "volume"
    iconOff: "volume_off"
    iconLow: "volume_down"
    iconHigh: (Services.Audio && Services.Audio.currentRoute === "phones") ? "headphones" : "volume_up"
    labelSuffix: "%"
    levelProperty: "volume"
    mutedProperty: "muted"
    changeMethod: "changeVolume"
    toggleOnClick: false
    tooltipTitle: "Volume"
    tooltipHints: [
        "Route: " + (Services.Audio ? Services.Audio.routeDisplayName : "?"),
        "Left click to cycle route.",
        "Scroll up/down to change volume."
    ]
    enableAdvancedToggle: false
    autoHideWhenMuted: true

    Item { id: ioSelector; visible: false }
    advancedSelector: ioSelector

    onClicked: {
        if (Services.Audio) Services.Audio.toggleRoute();
    }
}
