pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

C.SpinBox {
    id: control
    implicitWidth: 118; implicitHeight: Tokens.controlHeight
    leftPadding: 30; rightPadding: 30
    hoverEnabled: true
    font.family: Tokens.font; font.pixelSize: Tokens.px(12)
    opacity: enabled ? 1 : .42
    validator: DoubleValidator { bottom: Number(control.textFromValue(control.from, control.locale)); top: Number(control.textFromValue(control.to, control.locale)); decimals: 3; notation: DoubleValidator.StandardNotation; locale: control.locale.name }
    contentItem: TextInput {
        text: control.textFromValue(control.value, control.locale); font: control.font; color: Tokens.text
        horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
        readOnly: !control.editable; validator: control.validator; inputMethodHints: Qt.ImhFormattedNumbersOnly
        selectByMouse: true; selectionColor: Tokens.alpha(Tokens.accent, .45); selectedTextColor: Tokens.text
    }
    up.indicator: Item {
        x: control.width - width; width: 30; height: control.height
        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: control.value < control.to ? (control.up.pressed ? Tokens.accent : Tokens.text2) : Tokens.text3 }
    }
    down.indicator: Item {
        width: 30; height: control.height
        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 16; color: control.value > control.from ? (control.down.pressed ? Tokens.accent : Tokens.text2) : Tokens.text3 }
    }
    background: Rectangle {
        radius: Tokens.controlRadius
        color: control.hovered ? Tokens.controlHover : Tokens.control
        border.width: control.activeFocus ? 2 : 0; border.color: Tokens.alpha(Tokens.accent, .7)
    }
}
