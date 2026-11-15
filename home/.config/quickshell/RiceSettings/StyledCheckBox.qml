pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// Rendered as a switch: settings are on/off states, not form ticks.
C.CheckBox {
    id: control
    implicitHeight: Math.max(28, contentItem.implicitHeight + 4)
    implicitWidth: indicator.width + (text ? spacing + contentItem.implicitWidth : 0) + leftPadding + rightPadding
    padding: 0
    spacing: 10
    hoverEnabled: true
    font.family: Tokens.font; font.pixelSize: Tokens.px(13)
    opacity: enabled ? 1 : .42
    indicator: Rectangle {
        implicitWidth: 38; implicitHeight: 22
        x: control.leftPadding; y: (control.height - height) / 2
        radius: height / 2
        color: control.checked ? Tokens.accent : control.hovered ? Tokens.controlHover : Tokens.control
        border.width: control.visualFocus ? 2 : 0
        border.color: Tokens.alpha(Tokens.text, .6)
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3
            x: control.checked ? parent.width - width - 3 : 3
            color: control.checked ? Tokens.onAccent : Tokens.text2
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        text: control.text; font: control.font; color: Tokens.text
        leftPadding: control.text ? control.indicator.width + control.spacing : control.indicator.width
        verticalAlignment: Text.AlignVCenter; wrapMode: Text.Wrap
    }
}
