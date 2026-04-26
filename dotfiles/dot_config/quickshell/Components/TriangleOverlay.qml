import QtQuick
import qs.Settings
import "../Helpers/Utils.js" as Utils

Canvas {
    property color color: Theme.background
    property bool flipX: false
    property bool flipY: false
    property real xCoverage: 1.0

    antialiasing: true
    enabled: visible
    contextType: "2d"

    onPaint: {
        var ctx = getContext("2d");
        var w = width;
        var h = height;
        ctx.clearRect(0, 0, w, h);
        if (w <= 0 || h <= 0) {
            return;
        }
        var coverage = Utils.clamp01(xCoverage);
        var span = Math.max(1, w * coverage);
        span = Math.min(span, w);
        var xBase = flipX ? w : 0;
        var xEdge = flipX ? Math.max(0, w - span) : span;
        var yBase = flipY ? 0 : h;
        var yOpp = flipY ? h : 0;
        ctx.lineWidth = 0;
        ctx.lineJoin = "miter";
        ctx.lineCap = "butt";
        ctx.beginPath();
        ctx.moveTo(xBase, yBase);
        ctx.lineTo(xBase, yOpp);
        ctx.lineTo(xEdge, yBase);
        ctx.closePath();
        ctx.fillStyle = color;
        ctx.fill();
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()
    onFlipXChanged: requestPaint()
    onFlipYChanged: requestPaint()
    onXCoverageChanged: requestPaint()
    Component.onCompleted: requestPaint()
}
