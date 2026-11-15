pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Скины": how the settings window itself looks. Every change applies live
// and is saved to ~/.config/rice-theme/settings-skin.json.
Flickable {
    id: page
    readonly property bool dirty: false
    readonly property bool loaded: true
    readonly property string status: ""

    clip: true
    contentHeight: body.implicitHeight + 16
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    readonly property var accents: ["", "#ff2e88", "#29f0ff", "#b6ff3b", "#ffb627", "#9d5cff", "#ff5a3c", "#01cdfe", "#ffffff"]

    component Heading: RowLayout {
        id: heading
        property string title
        spacing: 8
        Text { text: Tokens.up(heading.title); font.family: Tokens.font; font.pixelSize: Tokens.px(14); font.weight: Font.ExtraBold; font.letterSpacing: Tokens.caps ? 2 : 0; color: Tokens.text }
    }

    // On/off row whose state always follows Tokens (re-bound after a click).
    component Toggle: SettingRow {
        id: row
        property string key
        property bool value
        StyledCheckBox {
            checked: row.value
            onClicked: { Tokens.set(row.key, checked); checked = Qt.binding(() => row.value); }
        }
    }

    ColumnLayout {
        id: body
        width: page.width - 12
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            Heading {
                title: "Скин"
            }
            Item { Layout.fillWidth: true }
            StyledButton { text: "Случайный"; onClicked: Tokens.randomSkin() }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: page.width > 820 ? 3 : 2
            columnSpacing: 14; rowSpacing: 14

            Repeater {
                model: Tokens.skins
                Item {
                    id: card
                    required property var modelData
                    readonly property var s: modelData
                    readonly property bool current: Tokens.skin.id === s.id
                    readonly property color hot: s.neon === "@accent" ? Tokens.themeAccent : s.neon
                    readonly property color face: Qt.tint(s.base, s.surface)
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    implicitHeight: 222

                    Rectangle {
                        width: parent.width - 5; height: parent.height - 5
                        radius: card.s.radius
                        color: card.s.base
                        border.width: card.current ? 2 : 1
                        border.color: card.current ? card.hot : Qt.alpha(card.s.text, .25)
                        clip: true

                        // Miniature of the settings window: sidebar, hero card, meters, player, modes
                        Item {
                            id: mini
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 8
                            height: 128
                            readonly property real cx: 64
                            readonly property real cw: width - cx
                            readonly property color ink: card.s.fan ? Qt.darker(card.s.base, 1.4) : "#000000"

                            Rectangle {   // sidebar
                                width: 58; height: parent.height
                                radius: 6
                                color: card.s.sidebar
                                border.width: 1; border.color: Qt.alpha(card.s.text, .1)
                                Rectangle {   // profile banner
                                    x: 4; y: 4; width: 50; height: 26; radius: 4
                                    color: card.s.base; clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: Qt.resolvedUrl("assets/banner.png")
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true; sourceSize.width: 120
                                    }
                                    Rectangle {
                                        anchors.bottom: parent.bottom; width: parent.width; height: 1.5
                                        gradient: Gradient { orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: card.hot }
                                            GradientStop { position: 1; color: card.s.cyan } }
                                    }
                                }
                                Rectangle { x: 4; y: 34; width: 50; height: 8; radius: 4; color: Qt.alpha(card.s.text, .07) }
                                Column {
                                    x: 4; y: 47; spacing: 3
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            id: navMini
                                            required property int index
                                            readonly property bool on: index === 1
                                            width: 50; height: 9; radius: 3
                                            color: on ? Qt.alpha(card.hot, .16) : "transparent"
                                            border.width: on ? 1 : 0; border.color: Qt.alpha(card.hot, .4)
                                            Rectangle { visible: navMini.on; x: -1; y: 2; width: 1.5; height: 5; radius: 1; color: card.hot }
                                            Rectangle { x: 3; y: 1.5; width: 6; height: 6; radius: 2; color: navMini.on ? card.hot : Qt.alpha(card.s.text, .16) }
                                            Rectangle { x: 13; y: 3; width: 16 + (navMini.index * 7) % 14; height: 3; radius: 1
                                                color: Qt.alpha(card.s.text, navMini.on ? .85 : .4) }
                                        }
                                    }
                                }
                            }
                            Rectangle {   // hero card
                                x: mini.cx; width: mini.cw; height: 58
                                radius: 6
                                color: mini.ink
                                clip: true
                                Image {
                                    id: miniArt
                                    readonly property var exts: ["png", "jpg", "jpeg", "webp"]
                                    property int tryIndex: 0
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: parent.width * .62
                                    source: card.s.fan ? Qt.resolvedUrl("assets/heroes/" + card.s.id + "." + exts[tryIndex]) : ""
                                    onStatusChanged: if (status === Image.Error && tryIndex < exts.length - 1) tryIndex++
                                    fillMode: Image.PreserveAspectCrop; horizontalAlignment: Image.AlignRight
                                    asynchronous: true; sourceSize.width: 320
                                    visible: status === Image.Ready
                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient { orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: mini.ink }
                                            GradientStop { position: .38; color: Qt.alpha(mini.ink, .55) }
                                            GradientStop { position: .7; color: Qt.alpha(mini.ink, 0) } }
                                    }
                                }
                                Image {
                                    visible: !card.s.fan
                                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top
                                    height: 46; width: 34
                                    source: Qt.resolvedUrl("assets/spider.png")
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true; sourceSize.height: 120
                                }
                                Text {
                                    id: miniClock
                                    x: 8; y: 7; text: "17:05"; color: "#ffffff"
                                    font.family: Tokens.display; font.pixelSize: 17; font.weight: Font.Medium
                                }
                                Text {
                                    anchors.left: miniClock.right; anchors.leftMargin: 2; anchors.baseline: miniClock.baseline
                                    text: "42"; color: card.hot
                                    font.family: Tokens.display; font.pixelSize: 6; font.weight: Font.Medium
                                }
                                Rectangle { x: 8; y: 33; width: 44; height: 3; radius: 1; color: Qt.alpha(card.s.text, .45) }
                                Row {
                                    x: 8; y: 42; spacing: 3
                                    Repeater {
                                        model: [20, 26, 23]
                                        Rectangle {
                                            required property int modelData
                                            required property int index
                                            width: modelData; height: 8; radius: 4
                                            color: Qt.alpha("#ffffff", .06)
                                            border.width: 1; border.color: index === 0 ? Qt.alpha(card.hot, .55) : Qt.alpha("#ffffff", .14)
                                        }
                                    }
                                }
                            }
                            Row {   // meters
                                x: mini.cx; y: 63; spacing: 4
                                Repeater {
                                    model: [card.s.cyan, card.hot, card.s.amber]
                                    Rectangle {
                                        id: meterMini
                                        required property var modelData
                                        required property int index
                                        readonly property int value: 22 + index * 19
                                        width: (mini.cw - 8) / 3; height: 30
                                        radius: 5
                                        color: card.s.surface
                                        border.width: 1; border.color: Qt.alpha(card.s.text, .1)
                                        Rectangle { x: 4; y: 4; width: 6; height: 6; radius: 2; color: Qt.alpha(meterMini.modelData, .35) }
                                        Rectangle { x: 13; y: 5.5; width: 18; height: 3; radius: 1; color: Qt.alpha(card.s.text, .4) }
                                        Text { x: 4; y: 11; text: meterMini.value + "%"; color: card.s.text; font.family: Tokens.display; font.pixelSize: 8; font.weight: Font.Medium }
                                        Rectangle {
                                            x: 4; anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                                            width: parent.width - 8; height: 2; radius: 1
                                            color: Qt.alpha(card.s.text, .12)
                                            Rectangle { width: parent.width * meterMini.value / 100; height: 2; radius: 1; color: meterMini.modelData }
                                        }
                                    }
                                }
                            }
                            Rectangle {   // player
                                x: mini.cx; y: 97; width: mini.cw; height: 14
                                radius: 5
                                color: card.s.surface
                                border.width: 1; border.color: Qt.alpha(card.s.text, .1)
                                Rectangle { x: 3; y: 3; width: 8; height: 8; radius: 2; color: Qt.alpha(card.s.text, .2) }
                                Rectangle { x: 15; y: 4; width: 34; height: 3; radius: 1; color: Qt.alpha(card.s.text, .6) }
                                Rectangle { x: 15; y: 9; width: parent.width - 36; height: 1.5; radius: 1; color: Qt.alpha(card.s.text, .14)
                                    Rectangle { width: parent.width * .3; height: parent.height; radius: 1; color: card.s.text } }
                                Rectangle { anchors.right: parent.right; anchors.rightMargin: 4; y: 3; width: 8; height: 8; radius: 4; color: card.s.acid }
                            }
                            Row {   // modes
                                x: mini.cx; y: 115; spacing: 3
                                Repeater {
                                    model: 5
                                    Rectangle {
                                        width: (mini.cw - 12) / 5; height: 13
                                        radius: 4
                                        color: card.s.surface
                                        border.width: 1; border.color: Qt.alpha(card.s.text, .1)
                                        Rectangle { x: 3; y: 3; width: 5; height: 5; radius: 2.5; color: Qt.alpha(card.s.text, .16) }
                                        Rectangle { anchors.right: parent.right; anchors.rightMargin: 3; y: 4; width: 9; height: 4; radius: 2; color: Qt.alpha(card.s.text, .2) }
                                    }
                                }
                            }
                        }

                        // Caption
                        Column {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 12
                            spacing: 3
                            RowLayout {
                                width: parent.width
                                Text {
                                    Layout.fillWidth: true
                                    text: card.s.name
                                    font.family: Tokens.font; font.pixelSize: Tokens.px(14); font.weight: Font.ExtraBold
                                    color: card.s.text
                                }
                                Repeater {
                                    model: Tokens.opt.autoSkin ? [[Tokens.opt.daySkin, "день"], [Tokens.opt.nightSkin, "ночь"]].filter(x => x[0] === card.s.id && !card.current) : []
                                    Rectangle {
                                        required property var modelData
                                        implicitWidth: dn.implicitWidth + 10; implicitHeight: 16
                                        radius: 8
                                        color: "transparent"; border.width: 1; border.color: card.hot
                                        Text { id: dn; anchors.centerIn: parent; text: parent.modelData[1]; font.family: Tokens.font; font.pixelSize: 9; font.weight: Font.DemiBold; color: card.hot }
                                    }
                                }
                                Rectangle {
                                    visible: card.current
                                    implicitWidth: badge.implicitWidth + 10; implicitHeight: 16
                                    radius: 8
                                    color: card.hot
                                    Text { id: badge; anchors.centerIn: parent; text: "активен"; font.family: Tokens.font; font.pixelSize: 9; font.weight: Font.DemiBold; color: card.s.onAccent }
                                }
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: card.s.tagline
                                font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: card.s.text2
                            }
                            Row {
                                spacing: 3; topPadding: 2
                                Repeater {
                                    model: [card.hot, card.s.cyan, card.s.amber, card.s.acid, card.s.text]
                                    Rectangle { required property var modelData; width: 12; height: 6; radius: 3; color: modelData }
                                }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Tokens.setSkin(card.s.id) }
                }
            }
        }

        // Auto day/night
        Heading { title: "Авто-смена" }
        Group {
            Toggle { key: "autoSkin"; value: !!Tokens.opt.autoSkin; label: "Менять скин по времени"
            }
            SettingRow {
                visible: !!Tokens.opt.autoSkin
                label: "Днём"
                StyledComboBox {
                    width: 220
                    model: Tokens.skins.map(s => s.name)
                    currentIndex: Math.max(0, Tokens.skins.findIndex(s => s.id === Tokens.opt.daySkin))
                    onActivated: Tokens.set("daySkin", Tokens.skins[currentIndex].id)
                }
            }
            SettingRow {
                visible: !!Tokens.opt.autoSkin
                label: "Ночью"
                StyledComboBox {
                    width: 220
                    model: Tokens.skins.map(s => s.name)
                    currentIndex: Math.max(0, Tokens.skins.findIndex(s => s.id === Tokens.opt.nightSkin))
                    onActivated: Tokens.set("nightSkin", Tokens.skins[currentIndex].id)
                }
            }
        }

        Heading { title: "Акцент" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: page.accents
                Item {
                    id: sw
                    required property string modelData
                    readonly property bool chosen: (Tokens.opt.accent || "") === modelData
                    readonly property color shown: modelData || (Tokens.skin.neon === "@accent" ? Tokens.themeAccent : Tokens.skin.neon)
                    width: modelData ? 40 : 118; height: 40
                    Rectangle {
                        width: parent.width - 3; height: parent.height - 3
                        radius: height / 2
                        color: sw.modelData ? sw.shown : Tokens.surface
                        border.width: sw.chosen ? 2 : 1
                        border.color: sw.chosen ? Tokens.text : Tokens.line
                        Row {
                            visible: !sw.modelData
                            anchors.centerIn: parent; spacing: 6
                            Rectangle { width: 12; height: 12; radius: 6; color: sw.shown; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "из скина"; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text }
                        }
                        Text {
                            visible: !!sw.modelData && sw.chosen
                            anchors.centerIn: parent; text: Tokens.glyph(0xF012C); font.family: Tokens.iconFont; font.pixelSize: 16
                            color: Tokens.onAccent
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Tokens.set("accent", sw.modelData) }
                }
            }
        }

        Heading { title: "Текст и меню" }
        Group {
            SettingRow {
                label: "Шрифт"
                Segmented {
                    model: ["Из темы", "Моноширинный"]
                    current: Tokens.mono ? 1 : 0
                    onActivated: index => Tokens.set("font", index ? "mono" : "skin")
                }
            }
            SettingRow {
                label: "Размер текста"
                Segmented {
                    readonly property var values: [0.9, 1, 1.1, 1.25]
                    model: ["90%", "100%", "110%", "125%"]
                    current: Math.max(0, values.indexOf(Tokens.scale))
                    onActivated: index => Tokens.set("textScale", values[index])
                }
            }
            Toggle { key: "caps"; value: Tokens.caps; label: "Заглавные" }
            Toggle { key: "compact"; value: Tokens.compact; label: "Компактное меню" }
            Toggle { key: "vignette"; value: Tokens.vignette; label: "Виньетка" }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StyledButton { text: "Сбросить"; onClicked: Tokens.reset() }
        }
    }
}
