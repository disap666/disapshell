// RiceDesktop: every desktop widget and menu in ONE quickshell process.
// Each separate qs process costs ~100 MB of Qt/QML baseline, so sharing one
// saves several hundred MB. Each part keeps its own IPC target:
//   qs ipc -c RiceDesktop call dock|music|weather|memory|notifications|apps|power|wallpaper <fn>
import QtQuick
import Quickshell
import Quickshell.Io
import "file:@HOME@/.config/quickshell/RiceDock" as RiceDock
import "file:@HOME@/.config/quickshell/RiceMusic" as RiceMusic
import "file:@HOME@/.config/quickshell/RiceWeather" as RiceWeather
import "file:@HOME@/.config/quickshell/RiceMemory" as RiceMemory
import "file:@HOME@/.config/quickshell/RiceNotifications" as RiceNotifications
import "file:@HOME@/.config/quickshell/RiceApps" as RiceApps
import "file:@HOME@/.config/quickshell/RicePower" as RicePower
import "file:@HOME@/.config/quickshell/RiceWallpaper" as RiceWallpaper

ShellRoot {
    id: desktop
    // Wallpaper auto-change, minutes from ~/.config/rice-theme/wallpaper.json (0 = off)
    property int wallpaperMinutes: 0
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/wallpaper.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { desktop.wallpaperMinutes = Math.max(0, parseInt(JSON.parse(text()).interval) || 0); } catch (e) { desktop.wallpaperMinutes = 0; } }
    }
    Timer {
        interval: Math.max(1, desktop.wallpaperMinutes) * 60000
        running: desktop.wallpaperMinutes > 0; repeat: true
        onTriggered: Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.local/share/wallpaper-picker/backend.py", "--random"])
    }
    RiceWallpaper.WallpaperLayer {}
    RiceDock.DockWidget {}
    RiceMusic.MusicWidget {}
    RiceWeather.WeatherWidget {}
    RiceMemory.MemoryWidget {}
    RiceNotifications.NotificationsWidget {}
    RiceApps.AppsMenu {}
    RicePower.PowerMenu {}
}
