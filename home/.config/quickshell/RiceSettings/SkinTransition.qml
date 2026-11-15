import QtQuick

// Short fade whenever the active skin changes.
Rectangle {
    id: veil
    enabled: false
    visible: fade.running
    color: Tokens.base
    opacity: 0
    property string last: Tokens.skin.id

    Connections {
        target: Tokens
        function onSkinChanged() {
            if (Tokens.skin.id === veil.last) return;
            veil.last = Tokens.skin.id;
            fade.restart();
        }
    }
    NumberAnimation { id: fade; target: veil; property: "opacity"; from: 1; to: 0; duration: 380; easing.type: Easing.OutCubic }
}
