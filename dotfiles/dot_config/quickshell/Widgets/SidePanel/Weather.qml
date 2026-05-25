import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Settings
import qs.Components
import "../../Helpers/Color.js" as Color
import "../../Helpers/WeatherIcons.js" as WeatherIcons
import qs.Services as Services

Rectangle {
    id: weatherRoot
    width: Math.round(Theme.sidePanelWeatherWidth * Theme.scale(Screen))
    height: Math.round(Theme.sidePanelWeatherHeight * Theme.scale(Screen))
    color: "transparent"
    anchors.horizontalCenterOffset: Theme.weatherCenterOffset

    property string city: Settings.settings.weatherCity !== undefined ? Settings.settings.weatherCity : ""
    property var weatherData: Services.Weather.weatherData
    property string errorString: Services.Weather.errorString
    property bool isVisible: false
    property int lastFetchTime: 0
    property bool isLoading: Services.Weather.isLoading

    readonly property var _cur: weatherData && weatherData.current ? weatherData.current : null
    readonly property real _tempC: _cur && typeof _cur.temperature_2m === 'number' ? _cur.temperature_2m : NaN
    readonly property int _wcode: _cur && typeof _cur.weather_code === 'number' ? _cur.weather_code : -1
    readonly property string _wicon: _wcode >= 0 ? WeatherIcons.materialSymbolForCode(_wcode) : "cloud"
    readonly property bool _useF: Settings.settings.useFahrenheit || false

    readonly property color _bgTop: cardGradientStop(_tempC, true)
    readonly property color _bgBot: cardGradientStop(_tempC, false)
    readonly property color _textColor: Theme.textOn(_bgTop)

    function cardGradientStop(celsius, isTop) {
        if (isNaN(celsius)) return isTop ? "#1E1E24" : "#141418";
        var t = Math.max(-25, Math.min(45, celsius));
        if (t < -5)  return isTop ? "#162436" : "#0C1620";
        if (t < 5)   return isTop ? "#1A2834" : "#0E1820";
        if (t < 15)  return isTop ? "#1E2830" : "#10181C";
        if (t < 25)  return isTop ? "#20201E" : "#141412";
        if (t < 33)  return isTop ? "#221E16" : "#16140E";
        return isTop ? "#241A18" : "#161010";
    }

    function temperatureColor(celsius) {
        if (isNaN(celsius)) return Theme.textPrimary;
        var t = Math.max(-25, Math.min(45, celsius));
        if (t < -10) return "#5BA0D0";
        if (t < 0)   return "#7BB8E0";
        if (t < 10)  return "#A0CCE8";
        if (t < 20)  return "#C8D8E0";
        if (t < 25)  return "#E8C878";
        if (t < 30)  return "#E8A840";
        if (t < 35)  return "#E86038";
        return "#E03828";
    }

    Connections { target: Services.Weather; function onWeatherDataChanged() { weatherRoot.weatherData = Services.Weather.weatherData } }
    Component.onCompleted: { if (isVisible) Services.Weather.start() }
    function startWeatherFetch() { isVisible = true; Services.Weather.start() }

    function warnContrast(bg, fg, label) {
        try {
            if (!(Settings.settings && Settings.settings.debugLogs)) return;
            var ratio = Color.contrastRatio(bg, fg);
            var th = (Settings.settings && Settings.settings.contrastWarnRatio) ? Settings.settings.contrastWarnRatio : 4.5;
            if (ratio < th) console.debug('[Contrast]', label || 'text', 'ratio', ratio.toFixed(2));
        } catch (e) { console.warn("[Weather.warnContrast]", e) }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.borderSubtle
        border.width: Theme.uiBorderWidth
        radius: Math.round(Theme.sidePanelCornerRadius * Theme.scale(Screen))
        clip: true

        gradient: Gradient {
            GradientStop { position: 0.0; color: weatherRoot._bgTop }
            GradientStop { position: 1.0; color: weatherRoot._bgBot }
        }

        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: Color.withAlpha("#000000", 0.08)
        }

        Canvas {
            id: weatherDecor
            anchors.fill: parent
            z: 0
            property int wcode: weatherRoot._wcode
            property color accent: weatherRoot.temperatureColor(weatherRoot._tempC)
            onWcodeChanged: requestPaint()
            onAccentChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.globalAlpha = 0.07;
                var w = width, h = height;

                if (wcode === 0) {
                    drawSunRays(ctx, w, h);
                } else if (wcode >= 1 && wcode <= 3) {
                    drawSunRays(ctx, w, h);
                    drawClouds(ctx, w, h);
                } else if (wcode >= 45 && wcode <= 48) {
                    drawFog(ctx, w, h);
                } else if (wcode >= 51 && wcode <= 67 || wcode >= 80 && wcode <= 82) {
                    drawRain(ctx, w, h);
                } else if (wcode >= 71 && wcode <= 77) {
                    drawSnow(ctx, w, h);
                } else if (wcode >= 95 && wcode <= 99) {
                    drawRain(ctx, w, h);
                    drawStormBolt(ctx, w, h);
                }
            }

            function drawSunRays(ctx, w, h) {
                var cx = w * 0.75, cy = h * 0.32;
                ctx.strokeStyle = accent;
                for (var i = 0; i < 14; i++) {
                    var angle = (i / 14) * Math.PI * 2 - Math.PI * 0.2;
                    var innerR = 24;
                    var outerR = innerR + 18 + (i % 3) * 16;
                    var opacity = 0.3 + (i % 3) * 0.25;
                    ctx.globalAlpha = 0.07 * opacity * 2;
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * innerR, cy + Math.sin(angle) * innerR);
                    ctx.lineTo(cx + Math.cos(angle) * outerR, cy + Math.sin(angle) * outerR);
                    ctx.stroke();
                }
                ctx.globalAlpha = 0.07;
            }

            function drawClouds(ctx, w, h) {
                ctx.fillStyle = "#AABBCC";
                drawCloud(ctx, w * 0.65, h * 0.18, 40);
                drawCloud(ctx, w * 0.78, h * 0.12, 35);
                drawCloud(ctx, w * 0.55, h * 0.22, 30);
            }

            function drawCloud(ctx, cx, cy, r) {
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.arc(cx + r * 0.7, cy - r * 0.25, r * 0.75, 0, Math.PI * 2);
                ctx.arc(cx + r * 1.2, cy, r * 0.7, 0, Math.PI * 2);
                ctx.arc(cx - r * 0.6, cy + r * 0.1, r * 0.6, 0, Math.PI * 2);
                ctx.arc(cx + r * 0.5, cy - r * 0.5, r * 0.55, 0, Math.PI * 2);
                ctx.fill();
            }

            function drawFog(ctx, w, h) {
                ctx.strokeStyle = "#8899AA";
                ctx.lineWidth = 2;
                for (var i = 0; i < 6; i++) {
                    var y = h * 0.2 + i * h * 0.1;
                    ctx.globalAlpha = 0.04 + i * 0.006;
                    ctx.beginPath();
                    ctx.moveTo(w * 0.1, y);
                    ctx.lineTo(w * 0.9, y);
                    ctx.stroke();
                }
                ctx.globalAlpha = 0.07;
            }

            function drawRain(ctx, w, h) {
                ctx.strokeStyle = "#88AACC";
                ctx.lineWidth = 1;
                for (var i = 0; i < 40; i++) {
                    var x = (i * 37 + 13) % w;
                    var y = (i * 53 + 7) % h;
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                    ctx.lineTo(x - 3, y + 8);
                    ctx.stroke();
                }
            }

            function drawSnow(ctx, w, h) {
                ctx.fillStyle = "#CCDDEE";
                for (var i = 0; i < 30; i++) {
                    var x = (i * 47 + 13) % w;
                    var y = (i * 59 + 7) % h;
                    var r = 1.5 + (i % 3) * 1;
                    ctx.beginPath();
                    ctx.arc(x, y, r, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            function drawStormBolt(ctx, w, h) {
                ctx.strokeStyle = "#FFD040";
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                var bx = w * 0.75, by = h * 0.08;
                ctx.moveTo(bx, by);
                ctx.lineTo(bx - 10, by + 22);
                ctx.lineTo(bx + 4, by + 22);
                ctx.lineTo(bx - 8, by + 44);
                ctx.stroke();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(Theme.panelSideMargin * 0.9 * Theme.scale(Screen))
            spacing: Math.round(Theme.sidePanelSpacingSmall * Theme.scale(Screen))
            z: 1

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.uiIconSizeLarge * Theme.scale(Screen))
                spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))

                Spinner {
                    id: loadingSpinner
                    running: isLoading
                    color: Theme.accentPrimary
                    size: Math.round(Theme.uiIconSizeLarge * Theme.scale(Screen))
                    visible: isLoading
                    Layout.alignment: Qt.AlignVCenter
                }

                MaterialIcon {
                    id: weatherIcon
                    visible: !isLoading
                    icon: weatherRoot._wicon
                    size: Math.round(Theme.uiIconSizeLarge * 1.1 * Theme.scale(Screen))
                    color: weatherRoot.temperatureColor(weatherRoot._tempC)
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: weatherRoot._tempC !== weatherRoot._tempC ? ((weatherRoot._useF) ? "--°F" : "--°C")
                        : (weatherRoot._useF ? Math.round(weatherRoot._tempC * 9/5 + 32) + "°F" : Math.round(weatherRoot._tempC) + "°C")
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(Theme.fontSizeHeader * Theme.weatherHeaderScale * 1.15 * Theme.scale(Screen))
                    font.bold: true
                    color: weatherRoot.temperatureColor(weatherRoot._tempC)
                    Layout.alignment: Qt.AlignVCenter
                    Component.onCompleted: weatherRoot.warnContrast(weatherRoot._bgTop, color, 'weather.temp')
                }

                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: city.length > 18 ? city.slice(0, 17) + "…" : city
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontSizeSmall * Theme.scale(Screen))
                        font.bold: true
                        color: weatherRoot._textColor
                        elide: Text.ElideRight
                    }
                    Text {
                        text: weatherData && weatherData.timezone_abbreviation ? weatherData.timezone_abbreviation : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.tooltipFontPx * Theme.tooltipSmallScaleRatio * Theme.scale(Screen))
                        color: Theme.textSecondary
                        visible: text !== ""
                    }
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))
                visible: weatherData && weatherData.current

                RowLayout {
                    spacing: 4
                    visible: weatherRoot._cur && typeof weatherRoot._cur.wind_speed_10m === 'number' && weatherRoot._cur.wind_speed_10m > 0.1
                    MaterialIcon {
                        icon: "navigation"
                        rotationAngle: WeatherIcons.windRotation(weatherRoot._cur ? weatherRoot._cur.wind_direction_10m : 0)
                        size: Math.round(Theme.fontSizeSmall * 0.85 * Theme.scale(Screen))
                        color: weatherRoot._textColor
                    }
                    Text {
                        text: WeatherIcons.formatWindFull(weatherRoot._cur.wind_speed_10m, weatherRoot._cur.wind_direction_10m)
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontSizeSmall * 0.85 * Theme.scale(Screen))
                        color: weatherRoot._textColor
                    }
                }

                RowLayout {
                    spacing: 4
                    visible: weatherRoot._cur && typeof weatherRoot._cur.relative_humidity_2m === 'number'
                    MaterialIcon {
                        icon: "water_drop"
                        size: Math.round(Theme.fontSizeSmall * 0.85 * Theme.scale(Screen))
                        color: weatherRoot._textColor
                    }
                    Text {
                        text: Math.round(weatherRoot._cur.relative_humidity_2m) + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontSizeSmall * 0.85 * Theme.scale(Screen))
                        color: weatherRoot._textColor
                    }
                }

                RowLayout {
                    spacing: 4
                    MoonPhaseIcon {
                        size: Math.round(Theme.fontSizeSmall * 0.85 * Theme.scale(Screen))
                        moonColor: weatherRoot._textColor
                        rimColor: Color.withAlpha(weatherRoot._textColor, 0.5)
                    }
                    Text {
                        text: WeatherIcons.moonName(new Date())
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontSizeSmall * 0.85 * Theme.scale(Screen))
                        color: weatherRoot._textColor
                    }
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                visible: weatherData && weatherData.daily && weatherData.daily.time

                Repeater {
                    model: weatherData && weatherData.daily && weatherData.daily.time ? Math.min(5, weatherData.daily.time.length) : 0
                    delegate: ColumnLayout {
                        spacing: 1
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: weatherData.daily.time[index] ? Qt.formatDateTime(new Date(weatherData.daily.time[index]), "ddd") : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSizeCaption * Theme.scale(Screen))
                            color: weatherRoot._textColor
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }

                        MaterialIcon {
                            icon: weatherData.daily.weathercode && weatherData.daily.weathercode[index] !== undefined
                                ? WeatherIcons.materialSymbolForCode(weatherData.daily.weathercode[index]) : "cloud"
                            size: Math.round(Theme.panelPillIconSize * 0.9 * Theme.scale(Screen))
                            color: weatherRoot._textColor
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: weatherData && weatherData.daily && weatherData.daily.temperature_2m_max
                                ? (weatherRoot._useF
                                    ? Math.round(weatherData.daily.temperature_2m_max[index] * 9/5 + 32) + "°"
                                    : Math.round(weatherData.daily.temperature_2m_max[index]) + "°")
                                : "--°"
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSizeCaption * Theme.scale(Screen))
                            font.bold: true
                            color: weatherRoot._textColor
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: weatherData && weatherData.daily && weatherData.daily.temperature_2m_min
                                ? (weatherRoot._useF
                                    ? Math.round(weatherData.daily.temperature_2m_min[index] * 9/5 + 32) + "°"
                                    : Math.round(weatherData.daily.temperature_2m_min[index]) + "°")
                                : "--°"
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSizeCaption * 0.85 * Theme.scale(Screen))
                            color: Color.withAlpha(weatherRoot._textColor, 0.65)
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            Text {
                text: errorString
                color: Theme.error
                visible: errorString !== ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(Theme.tooltipFontPx * 0.71 * Theme.scale(Screen))
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
