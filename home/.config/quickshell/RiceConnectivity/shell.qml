pragma ComponentBehavior: Bound
// Wi-Fi and Bluetooth popups, derived from 0-ss/MacShell (MIT). See SOURCE.md and LICENSE.
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    readonly property color accent: Rice.Theme.color("#b49ad9")
    readonly property var pal: ({ fg: Rice.Theme.color("#eee7fa"), fg2: Rice.Theme.color("#b3a6c4"), fg3: Rice.Theme.color("#827a94"), sep: Rice.Theme.color("#36beaaDD"), hover: Rice.Theme.color("#364a3b60"), btnOff: Rice.Theme.color("#604a3b60"), switchOff: Rice.Theme.color("#55504661"), dark: true, fam: "Noto Sans" })
    function tr(text) { return text; }
    function fontForWeight(weight, family) { return family; }
    function sh(command) { Quickshell.execDetached(["sh", "-c", command]); }
    property bool liquidActive: true
    property url glassShaderUrl: Qt.resolvedUrl("liquidglass.frag.qsb")
    property real glassLiquid: 1
    property real glassRim: 0.45
    property real glassGrain: 0.03
    property real glassOpacity: 0.42 * Rice.Theme.glassOpacity
    property color menuBorderColor: Rice.Theme.color("#b49ad9")
    property string glassState: "ready"
    component PSwitch: GlassSwitch {
        required property var t
        accentColor: root.accent
        offColor: t.switchOff
        dark: true
        baseColor: Rice.Theme.color("#211c30")
        glass: root.liquidActive && root.glassState !== "failed"
        shaderUrl: root.glassShaderUrl
        glassLiquid: root.glassLiquid
        glassRim: root.glassRim
        glassGrain: root.glassGrain
        glassTint: root.glassOpacity
        borderTint: root.menuBorderColor
        onGlassFailed: root.glassState = "failed"
    }
    QtObject {
        id: ui
        property string pop: ""
        property string wifiPrompt: ""
        function wifiPick(n) {
            if (n.inUse) { root.disconnectWifi(); return; }
            if (root.wifiBusy !== "") return;
            if (n.secure && !n.saved) { wifiPrompt = wifiPrompt === n.ssid ? "" : n.ssid; return; }
            wifiPrompt = "";
            root.connectWifi(n.ssid, "");
        }
        function wifiSubmit(ssid, password) {
            if (!password) return;
            wifiPrompt = "";
            root.connectWifi(ssid, password);
        }
    }
    IpcHandler {
        target: "connectivity"
        function toggle(mode: string): void {
            if (mode !== "wifi" && mode !== "bluetooth") return;
            ui.wifiPrompt = "";
            ui.pop = ui.pop === mode ? "" : mode;
            if (ui.pop === "wifi") { root.refreshWifi(); root.scanWifi(); }
            if (ui.pop === "bluetooth") { root.refreshBt(); }
        }
        function close(): void { ui.pop = ""; }
    }
    // Free RAM: exit a minute after the popup closes; connectivity-widget relaunches it.
    Timer { interval: 60000; running: ui.pop === ""; onTriggered: Qt.quit() }
    Timer { interval: 6000; repeat: true; running: ui.pop === "wifi" && ui.wifiPrompt === ""; onTriggered: root.scanWifi() }
    Timer { interval: 15000; repeat: true; running: ui.pop === "bluetooth" && root.btOn; onTriggered: root.refreshBt() }
    PanelWindow {
        id: popup
        visible: ui.pop !== ""
        screen: Quickshell.screens.find(function(s) { return Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name; }) || Quickshell.screens[0]
        anchors { top: true; right: true }
        // Waybar is 1000 logical pixels wide and centered. Align each menu
        // with its own icon in the right-hand group.
        margins {
            top: 56
            right: Math.max(10, (screen.width - Math.min(1000, screen.width)) / 2
                            + (ui.pop === "bluetooth" ? 142 : 160))
        }
        implicitWidth: 322
        implicitHeight: (content.item ? content.item.implicitHeight : 100) + 26
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-connectivity"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        HyprlandFocusGrab {
            windows: [popup]
            active: popup.visible
            onCleared: ui.pop = ""
        }
        Rectangle {
            id: pane
            anchors.fill: parent
            radius: 26
            color: Rice.Theme.color("#c2191725")
            border.width: 1
            border.color: Rice.Theme.color("#50beaadD")
            focus: true
            Keys.onEscapePressed: ui.pop = ""
            MenuBorder { anchors.fill: parent; cornerR: 26; dark: true; tint: root.menuBorderColor }
            Loader {
                id: content
                x: 12; y: 12
                width: parent.width - 24
                sourceComponent: ui.pop === "bluetooth" ? btContent : wifiContent
            }
            scale: visible ? 1 : .96
            opacity: popup.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
    // wifi
    property bool wifiOn: true
    property string wifiSsid: ""
    property int wifiSignal: 0
    property bool ethernetUp: false             // a wired connection is up (shown with Apple's <···> symbol when Wi-Fi isn't in use)
    readonly property bool showEthernet: ethernetUp && wifiSsid === ""
    readonly property int wifiLevel: !wifiOn ? 0 : (wifiSsid === "" ? 0 : (wifiSignal > 66 ? 3 : (wifiSignal > 33 ? 2 : 1)))
    function refreshWifi() { if (!wifiProc.running) wifiProc.running = true; }
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null; nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -n1; echo; nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$' && echo eth || echo -"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                root.wifiOn = (l[0] || "").trim() === "enabled";
                root.ethernetUp = l.some(function (x) { return x.trim() === "eth"; });
                var a = (l[1] || "").trim();
                if (a !== "") {
                    var parts = a.split(":");
                    root.wifiSignal = parseInt(parts[parts.length - 1]) || 0;
                    root.wifiSsid = parts.slice(1, parts.length - 1).join(":").replace(/\\/g, "");
                } else { root.wifiSsid = ""; root.wifiSignal = 0; }
            }
        }
    }
    function toggleWifi() {
        root.wifiOn = !root.wifiOn;
        Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]);
        settleTimer.restart();
    }

    // wifi network list (feeds the Wi-Fi popover)
    property var wifiNets: []                  // [{ ssid, signal, secure, inUse, saved }]
    property bool wifiScanning: false
    property string wifiBusy: ""               // ssid currently being joined
    property string wifiError: ""
    function sigLevel(s) { return s > 66 ? 3 : (s > 33 ? 2 : 1); }
    // split an `nmcli -t` line on unescaped colons (and unescape \: and \\)
    function splitNm(line) {
        var out = [], cur = "";
        for (var i = 0; i < line.length; i++) {
            var c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }
    function nmErr(t) {
        var s = (t || "").trim().split("\n")[0].replace(/^Error:\s*/, "");
        if (/secrets were required|no secrets|password/i.test(s)) return "Incorrect password.";
        if (/no network with ssid|not found/i.test(s)) return "Network not found.";
        return s !== "" ? s : "Couldn't join the network.";
    }
    function scanWifi() {
        if (wifiListProc.running) return;
        wifiScanning = true;
        wifiListProc.running = true;
    }
    Process {
        id: wifiListProc
        command: ["sh", "-c",
            "nmcli dev wifi rescan >/dev/null 2>&1; "
            + "nmcli -t -f NAME,TYPE connection show 2>/dev/null | sed -n 's/:802-11-wireless$//p' | sed 's/^/S:/'; "
            + "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null | sed 's/^/N:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n"), saved = {}, best = {}, i, f;
                for (i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("S:") === 0) saved[root.splitNm(lines[i].substring(2))[0]] = true;
                }
                for (i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("N:") !== 0) continue;
                    f = root.splitNm(lines[i].substring(2));
                    if (f.length < 4 || f[1] === "") continue;
                    var ssid = f[1], sig = parseInt(f[2]) || 0, sec = f[3];
                    var n = { ssid: ssid, signal: sig, secure: (sec !== "" && sec !== "--"),
                              inUse: f[0] === "*", saved: saved[ssid] === true };
                    var o = best[ssid];
                    if (!o) best[ssid] = n;
                    else {
                        if (n.signal > o.signal) o.signal = n.signal;
                        if (n.inUse) o.inUse = true;
                    }
                }
                var arr = [];
                for (var k in best) arr.push(best[k]);
                arr.sort(function (a, b) {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
                    return b.signal - a.signal;
                });
                if (JSON.stringify(arr) !== JSON.stringify(root.wifiNets)) root.wifiNets = arr;
                root.wifiScanning = false;
            }
        }
        onExited: root.wifiScanning = false
    }
    function connectWifi(ssid, pw) {
        if (wifiConnProc.running) return;
        wifiError = "";
        wifiBusy = ssid;
        var cmd = ["nmcli", "--wait", "25", "dev", "wifi", "connect", ssid];
        if (pw && pw !== "") {
            wifiConnProc.command = ["python3", Qt.resolvedUrl("connect-wifi.py").toString().replace("file://", ""), ssid];
            wifiConnProc.stdinEnabled = true;
            wifiConnProc.running = true;
            wifiConnProc.write(pw + "\n");
            wifiConnProc.stdinEnabled = false;
            return;
        }
        wifiConnProc.command = cmd;
        wifiConnProc.running = true;
    }
    Process {
        id: wifiConnProc
        stdinEnabled: true
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") root.wifiError = root.nmErr(text) }
        onExited: (code, status) => {
            root.wifiBusy = "";
            if (code !== 0 && root.wifiError === "") root.wifiError = "Couldn't join the network.";
            if (code === 0) root.wifiError = "";
            wifiAfter.restart();
        }
    }
    function disconnectWifi() {
        sh("nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -n1 | xargs -r nmcli dev disconnect");
        wifiAfter.restart();
    }
    Timer { id: wifiAfter; interval: 1200; onTriggered: { root.scanWifi(); root.refreshWifi(); } }
    // BLUETOOTH
    property bool btOn: false
    property int btConnected: 0
    property string btConnectedName: ""
    property bool btScanning: false
    property var btDevices: []             // [ { mac, name, icon, connected, paired } ]
    property string btBusy: ""             // mac of device currently connecting/disconnecting
    property string btError: ""

    function btIconFor(name) {
        var n = (name || "").toLowerCase();
        if (n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0 || n.indexOf("earbud") >= 0 || n.indexOf("airpod") >= 0 || n.indexOf("buds") >= 0 || n.indexOf("wh-") >= 0 || n.indexOf("wf-") >= 0) return "headphones";
        if (n.indexOf("mouse") >= 0 || n.indexOf("trackpad") >= 0 || n.indexOf("magic mouse") >= 0) return "mouse";
        if (n.indexOf("keyboard") >= 0 || n.indexOf("keychron") >= 0) return "keyboard";
        if (n.indexOf("speaker") >= 0 || n.indexOf("soundbar") >= 0 || n.indexOf("echo") >= 0 || n.indexOf("homepod") >= 0) return "speaker";
        if (n.indexOf("controller") >= 0 || n.indexOf("gamepad") >= 0 || n.indexOf("xbox") >= 0 || n.indexOf("dualshock") >= 0 || n.indexOf("dualsense") >= 0) return "gamepad";
        if (n.indexOf("phone") >= 0 || n.indexOf("iphone") >= 0 || n.indexOf("galaxy") >= 0 || n.indexOf("pixel") >= 0) return "phone";
        return "bluetooth";
    }

    function refreshBt() { if (!btProc.running) btProc.running = true; }
    // One line per known device: D:<mac> <paired 0|1> <connected 0|1> <battery %> <name>   (tab separated).
    // Every device is asked with "bluetoothctl info", because the "devices Paired|Connected" filters only exist in
    // newer BlueZ versions: older ones ignore the argument and print every device (so everything looked connected).
    Process {
        id: btProc
        command: ["sh", "-c",
            "p=$(timeout 4 bluetoothctl show 2>/dev/null </dev/null | grep -i 'Powered:' | head -n1); echo \"P:$p\"; "
            + "timeout 4 bluetoothctl devices 2>/dev/null </dev/null | while read -r _ mac name; do "
            + "[ -n \"$mac\" ] || continue; "
            + "i=$(timeout 3 bluetoothctl info \"$mac\" 2>/dev/null </dev/null); "
            + "pr=$(printf '%s\\n' \"$i\" | grep -Ec 'Paired: yes|Bonded: yes'); "
            + "c=$(printf '%s\\n' \"$i\" | grep -c 'Connected: yes'); "
            + "b=$(printf '%s\\n' \"$i\" | sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\\([0-9]*\\)).*/\\1/p' | head -n1); "
            + "printf 'D:%s\\t%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$pr\" \"$c\" \"$b\" \"$name\"; "
            + "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n"), on = false, devList = [], connCount = 0, firstConnName = "", i;
                for (i = 0; i < lines.length; i++) {
                    var l = lines[i].replace(/\r$/, "");
                    if (!l) continue;
                    if (l.indexOf("P:") === 0) { on = l.toLowerCase().indexOf("yes") >= 0; continue; }
                    if (l.indexOf("D:") !== 0) continue;
                    var f = l.substring(2).split("\t");
                    if (f.length < 5 || !f[0]) continue;
                    var mac = f[0], isPair = f[1] === "1", isConn = f[2] === "1", name = (f[4] || "").trim() || mac;
                    // BlueZ names an unnamed device after its address with dashes: show those last
                    if (isConn) { connCount++; if (!firstConnName) firstConnName = name; }
                    devList.push({ mac: mac, name: name, connected: isConn, paired: isPair, bat: f[3] || "", icon: root.btIconFor(name) });
                }
                root.btOn = on;
                devList.sort(function (a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1;
                    if (a.paired !== b.paired) return a.paired ? -1 : 1;
                    return a.name.localeCompare(b.name);
                });
                root.btConnected = connCount;
                root.btConnectedName = connCount === 1 ? firstConnName : (connCount > 1 ? connCount + " Connected" : "");
                if (JSON.stringify(devList) !== JSON.stringify(root.btDevices)) root.btDevices = devList;
            }
        }
    }

    // Discovery only lasts while bluetoothctl stays alive (BlueZ stops it when the client exits), so "scan on" has to
    // run for a while with --timeout instead of being fired and forgotten.
    function scanBt() {
        if (!root.btOn || btScanProc.running) return;
        root.btScanning = true;
        btScanProc.running = true;
    }
    Process {
        id: btScanProc
        command: ["sh", "-c", "bluetoothctl --timeout 10 scan on >/dev/null 2>&1 </dev/null; exit 0"]
        onExited: {
            root.btScanning = false;
            root.refreshBt();
        }
    }
    Timer { interval: 2500; repeat: true; running: root.btScanning; onTriggered: root.refreshBt() }

    function connectBt(mac, connected) {
        if (btActionProc.running || !mac) return;
        var device = root.btDevices.find(function(d) { return d.mac === mac; });
        if (!connected && device && !device.paired) {
            Quickshell.execDetached(["blueman-manager"]);
            root.btError = "Complete pairing in the Bluetooth window, then connect here.";
            return;
        }
        root.btError = "";
        root.btBusy = mac;
        if (connected) {
            btActionProc.command = ["sh", "-c", "bluetoothctl disconnect \"$1\" >/dev/null 2>&1 </dev/null; exit 0", "sh", mac];
        } else {
            // pair first when needed (with a simple agent, no PIN prompt), trust, then connect
            btActionProc.command = ["sh", "-c",
                "d=\"$1\"; "
                + "fail() { m=$(printf '%s\\n' \"$1\" | grep -iE 'fail|error|not available|timeout|rejected|canceled' | tail -n1); "
                + "[ -n \"$m\" ] || m=\"$2\"; echo \"$m\" >&2; exit 1; }; "
                + "if ! bluetoothctl info \"$d\" 2>/dev/null </dev/null | grep -qE 'Paired: yes|Bonded: yes'; then "
                + "o=$(timeout 45 bluetoothctl --agent NoInputNoOutput pair \"$d\" 2>&1 </dev/null); "
                + "printf '%s\\n' \"$o\" | grep -qi 'Pairing successful' || fail \"$o\" 'Could not pair. Put the device in pairing mode and try again.'; "
                + "fi; "
                + "bluetoothctl trust \"$d\" >/dev/null 2>&1 </dev/null; "
                + "o=$(timeout 25 bluetoothctl connect \"$d\" 2>&1 </dev/null); "
                + "printf '%s\\n' \"$o\" | grep -qi 'Connection successful' || fail \"$o\" 'Could not connect to the device.'",
                "sh", mac];
        }
        btActionProc.running = true;
    }
    Process {
        id: btActionProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") root.btError = text.trim(); }
        onExited: (code, status) => {
            root.btBusy = "";
            if (code !== 0 && root.btError === "") root.btError = "Failed to connect to device.";
            btAfter.restart();
        }
    }
    Timer { id: btAfter; interval: 800; onTriggered: root.refreshBt() }

    // power: a soft-blocked adapter (rfkill, e.g. after Airplane Mode) refuses "power on", so unblock it first
    function toggleBt() {
        root.btOn = !root.btOn;
        Quickshell.execDetached(["sh", "-c",
            root.btOn ? "rfkill unblock bluetooth 2>/dev/null; sleep 0.3; bluetoothctl power on"
                      : "bluetoothctl power off"]);
        settleTimer.interval = 1500;
        settleTimer.restart();
    }
    readonly property bool airplane: !wifiOn && !btOn
    function toggleAirplane() {
        sh(airplane ? "rfkill unblock all; sleep 0.5; bluetoothctl power on" : "rfkill block all");
        wifiOn = airplane; btOn = airplane;
        settleTimer.restart();
    }
    Timer { id: settleTimer; interval: 900; onTriggered: { root.refreshWifi(); root.refreshBt(); } }
    Timer { interval: 6000; repeat: true; running: ui.pop !== ""; triggeredOnStart: true; onTriggered: { root.refreshWifi(); root.refreshBt(); } }

                Component {
                    id: wifiContent
                    Column {
                        id: wifiCol
                        property var pp: pal                // palette: the panel palette in the popover, ccPal in the Control Center
                        property bool showBack: false       // Control Center page: show the back arrow
                        signal back()
                        width: parent ? parent.width : 296
                        spacing: 6

                        // header: title + on/off switch
                        Item {
                            width: parent.width; height: 32
                            Item {
                                visible: wifiCol.showBack
                                x: 0; width: 30; height: parent.height
                                WGlyph { anchors.centerIn: parent; width: 12; height: 12; kind: "chevL"; color: pp.fg }
                                MouseArea { anchors.fill: parent; onClicked: wifiCol.back() }
                            }
                            Text {
                                x: wifiCol.showBack ? 30 : 6; anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("Wi-Fi")
                                color: pp.fg
                                font.family: pp.fam; font.pixelSize: (15 * Rice.Theme.textScale); font.weight: Font.DemiBold
                            }
                            PSwitch {
                                t: pp
                                anchors.right: parent.right; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.wifiOn
                                onToggled: { root.toggleWifi(); wifiAfter.restart(); }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: pp.sep }
                        Text {
                            visible: !root.wifiOn
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: root.tr("Wi-Fi is turned off")
                            color: pp.fg2
                            font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                        }
                        Text {
                            visible: root.wifiOn && root.wifiNets.length === 0
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: root.wifiScanning ? root.tr("Searching\u2026") : root.tr("No networks found")
                            color: pp.fg2
                            font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                        }
                        Text {
                            visible: root.wifiOn && root.wifiNets.length > 0
                            leftPadding: 6
                            text: root.tr("Networks")
                            color: pp.fg2
                            font.family: pp.fam; font.pixelSize: (11 * Rice.Theme.textScale); font.weight: Font.DemiBold
                        }

                        // the list
                        Flickable {
                            id: wifiFlick
                            visible: root.wifiOn && root.wifiNets.length > 0
                            width: parent.width
                            height: Math.min(wifiList.height, 300)
                            contentWidth: width
                            contentHeight: wifiList.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: wifiList
                                width: wifiFlick.width
                                Repeater {
                                    model: root.wifiNets
                                    delegate: Column {
                                        id: nr
                                        required property var modelData
                                        readonly property bool busy: root.wifiBusy === modelData.ssid
                                        readonly property bool prompting: ui.wifiPrompt === modelData.ssid
                                        width: wifiList.width

                                        Item {
                                            width: parent.width; height: 38
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                color: root.accent
                                                visible: wma.containsMouse
                                            }
                                            WGlyph {
                                                visible: nr.modelData.inUse
                                                x: 9; anchors.verticalCenter: parent.verticalCenter
                                                width: 14; height: 14
                                                kind: "check"
                                                color: wma.containsMouse ? "white" : pp.fg
                                            }
                                            Text {
                                                x: 30
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 30 - 96
                                                elide: Text.ElideRight
                                                text: nr.modelData.ssid
                                                color: wma.containsMouse ? "white" : pp.fg
                                                font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                                                font.weight: nr.modelData.inUse ? Font.DemiBold : Font.Normal
                                            }
                                            Text {
                                                visible: nr.busy
                                                anchors.right: parent.right; anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.tr("Connecting\u2026")
                                                color: pp.fg2
                                                font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                            }
                                            Text {
                                                visible: !nr.busy && nr.modelData.inUse && wma.containsMouse
                                                anchors.right: parent.right; anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.tr("Disconnect")
                                                color: "white"
                                                font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                            }
                                            Row {
                                                visible: !nr.busy && !(nr.modelData.inUse && wma.containsMouse)
                                                anchors.right: parent.right; anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 7
                                                WGlyph {
                                                    visible: nr.modelData.secure
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 13; height: 13
                                                    kind: "lock"
                                                    color: wma.containsMouse ? "white" : pp.fg2
                                                }
                                                WGlyph {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 16; height: 16
                                                    kind: "wifi"; level: root.sigLevel(nr.modelData.signal)
                                                    color: wma.containsMouse ? "white" : pp.fg
                                                }
                                            }
                                            MouseArea {
                                                id: wma
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !nr.busy
                                                onClicked: ui.wifiPick(nr.modelData)
                                            }
                                        }

                                        // password field (secured network that has no saved profile)
                                        Item {
                                            visible: nr.prompting
                                            width: parent.width; height: 42
                                            Rectangle {
                                                x: 30; y: 3
                                                width: parent.width - 30 - 4; height: 32; radius: 10
                                                color: pp.btnOff
                                            }
                                            Text {
                                                x: 42; y: 3; height: 32
                                                verticalAlignment: Text.AlignVCenter
                                                visible: pw.text === ""
                                                text: root.tr("Password")
                                                color: pp.fg3
                                                font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                                            }
                                            TextInput {
                                                id: pw
                                                x: 42; y: 3
                                                width: parent.width - 42 - 62; height: 32
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                echoMode: TextInput.Password
                                                color: pp.fg
                                                selectionColor: root.accent
                                                selectedTextColor: "white"
                                                font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                                Keys.onPressed: event => {
                                                    if (event.key === Qt.Key_Escape) { ui.wifiPrompt = ""; event.accepted = true; }
                                                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                        ui.wifiSubmit(nr.modelData.ssid, text); event.accepted = true;
                                                    }
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right; anchors.rightMargin: 16
                                                y: 3; height: 32
                                                verticalAlignment: Text.AlignVCenter
                                                text: root.tr("Join")
                                                color: pw.text.length > 0 ? root.accent : pp.fg3
                                                font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale); font.weight: Font.DemiBold
                                                MouseArea {
                                                    anchors.fill: parent; anchors.margins: -6
                                                    onClicked: ui.wifiSubmit(nr.modelData.ssid, pw.text)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.wifiError !== ""
                            width: parent.width
                            leftPadding: 6; rightPadding: 6
                            wrapMode: Text.WordWrap
                            text: root.wifiError
                            color: Rice.Theme.color("#FF6961")
                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                        }

                        Rectangle { width: parent.width; height: 1; color: pp.sep }
                        Item {
                            width: parent.width; height: 30
                            Rectangle {
                                anchors.fill: parent; radius: 8
                                color: root.accent
                                visible: wsa.containsMouse
                            }
                            Text {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("Refresh Networks")
                                color: wsa.containsMouse ? "white" : pp.fg
                                font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                            }
                            MouseArea {
                                id: wsa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { root.scanWifi(); }
                            }
                        }
                    }
                }

                Component {
                    id: btContent
                    Column {
                        id: btCol
                        property var pp: pal                // palette: the panel palette in the popover, ccPal in the Control Center
                        property bool showBack: false       // Control Center page: show the back arrow
                        signal back()
                        width: parent ? parent.width : 296
                        spacing: 6

                        // header: title + on/off switch
                        Item {
                            width: parent.width; height: 32
                            Item {
                                visible: btCol.showBack
                                x: 0; width: 30; height: parent.height
                                WGlyph { anchors.centerIn: parent; width: 12; height: 12; kind: "chevL"; color: pp.fg }
                                MouseArea { anchors.fill: parent; onClicked: btCol.back() }
                            }
                            Text {
                                x: btCol.showBack ? 30 : 6; anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("Bluetooth")
                                color: pp.fg
                                font.family: pp.fam; font.pixelSize: (15 * Rice.Theme.textScale); font.weight: Font.DemiBold
                            }
                            PSwitch {
                                t: pp
                                anchors.right: parent.right; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.btOn
                                onToggled: root.toggleBt()
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: pp.sep }

                        Text {
                            visible: !root.btOn
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: root.tr("Bluetooth is turned off")
                            color: pp.fg2
                            font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                        }

                        Text {
                            visible: root.btOn && root.btDevices.length === 0
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: root.btScanning ? root.tr("Searching for devices\u2026") : root.tr("No devices found")
                            color: pp.fg2
                            font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                        }

                        Item {
                            visible: root.btOn && root.btDevices.length > 0
                            width: parent.width; height: 22
                            Text {
                                x: 6; anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("Devices")
                                color: pp.fg2
                                font.family: pp.fam; font.pixelSize: (11 * Rice.Theme.textScale); font.weight: Font.DemiBold
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    visible: root.btScanning
                                    text: root.tr("Scanning\u2026")
                                    color: pp.fg2; font.family: pp.fam; font.pixelSize: (11 * Rice.Theme.textScale)
                                }
                                Text {
                                    visible: !root.btScanning
                                    text: root.tr("Scan")
                                    color: root.accent; font.family: pp.fam; font.pixelSize: (11 * Rice.Theme.textScale); font.weight: Font.DemiBold
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.scanBt() }
                                }
                            }
                        }

                        // the list
                        Flickable {
                            id: btFlick
                            visible: root.btOn && root.btDevices.length > 0
                            width: parent.width
                            height: Math.min(btList.height, 300)
                            contentWidth: width
                            contentHeight: btList.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: btList
                                width: btFlick.width
                                Repeater {
                                    model: root.btDevices
                                    delegate: Item {
                                        id: devRow
                                        required property var modelData
                                        readonly property bool busy: root.btBusy === modelData.mac
                                        width: btList.width; height: 38

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: root.accent
                                            visible: bma.containsMouse
                                        }

                                        WGlyph {
                                            visible: devRow.modelData.connected
                                            x: 9; anchors.verticalCenter: parent.verticalCenter
                                            width: 14; height: 14
                                            kind: "check"
                                            color: bma.containsMouse ? "white" : pp.fg
                                        }
                                        WGlyph {
                                            visible: !devRow.modelData.connected
                                            x: 9; anchors.verticalCenter: parent.verticalCenter
                                            width: 14; height: 14
                                            kind: devRow.modelData.icon || "bluetooth"
                                            color: bma.containsMouse ? "white" : pp.fg2
                                        }

                                        Text {
                                            x: 30
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 30 - 100
                                            elide: Text.ElideRight
                                            text: devRow.modelData.name || devRow.modelData.mac
                                            color: bma.containsMouse ? "white" : pp.fg
                                            font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                                            font.weight: devRow.modelData.connected ? Font.DemiBold : Font.Normal
                                        }

                                        Text {
                                            visible: devRow.busy
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: devRow.modelData.connected ? root.tr("Disconnecting\u2026") : root.tr("Connecting\u2026")
                                            color: bma.containsMouse ? "white" : pp.fg2
                                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                        }

                                        Text {
                                            visible: !devRow.busy && devRow.modelData.connected && bma.containsMouse
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.tr("Disconnect")
                                            color: "white"
                                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                        }

                                        Text {
                                            visible: !devRow.busy && devRow.modelData.connected && !bma.containsMouse
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.tr("Connected")
                                            color: pp.fg2
                                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                        }

                                        Text {
                                            visible: !devRow.busy && !devRow.modelData.connected && bma.containsMouse
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.tr("Connect")
                                            color: "white"
                                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                        }

                                        Text {
                                            visible: !devRow.busy && !devRow.modelData.connected && !bma.containsMouse && devRow.modelData.paired
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.tr("Paired")
                                            color: pp.fg2
                                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                                        }

                                        MouseArea {
                                            id: bma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !devRow.busy
                                            onClicked: root.connectBt(devRow.modelData.mac, devRow.modelData.connected)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.btError !== ""
                            width: parent.width
                            leftPadding: 6; rightPadding: 6
                            wrapMode: Text.WordWrap
                            text: root.btError
                            color: Rice.Theme.color("#FF6961")
                            font.family: pp.fam; font.pixelSize: (12 * Rice.Theme.textScale)
                        }

                        Rectangle { width: parent.width; height: 1; color: pp.sep }
                        Item {
                            width: parent.width; height: 30
                            Rectangle {
                                anchors.fill: parent; radius: 8
                                color: root.accent
                                visible: bsa.containsMouse
                            }
                            Text {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("Scan for Devices")
                                color: bsa.containsMouse ? "white" : pp.fg
                                font.family: pp.fam; font.pixelSize: (13 * Rice.Theme.textScale)
                            }
                            MouseArea {
                                id: bsa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { root.scanBt(); }
                            }
                        }
                    }
                }


}
