import QtQuick
import qs.Components
import qs.Settings
import qs.Widgets.SidePanel
import qs.Services as Services
import "../../Helpers/TooltipText.js" as TooltipText
import "../../Helpers/WeatherIcons.js" as WeatherIcons
import "../../Helpers/Color.js" as Color

OverlayToggleCapsule {
    id: root
    readonly property real capsuleScale: capsule.capsuleScale
    readonly property int iconBox: Math.round(capsule.capsuleInner * 1.08)
    capsule.backgroundKey: "weather"
    capsule.centerContent: true
    capsule.cursorShape: Qt.PointingHandCursor
    capsule.implicitWidth: capsule.horizontalPadding * 2 + weatherContent.implicitWidth
    capsuleVisible: true
    autoToggleOnTap: true
    overlayNamespace: "sideleft-weather"

    Component.onCompleted: Services.Weather.start()

    readonly property var _weatherData: Services.Weather.weatherData
    readonly property var _current: _weatherData && _weatherData.current ? _weatherData.current : null
    readonly property string weatherIcon: _current && typeof _current.weather_code === 'number'
        ? WeatherIcons.materialSymbolForCode(_current.weather_code)
        : "partly_cloudy_day"
    readonly property real _tempC: _current && typeof _current.temperature_2m === 'number'
        ? _current.temperature_2m : NaN
    readonly property string temperatureText: {
        try {
            if (!isNaN(_tempC)) {
                var useF = Settings.settings.useFahrenheit || false;
                return useF ? Math.round(_tempC * 9/5 + 32) + "°F" : Math.round(_tempC) + "°C";
            }
        } catch (e) {}
        return (Settings.settings.useFahrenheit || false) ? "--°F" : "--°C";
    }
    readonly property bool hasWind: _current && typeof _current.wind_speed_10m === 'number'
    readonly property string windSpeed: {
        try { if (hasWind) return WeatherIcons.formatWindSpeed(_current.wind_speed_10m); } catch (e) {}
        return "";
    }
    readonly property real windRotation: {
        try { if (hasWind) return WeatherIcons.windRotation(_current.wind_direction_10m); } catch (e) {}
        return 0;
    }
    readonly property bool hasHumidity: _current && typeof _current.relative_humidity_2m === 'number'
    readonly property string humidityText: {
        try { if (hasHumidity) return Math.round(_current.relative_humidity_2m) + "%"; } catch (e) {}
        return "";
    }

    function temperatureColor(celsius) {
        if (isNaN(celsius)) return Theme.textPrimary;
        var t = Math.max(-25, Math.min(45, celsius));
        if (t < -10) return "#5BA0D0";
        if (t < 0) return lerpColor("#7BB8E0", "#A0D0EF", (t + 10) / 10);
        if (t < 12) return lerpColor("#B8D8F0", "#D0DAE8", t / 12);
        if (t < 22) return lerpColor("#D8D8E0", "#E8C878", (t - 12) / 10);
        if (t < 32) return lerpColor("#E8A840", "#E86038", (t - 22) / 10);
        return "#E03828";
    }

    function lerpColor(c1, c2, t) {
        t = Math.max(0, Math.min(1, t));
        var r1 = parseInt(c1.slice(1,3), 16), g1 = parseInt(c1.slice(3,5), 16), b1 = parseInt(c1.slice(5,7), 16);
        var r2 = parseInt(c2.slice(1,3), 16), g2 = parseInt(c2.slice(3,5), 16), b2 = parseInt(c2.slice(5,7), 16);
        var r = Math.round(r1 + (r2 - r1) * t);
        var g = Math.round(g1 + (g2 - g1) * t);
        var b = Math.round(b1 + (b2 - b1) * t);
        return "#" + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1);
    }

    Row {
        id: weatherContent
        anchors.centerIn: parent
        spacing: Math.round(3 * capsuleScale)

        Item {
            id: iconGlow
            width: iconBox + Math.round(8 * capsuleScale)
            height: iconBox + Math.round(8 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: glowCanvas
                anchors.fill: parent
                visible: !isNaN(root._tempC)
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var cx = width / 2, cy = height / 2;
                    var grad = ctx.createRadialGradient(cx, cy, iconBox * 0.25, cx, cy, iconBox * 0.7);
                    grad.addColorStop(0, Color.withAlpha(root.temperatureColor(root._tempC), 0.22));
                    grad.addColorStop(1, "transparent");
                    ctx.fillStyle = grad;
                    ctx.fillRect(0, 0, width, height);
                }
                Connections {
                    target: Services.Weather
                    function onWeatherDataChanged() { if (glowCanvas) glowCanvas.requestPaint(); }
                }
            }

            MaterialIcon {
                id: weatherIconItem
                icon: root.weatherIcon
                size: iconBox
                color: root.temperatureColor(root._tempC)
                anchors.centerIn: parent
                Behavior on color { ColorFastInOutBehavior {} }
            }
        }

        Text {
            id: tempLabel
            text: root.temperatureText
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSizeSmall * capsuleScale)
            font.bold: true
            color: root.temperatureColor(root._tempC)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorFastInOutBehavior {} }
        }
    }

    HoverHandler {
        id: hoverArea
    }

    overlayChildren: [
        PanelOverlaySurface {
            id: popup
            screen: root.screen
            scaleHint: capsuleScale
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: Math.round(Theme.sidePanelSpacingMedium * capsuleScale)
            anchors.leftMargin: Math.round(Theme.panelSideMargin * capsuleScale)

            Weather {
                id: weather
                width: Math.round(Theme.sidePanelWeatherWidth * capsuleScale)
                height: Math.round(Theme.sidePanelWeatherHeight * capsuleScale)
            }
        }
    ]

    PanelTooltip {
        id: weatherTip
        targetItem: weatherContent
        text: root.tooltipText()
        visibleWhen: hoverArea.hovered
    }

    function tooltipText() {
        try {
            const city = Settings.settings.weatherCity || "";
            const cur = root._current;
            if (cur && typeof cur.temperature_2m === 'number') {
                const c = Math.round(cur.temperature_2m);
                const useF = Settings.settings.useFahrenheit || false;
                const t = useF ? Math.round(c * 9/5 + 32) + "°F" : c + "°C";
                const wind = root.hasWind ? WeatherIcons.formatWindFull(cur.wind_speed_10m, cur.wind_direction_10m) : "";
                var sub = [];
                if (wind) sub.push("Wind: " + wind);
                if (root.hasHumidity) sub.push("Humidity: " + Math.round(cur.relative_humidity_2m) + "%");
                sub.push("Moon: " + WeatherIcons.moonName(new Date()));
                return TooltipText.compose(city || "Weather", t, sub);
            }
            return TooltipText.compose("Weather", city, []);
        } catch (e) {
            return "Weather";
        }
    }

    Connections { target: Services.Weather; function onWeatherDataChanged() { weatherTip.text = root.tooltipText(); } }
}
