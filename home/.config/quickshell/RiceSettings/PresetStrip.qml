pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// One-click looks: each card renders the preset over your wallpaper.
// A preset only overrides the keys it lists; everything else stays yours.
Flickable {
    id: root
    property var presets: []          // [{ name, values }]
    property var base: ({})           // current appearance
    property string wallpaper: ""
    property bool dock: false
    property real alphaScale: 100     // waybar stores 0..100, the dock 0..1
    signal chosen(var values)

    function merged(p) { return Object.assign({}, base, p.values); }
    function isCurrent(p) { return Object.keys(p.values).every(k => base[k] === p.values[k]); }
    function hex(v, f) { return /^#[0-9a-fA-F]{6}$/.test(v || "") ? v : f; }

    implicitHeight: 92
    contentWidth: row.implicitWidth; contentHeight: height
    clip: true; boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    C.ScrollBar.horizontal: C.ScrollBar { policy: row.implicitWidth > root.width ? C.ScrollBar.AsNeeded : C.ScrollBar.AlwaysOff; height: 5 }
    WheelHandler { onWheel: event => root.contentX = Math.max(0, Math.min(root.contentWidth - root.width, root.contentX - event.angleDelta.y)) }

    Row {
        id: row
        spacing: 10
        Repeater {
            model: root.presets
            Item {
                id: card
                required property var modelData
                readonly property var a: root.merged(modelData)
                readonly property bool on: root.isCurrent(modelData)
                width: 132; height: 84
                Rectangle {
                    id: frame
                    anchors.fill: parent; anchors.bottomMargin: 18
                    radius: 10; clip: true
                    color: "#1b1d26"
                    border.width: card.on ? 2 : 1
                    border.color: card.on ? Tokens.accent : cardArea.containsMouse ? Tokens.alpha(Tokens.accent, .6) : Tokens.alpha(Tokens.text, .1)
                    Image { anchors.fill: parent; anchors.margins: 1; source: root.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 264; opacity: .9 }
                    MiniBar {
                        x: root.dock ? (parent.width - width) / 2 : 6
                        y: root.dock ? parent.height - height - 6 : 6
                        width: root.dock ? 34 + 18 * Math.min(3, (card.a.parts || 1)) : parent.width - 12
                        height: root.dock ? 16 : 12
                        parts: root.dock ? (card.a.parts || 1) : (card.a.layout || 3)
                        radius: Math.min(8, (card.a.radius || 0) / 3)
                        gap: Math.min(8, (card.a.gap === undefined ? 12 : card.a.gap) / 3)
                        dock: root.dock
                        background: root.hex(card.a.background, "#201a2d")
                        highlight: root.hex(card.a.highlight, "#493957")
                        gradient: !!card.a.gradient
                        alpha: (card.a.opacity === undefined ? 0.8 * root.alphaScale : card.a.opacity) / root.alphaScale
                        border: root.hex(card.a.border, "#ffffff")
                        borderAlpha: (card.a.borderOpacity === undefined ? .3 * root.alphaScale : card.a.borderOpacity) / root.alphaScale
                        borderWidth: card.a.borderWidth === undefined ? 1 : card.a.borderWidth
                        accent: root.hex(card.a.accent, "#c6acee")
                    }
                    scale: cardArea.pressed ? .97 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    text: (card.on ? "✓ " : "") + card.modelData.name
                    font.family: Tokens.font; font.pixelSize: Tokens.px(11); font.weight: card.on ? Font.Bold : Font.Normal
                    color: card.on ? Tokens.accent : Tokens.text2
                }
                MouseArea { id: cardArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen(card.modelData.values) }
            }
        }
    }
}
