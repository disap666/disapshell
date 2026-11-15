pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Live dock replica: drag icons to reorder, drag one down out of the dock to unpin.
ClippingRectangle {
    id: root
    required property var page
    property string wallpaper: ""
    readonly property var apps: page.settings.apps || []
    readonly property var s: page.settings
    property int dragIndex: -1
    property int dropIndex: -1
    property bool outside: false
    property point pointer: Qt.point(0, 0)
    implicitHeight: 170
    radius: Tokens.radius
    color: "#14121c"

    function hex(v, f) { return /^#[0-9a-fA-F]{6}$/.test(v || "") ? v : f; }
    function finish() {
        var from = dragIndex, to = dropIndex, out = outside;
        dragIndex = -1; dropIndex = -1; outside = false;
        if (from < 0) return;
        var list = apps.slice();
        if (out) { list.splice(from, 1); page.set("apps", list); return; }
        if (to < 0 || to === from || to === from + 1) return;
        var item = list.splice(from, 1)[0];
        list.splice(to > from ? to - 1 : to, 0, item);
        page.set("apps", list);
    }
    function track(item, mx, my) {
        pointer = item.mapToItem(root, mx, my);
        var local = icons.mapFromItem(root, pointer.x, pointer.y);
        outside = local.y > icons.height + 46 || local.y < -60;
        var idx = rep.count;
        for (var i = 0; i < rep.count; i++) { var it = rep.itemAt(i); if (local.x < it.x + it.width / 2) { idx = i; break; } }
        dropIndex = idx;
    }

    Image { anchors.fill: parent; source: root.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1200; verticalAlignment: Image.AlignBottom }
    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#90000000" } GradientStop { position: 1; color: "#20000000" } } }
    Text {
        x: 16; y: 14
        text: root.dragIndex >= 0 ? (root.outside ? "Открепить" : "") : ""
        font.family: Tokens.font; font.pixelSize: 12; color: root.outside ? Tokens.danger : "#d0ffffff"
    }

    Rectangle {
        id: dockSurface
        readonly property real k: Math.min(1.2, root.s.scale || 1.25)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        width: icons.width + 28; height: 46 * k + 14
        radius: Math.min(height / 2, (root.s.radius === undefined ? 18 : root.s.radius))
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.s.gradient ? root.hex(root.s.highlight, "#493957") : root.hex(root.s.background, "#201a2d"), root.s.opacity === undefined ? .86 : root.s.opacity) }
            GradientStop { position: 1; color: Qt.alpha(root.hex(root.s.background, "#201a2d"), root.s.opacity === undefined ? .86 : root.s.opacity) }
        }
        border.width: root.s.borderWidth === undefined ? 1 : root.s.borderWidth
        border.color: Qt.alpha(root.hex(root.s.border, "#d8c0f2"), root.s.borderOpacity === undefined ? .5 : root.s.borderOpacity)
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            id: icons
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                id: rep
                model: root.apps
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool lifted: root.dragIndex === index
                    readonly property bool gapBefore: root.dragIndex >= 0 && !root.outside && root.dropIndex === index && index !== root.dragIndex && index !== root.dragIndex + 1
                    width: 46 * dockSurface.k + (gapBefore ? 26 : 0)
                    height: 46 * dockSurface.k
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Rectangle {
                        anchors.right: parent.right
                        width: 46 * dockSurface.k; height: parent.height
                        radius: root.s.iconRadius === undefined ? 13 : root.s.iconRadius
                        color: mouse.containsMouse ? Qt.alpha("#ffffff", .14) : Qt.alpha("#ffffff", .05)
                        opacity: tile.lifted ? .25 : 1
                        scale: mouse.containsMouse && root.dragIndex < 0 ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        IconImage { anchors.centerIn: parent; implicitSize: parent.width * .68; source: Quickshell.iconPath(tile.modelData.icon, "application-x-executable") }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true; preventStealing: true
                        cursorShape: root.dragIndex >= 0 ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point origin
                        onPressed: m => origin = Qt.point(m.x, m.y)
                        onPositionChanged: m => {
                            if (!pressed) return;
                            if (root.dragIndex < 0 && Math.abs(m.x - origin.x) + Math.abs(m.y - origin.y) > 6) root.dragIndex = tile.index;
                            if (root.dragIndex >= 0) root.track(mouse, m.x, m.y);
                        }
                        onReleased: root.finish()
                        ToolTip.visible: containsMouse && root.dragIndex < 0
                        ToolTip.delay: 400
                        ToolTip.text: tile.modelData.name
                    }
                }
            }
            Item {
                visible: root.dragIndex >= 0 && !root.outside && root.dropIndex === rep.count
                width: 26; height: 1
            }
        }
    }
    // ghost
    Item {
        visible: root.dragIndex >= 0
        x: root.pointer.x - width / 2; y: root.pointer.y - height / 2
        width: 56; height: 56
        scale: root.outside ? .85 : 1.12
        opacity: root.outside ? .55 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        Rectangle { anchors.fill: parent; radius: 14; color: Qt.alpha("#000000", .35); border.width: 2; border.color: root.outside ? Tokens.danger : Tokens.accent }
        IconImage { anchors.centerIn: parent; implicitSize: 38; source: root.dragIndex >= 0 && root.apps[root.dragIndex] ? Quickshell.iconPath(root.apps[root.dragIndex].icon, "application-x-executable") : "" }
    }
}
