pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    property var palette: ({})
    property var globalStyle: ({})
    readonly property string fontFamily: globalStyle.fontFamily || "Noto Sans"
    readonly property real textScale: globalStyle.textScale || 1
    readonly property real glassOpacity: globalStyle.glassOpacity || 1
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/global.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { theme.globalStyle=JSON.parse(text()); } catch(e) { theme.globalStyle={}; } }
    }
    property var dockOverrides: ({})
    readonly property var deck: Object.assign({parts: 1, radius: 23, gap: 0, padding: 7, opacity: .86,
        borderOpacity: .5, borderWidth: 1, scale: 1.25, iconRadius: 13, bottomMargin: 10,
        gradient: true, autoHide: true, zoom: true, showRunning: true, showLauncher: true, alignment: "center", hideDelay: 450, tintIcons: true,
        background: palette.colors ? palette.colors.background : "#211a2e",
        highlight: palette.colors ? palette.colors.surface : "#493957",
        accent: palette.colors ? palette.colors.accent : "#bd9ce9",
        foreground: palette.colors ? palette.colors.foreground : "#eee7fa",
        border: palette.colors ? palette.colors.border : "#beadd9"}, palette.deck || {}, dockOverrides)
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/deck.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { theme.dockOverrides = JSON.parse(text()); } catch(e) { theme.dockOverrides = {}; } }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/palette.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { theme.palette = JSON.parse(text()); }
            catch (e) { theme.palette = {}; }
        }
    }
    // Maps a built-in purple shade to the matching colour of the active palette.
    // Alpha is kept; status colours (red, green, amber) and greys pass through.
    function color(original) {
        var hex = original.slice(1), alpha = 1;
        if (hex.length === 8) { alpha = parseInt(hex.slice(0, 2), 16) / 255; hex = hex.slice(2); }
        var r = parseInt(hex.slice(0,2),16)/255, g = parseInt(hex.slice(2,4),16)/255, b = parseInt(hex.slice(4,6),16)/255;
        var high = Math.max(r,g,b), low = Math.min(r,g,b), delta = high-low;
        if (alpha < .95 && high < .72) alpha = Math.min(1, alpha * glassOpacity);
        if (!palette.colors || delta < .035) return Qt.rgba(r,g,b,alpha);
        // Only purple-ish shades are remapped.
        if (!(b >= g && r >= g * .94)) return Qt.rgba(r,g,b,alpha);
        var key = high < .24 ? "background" : high < .48 ? "surface" : high < .72 ? "muted" : delta > .14 ? "accent" : "foreground";
        var target = palette.colors[key];
        if (!target) return original;
        return Qt.rgba(parseInt(target.slice(1,3),16)/255, parseInt(target.slice(3,5),16)/255, parseInt(target.slice(5,7),16)/255, alpha);
    }
}
