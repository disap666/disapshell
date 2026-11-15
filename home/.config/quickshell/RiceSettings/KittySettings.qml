pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: page
    property int tab: 0
    readonly property bool busy: terminalPage.busy || promptPage.busy
    readonly property bool loaded: terminalPage.loaded && promptPage.loaded
    readonly property string status: tab===0 ? terminalPage.status : promptPage.status
    readonly property bool dirty: terminalPage.dirty || promptPage.dirty
    function read() { terminalPage.read(); }
    spacing: 14
    Segmented { model: ["Kitty", "Приглашение zsh"]; current: page.tab; onActivated: index => page.tab = index }
    SettingsEditor {id:terminalPage;visible: page.tab===0;backendName:"kitty_settings.py";kind:"kitty";Layout.fillWidth:true;Layout.fillHeight:true}
    SettingsEditor {id:promptPage;visible: page.tab===1;backendName:"shell_prompt.py";kind:"prompt";Layout.fillWidth:true;Layout.fillHeight:true}
}
