pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import QtCore
import "AppIcons.js" as AppIcons
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

// One widget of the merged RiceDesktop process (see ../RiceDesktop/shell.qml).
Scope {
    id: root
    Settings {
        id: preferences
        location: "file://" + Quickshell.env("HOME") + "/.config/quickshell/RiceNotifications/size.ini"
        category: "RiceNotifications"
        property int panelWidth: 380
        property int panelHeight: 650
    }
    property bool opened: false
    property bool dnd: false
    property var toast: null
    property var receivedAt: ({})
    property real volume: 0.5
    property real brightness: 0.5
    readonly property color blue: Rice.Theme.color("#bba5d5")
    readonly property color ink: Rice.Theme.color("#211c30")
    readonly property string family: Rice.Theme.fontFamily
    readonly property real charge: UPower.displayDevice ? UPower.displayDevice.percentage : 0
    property string laptopName: "Ноутбук"
    property var receiverHeadset: null
    property var receiverMouse: null
    readonly property var batteries: {
        const devices = UPower.devices.values.filter(d => d.isPresent && d.type !== UPowerDeviceType.LinePower && (d.isLaptopBattery || d.percentage >= 0));
        if (receiverMouse && !devices.some(d => !d.isLaptopBattery && /pulsar/i.test(d.model))) devices.push(receiverMouse);
        if (receiverHeadset && !devices.some(d => !d.isLaptopBattery && /hyperx|stinger/i.test(d.model))) devices.push(receiverHeadset);
        return devices;
    }
    Process {
        command: ["cat", "/sys/class/dmi/id/product_name"]
        running: true
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.laptopName = text.trim() }
    }
    Process {
        id: headsetBattery
        command: ["python3", Quickshell.env("HOME") + "/.local/lib/rice/headset-battery.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.receiverHeadset = JSON.parse(text); }
                catch (error) { root.receiverHeadset = null; }
            }
        }
    }
    Timer { interval: 30000; running: root.opened; repeat: true; triggeredOnStart: true; onTriggered: if (!headsetBattery.running) headsetBattery.running = true }
    Process {
        id: mouseBattery
        command: ["python3", Quickshell.env("HOME") + "/.local/lib/rice/mouse-battery.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    if (next && next.percentage === null && root.receiverMouse && root.receiverMouse.percentage !== null && next.status === "no-response") {
                        next.percentage = root.receiverMouse.percentage;
                        next.state = root.receiverMouse.state;
                        next.stale = true;
                    }
                    root.receiverMouse = next;
                } catch (error) { root.receiverMouse = null; }
            }
        }
    }
    Timer { interval: 30000; running: root.opened; repeat: true; triggeredOnStart: true; onTriggered: if (!mouseBattery.running) mouseBattery.running = true }
    readonly property var runningApps: {
        const groups = [];
        for (const win of Hyprland.toplevels.values) {
            const cls = win.lastIpcObject["class"] || win.lastIpcObject.initialClass || (win.wayland ? win.wayland.appId : "") || "";
            const entry = cls ? DesktopEntries.heuristicLookup(cls) : null;
            const key = entry ? entry.id : (cls || win.address);
            let group = groups.find(a => a.key === key);
            if (!group) {
                group = { key: key, name: entry ? entry.name : (cls || "Окно"),
                    icon: entry && entry.icon ? entry.icon : (cls || "application-x-executable"), windows: [], active: false };
                groups.push(group);
            }
            group.windows.push(win);
            if (win.activated) group.active = true;
        }
        return groups;
    }
    function iconSource(icon) {
        if (!icon) return Qt.resolvedUrl("app.svg");
        const installed = AppIcons.paths[icon.toLowerCase().replace(/\.desktop$/, "")];
        if (installed) return "file://" + installed;
        if (icon.startsWith("/") ) return "file://" + icon;
        if (/^(file|image|data|https?):/.test(icon)) return icon;
        return Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon) : Qt.resolvedUrl("app.svg");
    }
    function focusApp(app) {
        const windows = app.windows.filter(w => Hyprland.toplevels.values.indexOf(w) >= 0);
        if (!windows.length) return;
        const current = windows.findIndex(w => w.activated);
        const address = windows[(current + 1) % windows.length].address;
        Hyprland.dispatch("focuswindow address:" + (address.startsWith("0x") ? address : "0x" + address));
        root.opened = false;
    }
    function sh(args) { Quickshell.execDetached(args); }
    function clearAll() { for (let n of server.trackedNotifications.values.slice()) n.dismiss(); }
    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        inlineReplySupported: true
        bodySupported: true
        onNotification: n => {
            root.receivedAt = Object.assign({}, root.receivedAt, { [n.id]: Date.now() });
            n.tracked = true;
            if (!root.dnd && !root.opened) { root.toast = n; toastTimer.restart(); }
        }
    }
    Timer { id: toastTimer; interval: 6500; onTriggered: root.toast = null }
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.opened = !root.opened; if (root.opened) root.toast = null; }
        function status(): string { return JSON.stringify({text: root.dnd ? "󰂛" : (server.trackedNotifications.values.length ? "󱅫" : "󰂚"), tooltip: "Уведомления · " + server.trackedNotifications.values.length, class: root.dnd ? "dnd-none" : "none"}); }
        function show(): void { root.opened = true; root.toast = null; }
        function close(): void { root.opened = false; }
        function toggleDnd(): void { root.dnd = !root.dnd; }
    }
    SystemClock { id: clock; precision: SystemClock.Seconds }
    Process {
        id: levels
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@; brightnessctl -m"]
        stdout: StdioCollector { onStreamFinished: {
            let v = text.match(/Volume:\s*([0-9.]+)/); if (v) root.volume = Math.min(1, Number(v[1]));
            let b = text.match(/,(\d+)%/); if (b) root.brightness = Number(b[1])/100;
        } }
    }
    Timer { interval: 3000; running: root.opened; repeat: true; triggeredOnStart: true; onTriggered: if (!levels.running) levels.running = true }
    component Label: Text { color: Rice.Theme.color("#eee3fa"); font.family: root.family; font.pixelSize: (12 * Rice.Theme.textScale) }
    component Button: Rectangle {
        id: button
        property string text
        property color tint: Rice.Theme.color("#304e405e")
        signal clicked()
        width: 37; height: 30; radius: 7
        border.width: 0; border.color: "transparent"
        color: ma.containsMouse ? Qt.lighter(tint, 1.3) : tint
        Label { anchors.centerIn: parent; text: button.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: (14 * Rice.Theme.textScale) }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: button.clicked() }
    }
    component Level: Item {
        id: level
        property string glyph
        property real value
        property color tint: root.blue
        signal changed(real amount)
        height: 28
        Label { text: level.glyph; anchors.verticalCenter: parent.verticalCenter; font.family: "JetBrainsMono Nerd Font"; color: level.tint; font.pixelSize: (17 * Rice.Theme.textScale) }
        Rectangle {
            x: 30; width: parent.width - 30; height: 5; radius: 3; anchors.verticalCenter: parent.verticalCenter
            color: Rice.Theme.color("#211a2d"); border.color: Rice.Theme.color("#594566")
            Rectangle { width: Math.max(5, parent.width * level.value); height: parent.height; radius: 3; color: level.tint; border.color: Qt.lighter(level.tint,1.12) }
            MouseArea { anchors.fill: parent; onPressed: mouse => level.changed(Math.max(0,Math.min(1,mouse.x/width))); onPositionChanged: mouse => { if (pressed) level.changed(Math.max(0,Math.min(1,mouse.x/width))); } }
        }
    }
    component Card: Rectangle {
        id: card
        required property var notification
        property bool replied: false
        function sendReply() {
            if (!notification || !notification.hasInlineReply || !replyInput.text.trim()) return;
            notification.sendInlineReply(replyInput.text.trim());
            replyInput.clear(); replied = true;
            if (root.toast === notification) toastTimer.restart();
        }
        readonly property real received: notification ? (root.receivedAt[notification.id] || 0) : 0
        readonly property string age: {
            const minutes = Math.max(0, Math.floor((clock.date.getTime() - received) / 60000));
            if (!received) return "";
            if (minutes < 1) return "сейчас";
            if (minutes < 60) return minutes + " мин назад";
            if (minutes < 1440) return Math.floor(minutes / 60) + " ч назад";
            return Qt.formatDateTime(new Date(received), "dd.MM HH:mm");
        }
        radius: 22
        color: cardHover.hovered ? Rice.Theme.color("#dd51445f") : Rice.Theme.color("#c53a3149")
        border.width: 1; border.color: Rice.Theme.color("#30ffffff")
        implicitHeight: cardColumn.implicitHeight + 32
        Behavior on color { ColorAnimation { duration: 160 } }
        HoverHandler { id: cardHover }
        opacity: 0
        transform: Translate { id: entrance; y: -12 }
        Component.onCompleted: arrival.start()
        ParallelAnimation {
            id: arrival
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 220 }
            NumberAnimation { target: entrance; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
        Column {
            id: cardColumn
            x: 16; y: 16; width: parent.width - 32; spacing: 6
            Item {
                width: parent.width; height: 24
                Image {
                    id: notificationIcon
                    width: 24; height: 24; sourceSize: Qt.size(48, 48); fillMode: Image.PreserveAspectFit
                    property bool failed: false
                    readonly property var entry: card.notification ? DesktopEntries.heuristicLookup(card.notification.desktopEntry || card.notification.appName) : null
                    readonly property string icon: card.notification ? (card.notification.appIcon || (entry ? entry.icon : "")) : ""
                    source: failed ? Qt.resolvedUrl("app.svg") : root.iconSource(icon)
                    onIconChanged: failed = false
                    onStatusChanged: if (status === Image.Error) failed = true
                }
                Label {
                    x: 33; anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 33 - ageLabel.implicitWidth - 32)
                    text: card.notification ? card.notification.appName : ""
                    elide: Text.ElideRight; color: Rice.Theme.color("#e2d8ec"); font.pixelSize: (11 * Rice.Theme.textScale); font.weight: Font.Medium
                }
                Label {
                    id: ageLabel
                    anchors.right: parent.right; anchors.rightMargin: 25; anchors.verticalCenter: parent.verticalCenter
                    text: card.age; color: Rice.Theme.color("#b9abc7"); font.pixelSize: (10 * Rice.Theme.textScale)
                }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; radius: 10; color: dismissHover.containsMouse ? Rice.Theme.color("#40ffffff") : Rice.Theme.color("#16ffffff")
                    Label { anchors.centerIn: parent; text: "×"; font.pixelSize: (14 * Rice.Theme.textScale); color: Rice.Theme.color("#dfd4e8") }
                    MouseArea { id: dismissHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if(card.notification) card.notification.dismiss() }
                }
            }
            Label {
                width: parent.width; topPadding: 3
                text: card.notification ? card.notification.summary : ""
                font.weight: Font.DemiBold; wrapMode: Text.Wrap; font.pixelSize: (14 * Rice.Theme.textScale); color: Rice.Theme.color("#faf5ff")
            }
            Label {
                width: parent.width; visible: text.length > 0
                text: card.notification ? card.notification.body : ""
                textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Rice.Theme.color("#ded3e8")
                font.pixelSize: (12 * Rice.Theme.textScale); lineHeight: 1.15; maximumLineCount: 6; elide: Text.ElideRight
            }
            Rectangle {
                width: parent.width; height: 38; radius: 13
                visible: card.notification !== null && card.notification.hasInlineReply && !card.replied
                color: Rice.Theme.color("#30211c30"); border.width: 1; border.color: replyInput.activeFocus ? Rice.Theme.color("#99bba5d5") : Rice.Theme.color("#25ffffff")
                TextField {
                    id: replyInput
                    x: 10; width: parent.width - 55; height: parent.height
                    placeholderText: card.notification ? (card.notification.inlineReplyPlaceholder || "Ответить…") : "Ответить…"
                    color: Rice.Theme.color("#faf5ff"); placeholderTextColor: Rice.Theme.color("#b9abc7"); font.family: root.family; font.pixelSize: (12 * Rice.Theme.textScale)
                    background: Item {}
                    selectByMouse: true
                    onAccepted: card.sendReply()
                    onActiveFocusChanged: if (activeFocus && root.toast === card.notification) toastTimer.stop()
                }
                Button {
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15; text: "↑"; tint: Rice.Theme.color("#605f477a")
                    enabled: replyInput.text.trim().length > 0; opacity: enabled ? 1 : .45
                    onClicked: card.sendReply()
                }
            }
            Label { visible: card.replied; text: "Ответ отправлен ✓"; color: Rice.Theme.color("#bcd9bf"); font.pixelSize: (11 * Rice.Theme.textScale) }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: card.notification ? card.notification.actions : []
                    Button {
                        required property var modelData
                        text: modelData.text; radius: 12; tint: Rice.Theme.color("#30d7c3ee")
                        width: Math.min(cardColumn.width, Math.max(90, modelData.text.length * 8 + 24))
                        height: 32; onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; right: true }
        margins { top: 8; right: 12 }
        implicitWidth: Math.min(Math.max(320, preferences.panelWidth), screen.width - 24)
        implicitHeight: Math.min(Math.max(deck.y + deck.height + 150, preferences.panelHeight), screen.height - 24)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-notification-center"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        Rectangle {
            anchors.fill: parent; radius: 28
            color: Rice.Theme.color("#80211c30")
            border.width: 1; border.color: Rice.Theme.color("#40e1d2ef")
            focus: true
            Keys.onEscapePressed: root.opened = false
            Label { x: 18; y: 14; text: "уведы"; font.pixelSize: (14 * Rice.Theme.textScale); font.weight: Font.Medium }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10; y: 8; spacing: 2
                Button { text: root.dnd ? "󰂛" : "󰂚"; tint: root.dnd ? Rice.Theme.color("#806b5584") : "transparent"; onClicked: { root.dnd = !root.dnd; root.toast = null; } }
                Button { text: "󰆴"; tint: "transparent"; onClicked: root.clearAll(); ToolTip.visible: clearHover.containsMouse; ToolTip.text: "Очистить уведомления"; MouseArea { id: clearHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton } }
                Button { text: "×"; tint: "transparent"; onClicked: root.opened = false }
            }
            Rectangle { x: 16; y: 45; width: parent.width-32; height: 1; color: Rice.Theme.color("#25ffffff") }
            // Compact control deck, part of the notification surface.
            Column {
                id: deck
                x: 16; y: 58; width: parent.width-32; spacing: 12
                Column {
                    width: parent.width; spacing: 7
                    Repeater {
                        model: root.batteries
                        Item {
                            id: batteryRow
                            required property var modelData
                            width: deck.width; height: 48
                            opacity: modelData.stale ? .6 : 1
                            HoverHandler { id: batteryHover }
                            ToolTip.visible: batteryHover.hovered && (!!modelData.statusText || (!!modelData.status && modelData.status !== "ok"))
                            ToolTip.text: modelData.statusText || (modelData.status === "permission-denied" ? "Нет доступа к приёмнику мыши" : (modelData.percentage === null ? "Приёмник не передал заряд. Разбудите мышь движением." : "Последнее измерение · мышь спит"))
                            Label { text: batteryRow.modelData.isLaptopBattery ? root.laptopName : ((/mouse/i.test(batteryRow.modelData.model) ? "󰍽  " : /key/i.test(batteryRow.modelData.model) ? "󰌌  " : /head|buds|pods|ear|hyperx|stinger/i.test(batteryRow.modelData.model) ? "󰋋  " : "󰂯  ") + (batteryRow.modelData.model || "Устройство")); width: parent.width-36; elide: Text.ElideRight; font.pixelSize: (11 * Rice.Theme.textScale); color: Rice.Theme.color("#d5cbdf") }
                            Label {
                                anchors.right: parent.right; anchors.rightMargin: 9
                                text: batteryRow.modelData.state === 1 ? "󰂄" : "󰁹"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: (18 * Rice.Theme.textScale)
                                color: batteryRow.modelData.percentage < .2 ? Rice.Theme.color("#e5a5a5") : Rice.Theme.color("#c4b2d8")
                            }
                            Label { y: 22; anchors.right: parent.right; text: (batteryRow.modelData.state === 1 ? "↗ " : "") + (batteryRow.modelData.percentage === null ? "Заряд недоступен" : (batteryRow.modelData.estimated ? "≈" : "") + Math.round(batteryRow.modelData.percentage*100) + "%"); font.pixelSize: (11 * Rice.Theme.textScale); font.family: "JetBrains Mono" }
                            Rectangle {
                                y: 42; width: parent.width; height: 3; radius: 2; color: Rice.Theme.color("#25ffffff")
                                Rectangle { height: 3; radius: 2; visible: batteryRow.modelData.percentage !== null; width: parent.width * Math.max(0,Math.min(1,batteryRow.modelData.percentage)); color: batteryRow.modelData.percentage < .2 ? Rice.Theme.color("#e5a5a5") : Rice.Theme.color("#c4b2d8"); Behavior on width { NumberAnimation { duration: 250 } } }
                            }
                        }
                    }
                    Label { visible: root.batteries.length === 0; text: "Питание от сети"; color: Rice.Theme.color("#b8a9c8"); font.pixelSize: (11 * Rice.Theme.textScale) }
                }
                Label {
                    width: parent.width
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    font.pixelSize: (12 * Rice.Theme.textScale); color: Rice.Theme.color("#d5cbdf")
                }
                Row {
                    width: parent.width; spacing: 16
                    Level { width: (deck.width-16)/2; glyph: "󰕾"; value: root.volume; onChanged: amount => { root.volume = amount; root.sh(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(amount*100)+"%"]); } }
                    Level { width: (deck.width-16)/2; glyph: "󰃠"; value: root.brightness; onChanged: amount => { root.brightness = amount; root.sh(["brightnessctl", "set", Math.max(1,Math.round(amount*100))+"%"]); } }
                }
                Rectangle {
                    width: parent.width; height: 56; radius: 12; color: Rice.Theme.color("#25211c30"); border.width: 1; border.color: Rice.Theme.color("#18ffffff")
                    Flickable {
                        anchors.fill: parent; anchors.margins: 6
                        contentWidth: runningRow.width; contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds; clip: true
                        Row {
                            id: runningRow
                            x: Math.max(0, (parent.width - width) / 2)
                            spacing: 8
                            Repeater {
                                model: root.runningApps
                                Item {
                                    id: app
                                    required property var modelData
                                    width: 40; height: 42
                                    Rectangle { anchors.fill: parent; radius: 9; color: appHover.containsMouse ? Rice.Theme.color("#30ffffff") : (app.modelData.active ? Rice.Theme.color("#25bba5d5") : "transparent") }
                                    Image {
                                        anchors.centerIn: parent; anchors.verticalCenterOffset: -2
                                        width: appHover.containsMouse ? 31 : 27; height: width
                                        property bool failed: false
                                        source: failed ? Qt.resolvedUrl("app.svg") : root.iconSource(app.modelData.icon)
                                        onSourceChanged: if (failed && source !== Qt.resolvedUrl("app.svg")) failed = false
                                        onStatusChanged: if (status === Image.Error) failed = true
                                        Behavior on width { NumberAnimation { duration: 100 } }
                                    }
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2; width: app.modelData.active ? 12 : 4; height: 3; radius: 2
                                        color: app.modelData.active ? Rice.Theme.color("#dfcff1") : Rice.Theme.color("#aa9bbd")
                                    }
                                    MouseArea { id: appHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.focusApp(app.modelData) }
                                    ToolTip.visible: appHover.containsMouse
                                    ToolTip.text: app.modelData.name + (app.modelData.windows.length > 1 ? " · окон: " + app.modelData.windows.length : "")
                                }
                            }
                        }
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 2 }
                    }
                    Label { anchors.centerIn: parent; visible: root.runningApps.length === 0; text: "Нет открытых приложений"; color: Rice.Theme.color("#aa9bbd"); font.pixelSize: (11 * Rice.Theme.textScale) }

                }
            }
            MouseArea {
                id: resizeHandle
                anchors.left: parent.left; anchors.bottom: parent.bottom
                width: 26; height: 26; z: 10
                hoverEnabled: true; cursorShape: Qt.SizeBDiagCursor
                property point origin
                property int initialWidth
                property int initialHeight
                onPressed: mouse => {
                    origin = mapToGlobal(mouse.x, mouse.y);
                    initialWidth = panel.width; initialHeight = panel.height;
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const point = mapToGlobal(mouse.x, mouse.y);
                    preferences.panelWidth = Math.round(Math.max(320, Math.min(panel.screen.width - 24, initialWidth + origin.x - point.x)));
                    preferences.panelHeight = Math.round(Math.max(380, Math.min(panel.screen.height - 24, initialHeight + point.y - origin.y)));
                }
                onDoubleClicked: { preferences.panelWidth = 380; preferences.panelHeight = 650; }
                Label { anchors.centerIn: parent; text: "◺"; color: resizeHandle.containsMouse ? Rice.Theme.color("#eee3fa") : Rice.Theme.color("#81718e"); font.pixelSize: (17 * Rice.Theme.textScale) }
            }
            Rectangle { id: divider; x: 16; y: deck.y + deck.height + 14; width: parent.width-32; height: 1; color: Rice.Theme.color("#25ffffff") }
            Flickable {
                id: notificationList
                x: 12; y: divider.y + 12; width: parent.width-24; height: Math.max(0,parent.height-y-14)
                contentHeight: cards.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Column {
                    id: cards; width: notificationList.width; spacing: 9
                    Repeater { model: server.trackedNotifications.values.slice().reverse(); Card { required property var modelData; width: cards.width; notification: modelData } }
                }
            }
            Item {
                x: notificationList.x; y: notificationList.y
                width: notificationList.width; height: notificationList.height
                clip: true
                visible: server.trackedNotifications.values.length === 0
                Column {
                    anchors.centerIn: parent; spacing: 8
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "󰂚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: (23 * Rice.Theme.textScale); color: Rice.Theme.color("#897998") }
                    Label { text: "Нет уведомлений"; color: Rice.Theme.color("#aa9bbd"); font.pixelSize: (11 * Rice.Theme.textScale) }
                }
            }
        }
    }
    PanelWindow {
        visible: root.toast !== null && !root.opened && !root.dnd
        anchors { top: true; right: true }
        margins { top: 8; right: 12 }
        implicitWidth: 380; implicitHeight: toastCard.implicitHeight
        color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-notification-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        Card { id: toastCard; anchors.fill: parent; notification: root.toast }
    }
}
