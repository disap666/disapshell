pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "WaybarLogic.js" as Logic
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page
    property var config: ({})
    property var appearance: ({})
    property string css: ""
    readonly property bool busy: reader.running || writer.running
    property bool loaded: false
    property bool dirty: false
    property string status: "Загрузка…"
    property int tab: 0
    property var selections: ({left: [], center: [], right: []})
    readonly property var groups: Object.keys(config).filter(k => k.startsWith("group/"))
    readonly property var swatches: ["#c6acee","#a8c9f5","#eaa2b1","#b4d3ad","#e8cb9d","#a8d4ce","#eee3fa","#201a2d"]
    property string module: "clock"
    property string wallpaper: ""
    readonly property alias builder: barBuilder
    readonly property string backend: Quickshell.env("HOME") + "/.local/share/rice-settings/waybar.py"
    readonly property var moduleNames: Object.keys(config).filter(k => typeof config[k] === "object" && !Array.isArray(config[k]) && !["output"].includes(k))
    spacing: 12
    function setConfig(key, value) { if(page.busy)return;var c = Object.assign({}, config); c[key] = value; config = c; touched(); }
    function setAppearance(key, value) { if(page.busy)return;var a = Object.assign({}, appearance); a[key] = value; appearance = a; touched(); }
    function setAppearanceMany(values) { if(page.busy)return;appearance = Object.assign({}, appearance, values); touched(); }

    // live: every edit reaches Waybar ~0.3 s later. The first live write of a session
    //    goes through "apply" (keeps a backup), the rest through "preview" (no backup spam),
    //    so "Откатить" returns to how things were before you started.
    readonly property bool live: Tokens.opt.liveApply !== false
    property bool liveBackedUp: false
    property bool livePending: false
    property int liveLayout: -1
    function touched() { if (live && loaded) { dirty = false; liveTimer.restart(); } else dirty = true; }
    Timer { id: liveTimer; interval: 280; onTriggered: page.pushLive() }
    function pushLive() {
        if (previewer.running) { livePending = true; return; }
        previewer.reread = page.appearance.layout !== page.liveLayout;
        page.liveLayout = page.appearance.layout === undefined ? -1 : page.appearance.layout;
        previewer.command = ["python3", backend, liveBackedUp ? "preview" : "apply"];
        liveBackedUp = true;
        previewer.running = true;
    }
    Process {
        id: previewer
        property bool reread: false
        stdinEnabled: true
        onStarted: { write(JSON.stringify({config: page.config, appearance: page.appearance, css: page.css})); stdinEnabled = false; }
        onExited: { stdinEnabled = true; if (page.livePending) { page.livePending = false; page.pushLive(); } }
        stdout: StdioCollector { onStreamFinished: {
            try { var d = JSON.parse(text);
                if (d.error) { page.status = "Ошибка: " + d.error; return; }
                page.status = "";
                // splitting into parts rebuilds module groups: pull them back in once things settle
                if (previewer.reread && !page.livePending && !liveTimer.running) page.read();
            } catch (e) { page.status = "Ошибка: " + e; }
        } }
    }
    onLiveChanged: if (live && dirty) { dirty = false; pushLive(); }

    readonly property var looks: [
        { name: "Стекло",   values: { layout: 1, radius: 16, gap: 0,  opacity: 38, borderOpacity: 30, borderWidth: 1, gradient: true,  padding: 8 } },
        { name: "Капсулы",  values: { layout: 3, radius: 22, gap: 12, opacity: 45, borderOpacity: 28, borderWidth: 1, gradient: true,  padding: 8 } },
        { name: "Острова",  values: { layout: 4, radius: 14, gap: 18, opacity: 70, borderOpacity: 20, borderWidth: 1, gradient: false, padding: 10 } },
        { name: "Пилюли",   values: { layout: 2, radius: 40, gap: 24, opacity: 60, borderOpacity: 45, borderWidth: 2, gradient: true,  padding: 10 } },
        { name: "Монолит",  values: { layout: 1, radius: 0,  gap: 0,  opacity: 92, borderOpacity: 0,  borderWidth: 0, gradient: false, padding: 6 } },
        { name: "Невидимка", values: { layout: 3, radius: 10, gap: 8, opacity: 0,  borderOpacity: 0,  borderWidth: 0, gradient: false, padding: 4 } }
    ]
    function read() { if (!reader.running) reader.running = true; }
    function act(action) { if (page.busy) return; writer.command = ["python3", backend, action]; writer.running = true; }
    function move(group, index, direction) {
        var list = (config["modules-"+group] || []).slice();
        var next = index + direction;
        if (next < 0 || next >= list.length) return;
        var item = list.splice(index, 1)[0]; list.splice(next, 0, item); setConfig("modules-"+group,list); selections = {left: [], center: [], right: []};
    }
    function selectModule(zone, index, selected) {
        var next = Object.assign({}, selections), items = (next[zone] || []).filter(i => i !== index);
        if (selected) items.push(index);
        next[zone] = items; selections = next;
    }
    function replaceConfig(next) { config = next; dirty = true; selections = {left: [], center: [], right: []}; }
    function editGroup(key, field, value) { var g=Object.assign({},config[key]); g[field]=value; setConfig(key,g); }
    function moveChild(key, index, direction) {
        var items=config[key].modules.slice(), target=index+direction;
        if (target<0 || target>=items.length) return;
        var item=items.splice(index,1)[0]; items.splice(target,0,item); editGroup(key,"modules",items);
    }
    Component.onCompleted: read()
    Process {
        id: reader
        command: ["python3", page.backend, "read"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var d = JSON.parse(text); if (d.error) { page.status = d.error; return; } page.config = d.config; page.css = d.css; page.appearance = d.appearance; page.loaded = true; page.dirty = false; page.selections = {left: [], center: [], right: []}; page.liveLayout = d.appearance.layout === undefined ? -1 : d.appearance.layout; if (!page.liveBackedUp) page.status = page.live ? "Вживую: изменения сразу видны на экране" : "Изменения применяются только по кнопке"; }
                catch(e) { page.status = "Ошибка чтения: " + e; }
            }
        }
    }
    Process {
        id: writer
        stdinEnabled: true
        onStarted: { if (command[2] === "apply") write(JSON.stringify({config: page.config, appearance: page.appearance, css: page.css})); stdinEnabled = false; }
        onExited: { stdinEnabled = true; }
        stdout: StdioCollector {
            onStreamFinished: {
                try { var d = JSON.parse(text); page.status = d.error || d.message; if (!d.error) { page.dirty = false; page.liveBackedUp = false; page.read(); } }
                catch(e) { page.status = "Ошибка сохранения: " + e; }
            }
        }
    }
    component Label: Text { font.family: Tokens.font; Layout.fillWidth: true; Layout.minimumWidth: 0; color: Tokens.text; font.pixelSize: Tokens.px(13); wrapMode: Text.Wrap }
    component Field: StyledTextField {}
    component Choice: StyledComboBox {}
    component Action: StyledButton {}
    Segmented { model: ["Конструктор", "Вид", "Положение", "Группы", "Виджеты", "Расширения", "Код"]; current: page.tab; onActivated: index => page.tab = index }
    BarStage {
        Layout.fillWidth: true
        visible: page.loaded && page.tab >= 1 && page.tab <= 2
        kind: "waybar"; configuration: page.config; appearance: page.appearance
        wallpaper: page.wallpaper; live: page.live
        onAppearanceEdited: (key, value) => page.setAppearance(key, value)
        onConfigEdited: (key, value) => page.setConfig(key, value)
    }
    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        contentHeight: body.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: body
            enabled: !page.busy
            width: parent.width - 12; spacing: 18
            BarBuilder {
                id: barBuilder
                visible: page.tab === 0 && page.loaded
                Layout.fillWidth: true
                page: page
                wallpaper: page.wallpaper
            }

            // Вид
            Group {
                visible: page.tab === 1 && page.loaded; title: "Готовые стили"
                Item {
                    Layout.fillWidth: true; implicitHeight: looksStrip.implicitHeight + 24
                    PresetStrip {
                        id: looksStrip
                        x: 12; y: 12; width: parent.width - 24
                        presets: page.looks; base: page.appearance; wallpaper: page.wallpaper
                        onChosen: values => page.setAppearanceMany(values)
                    }
                }
            }
            Group {
                visible: page.tab === 1 && page.loaded; title: "Форма"
                SettingRow {
                    label: "Части панели"
                    PartsPicker { current: page.appearance.layout || 3; onChosen: n => { page.setAppearance("layout", n); if (page.appearance.gap === undefined) page.setAppearance("gap", 12); } }
                }
                Repeater {
                    model: [
                        { key: "gap",         label: "Промежуток между частями", max: 100, def: 12 },
                        { key: "radius",      label: "Скругление",               max: 60,  def: 20 },
                        { key: "borderWidth", label: "Толщина рамки",            max: 10,  def: 1 },
                        { key: "padding",     label: "Внутренние отступы",       max: 40,  def: 6 }
                    ]
                    SettingRow {
                        id: shapeRow
                        required property var modelData
                        label: modelData.label
                        ValueSlider {
                            from: 0; to: shapeRow.modelData.max; unit: " px"; defaultValue: shapeRow.modelData.def
                            value: page.appearance[shapeRow.modelData.key] === undefined ? shapeRow.modelData.def : page.appearance[shapeRow.modelData.key]
                            onEdited: v => page.setAppearance(shapeRow.modelData.key, v)
                        }
                    }
                }
            }
            Group {
                visible: page.tab === 1 && page.loaded; title: "Цвета"
                Repeater {
                    model: [{key:"background",label:"Фон"},{key:"highlight",label:"Верх градиента"},{key:"foreground",label:"Текст и значки"},{key:"accent",label:"Акцент"},{key:"border",label:"Рамка"}]
                    SettingRow {
                        id: colorRow
                        required property var modelData
                        label: modelData.label
                        ColorField { title: colorRow.modelData.label; value: page.appearance[colorRow.modelData.key] || ""; onEdited: h => page.setAppearance(colorRow.modelData.key, h) }
                    }
                }
                SettingRow {
                    label: "Градиент фона"
                    StyledCheckBox { checked: !!page.appearance.gradient; onToggled: page.setAppearance("gradient",checked) }
                }
                Repeater {
                    model: [{key:"opacity",label:"Непрозрачность фона",def:82},{key:"borderOpacity",label:"Непрозрачность рамки",def:34}]
                    SettingRow {
                        id: alphaRow
                        required property var modelData
                        label: modelData.label
                        ValueSlider {
                            from: 0; to: 100; unit: "%"; defaultValue: alphaRow.modelData.def
                            value: page.appearance[alphaRow.modelData.key] === undefined ? alphaRow.modelData.def : page.appearance[alphaRow.modelData.key]
                            onEdited: v => page.setAppearance(alphaRow.modelData.key, v)
                        }
                    }
                }
            }
            Group {
                visible: page.tab === 1 && page.loaded; title: "Текст"
                SettingRow {
                    label: "Шрифт"
                    StyledComboBox {
                        id: fontBox
                        width: 260
                        model: Array.from(new Set([String(page.appearance.font || "JetBrainsMono Nerd Font")].concat(Qt.fontFamilies().filter(f => /nerd|mono|sans/i.test(f)).sort())))
                        currentIndex: Math.max(0, model.indexOf(String(page.appearance.font || "JetBrainsMono Nerd Font")))
                        onActivated: page.setAppearance("font", currentText)
                        // each entry is drawn in its own font
                        delegate: ItemDelegate {
                            required property string modelData
                            required property int index
                            width: fontBox.width
                            highlighted: fontBox.highlightedIndex === index
                            contentItem: Text { text: parent.modelData; font.family: parent.modelData; font.pixelSize: Tokens.px(13); color: Tokens.text; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.highlighted ? Tokens.controlHover : "transparent"; radius: Tokens.controlRadius }
                        }
                    }
                }
                SettingRow {
                    label: "Размер шрифта"
                    ValueSlider { from: 6; to: 32; unit: " px"; defaultValue: 12; value: page.appearance.fontSize || 12; onEdited: v => page.setAppearance("fontSize", v) }
                }
            }

            // Положение
            Group {
                visible: page.tab === 2 && page.loaded; title: "Место на экране"
                SettingRow {
                    label: "Край экрана"
                    EdgePicker { current: page.config.position || "top"; onChosen: edge => page.setConfig("position", edge) }
                }
                SettingRow {
                    label: "Слой"
                    Segmented { model: ["Над окнами","Под окнами","Поверх всего","Фон"]; current: Math.max(0,["top","bottom","overlay","background"].indexOf(page.config.layer || "top")); onActivated: index => page.setConfig("layer",["top","bottom","overlay","background"][index]) }
                }
                SettingRow {
                    label: "Экран"
                    StyledComboBox {
                        width: 170
                        model: ["Все мониторы"].concat(Quickshell.screens.map(sc => sc.name))
                        currentIndex: typeof page.config.output === "string" ? Math.max(0, model.indexOf(page.config.output)) : 0
                        onActivated: { if (currentIndex > 0) page.setConfig("output", currentText); else { var c=Object.assign({},page.config); delete c.output; page.config=c; page.touched(); } }
                    }
                }
                SettingRow {
                    label: "Центр строго по центру экрана"
                    StyledCheckBox { checked: page.config["fixed-center"] !== false; onToggled: page.setConfig("fixed-center",checked) }
                }
                SettingRow {
                    label: "Резервировать место"
                    StyledCheckBox { checked: page.config.exclusive !== false; onToggled: page.setConfig("exclusive",checked) }
                }
            }
            Group {
                visible: page.tab === 2 && page.loaded; title: "Размеры и отступы"
                Repeater {
                    model: [{key:"height",label:"Высота",max:120},{key:"spacing",label:"Между модулями",max:40},{key:"margin-top",label:"Отступ сверху",max:100},{key:"margin-bottom",label:"Отступ снизу",max:100},{key:"margin-left",label:"Отступ слева",max:300},{key:"margin-right",label:"Отступ справа",max:300}]
                    SettingRow {
                        id: numberRow
                        required property var modelData
                        label: modelData.label
                        ValueSlider { from: 0; to: numberRow.modelData.max; unit: " px"; defaultValue: numberRow.modelData.key === "height" ? 0 : NaN; value: page.config[numberRow.modelData.key] || 0; onEdited: v => page.setConfig(numberRow.modelData.key, v) }
                    }
                }
                SettingRow {
                    label: "Ширина"
                    StyledSpinBox { from: 0; to: 7680; editable: true; value: page.config.width || 0; onValueModified: page.setConfig("width",value) }
                }
            }
            ColumnLayout {
                visible: page.tab === 3 && page.loaded; Layout.fillWidth: true; spacing: 12
                Label { text: "Состав панели"; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                Repeater {
                    model: ["left","center","right"]
                    ColumnLayout {
                        id: group
                        required property string modelData
                        Layout.fillWidth: true
                        Label { text: ({left:"Слева",center:"По центру",right:"Справа"})[group.modelData]; font.pixelSize: (15 * Rice.Theme.textScale); Layout.topMargin: 10 }
                        Repeater {
                            model: page.config["modules-"+group.modelData] || []
                            RowLayout {
                                id: moduleRow
                                required property string modelData
                                required property int index
                                Layout.fillWidth: true
                                StyledCheckBox { checked: (page.selections[group.modelData] || []).indexOf(moduleRow.index)>=0; onToggled: page.selectModule(group.modelData,moduleRow.index,checked) }
                                Label { text: moduleRow.modelData; Layout.fillWidth: true }
                                Action { text: "↑"; onClicked: page.move(group.modelData,moduleRow.index,-1) }
                                Action { text: "↓"; onClicked: page.move(group.modelData,moduleRow.index,1) }
                                Action { text: "×"; onClicked: { var l=page.config["modules-"+group.modelData].slice(); l.splice(moduleRow.index,1); page.setConfig("modules-"+group.modelData,l); page.selections={left:[],center:[],right:[]}; } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Field { id: groupName; Layout.fillWidth: true; placeholderText: "Имя группы · например media" }
                            Action {
                                text: "Объединить ("+(page.selections[group.modelData] || []).length+")"
                                enabled: (page.selections[group.modelData] || []).length>=2 && groupName.text.length>0
                                onClicked: { try { page.replaceConfig(Logic.combine(page.config,group.modelData,page.selections[group.modelData],groupName.text,false)); groupName.clear(); page.status="Группа создана в черновике"; } catch(e) { page.status=String(e); } }
                            }
                        }
                        RowLayout {
                            Choice { id: addModule; Layout.fillWidth: true; model: Array.from(new Set(page.moduleNames.concat(["cpu","memory","disk","backlight","tray","idle_inhibitor","hyprland/window","wlr/taskbar"]))).sort() }
                            Action { text: "Добавить"; onClicked: { var l=(page.config["modules-"+group.modelData]||[]).slice(); if (l.indexOf(addModule.currentText)<0) { l.push(addModule.currentText); page.setConfig("modules-"+group.modelData,l); } } }
                        }
                    }
                }
                Label { text: "Созданные группы"; visible: page.groups.length>0; font.pixelSize: (16 * Rice.Theme.textScale); Layout.topMargin: 12 }
                Repeater {
                    model: page.groups
                    ColumnLayout {
                        id: groupEditor
                        required property string modelData
                        readonly property var settings: page.config[modelData] || {}
                        Layout.fillWidth: true
                        RowLayout {
                            Label { text: groupEditor.modelData; font.pixelSize: (14 * Rice.Theme.textScale) }
                            Choice { model: ["inherit","horizontal","vertical","orthogonal"]; currentIndex: Math.max(0,model.indexOf(groupEditor.settings.orientation || "inherit")); onActivated: page.editGroup(groupEditor.modelData,"orientation",currentText) }
                            Action { text: "Разъединить"; onClicked: { try { page.replaceConfig(Logic.ungroup(page.config,groupEditor.modelData)); } catch(e) { page.status=String(e); } } }
                        }
                        StyledCheckBox {
                            text: "Скрывать остальные модули до наведения"; palette.windowText: Rice.Theme.color("#eee3fa")
                            checked: !!groupEditor.settings.drawer
                            onToggled: { var g=Object.assign({},groupEditor.settings); if (checked) g.drawer={"transition-duration":300,"children-class":"rice-group-hidden"}; else delete g.drawer; page.setConfig(groupEditor.modelData,g); }
                        }
                        Repeater {
                            model: groupEditor.settings.modules || []
                            RowLayout {
                                id: childRow
                                required property string modelData
                                required property int index
                                Label { text: "    "+childRow.modelData }
                                Action { text: "↑"; onClicked: page.moveChild(groupEditor.modelData,childRow.index,-1) }
                                Action { text: "↓"; onClicked: page.moveChild(groupEditor.modelData,childRow.index,1) }
                                Action { text: "×"; enabled: (groupEditor.settings.modules || []).length>1; onClicked: { var l=groupEditor.settings.modules.slice(); l.splice(childRow.index,1); page.editGroup(groupEditor.modelData,"modules",l); } }
                            }
                        }
                        RowLayout {
                            Choice { id: groupAdd; Layout.fillWidth: true; model: page.moduleNames.filter(k => !k.startsWith("group/") && (groupEditor.settings.modules || []).indexOf(k)<0) }
                            Action { text: "В группу"; enabled: groupAdd.currentIndex>=0; onClicked: { var l=(groupEditor.settings.modules || []).slice(); l.push(groupAdd.currentText); page.editGroup(groupEditor.modelData,"modules",l); } }
                        }
                    }
                }
                Label { text: "Своя кнопка приложения"; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2; Layout.topMargin: 14 }
                Field { id: appName; placeholderText: "Название (например browser)"; Layout.fillWidth: true }
                Field { id: appIcon; placeholderText: "Значок или подпись"; Layout.fillWidth: true }
                Field { id: appCommand; placeholderText: "Команда запуска (например firefox)"; Layout.fillWidth: true }
                Action { text: "Создать и добавить слева"; enabled: /^[a-zA-Z0-9_-]+$/.test(appName.text) && appCommand.text.length > 0; onClicked: { var key="custom/"+appName.text; if (page.config[key]) { page.status="Модуль с таким именем уже существует"; return; } page.setConfig(key,{format:appIcon.text || appName.text,"on-click":appCommand.text,tooltip:false}); var l=(page.config["modules-left"]||[]).slice(); l.push(key); page.setConfig("modules-left",l); appName.clear(); appCommand.clear(); appIcon.clear(); } }
            }
            ColumnLayout {
                visible: page.tab === 4 && page.loaded; Layout.fillWidth: true; spacing: 12
                Label { text: "Параметры любого виджета"; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                Choice { Layout.fillWidth: true; model: page.moduleNames; currentIndex: Math.max(0,page.moduleNames.indexOf(page.module)); onActivated: { page.module=currentText; moduleJson.text=JSON.stringify(page.config[page.module] || {},null,2); } }
                Repeater {
                    model: Object.keys(page.config[page.module] || {}).filter(k => ["string","number","boolean"].includes(typeof page.config[page.module][k]))
                    RowLayout {
                        id: widgetField
                        required property string modelData
                        readonly property var current: (page.config[page.module] || {})[modelData]
                        Layout.fillWidth: true
                        Label { text: widgetField.modelData; Layout.preferredWidth: 160 }
                        Field {
                            Layout.fillWidth: true
                            visible: typeof widgetField.current !== "boolean"
                            text: String(widgetField.current)
                            onEditingFinished: {
                                var m=Object.assign({},page.config[page.module]);
                                if (typeof widgetField.current === "number") {
                                    if (!isFinite(Number(text))) { page.status="Нужно число: "+widgetField.modelData; return; }
                                    m[widgetField.modelData]=Number(text);
                                } else m[widgetField.modelData]=text;
                                page.setConfig(page.module,m);
                            }
                        }
                        StyledCheckBox {
                            visible: typeof widgetField.current === "boolean"
                            checked: widgetField.current === true
                            onToggled: { var m=Object.assign({},page.config[page.module]); m[widgetField.modelData]=checked; page.setConfig(page.module,m); }
                        }
                    }
                }
                Label { text: "Все параметры виджета · JSON"; color: Tokens.text3 }
                ScrollView {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredHeight: 250; clip: true
                TextArea {
                    id: moduleJson
                    width: parent.width
                    text: JSON.stringify(page.config[page.module] || {},null,2)
                    color: Rice.Theme.color("#eee3fa"); font.family: "JetBrains Mono"; font.pixelSize: (12 * Rice.Theme.textScale); wrapMode: TextEdit.Wrap; selectByMouse: true
                    background: Rectangle { color: Tokens.well; radius: Tokens.controlRadius; border.width: 1; border.color: Tokens.line }
                }
                }
                Action { text: "Обновить виджет"; onClicked: { try { var v=JSON.parse(moduleJson.text); if (typeof v !== "object" || v === null || Array.isArray(v)) throw new Error("Нужен объект JSON"); page.setConfig(page.module,v); page.status="Виджет обновлён в черновике"; } catch(e) { page.status="Ошибка JSON: "+e; } } }
            }
            ColumnLayout {
                visible: page.tab === 5 && page.loaded; Layout.fillWidth: true; spacing: 14
                Label { text: "Предлагаемые расширения"; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                RowLayout {
                    Label { text: "Добавлять" }
                    Choice { id: extensionZone; model: ["Справа","По центру","Слева"] }
                }
                Repeater {
                    model: Logic.extensions
                    Rectangle {
                        id: extension
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: extensionContent.implicitHeight+28
                        radius: Tokens.radius; color: Tokens.card; border.width: 1; border.color: Tokens.line
                        RowLayout {
                            id: extensionContent
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
                            spacing: 12
                            Text { text: extension.modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: (23 * Rice.Theme.textScale); color: Rice.Theme.color("#c6acee") }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: extension.modelData.name; font.pixelSize: (14 * Rice.Theme.textScale) }
                                Label { text: extension.modelData.description; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
                            }
                            Action {
                                readonly property bool added: Logic.active(page.config,extension.modelData.id)
                                text: added ? "Добавлено" : "+ Добавить"; enabled: !added
                                onClicked: { page.replaceConfig(Logic.install(page.config,extension.modelData,["right","center","left"][extensionZone.currentIndex])); page.status=extension.modelData.name+" добавлен в черновик"; }
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                visible: page.tab === 6 && page.loaded; Layout.fillWidth: true; spacing: 12
                Label { text: "Полная конфигурация Waybar"; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                ScrollView {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredHeight: 300; clip: true
                TextArea {
                    id: configJson
                    width: parent.width
                    text: JSON.stringify(page.config,null,2); color: Rice.Theme.color("#eee3fa"); font.family: "JetBrains Mono"; font.pixelSize: (12 * Rice.Theme.textScale); wrapMode: TextEdit.Wrap; selectByMouse: true
                    background: Rectangle { color: Tokens.well; radius: Tokens.controlRadius; border.width: 1; border.color: Tokens.line }
                }
                }
                Action { text: "Обновить конфигурацию"; onClicked: { try { var v=JSON.parse(configJson.text); if (!v || Array.isArray(v) || typeof v !== "object") throw new Error("Нужен объект JSON"); page.config=v; page.dirty=true; page.status="Конфигурация обновлена в черновике"; } catch(e) { page.status="Ошибка JSON: "+e; } } }
                Label { text: "Исходный CSS"; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                ScrollView {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredHeight: 300; clip: true
                TextArea {
                    id: cssEditor
                    width: parent.width
                    text: page.css; color: Rice.Theme.color("#eee3fa"); font.family: "JetBrains Mono"; font.pixelSize: (12 * Rice.Theme.textScale); wrapMode: TextEdit.Wrap; selectByMouse: true
                    background: Rectangle { color: Tokens.well; radius: Tokens.controlRadius; border.width: 1; border.color: Tokens.line }
                }
                }
                Action { text: "Обновить CSS"; onClicked: { page.css=cssEditor.text; page.dirty=true; page.status="CSS обновлён в черновике"; } }
            }
        }
    }
    ApplyBar {
        dirty: page.dirty; busy: page.busy; loaded: page.loaded; canRestore: true
        liveCapable: true
        status: page.status
        error: page.status.indexOf("Ошибка") === 0 ? page.status : ""
        revertText: "Перечитать"; restoreText: "Откатить последнее"
        onApply: page.act("apply"); onRevert: page.read(); onRestore: page.act("restore")
    }
}
