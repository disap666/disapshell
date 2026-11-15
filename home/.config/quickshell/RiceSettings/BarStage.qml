pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Effects
import QtQuick.Controls as C
import Quickshell
import Quickshell.Widgets

// Big interactive preview for the bar (kind "waybar") and the dock (kind "deck").
// Heights, radii, paddings and fonts are drawn 1:1; only the length is fitted to the stage.
//   - drag the handles: corner radius, height / size, gap between parts
//   - click a surface: opens the colour picker for exactly that colour
Rectangle {
    id: stage
    property string kind: "waybar"
    property var appearance: ({})
    property var configuration: ({})
    property string wallpaper: ""
    property bool live: false
    signal appearanceEdited(string key, var value)
    signal configEdited(string key, var value)

    readonly property bool dock: kind === "deck"
    readonly property var a: appearance || {}
    readonly property var c: configuration || {}
    function hex(v, f) { return /^#[0-9a-fA-F]{6}$/.test(v || "") ? v : f; }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Math.round(v))); }

    // shared look
    readonly property int parts: Math.max(1, dock ? (a.parts || 1) : (a.layout || 3))
    readonly property real shapeRadius: a.radius === undefined ? (dock ? 24 : 20) : a.radius
    readonly property real gap: a.gap === undefined ? 12 : a.gap
    readonly property real alpha: a.opacity === undefined ? .82 : dock ? a.opacity : a.opacity / 100
    readonly property real borderAlpha: a.borderOpacity === undefined ? .34 : dock ? a.borderOpacity : a.borderOpacity / 100
    readonly property real borderWidth: a.borderWidth === undefined ? 1 : a.borderWidth
    readonly property color bg: hex(a.background, "#201a2d")
    readonly property color hi: hex(a.highlight, "#493957")
    readonly property color fg: hex(a.foreground, "#eee3fa")
    readonly property color accentColor: hex(a.accent, "#c6acee")
    readonly property color borderColor: hex(a.border, "#d8c0f2")
    readonly property string fontFamily: a.font || Rice.Theme.fontFamily
    readonly property real fontSize: a.fontSize || 12
    readonly property real padding: a.padding === undefined ? 8 : a.padding

    // waybar geometry
    readonly property string position: dock ? "bottom" : (c.position || "top")
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real barThickness: vertical ? Math.max(24, Math.min(140, c.width || 44)) : Math.max(18, Math.min(120, c.height || Math.round(fontSize + padding * 2 + 12)))
    readonly property real mTop: Math.min(36, c["margin-top"] || 0)
    readonly property real mBottom: Math.min(36, c["margin-bottom"] || 0)
    readonly property real mLeft: Math.min(80, c["margin-left"] || 0)
    readonly property real mRight: Math.min(80, c["margin-right"] || 0)

    // dock geometry
    readonly property var apps: (a.showLauncher !== false ? [{ launcher: true }] : []).concat(a.apps || [])
    readonly property real dockScaleWanted: a.scale || 1.25
    readonly property real dockScale: Math.min(dockScaleWanted, 1.6)

    property string hover: ""

    implicitHeight: dock ? 210 : (vertical ? 230 : 168)
    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    radius: Tokens.radius
    color: "#14161d"
    clip: true
    border.width: 1; border.color: Tokens.line

    Image {
        anchors.fill: parent; anchors.margins: 1
        source: stage.wallpaper; fillMode: Image.PreserveAspectCrop
        asynchronous: true; sourceSize.width: 1200; opacity: .95
    }
    Rectangle { anchors.fill: parent; radius: Tokens.radius; color: "#000000"; opacity: .18 }
    // a window to show what the bar sits next to
    Rectangle {
        visible: !stage.dock
        x: stage.vertical ? stage.width * .3 : stage.width * .22
        y: stage.position === "bottom" ? 14 : stage.vertical ? 30 : stage.barThickness + stage.mTop + 16
        width: stage.width * .45; height: stage.height - y - (stage.position === "bottom" ? stage.barThickness + stage.mBottom + 16 : 14)
        radius: 10; color: "#22000000"; border.width: 1; border.color: "#24ffffff"
    }

    // colour picking from the preview
    ColorPopover { id: picker; property string key: ""; onPicked: h => stage.appearanceEdited(key, h) }
    function pick(key, title, item, mx, my) {
        var p = item.mapToItem(stage, mx, my);
        picker.key = key; picker.title = title;
        picker.load(hex(a[key], "#c6acee"));
        picker.x = Math.max(8, Math.min(stage.width - picker.width - 8, p.x - picker.width / 2));
        picker.y = p.y + 14;
        picker.open();
    }

    // reusable drag handle
    component Handle: Rectangle {
        id: h
        property string tip: ""
        property real startValue: 0
        property real dx: 0
        property real dy: 0
        property bool dragging: dragArea.pressed
        property int cursor: Qt.SizeAllCursor
        signal begin()
        signal moved(real dx, real dy)
        width: 14; height: 14; radius: 7; z: 50
        color: dragging ? Tokens.accent : "#ffffff"
        border.width: 2; border.color: Tokens.accent
        opacity: stageHover.hovered || dragging ? 1 : 0
        scale: dragging ? 1.3 : dragArea.containsMouse ? 1.15 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
        Rectangle {
            visible: h.dragging || dragArea.containsMouse
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: 6
            width: tipText.implicitWidth + 12; height: 20; radius: 5; color: "#e6111318"
            Text { id: tipText; anchors.centerIn: parent; text: h.tip; color: "#ffffff"; font.family: Tokens.font; font.pixelSize: 11 }
        }
        MouseArea {
            id: dragArea
            anchors.fill: parent; anchors.margins: -6
            hoverEnabled: true; preventStealing: true; cursorShape: h.cursor
            property point origin
            onPressed: m => { origin = mapToItem(stage, m.x, m.y); h.begin(); }
            onPositionChanged: m => { if (!pressed) return; var p = mapToItem(stage, m.x, m.y); h.moved(p.x - origin.x, p.y - origin.y); }
        }
    }

    HoverHandler { id: stageHover }

    // WAYBAR
    Item {
        id: barArea
        visible: !stage.dock
        x: stage.position === "right" ? stage.width - width - stage.mRight - 14 : stage.position === "left" ? stage.mLeft + 14 : stage.mLeft + 14
        y: stage.position === "bottom" ? stage.height - height - stage.mBottom - 12 : stage.vertical ? 14 : stage.mTop + 12
        width: stage.vertical ? stage.barThickness : stage.width - 28 - stage.mLeft - stage.mRight
        height: stage.vertical ? stage.height - 28 : stage.barThickness

        // module distribution per number of parts
        readonly property var layout: [
            [["ws", "title", "clock", "tray"]],
            [["ws", "title"], ["clock", "tray"]],
            [["ws", "title"], ["clock"], ["tray"]],
            [["ws"], ["title"], ["clock"], ["tray"]]
        ][Math.min(4, stage.parts) - 1]
        readonly property real partLen: ((stage.vertical ? height : width) - stage.gap * (stage.parts - 1)) / stage.parts

        Repeater {
            model: barArea.layout
            Rectangle {
                id: part
                required property var modelData
                required property int index
                x: stage.vertical ? 0 : index * (barArea.partLen + stage.gap)
                y: stage.vertical ? index * (barArea.partLen + stage.gap) : 0
                width: stage.vertical ? barArea.width : Math.max(8, barArea.partLen)
                height: stage.vertical ? Math.max(8, barArea.partLen) : barArea.height
                radius: Math.min(width / 2, height / 2, stage.shapeRadius)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(stage.a.gradient ? stage.hi : stage.bg, stage.alpha) }
                    GradientStop { position: 1; color: Qt.alpha(stage.bg, stage.alpha) }
                }
                border.width: stage.borderWidth; border.color: Qt.alpha(stage.borderColor, stage.borderAlpha)
                Behavior on x { enabled: !gapHandle.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: !gapHandle.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: stage.hover = "Клик: цвет фона"; onExited: stage.hover = ""
                    onClicked: m => stage.pick(m.modifiers & Qt.ShiftModifier ? "highlight" : "background", m.modifiers & Qt.ShiftModifier ? "Верх градиента" : "Фон панели", part, m.x, m.y)
                }

                // contents
                Grid {
                    anchors.centerIn: parent
                    columns: stage.vertical ? 1 : 99
                    columnSpacing: Math.max(10, stage.padding * 2); rowSpacing: 8
                    verticalItemAlignment: Grid.AlignVCenter; horizontalItemAlignment: Grid.AlignHCenter
                    Repeater {
                        model: part.modelData
                        Loader {
                            required property string modelData
                            sourceComponent: modelData === "ws" ? wsAtom : modelData === "title" ? titleAtom : modelData === "clock" ? clockAtom : trayAtom
                        }
                    }
                }
            }
        }

        // radius on the first part's corner
        Handle {
            id: radiusHandle
            readonly property real r: Math.min(stage.shapeRadius, barArea.height / 2, (stage.vertical ? barArea.width : barArea.partLen) / 2)
            x: r * .3 - width / 2 + 3; y: r * .3 - height / 2 + 3
            tip: "Скругление " + Math.round(stage.shapeRadius) + " px"
            cursor: Qt.SizeFDiagCursor
            onBegin: startValue = stage.shapeRadius
            onMoved: (dx, dy) => stage.appearanceEdited("radius", stage.clamp(startValue + (dx + dy) / 1.4, 0, 60))
        }
        // gap between first two parts
        Handle {
            id: gapHandle
            visible: stage.parts > 1
            x: stage.vertical ? (barArea.width - width) / 2 : barArea.partLen + stage.gap / 2 - width / 2
            y: stage.vertical ? barArea.partLen + stage.gap / 2 - height / 2 : (barArea.height - height) / 2
            tip: "Промежуток " + Math.round(stage.gap) + " px"
            cursor: stage.vertical ? Qt.SizeVerCursor : Qt.SizeHorCursor
            onBegin: startValue = stage.gap
            onMoved: (dx, dy) => stage.appearanceEdited("gap", stage.clamp(startValue + (stage.vertical ? dy : dx) * stage.parts / Math.max(1, stage.parts - 1), 0, 100))
        }
        // thickness on the inner edge
        Handle {
            id: sizeHandle
            width: stage.vertical ? 10 : 34; height: stage.vertical ? 34 : 10; radius: 5
            x: stage.vertical ? (stage.position === "left" ? barArea.width - width / 2 : -width / 2) : (barArea.width - width) / 2
            y: stage.vertical ? (barArea.height - height) / 2 : (stage.position === "bottom" ? -height / 2 : barArea.height - height / 2)
            tip: (stage.vertical ? "Ширина " : "Высота ") + Math.round(stage.barThickness) + " px"
            cursor: stage.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onBegin: startValue = stage.barThickness
            onMoved: (dx, dy) => {
                var d = stage.vertical ? (stage.position === "left" ? dx : -dx) : (stage.position === "bottom" ? -dy : dy);
                stage.configEdited(stage.vertical ? "width" : "height", stage.clamp(startValue + d, stage.vertical ? 24 : 18, stage.vertical ? 140 : 120));
            }
        }
    }

    // waybar atoms
    component Clicky: MouseArea {
        id: ck
        property string key
        property string title
        anchors.fill: parent; anchors.margins: -3
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: stage.hover = "Клик: " + title.toLowerCase(); onExited: stage.hover = ""
        onClicked: m => stage.pick(ck.key, ck.title, ck, m.x, m.y)
    }
    Component {
        id: wsAtom
        Grid {
            columns: stage.vertical ? 1 : 4; spacing: Math.max(4, stage.fontSize * .4)
            verticalItemAlignment: Grid.AlignVCenter; horizontalItemAlignment: Grid.AlignHCenter
            Repeater {
                model: 4
                Rectangle {
                    id: wsDot
                    required property int index
                    readonly property bool active: index === 0
                    width: stage.vertical ? stage.fontSize * .6 : (wsDot.active ? stage.fontSize * 1.8 : stage.fontSize * .6)
                    height: stage.vertical ? (wsDot.active ? stage.fontSize * 1.8 : stage.fontSize * .6) : stage.fontSize * .6
                    radius: Math.min(width, height) / 2
                    color: wsDot.active ? stage.accentColor : Qt.alpha(stage.fg, .45)
                    Clicky { key: wsDot.active ? "accent" : "foreground"; title: wsDot.active ? "Акцент" : "Текст и значки" }
                }
            }
        }
    }
    Component {
        id: titleAtom
        Text {
            visible: !stage.vertical
            text: "kitty  ~/rice"; color: Qt.alpha(stage.fg, .8)
            font.family: stage.fontFamily; font.pixelSize: stage.fontSize
            Clicky { key: "foreground"; title: "Текст и значки" }
        }
    }
    Component {
        id: clockAtom
        Text {
            text: stage.vertical ? "12\n30" : "12:30"; horizontalAlignment: Text.AlignHCenter
            color: stage.fg
            font.family: stage.fontFamily; font.pixelSize: stage.fontSize; font.weight: Font.Bold
            Clicky { key: "foreground"; title: "Текст и значки" }
        }
    }
    Component {
        id: trayAtom
        Text {
            text: stage.vertical ? "󰖩\n󰕾\n󰁹" : "󰖩   󰕾   󰁹 87%"; horizontalAlignment: Text.AlignHCenter
            color: stage.fg
            font.family: stage.fontFamily; font.pixelSize: stage.fontSize
            Clicky { key: "foreground"; title: "Текст и значки" }
        }
    }

    // DOCK
    Item {
        id: dockArea
        visible: stage.dock
        readonly property int per: Math.max(1, Math.ceil(stage.apps.length / stage.parts))
        readonly property real s: stage.dockScale
        readonly property real tile: 56 * s
        readonly property real islandH: 68 * s
        width: dockRow.width; height: islandH
        x: stage.a.alignment === "left" ? 14 : stage.a.alignment === "right" ? stage.width - width - 14 : (stage.width - width) / 2
        y: stage.height - height - Math.min(40, stage.a.bottomMargin || 0) - 14
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            id: dockRow
            spacing: stage.gap
            Repeater {
                model: stage.parts
                Rectangle {
                    id: island
                    required property int index
                    readonly property var items: stage.apps.slice(index * dockArea.per, (index + 1) * dockArea.per)
                    width: Math.max(dockArea.tile, items.length * dockArea.tile) + stage.padding * 2 * dockArea.s
                    height: dockArea.islandH
                    radius: Math.min(height / 2, stage.shapeRadius)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(stage.a.gradient ? stage.hi : stage.bg, stage.alpha) }
                        GradientStop { position: 1; color: Qt.alpha(stage.bg, stage.alpha) }
                    }
                    border.width: stage.borderWidth; border.color: Qt.alpha(stage.borderColor, stage.borderAlpha)
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: stage.hover = "Клик: цвет фона"; onExited: stage.hover = ""
                        onClicked: m => stage.pick(m.modifiers & Qt.ShiftModifier ? "highlight" : "background", m.modifiers & Qt.ShiftModifier ? "Верх градиента" : "Фон дока", island, m.x, m.y)
                    }
                    Row {
                        anchors.centerIn: parent
                        Repeater {
                            model: island.items
                            Item {
                                id: dt
                                required property var modelData
                                width: dockArea.tile; height: dockArea.islandH
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 50 * dockArea.s; height: width
                                    radius: stage.shapeRadius === 0 ? 0 : (stage.a.iconRadius === undefined ? 14 : stage.a.iconRadius) * dockArea.s
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Qt.alpha(stage.accentColor, .25) }
                                        GradientStop { position: 1; color: Qt.alpha(stage.bg, .75) }
                                    }
                                    border.width: 1; border.color: Qt.alpha(stage.borderColor, .4)
                                    IconImage {
                                        visible: !dt.modelData.launcher
                                        anchors.centerIn: parent; implicitSize: 35 * dockArea.s
                                        source: dt.modelData.launcher ? "" : Quickshell.iconPath(dt.modelData.icon || "", "application-x-executable")
                                        layer.enabled: stage.a.tintIcons !== false
                                        layer.effect: MultiEffect { colorization: 1; colorizationColor: stage.accentColor; brightness: .08; saturation: -.35 }
                                    }
                                    Grid {
                                        visible: !!dt.modelData.launcher
                                        anchors.centerIn: parent
                                        columns: 3; spacing: 4 * dockArea.s
                                        Repeater { model: 9; Rectangle { width: 5 * dockArea.s; height: width; radius: stage.shapeRadius === 0 ? 0 : 1; color: stage.accentColor } }
                                    }
                                    Clicky { key: "accent"; title: "Иконки и акценты" }
                                }
                            }
                        }
                    }
                }
            }
        }

        Handle {
            readonly property real r: Math.min(stage.shapeRadius, dockArea.islandH / 2)
            x: r * .3 - width / 2 + 3; y: r * .3 - height / 2 + 3
            tip: "Скругление " + Math.round(stage.shapeRadius) + " px"
            cursor: Qt.SizeFDiagCursor
            onBegin: startValue = stage.shapeRadius
            onMoved: (dx, dy) => stage.appearanceEdited("radius", stage.clamp(startValue + (dx + dy) / 1.4, 0, 40))
        }
        Handle {
            id: dockGap
            visible: stage.parts > 1
            x: (dockRow.children.length > 0 ? dockRow.children[0].width : 0) + stage.gap / 2 - width / 2
            y: (dockArea.islandH - height) / 2
            tip: "Промежуток " + Math.round(stage.gap) + " px"
            cursor: Qt.SizeHorCursor
            onBegin: startValue = stage.gap
            onMoved: (dx, dy) => stage.appearanceEdited("gap", stage.clamp(startValue + dx, 0, 60))
        }
        Handle {
            width: 34; height: 10; radius: 5
            x: (dockArea.width - width) / 2; y: -height / 2
            tip: "Размер " + Math.round(stage.dockScaleWanted * 100) + "%"
            cursor: Qt.SizeVerCursor
            onBegin: startValue = stage.dockScaleWanted
            onMoved: (dx, dy) => stage.appearanceEdited("scale", Math.max(.7, Math.min(1.8, Math.round((startValue - dy / 68) * 20) / 20)))
        }
    }

    // overlays: hint (left) + live badge (right), on the side away from the bar
    Item {
        id: overlayRow
        readonly property bool atTop: stage.dock || stage.position === "bottom"
        x: 10; width: parent.width - 20; height: 24
        y: atTop ? 10 : parent.height - height - 10
        Rectangle {
            anchors.right: parent.right
            width: badge.implicitWidth + 20; height: 24; radius: 12
            color: stage.live ? "#cc1d6b45" : "#cc2a2d38"
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                id: badge; anchors.centerIn: parent
                text: stage.live ? "Вживую" : "Черновик"
                color: "#ffffff"; font.family: Tokens.font; font.pixelSize: 11
            }
        }
        Rectangle {
            anchors.left: parent.left
            width: Math.min(parent.width - badge.implicitWidth - 34, hintText.implicitWidth + 20); height: 24; radius: 12
            color: "#b3111318"
            opacity: stageHover.hovered && stage.hover ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Text {
                id: hintText; anchors.centerIn: parent; width: parent.width - 20; elide: Text.ElideRight
                text: stage.hover
                color: "#ffffff"; font.family: Tokens.font; font.pixelSize: 11
            }
        }
    }
}
