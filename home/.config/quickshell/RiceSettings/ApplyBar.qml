pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Shared footer: status on the left, revert / rollback / apply on the right.
Rectangle {
    id: bar
    property bool dirty: false
    property bool busy: false
    property bool loaded: true
    property bool valid: true
    property bool canRestore: false
    property string status: ""
    property string error: ""
    property string revertText: "Сбросить"
    property string restoreText: "Откатить"
    property string applyText: "Применить"
    property bool showApply: true
    // live mode: every change reaches the screen right away; Apply is not needed
    property bool liveCapable: false
    readonly property bool live: liveCapable && Tokens.opt.liveApply !== false
    signal apply()
    signal revert()
    signal restore()
    readonly property bool failed: status.indexOf("Ошибка") === 0 || error.length > 0
    Layout.fillWidth: true
    implicitHeight: 52
    radius: Tokens.radius
    color: dirty ? Tokens.alpha(Tokens.accent, .09) : "transparent"
    border.width: dirty ? 1 : 0
    border.color: Tokens.alpha(Tokens.accent, .22)
    Behavior on color { ColorAnimation { duration: 160 } }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
        spacing: 8
        Rectangle {
            visible: bar.dirty || bar.failed
            Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4
            color: bar.failed ? Tokens.danger : Tokens.accent
        }
        Text {
            Layout.fillWidth: true
            text: bar.error || (bar.busy ? "Применяю…" : bar.dirty ? "Есть несохранённые изменения" : bar.status)
            elide: Text.ElideRight
            font.family: Tokens.font; font.pixelSize: Tokens.px(12)
            color: bar.failed ? Tokens.danger : bar.dirty ? Tokens.text : Tokens.text3
        }
        // "Вживую" switch
        Rectangle {
            visible: bar.liveCapable
            Layout.preferredHeight: 30; Layout.preferredWidth: liveRow.implicitWidth + 18
            radius: 15
            color: bar.live ? Tokens.alpha(Tokens.good, .16) : liveArea.containsMouse ? Tokens.controlHover : Tokens.control
            border.width: 1; border.color: bar.live ? Tokens.alpha(Tokens.good, .5) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
            Row {
                id: liveRow; anchors.centerIn: parent; spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 16; radius: 8
                    color: bar.live ? Tokens.good : Tokens.alpha(Tokens.text, .2)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        width: 12; height: 12; radius: 6; y: 2; color: "#ffffff"
                        x: bar.live ? parent.width - width - 2 : 2
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Вживую"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: bar.live ? Tokens.text : Tokens.text2 }
            }
            MouseArea { id: liveArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Tokens.set("liveApply", !bar.live) }
        }
        StyledButton { text: bar.revertText; flat: true; visible: bar.dirty; enabled: !bar.busy; onClicked: bar.revert() }
        StyledButton { text: bar.restoreText; flat: true; visible: bar.canRestore && !bar.dirty; enabled: !bar.busy; onClicked: bar.restore() }
        StyledButton { visible: bar.showApply && !(bar.live && !bar.dirty); text: bar.busy ? "Применяю…" : bar.applyText; primary: enabled; enabled: bar.loaded && bar.dirty && bar.valid && !bar.busy; onClicked: bar.apply() }
    }
}
