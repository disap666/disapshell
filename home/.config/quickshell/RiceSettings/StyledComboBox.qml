pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

C.ComboBox {
    id: control
    implicitHeight: Tokens.controlHeight; implicitWidth: 220
    leftPadding: 12; rightPadding: 30
    hoverEnabled: true
    font.family: Tokens.font; font.pixelSize: Tokens.px(12)
    opacity: enabled ? 1 : .42
    contentItem: Text { text: control.displayText; font: control.font; color: Tokens.text; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    indicator: Text {
        x: control.width - width - 11; y: (control.height - height) / 2
        text: Tokens.glyph(0xF0140); font.family: Tokens.iconFont; font.pixelSize: 15; color: Tokens.text2
    }
    background: Rectangle {
        radius: Tokens.controlRadius
        color: control.pressed ? Tokens.controlDown : control.hovered ? Tokens.controlHover : Tokens.control
        border.width: control.visualFocus ? 2 : 0; border.color: Tokens.alpha(Tokens.accent, .7)
    }
    delegate: C.ItemDelegate {
        id: entry
        required property int index; required property var modelData
        width: ListView.view ? ListView.view.width : control.width
        implicitHeight: 30; highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: String(entry.modelData); font: control.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
            color: entry.index === control.currentIndex ? Tokens.accent : Tokens.text
        }
        background: Rectangle { radius: 6; color: entry.highlighted ? Tokens.controlHover : "transparent" }
    }
    popup: C.Popup {
        y: control.height + 4; width: Math.max(control.width, 180); padding: 4
        implicitHeight: Math.min(320, contentItem.implicitHeight + 8)
        contentItem: ListView {
            clip: true; implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            C.ScrollIndicator.vertical: C.ScrollIndicator {}
        }
        background: Rectangle { radius: 10; color: Qt.lighter(Tokens.base, 1.25); border.width: 1; border.color: Tokens.line }
    }
}
