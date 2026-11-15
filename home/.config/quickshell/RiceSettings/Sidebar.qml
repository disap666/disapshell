pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Navigation: profile banner, search, grouped sections, clock.
Rectangle {
    id: bar
    required property var shell          // ShellRoot: sections, visibleSections, section, pages, search
    function clearSearch() { field.clear(); }
    function focusSearch() { field.forceActiveFocus(); }

    color: Tokens.sidebar
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tokens.line }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // Profile banner
        ClippingRectangle {
            id: profile
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 118
            radius: Tokens.radius
            color: Tokens.base

            Image {
                id: banner
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                source: Qt.resolvedUrl("assets/banner.png")
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true
                scale: profileHover.hovered ? 1.07 : 1
                Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
            }
            Rectangle {   // shown when there is no banner image
                visible: banner.status !== Image.Ready
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Tokens.cyan }
                    GradientStop { position: 1; color: Tokens.neon }
                }
            }
            Rectangle {   // darker towards the bottom so the name stays readable
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#22000000" }
                    GradientStop { position: .45; color: "#33000000" }
                    GradientStop { position: 1; color: "#e6080610" }
                }
            }
            Column {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 11
                spacing: 2
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: Quickshell.env("USER")
                    font.family: Tokens.display; font.pixelSize: Tokens.px(16); font.weight: Font.Medium
                    color: "#ffffff"
                }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Tokens.duo ? Tokens.neon : "#e23b3b" }
                    GradientStop { position: 1; color: Tokens.duo ? Tokens.cyan : "#3d6fe0" }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: profile.radius; color: "transparent"
                border.width: 1; border.color: profileHover.hovered ? "#40ffffff" : "#1affffff"
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }
            HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: bar.shell.section = "home" }
        }

        // Search
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            color: Tokens.alpha("#ffffff", .06)
            radius: 19
            border.width: field.activeFocus ? 1 : 0
            border.color: Tokens.neon
            Text {
                id: prompt
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: Tokens.glyph(0xF0349)
                font.family: Tokens.iconFont; font.pixelSize: 15
                color: Tokens.text3
            }
            TextField {
                id: field
                anchors.left: prompt.right; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                leftPadding: 8; rightPadding: 8
                background: Item {}
                placeholderText: "Поиск"
                placeholderTextColor: Tokens.text3
                font.family: Tokens.font; font.pixelSize: Tokens.px(13)
                color: Tokens.text
                selectByMouse: true
                selectionColor: Tokens.neon
                onTextChanged: {
                    var s = bar.shell;
                    s.search = text.trim().toLowerCase();
                    if (s.visibleSections.length && !s.visibleSections.some(x => x.id === s.section)) s.section = s.visibleSections[0].id;
                }
                Keys.onReturnPressed: if (bar.shell.visibleSections.length) bar.shell.section = bar.shell.visibleSections[0].id
            }
        }

        // Sections
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; contentHeight: nav.implicitHeight; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: nav
                width: parent.width
                spacing: 2
                Repeater {
                    model: ["", "Оформление", "Панели", "Система"]
                    ColumnLayout {
                        id: navGroup
                        required property string modelData
                        readonly property var items: bar.shell.visibleSections.filter(s => s.group === modelData)
                        visible: items.length > 0
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            visible: navGroup.modelData.length > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 16; Layout.bottomMargin: 4
                            Layout.leftMargin: 12
                            spacing: 6
                            Text {
                                text: navGroup.modelData.toUpperCase()
                                font.family: Tokens.font
                                font.pixelSize: Tokens.px(10)
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.6
                                color: Tokens.text3
                            }
                            Rectangle { Layout.fillWidth: true; Layout.rightMargin: 8; height: 1; color: Tokens.alpha(Tokens.text, .07) }
                        }
                        Repeater {
                            model: navGroup.items
                            Item {
                                id: item
                                required property var modelData
                                readonly property bool active: bar.shell.section === modelData.id
                                readonly property var page: bar.shell.pages[modelData.id]
                                Layout.fillWidth: true
                                implicitHeight: Tokens.compact ? 27 : 38

                                Rectangle {
                                    anchors.fill: parent; anchors.bottomMargin: 2
                                    radius: 12
                                    color: !item.active && hover.containsMouse ? Tokens.cardStrong : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Rectangle {
                                        anchors.fill: parent; radius: parent.radius
                                        opacity: item.active ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 180 } }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: Tokens.alpha(Tokens.neon, .26) }
                                            GradientStop { position: 1; color: Tokens.alpha(Tokens.duo ? Tokens.cyan : Tokens.neon, .05) }
                                        }
                                        border.width: 1
                                        border.color: Tokens.alpha(Tokens.neon, .22)
                                    }
                                }
                                Rectangle {
                                    x: 1; width: 3; radius: 1.5
                                    height: item.active ? 16 : 0
                                    anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -1
                                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Tokens.neon }
                                        GradientStop { position: 1; color: Tokens.duo ? Tokens.cyan : Tokens.neon }
                                    }
                                }

                                RowLayout {
                                    width: parent.width - 3; height: parent.height - 2
                                    spacing: 10
                                    Rectangle {
                                        Layout.leftMargin: 8
                                        width: 26; height: 26; radius: 8
                                        color: item.active ? Tokens.neon
                                            : Tokens.duo ? Tokens.alpha("#ffffff", hover.containsMouse ? .09 : .05)
                                            : Qt.alpha(item.modelData.tint, .16)
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: Tokens.glyph(item.modelData.icon); font.family: Tokens.iconFont; font.pixelSize: 14
                                            color: item.active ? Tokens.onAccent
                                                : Tokens.duo ? (hover.containsMouse ? Tokens.text : Tokens.text2)
                                                : item.modelData.tint
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: item.active ? Tokens.up(item.modelData.name) : item.modelData.name
                                        elide: Text.ElideRight
                                        font.family: Tokens.font
                                        font.pixelSize: Tokens.px(13)
                                        font.weight: item.active ? Font.DemiBold : Font.Normal
                                        font.letterSpacing: item.active && Tokens.caps ? 1 : 0
                                        color: Tokens.duo && !item.active && !hover.containsMouse ? Tokens.alpha(Tokens.text, .78) : Tokens.text
                                    }
                                    Rectangle {
                                        visible: !!item.page && !!item.page.dirty
                                        Layout.rightMargin: 10
                                        width: 6; height: 6; radius: 3
                                        color: Tokens.amber
                                    }
                                }
                                MouseArea {
                                    id: hover
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: bar.shell.section = item.modelData.id
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: bar.shell.visibleSections.length === 0
                    Layout.fillWidth: true; Layout.topMargin: 16; horizontalAlignment: Text.AlignHCenter
                    text: "Ничего не найдено"
                    font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3
                }
            }
        }

        // Footer: clock and the palette shortcut
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 6
            spacing: 8
            Text {
                text: Qt.formatTime(clock.date, "HH:mm")
                font.family: Tokens.display; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2
            }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "d MMMM, ddd")
                font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3
            }
            Rectangle {
                implicitWidth: kbd.implicitWidth + 12; implicitHeight: 20; radius: 6
                color: Tokens.alpha("#ffffff", .05)
                border.width: 1; border.color: Tokens.alpha(Tokens.text, .1)
                Text { id: kbd; anchors.centerIn: parent; text: "Ctrl K"; font.family: Tokens.font; font.pixelSize: Tokens.px(10); font.weight: Font.Medium; color: Tokens.text3 }
            }
        }
    }
}
