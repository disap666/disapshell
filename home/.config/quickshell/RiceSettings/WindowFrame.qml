import QtQuick

// Laid over the whole window: optional darkened corners and a hairline border.
Item {
    enabled: false

    Canvas {
        visible: Tokens.vignette
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var g = ctx.createRadialGradient(width / 2, height / 2, Math.min(width, height) * .35, width / 2, height / 2, Math.max(width, height) * .75);
            g.addColorStop(0, "rgba(0,0,0,0)");
            g.addColorStop(1, "rgba(0,0,0,0.55)");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 14
        border.width: 1
        border.color: Tokens.alpha("#ffffff", .16)
    }
}
