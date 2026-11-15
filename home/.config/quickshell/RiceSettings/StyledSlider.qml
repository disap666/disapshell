pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

C.Slider {
    id: control
    implicitHeight: 28; implicitWidth: 200
    hoverEnabled: true
    opacity: enabled ? 1 : .42
    background: Rectangle {
        x: control.leftPadding; y: (control.height - height) / 2
        width: control.availableWidth; height: 4; radius: 2; color: Tokens.control
        Rectangle { width: control.visualPosition * parent.width; height: parent.height; radius: 2; color: Tokens.accent }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: (control.height - height) / 2
        implicitWidth: 18; implicitHeight: 18; radius: 9
        color: Tokens.text
        border.width: control.visualFocus ? 3 : 0; border.color: Tokens.accent
        scale: control.pressed ? 1.12 : control.hovered ? 1.05 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
}
