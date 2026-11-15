pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

RowLayout {
    id: preview
    property string kind: "waybar"
    property var configuration: ({})
    property var appearance: ({})
    readonly property bool dock: kind === "deck"
    readonly property real screenWidth: Quickshell.screens.length ? Quickshell.screens[0].width : 1920
    readonly property real screenHeight: Quickshell.screens.length ? Quickshell.screens[0].height : 1080
    readonly property string position: dock ? "bottom" : (configuration.position || "top")
    readonly property bool vertical: position === "left" || position === "right"
    readonly property int parts: dock ? (appearance.parts || 1) : (appearance.layout || 3)
    readonly property int radius: appearance.radius || 0
    readonly property real gap: appearance.gap === undefined ? 12 : appearance.gap
    readonly property real topMargin: dock ? 0 : (configuration["margin-top"] || 0)
    readonly property real bottomMargin: dock ? (appearance.bottomMargin || 0) : (configuration["margin-bottom"] || 0)
    readonly property real leftMargin: dock ? 0 : (configuration["margin-left"] || 0)
    readonly property real rightMargin: dock ? 0 : (configuration["margin-right"] || 0)
    readonly property color background: validColor(appearance.background, "#201a2d")
    readonly property color foreground: validColor(appearance.accent, "#c6acee")
    readonly property color highlight: validColor(appearance.highlight, "#493957")
    readonly property color borderColor: validColor(appearance.border, "#d8c0f2")
    readonly property real borderAlpha: appearance.borderOpacity === undefined ? .5 : dock ? appearance.borderOpacity : appearance.borderOpacity / 100
    readonly property real alpha: appearance.opacity === undefined ? .9 : dock ? appearance.opacity : appearance.opacity / 100
    readonly property real dockScale: appearance.scale || 1.25
    readonly property int appCount: (appearance.apps || []).length + (appearance.showLauncher ? 1 : 0)
    function validColor(value, fallback) { return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback; }
    spacing: 18
    Layout.fillWidth: true
    Rectangle {
        id: monitor
        Layout.preferredHeight: 128
        Layout.preferredWidth: 128 * preview.screenWidth / preview.screenHeight
        radius: 8; clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: "#26344a" }
            GradientStop { position: 1; color: "#171521" }
        }
        border.width: 1; border.color: Tokens.line
        readonly property real sx: width / preview.screenWidth
        readonly property real sy: height / preview.screenHeight
        Rectangle { x: parent.width*.16; y: parent.height*.25; width: parent.width*.4; height: parent.height*.48; radius: 4; color: "#2537455d"; border.width: 1; border.color: "#304f5b73" }
        Item {
            id: panel
            readonly property real actualWidth: preview.dock
                ? Math.min(preview.screenWidth-26,Math.max(56,preview.appCount*60 + preview.parts*(preview.appearance.padding || 0)*2)*preview.dockScale + (preview.parts-1)*preview.gap)
                : (preview.configuration.width || (preview.vertical ? 40 : preview.screenWidth-preview.leftMargin-preview.rightMargin))
            readonly property real actualHeight: preview.dock ? 68*preview.dockScale
                : (preview.configuration.height || (preview.vertical ? preview.screenHeight-preview.topMargin-preview.bottomMargin : 40))
            width: Math.max(3,Math.min(monitor.width,actualWidth*monitor.sx))
            height: Math.max(3,Math.min(monitor.height,actualHeight*monitor.sy))
            x: preview.dock && preview.appearance.alignment === "left" ? 2
                : preview.dock && preview.appearance.alignment === "right" ? monitor.width-width-2
                : preview.position === "left" ? preview.leftMargin*monitor.sx
                : preview.position === "right" ? monitor.width-width-preview.rightMargin*monitor.sx
                : (monitor.width-width+(preview.leftMargin-preview.rightMargin)*monitor.sx)/2
            y: preview.position === "bottom" ? monitor.height-height-preview.bottomMargin*monitor.sy
                : preview.vertical ? (monitor.height-height+(preview.topMargin-preview.bottomMargin)*monitor.sy)/2 : preview.topMargin*monitor.sy
            Repeater {
                model: preview.parts
                Rectangle {
                    required property int index
                    readonly property real distance: Math.max(preview.parts===1 ? 0 : 2,preview.gap*(preview.vertical ? monitor.sy : monitor.sx))
                    width: preview.vertical ? panel.width : Math.max(2,(panel.width-distance*(preview.parts-1))/preview.parts)
                    height: preview.vertical ? Math.max(2,(panel.height-distance*(preview.parts-1))/preview.parts) : panel.height
                    x: preview.vertical ? 0 : index*(width+distance)
                    y: preview.vertical ? index*(height+distance) : 0
                    radius: Math.min(width/2,height/2,preview.radius*monitor.sx)
                    color: Qt.rgba(preview.background.r,preview.background.g,preview.background.b,preview.alpha)
                    gradient: Gradient {
                        GradientStop { position: 0; color: preview.appearance.gradient ? Qt.rgba(preview.highlight.r,preview.highlight.g,preview.highlight.b,preview.alpha) : Qt.rgba(preview.background.r,preview.background.g,preview.background.b,preview.alpha) }
                        GradientStop { position: 1; color: Qt.rgba(preview.background.r,preview.background.g,preview.background.b,preview.alpha) }
                    }
                    border.width: preview.appearance.borderWidth === 0 ? 0 : .7
                    border.color: Qt.rgba(preview.borderColor.r,preview.borderColor.g,preview.borderColor.b,preview.borderAlpha)
                    Row {
                        anchors.centerIn: parent; spacing: 2
                        visible: !preview.vertical
                        Repeater { model: preview.dock ? Math.max(1,Math.ceil(preview.appCount/preview.parts)) : 3
                            Rectangle { width: preview.dock ? 3 : 2; height: preview.dock ? 4 : 1; radius: preview.radius===0 ? 0 : 1; color: preview.foreground }
                        }
                    }
                }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 8
        Text { font.family: Rice.Theme.fontFamily; text: "Предпросмотр"; color: Tokens.text; font.pixelSize: Tokens.px(13); font.weight: Font.Medium }
        Text { font.family: Rice.Theme.fontFamily;
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: ({top:"Сверху",bottom:"Снизу",left:"Слева",right:"Справа"})[preview.position] + " · " + preview.parts + (preview.parts===1 ? " цельный блок" : " части") + "\n" + (preview.radius===0 ? "Квадратные края" : "Скругление: "+preview.radius+" px")
            color: Tokens.text2; font.pixelSize: Tokens.px(12)
        }
    }
}
