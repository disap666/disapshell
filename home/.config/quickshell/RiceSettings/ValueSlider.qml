pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// Slider + editable value pill, shared by every numeric look setting.
//  - drag: value bubble follows the handle
//  - click the pill: type an exact number (Enter), ↑/↓ nudge
//  - wheel on pill: ±step (Shift ×10)
//  - double-click: back to the default (tick mark on the track)
Row {
    id: root
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string unit: ""
    property real defaultValue: NaN
    property int decimals: 0
    property real sliderWidth: 200
    readonly property bool hasDefault: !isNaN(defaultValue)
    signal edited(real value)
    spacing: 10
    opacity: enabled ? 1 : .42

    function clamp(v) {
        if (isNaN(v)) return value;
        v = Math.round((v - from) / step) * step + from;
        return Math.max(from, Math.min(to, +v.toFixed(4)));
    }
    function commit(v) { v = clamp(v); if (v !== value) edited(v); }
    function fmt(v) { return Number(v).toFixed(decimals).replace(".", ","); }

    C.Slider {
        id: slider
        anchors.verticalCenter: parent.verticalCenter
        width: root.sliderWidth; height: 32
        from: root.from; to: root.to; stepSize: root.step
        value: root.value
        hoverEnabled: true
        onMoved: root.commit(value)
        background: Item {
            x: slider.leftPadding; y: (slider.height - height) / 2
            width: slider.availableWidth; height: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Tokens.control }
            Rectangle {
                width: Math.max(height, slider.visualPosition * parent.width); height: parent.height; radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Tokens.alpha(Tokens.accent, .55) }
                    GradientStop { position: 1; color: Tokens.accent }
                }
            }
            Rectangle {
                visible: root.hasDefault
                x: (root.defaultValue - root.from) / Math.max(1e-9, root.to - root.from) * parent.width - 1
                y: -4; width: 2; height: 14; radius: 1
                color: Tokens.alpha(Tokens.text, .35)
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 18; height: 18; radius: 9
            color: Tokens.text
            border.width: 3; border.color: Tokens.accent
            scale: slider.pressed ? 1.2 : slider.hovered ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Rectangle {
                opacity: slider.pressed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top; anchors.bottomMargin: 8
                width: bubble.implicitWidth + 14; height: 22; radius: 6
                color: Tokens.accent
                Text { id: bubble; anchors.centerIn: parent; text: root.fmt(root.value) + root.unit; color: Tokens.onAccent; font.family: Tokens.font; font.pixelSize: Tokens.px(11); font.weight: Font.Bold }
            }
        }
        TapHandler { onDoubleTapped: if (root.hasDefault) root.commit(root.defaultValue) }
    }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(62, input.contentWidth + 18); height: 28
        radius: Tokens.controlRadius
        color: input.activeFocus || pillHover.hovered ? Tokens.controlHover : Tokens.control
        border.width: input.activeFocus ? 1 : 0; border.color: Tokens.accent
        Behavior on color { ColorAnimation { duration: 100 } }
        TextInput {
            id: input
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
            horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium
            color: Tokens.text; selectionColor: Tokens.alpha(Tokens.accent, .45); selectedTextColor: Tokens.text
            selectByMouse: true
            readonly property string shown: activeFocus ? root.fmt(root.value) : root.fmt(root.value) + root.unit
            text: shown
            onActiveFocusChanged: { text = Qt.binding(() => input.shown); if (activeFocus) selectAll(); }
            onAccepted: { root.commit(parseFloat(text.replace(",", "."))); focus = false; }
            Keys.onEscapePressed: focus = false
            Keys.onUpPressed: root.commit(root.value + root.step)
            Keys.onDownPressed: root.commit(root.value - root.step)
        }
        HoverHandler { id: pillHover; cursorShape: Qt.IBeamCursor }
        WheelHandler {
            onWheel: event => root.commit(root.value + (event.angleDelta.y > 0 ? 1 : -1) * root.step * ((event.modifiers & Qt.ShiftModifier) ? 10 : 1))
        }
    }

    // reset arrow appears only when the value differs from the default
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        visible: root.hasDefault
        opacity: root.hasDefault && Math.abs(root.value - root.defaultValue) > 1e-6 ? (resetArea.containsMouse ? 1 : .55) : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        text: "↺"; font.pixelSize: Tokens.px(15); color: Tokens.text2
        MouseArea { id: resetArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.commit(root.defaultValue) }
        C.ToolTip.visible: resetArea.containsMouse; C.ToolTip.delay: 500; C.ToolTip.text: "Вернуть " + root.fmt(root.defaultValue) + root.unit
    }
}
