pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ctrl+K: one search box for sections, modes, skins and actions.
// Fuzzy match (letters in order), arrows to move, Enter to run, Esc to close.
Item {
    id: palette
    property var commands: []          // [{ title, icon, group, keys, run }]
    property bool opened: false
    property int current: 0
    readonly property string query: input.text.trim().toLowerCase()
    visible: opened || hideAnim.running
    z: 200

    function show() { input.text = ""; current = 0; opened = true; input.forceActiveFocus(); }
    function hide() { opened = false; }
    function exec(cmd) { if (!cmd) return; hide(); cmd.run(); }

    // subsequence score: higher is better, -1 = no match
    function score(cmd) {
        if (!query) return 0;
        var hay = (cmd.title + " " + (cmd.keys || "") + " " + (cmd.group || "")).toLowerCase();
        if (hay.indexOf(query) >= 0) return 100 - hay.indexOf(query);
        var i = 0, gaps = 0, last = -1;
        for (var k = 0; k < query.length; k++) {
            var at = hay.indexOf(query[k], i);
            if (at < 0) return -1;
            if (last >= 0) gaps += at - last - 1;
            last = at; i = at + 1;
        }
        return 50 - gaps;
    }
    readonly property var results: {
        if (!query) return commands;
        return commands.map(c => ({ c: c, s: score(c) })).filter(r => r.s >= 0)
            .sort((a, b) => b.s - a.s).slice(0, 40).map(r => r.c);
    }
    onResultsChanged: current = 0

    // dim backdrop
    Rectangle {
        anchors.fill: parent
        color: "#99000000"
        opacity: palette.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { id: hideAnim; duration: 140 } }
        MouseArea { anchors.fill: parent; onClicked: palette.hide() }
    }

    Item {
        id: sheet
        width: Math.min(620, palette.width - 80)
        height: Math.min(470, 64 + list.contentHeight + 14)
        anchors.horizontalCenter: parent.horizontalCenter
        y: palette.height * .14 + (palette.opened ? 0 : -12)
        opacity: palette.opened ? 1 : 0
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Repeater {   // soft shadow
            model: 4
            Rectangle {
                required property int index
                x: -index * 3; y: 6 + index * 4; width: sheet.width + index * 6; height: sheet.height
                radius: Tokens.radius + index * 3; color: "#000000"; opacity: .14
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius
            color: Qt.tint(Qt.lighter(Tokens.base, 1.6), Tokens.surface)
            border.width: 1
            border.color: Tokens.alpha("#ffffff", .12)
        }
        MouseArea { anchors.fill: parent }   // swallow clicks

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10
            spacing: 6

            // query row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 8
                Text {
                    Layout.leftMargin: 8
                    text: Tokens.glyph(0xF0349)
                    font.family: Tokens.iconFont
                    font.pixelSize: 18; font.weight: Font.Bold
                    color: Tokens.text3
                }
                TextField {
                    id: input
                    Layout.fillWidth: true
                    background: Item {}
                    placeholderText: "Раздел, режим, скин или действие"
                    placeholderTextColor: Tokens.text3
                    color: Tokens.text
                    font.family: Tokens.font; font.pixelSize: Tokens.px(17)
                    selectionColor: Tokens.neon
                    Keys.onEscapePressed: event => { palette.hide(); event.accepted = true; }
                    Keys.onUpPressed: { palette.current = Math.max(0, palette.current - 1); list.positionViewAtIndex(palette.current, ListView.Contain); }
                    Keys.onDownPressed: { palette.current = Math.min(palette.results.length - 1, palette.current + 1); list.positionViewAtIndex(palette.current, ListView.Contain); }
                    Keys.onReturnPressed: palette.exec(palette.results[palette.current])
                    Keys.onEnterPressed: palette.exec(palette.results[palette.current])
                }
                Rectangle {
                    Layout.rightMargin: 6
                    implicitWidth: escTxt.implicitWidth + 12; implicitHeight: 20
                    radius: 6
                    color: "transparent"; border.width: 1; border.color: Tokens.line
                    Text { id: escTxt; anchors.centerIn: parent; text: "esc"; font.family: Tokens.font; font.pixelSize: Tokens.px(10); color: Tokens.text3 }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.line }

            ListView {
                id: list
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                model: palette.results
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === palette.current
                    width: list.width; height: 42

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: row.sel ? Tokens.alpha(Tokens.neon, .18) : rowMouse.containsMouse ? Tokens.cardStrong : "transparent"
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 12
                        Text {
                            text: Tokens.glyph(row.modelData.icon || 0xF0142)
                            font.family: Tokens.iconFont; font.pixelSize: 16
                            color: row.sel ? Tokens.neon : (row.modelData.tint || Tokens.text2)
                            Layout.preferredWidth: 20
                        }
                        Text {
                            text: row.modelData.title
                            font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: row.sel ? Font.DemiBold : Font.Normal
                            color: Tokens.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: row.modelData.group
                            font.family: Tokens.font; font.pixelSize: Tokens.px(10)
                            color: Tokens.text3
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: palette.current = row.index
                        onClicked: palette.exec(row.modelData)
                    }
                }
                Text {
                    visible: palette.results.length === 0
                    anchors.centerIn: parent
                    text: "Ничего не найдено"
                    font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text3
                }
            }
        }
    }
}
