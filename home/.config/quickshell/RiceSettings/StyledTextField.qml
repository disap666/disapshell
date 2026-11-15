pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

C.TextField {
    id: control
    implicitHeight: Tokens.controlHeight
    leftPadding: 11; rightPadding: 11
    hoverEnabled: true
    font.family: Tokens.font; font.pixelSize: Tokens.px(12)
    color: Tokens.text; placeholderTextColor: Tokens.text3
    selectionColor: Tokens.alpha(Tokens.accent, .45); selectedTextColor: Tokens.text
    selectByMouse: true
    opacity: enabled ? 1 : .42
    background: Rectangle {
        radius: Tokens.controlRadius
        color: control.activeFocus ? Tokens.well : control.hovered ? Tokens.controlHover : Tokens.control
        border.width: control.activeFocus ? 2 : 0; border.color: Tokens.alpha(Tokens.accent, .7)
    }
}
