pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property var settings: ({width:600,height:454,columns:6,rows:3,iconSize:35,showSearch:true,showCategories:true,showLabels:true})
    readonly property int columns: Math.max(1,Math.min(settings.columns,Math.floor((window.width-48)/Math.max(64,settings.iconSize+20))))
    readonly property int rows: Math.max(1,Math.min(settings.rows,Math.floor(grid.height/(settings.iconSize+(settings.showLabels ? 48 : 24)))))
    readonly property real searchHeight: settings.showSearch ? 52 : 0
    readonly property real categoryTop: settings.showSearch ? 64 : 0
    readonly property real resultsTop: settings.showCategories ? categoryTop+categoryFlow.height+12 : settings.showSearch ? 64 : 0
    FileView {
        path: Quickshell.env("HOME")+"/.config/rice-theme/apps.json"
        watchChanges: true;preload: true;printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {root.settings=Object.assign({},root.settings,JSON.parse(text()));if(!root.settings.showSearch){root.query="";search.text="";}if(!root.settings.showCategories)root.category="";if(root.opened)Qt.callLater(root.focusSearch);}catch(e){console.warn("App searcher settings:",e);}
        }
    }
    function focusSearch() { if(settings.showSearch)search.forceActiveFocus();else pane.forceActiveFocus(); }
    property bool opened: false
    property string query: ""
    property string category: ""
    readonly property var favorites: ["kitty","org.kde.dolphin","google-chrome","code","org.telegram.desktop","discord","spotify"]
    readonly property var filters: [
        { label: "Все", id: "" }, { label: "Интернет", id: "Network" },
        { label: "Работа", id: "Work" }, { label: "Медиа", id: "AudioVideo" }, { label: "Игры", id: "Game" }
    ]
    readonly property var apps: {
        var q = query.trim().toLocaleLowerCase();
        return DesktopEntries.applications.values.filter(function(app) {
            if (app.noDisplay || !app.name || !app.execString) return false;
            var cats = app.categories || [];
            if (category === "Work") { if (cats.indexOf("Development") < 0 && cats.indexOf("Office") < 0) return false; }
            else if (category && cats.indexOf(category) < 0) return false;
            var words = q.split(/\s+/);
            var text = (app.name+" "+app.genericName+" "+app.id+" "+(app.keywords || []).join(" ")).toLocaleLowerCase();
            return words.every(function(word) { return text.indexOf(word) >= 0; });
        }).sort(function(a,b) {
            if (q) {
                var aStart = a.name.toLocaleLowerCase().indexOf(q) === 0;
                var bStart = b.name.toLocaleLowerCase().indexOf(q) === 0;
                if (aStart !== bStart) return aStart ? -1 : 1;
            } else if (!category) {
                var ai = favorites.indexOf(a.id), bi = favorites.indexOf(b.id);
                if (ai >= 0 || bi >= 0) return (ai < 0 ? 999 : ai)-(bi < 0 ? 999 : bi);
            }
            return a.name.localeCompare(b.name);
        });
    }
    onAppsChanged: grid.currentIndex = apps.length ? 0 : -1
    function show(text) { category = ""; query = settings.showSearch ? (text || "") : ""; search.text = query; opened = true; Qt.callLater(function() { root.focusSearch(); }); }
    function launch(app) { if (!app) return; opened = false; app.execute(); }
    IpcHandler {
        target: "apps"
        function toggle(): void { if (root.opened) root.opened = false; else root.show(""); }
        function open(query: string): void { root.show(query); }
        function close(): void { root.opened = false; }
        function status(): string { return JSON.stringify({visible:root.opened,width:window.width,height:window.height,columns:root.columns,rows:root.rows,search:root.settings.showSearch}); }
    }
    PanelWindow {
        id: window
        visible: root.opened
        screen: Quickshell.screens.find(function(s) { return Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name; }) || Quickshell.screens[0]
        implicitWidth: Math.min(Math.max(360,root.settings.width),screen.width-24)
        implicitHeight: Math.min(Math.max(root.resultsTop+100,root.settings.height),screen.height-24)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "rice-apps"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        HyprlandFocusGrab { windows: [window]; active: root.opened; onCleared: root.opened = false }
        Rectangle {
            id: pane
            focus: !root.settings.showSearch
            Keys.onPressed: event => {
                if(root.settings.showSearch)return;
                if(event.key===Qt.Key_Escape){root.opened=false;event.accepted=true;}
                else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter){root.launch(root.apps[grid.currentIndex]);event.accepted=true;}
                else if(event.key===Qt.Key_Down){grid.currentIndex=Math.min(root.apps.length-1,Math.max(0,grid.currentIndex+root.columns));event.accepted=true;}
                else if(event.key===Qt.Key_Up){grid.currentIndex=Math.max(0,grid.currentIndex-root.columns);event.accepted=true;}
                else if(event.key===Qt.Key_Right){grid.currentIndex=Math.min(root.apps.length-1,grid.currentIndex+1);event.accepted=true;}
                else if(event.key===Qt.Key_Left){grid.currentIndex=Math.max(0,grid.currentIndex-1);event.accepted=true;}
            }
            anchors.fill: parent
            color: "transparent"
            Rectangle {
                x: 0; y: root.resultsTop; width: parent.width; height: parent.height-y; radius: 22
                gradient: Gradient {
                    GradientStop { position: 0; color: Rice.Theme.color("#6681679c") }
                    GradientStop { position: .48; color: Rice.Theme.color("#c72e243f") }
                    GradientStop { position: 1; color: Rice.Theme.color("#d1201a2d") }
                }
                border.width: 1; border.color: Rice.Theme.color("#57d8c0f2")
                Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 21; color: "transparent"; border.width: 1; border.color: Rice.Theme.color("#26f7e8ff") }
            }
            Rectangle {
                visible: root.settings.showSearch
                x: 0; y: 0; width: parent.width; height: 52; radius: 20
                gradient: Gradient {
                    GradientStop { position: 0; color: Rice.Theme.color("#6681679c") }
                    GradientStop { position: .48; color: Rice.Theme.color("#c72e243f") }
                    GradientStop { position: 1; color: Rice.Theme.color("#d1201a2d") }
                }
                border.width: 1; border.color: Rice.Theme.color("#57d8c0f2")
                Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 19; color: "transparent"; border.width: 1; border.color: Rice.Theme.color("#26f7e8ff") }
                Text { x: 15; anchors.verticalCenter: parent.verticalCenter; text: ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: (16 * Rice.Theme.textScale); color: Rice.Theme.color("#b49ad9") }
                Text { x: 43; anchors.verticalCenter: parent.verticalCenter; text: "Поиск приложений"; visible: !search.text; color: Rice.Theme.color("#8f819f"); font.family: Rice.Theme.fontFamily; font.pixelSize: (13 * Rice.Theme.textScale) }
                TextInput {
                    id: search
                    x: 43; width: parent.width-85; height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Rice.Theme.fontFamily; font.pixelSize: (14 * Rice.Theme.textScale)
                    color: Rice.Theme.color("#eee7fa"); selectionColor: Rice.Theme.color("#70598c"); selectedTextColor: "#fff"; clip: true
                    selectByMouse: true
                    onTextChanged: root.query = text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { root.opened = false; event.accepted = true; }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.launch(root.apps[grid.currentIndex]); event.accepted = true; }
                        else if (event.key === Qt.Key_Down) { grid.currentIndex = Math.min(root.apps.length-1,Math.max(0,grid.currentIndex+root.columns)); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { grid.currentIndex = Math.max(0,grid.currentIndex-root.columns); event.accepted = true; }
                        else if (!text && event.key === Qt.Key_Right) { grid.currentIndex = Math.min(root.apps.length-1,grid.currentIndex+1); event.accepted = true; }
                        else if (!text && event.key === Qt.Key_Left) { grid.currentIndex = Math.max(0,grid.currentIndex-1); event.accepted = true; }
                    }
                }
            }
            Flow {
                id: categoryFlow
                visible: root.settings.showCategories
                x: 12; width: parent.width-24; y: root.categoryTop; spacing: 6
                Repeater {
                    model: root.filters
                    delegate: Rectangle {
                        id: categoryTile
                        required property var modelData
                        width: categoryName.implicitWidth+24; height: 30; radius: 14
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.category === categoryTile.modelData.id ? Rice.Theme.color("#a38e71a9") : Rice.Theme.color("#6681679c") }
                            GradientStop { position: 1; color: root.category === categoryTile.modelData.id ? Rice.Theme.color("#cc5b4673") : Rice.Theme.color("#c72e243f") }
                        }
                        border.width: 1; border.color: root.category === modelData.id ? Rice.Theme.color("#99cfb3ed") : Rice.Theme.color("#57d8c0f2")
                        Text { id: categoryName; anchors.centerIn: parent; text: categoryTile.modelData.label; color: root.category === categoryTile.modelData.id ? Rice.Theme.color("#e4d3f8") : Rice.Theme.color("#9d8dad"); font.family: Rice.Theme.fontFamily; font.pixelSize: (11 * Rice.Theme.textScale) }
                        MouseArea { id: categoryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.category = categoryTile.modelData.id; root.focusSearch(); } }
                    }
                }
            }
            GridView {
                id: grid
                x: 24; y: root.resultsTop+18; width: parent.width-48; height: parent.height-y-24
                cellWidth: width/root.columns; cellHeight: Math.floor(height/root.rows)
                model: root.apps
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Rice.Theme.color("#887c6299") }
                    background: Item {}
                }
                delegate: Item {
                    id: appTile
                    required property var modelData
                    required property int index
                    width: grid.cellWidth; height: grid.cellHeight
                    readonly property bool selected: grid.currentIndex === index
                    Rectangle {
                        x: 2; y: 1; width: parent.width-6; height: parent.height-6; radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0; color: appTile.selected ? Rice.Theme.color("#7081679c") : Rice.Theme.color("#0081679c") }
                            GradientStop { position: 1; color: appTile.selected ? Rice.Theme.color("#44473561") : Rice.Theme.color("#00473561") }
                        }
                        border.width: 1; border.color: appTile.selected ? Rice.Theme.color("#557e659a") : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Rectangle {
                        x: (parent.width-width)/2; y: 10; width: root.settings.iconSize+13; height: width; radius: 14
                        color: Rice.Theme.color("#22d5beee"); border.width: 1; border.color: Rice.Theme.color("#2cc5afe0")
                        Image {
                            anchors.centerIn: parent; width: root.settings.iconSize; height: width
                            property bool iconFailed: false
                            source: iconFailed ? Qt.resolvedUrl("app.svg") : (Quickshell.hasThemeIcon(appTile.modelData.icon) ? Quickshell.iconPath(appTile.modelData.icon) : (appTile.modelData.icon.startsWith("/") ? "file://" + appTile.modelData.icon : Qt.resolvedUrl("app.svg")))
                            onStatusChanged: if (status === Image.Error) iconFailed = true
                            sourceSize: Qt.size(96,96); fillMode: Image.PreserveAspectFit; smooth: true
                            scale: appMouse.containsMouse ? 1.1 : 1
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text {
                        visible: root.settings.showLabels
                        x: 4; y: root.settings.iconSize+30; width: parent.width-8; height: Math.max(16,parent.height-y-4)
                        text: appTile.modelData.name; color: appTile.selected ? Rice.Theme.color("#eee7fa") : Rice.Theme.color("#baaccb")
                        font.family: Rice.Theme.fontFamily; font.pixelSize: (10 * Rice.Theme.textScale)
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignTop; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = appTile.index
                        onClicked: root.launch(appTile.modelData)
                    }
                }
            }
            Text {
                anchors.centerIn: grid; visible: root.apps.length === 0
                text: "Ничего не найдено"; color: Rice.Theme.color("#9d8dad"); font.family: Rice.Theme.fontFamily; font.pixelSize: (14 * Rice.Theme.textScale)
            }
        }
    }
}
