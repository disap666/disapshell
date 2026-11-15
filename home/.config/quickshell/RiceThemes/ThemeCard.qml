pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets

// A miniature desktop rendered in a preset's colours, over the real wallpaper:
// Waybar shape, a kitty window with the ANSI palette, a notification and the dock.
ClippingRectangle {
    id: card
    required property var preset
    property string wallpaper: ""
    property var apps: []
    readonly property var c: preset.colors
    readonly property var bar: preset.layout
    readonly property var dock: preset.deck
    readonly property var k: preset.kitty
    readonly property real s: width / 1920              // screen -> card scale
    readonly property bool glassy: bar.opacity < 60
    function a(col, alpha) { return Qt.alpha(col, alpha); }

    radius: 18
    color: c.background

    Image {
        anchors.fill: parent
        source: card.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 960
    }
    // Tint the wallpaper toward the theme so cards read as different moods.
    Rectangle { anchors.fill: parent; color: card.c.background; opacity: card.glassy ? .18 : .5 }

    // Waybar
    Row {
        id: barRow
        readonly property real m: Math.max(3, card.bar.margin * card.s * 1.6)
        x: m; y: m
        width: card.width - m * 2
        height: Math.max(12, card.bar.height * card.s * 1.5)
        spacing: card.bar.parts > 1 ? Math.max(4, card.bar.gap * card.s * 1.6) : 0
        Repeater {
            model: card.bar.parts
            Rectangle {
                id: part
                required property int index
                width: (barRow.width - barRow.spacing * (card.bar.parts - 1)) / card.bar.parts
                height: barRow.height
                radius: Math.min(height / 2, card.bar.radius * card.s * 1.6)
                gradient: Gradient {
                    GradientStop { position: 0; color: card.a(card.bar.gradient ? card.c.highlight : card.c.background, card.bar.opacity / 100) }
                    GradientStop { position: 1; color: card.a(card.c.background, card.bar.opacity / 100) }
                }
                border.width: 1; border.color: card.a(card.c.border, card.glassy ? .45 : .3)
                Row {
                    visible: part.index === 0
                    anchors.left: parent.left; anchors.leftMargin: parent.height * .5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater { model: 5; Rectangle { required property int index; width: index === 0 ? 12 : 5; height: 5; radius: 2.5; color: index === 0 ? card.c.accent : card.a(card.c.muted, .6) } }
                }
                Text {
                    visible: part.index === (card.bar.parts === 2 ? 1 : Math.floor((card.bar.parts - 1) / 2))
                    anchors.centerIn: parent
                    text: "14:30"
                    font.pixelSize: Math.max(8, parent.height * .5); font.weight: Font.DemiBold
                    color: card.c.foreground
                }
                Row {
                    visible: part.index === card.bar.parts - 1
                    anchors.right: parent.right; anchors.rightMargin: parent.height * .5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater { model: 3; Rectangle { width: 5; height: 5; radius: 2.5; color: card.a(card.c.foreground, .75) } }
                    Rectangle { width: 16; height: 7; radius: 3; color: card.c.accent }
                }
            }
        }
    }

    // kitty
    Rectangle {
        id: term
        x: card.width * .055
        y: barRow.y + barRow.height + card.height * .07
        width: card.width * .5; height: card.height * .52
        radius: Math.max(4, 14 * card.s * 1.4)
        color: card.a(card.k.background, Math.max(card.glassy ? .55 : .85, card.k.background_opacity * (card.glassy ? .8 : 1)))
        border.width: 2
        border.color: card.c.accent
        Column {
            anchors.fill: parent; anchors.margins: parent.width * .05
            spacing: parent.height * .045
            readonly property real fs: Math.max(7, term.height * .085)
            Text { text: "<span style='color:" + card.c.accent + "'>❯</span> fastfetch"; textFormat: Text.RichText; font.family: "JetBrains Mono"; font.pixelSize: parent.fs; color: card.k.foreground }
            Row {
                spacing: term.width * .04
                Rectangle { width: term.height * .32; height: width; radius: width / 2; color: "transparent"; border.width: 2; border.color: card.c.accent
                    Rectangle { anchors.centerIn: parent; width: parent.width * .45; height: width; radius: width / 2; color: card.c.border } }
                Column {
                    spacing: 2
                    Repeater {
                        model: [["os", "Arch Linux"], ["wm", "Hyprland"], ["theme", card.preset.name]]
                        Text {
                            required property var modelData
                            textFormat: Text.RichText
                            text: "<span style='color:" + card.c.accent + "'>" + modelData[0] + "</span> " + modelData[1]
                            font.family: "JetBrains Mono"; font.pixelSize: Math.max(6, term.height * .07); color: card.k.foreground
                        }
                    }
                }
            }
            Row {
                spacing: 0
                Repeater {
                    model: 8
                    Rectangle { required property int index; width: (term.width * .9) / 8; height: term.height * .09; color: card.k["color" + (index + 1 < 8 ? index + 1 : 8)] || card.c.accent }
                }
            }
            Text { text: "<span style='color:" + card.c.accent + "'>❯</span> <span style='background:" + card.k.cursor + "'>&nbsp;</span>"; textFormat: Text.RichText; font.family: "JetBrains Mono"; font.pixelSize: parent.fs; color: card.k.foreground }
        }
    }

    // side window / notification
    Rectangle {
        x: term.x + term.width + card.width * .035
        y: term.y
        width: card.width - x - card.width * .055
        height: term.height * .46
        radius: term.radius
        color: card.a(card.c.surface, card.glassy ? .55 : .94)
        border.width: 1; border.color: card.a(card.c.border, .35)
        Column {
            anchors.fill: parent; anchors.margins: parent.width * .08
            spacing: parent.height * .1
            Row {
                spacing: 6
                Rectangle { width: 14; height: 14; radius: 4; color: card.c.accent }
                Text { text: "Уведомление"; font.pixelSize: Math.max(7, card.height * .028); font.weight: Font.Medium; color: card.c.foreground; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle { width: parent.width * .9; height: 4; radius: 2; color: card.a(card.c.muted, .55) }
            Rectangle { width: parent.width * .6; height: 4; radius: 2; color: card.a(card.c.muted, .35) }
        }
    }
    Rectangle {
        x: term.x + term.width + card.width * .035
        y: term.y + term.height * .54
        width: card.width - x - card.width * .055
        height: term.height * .46
        radius: term.radius
        color: card.a(card.c.background, card.glassy ? .45 : .92)
        border.width: 1; border.color: card.a(card.c.border, .25)
        Row {
            anchors.centerIn: parent
            spacing: parent.width * .05
            Repeater {
                model: ["background", "surface", "muted", "foreground", "accent", "border"]
                Rectangle { required property string modelData; width: Math.max(8, parent.parent.height * .2); height: width; radius: width / 2; color: card.c[modelData]; border.width: 1; border.color: card.a("#ffffff", .2) }
            }
        }
    }

    // Dock
    Row {
        id: dockRow
        readonly property int count: Math.max(4, Math.min(7, card.apps.length || 6))
        readonly property real tile: Math.max(12, card.height * .07)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: card.height * .035
        spacing: card.dock.parts > 1 ? Math.max(4, card.dock.gap * card.s * 2) : 0
        Repeater {
            model: card.dock.parts
            Rectangle {
                id: dockPart
                required property int index
                readonly property int share: Math.ceil(dockRow.count / card.dock.parts)
                readonly property int first: index * share
                readonly property int n: Math.max(0, Math.min(share, dockRow.count - first))
                width: n * dockRow.tile + (n + 1) * dockRow.tile * .35
                height: dockRow.tile * 1.7
                radius: Math.min(height / 2, card.dock.radius * card.s * 2)
                color: card.a(card.c.background, card.dock.opacity)
                border.width: 1; border.color: card.a(card.c.border, .4)
                Row {
                    anchors.centerIn: parent
                    spacing: dockRow.tile * .35
                    Repeater {
                        model: dockPart.n
                        Item {
                            required property int index
                            readonly property var app: card.apps[dockPart.first + index]
                            width: dockRow.tile; height: dockRow.tile
                            IconImage {
                                anchors.fill: parent
                                visible: !!parent.app
                                source: parent.app ? Quickshell.iconPath(parent.app.icon, "application-x-executable") : ""
                            }
                            Rectangle { anchors.fill: parent; visible: !parent.app; radius: 4; color: card.c.accent; opacity: .8 }
                        }
                    }
                }
            }
        }
    }
}
