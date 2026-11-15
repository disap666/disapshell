pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// primary: filled accent, flat: no fill until hover, default: quiet tinted
C.Button {
    id: control
    property bool primary: false
    implicitHeight: Tokens.controlHeight
    implicitWidth: Math.max(Tokens.controlHeight, contentItem.implicitWidth + 24)
    hoverEnabled: true
    font.family: Tokens.font
    font.pixelSize: Tokens.px(12)
    font.weight: primary ? Font.DemiBold : Font.Normal
    opacity: enabled ? 1 : .42
    contentItem: Text {
        text: control.text; font: control.font
        color: control.primary ? Tokens.onAccent : control.highlighted ? Tokens.text : Tokens.text
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Tokens.controlRadius
        color: control.primary
            ? (control.down ? Qt.darker(Tokens.accent, 1.12) : control.hovered ? Qt.lighter(Tokens.accent, 1.06) : Tokens.accent)
            : control.down ? Tokens.controlDown
            : (control.hovered || control.highlighted) ? Tokens.controlHover
            : control.flat ? "transparent" : Tokens.control
        border.width: control.visualFocus ? 2 : 0
        border.color: Tokens.alpha(Tokens.accent, .7)
        Behavior on color { ColorAnimation { duration: 90 } }
    }
}
