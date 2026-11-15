pragma Singleton
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import Quickshell
import Quickshell.Io

// Colours, fonts and sizes of the settings window. The active skin and the
// user's tweaks are stored in ~/.config/rice-theme/settings-skin.json.
Singleton {
    id: tokens

    // neon/cyan/amber/acid are the four signal colours, skyDay/skyNight tint the home card.
    readonly property var skins: [
        { id: "glass", name: "GLASS", tagline: "Полупрозрачное окно, цвета темы",
          base: "#1b1726", glassAlpha: .45, sidebar: "#10ffffff", surface: "#14ffffff",
          text: "#eee3fa", text2: "#ac9bbb", text3: "#857796", onAccent: "#201a2d",
          neon: "@accent", cyan: "#a8c9f5", amber: "#e8cb9d", acid: "#b4d3ad", danger: "#eaa2b1",
          radius: 14, controlRadius: 9, logo: "rice",
          skyDay: ["#6f9fd8", "#5c4a7a", "#2c3f6b"], skyNight: ["#0d0b1c", "#1c1530", "#241a3a"] },
        { id: "avatar", name: "Аватар", tagline: "Шафран и небесно-синий, стихии", fan: "air",
          base: "#0f0b07", glassAlpha: 1, sidebar: "#a00c0905", surface: "#0dffffff",
          text: "#f7f1e8", text2: "#bcae9b", text3: "#7c6f5f", onAccent: "#1a1206",
          neon: "#f59a23", cyan: "#4fb8e8", amber: "#ffd36b", acid: "#8fd17a", danger: "#e8584c",
          radius: 16, controlRadius: 10, logo: "avatar",
          skyDay: ["#f59a23", "#4fb8e8", "#0f0b07"], skyNight: ["#f59a23", "#4fb8e8", "#0f0b07"] },
        { id: "avengers", name: "Мстители", tagline: "Красный и золотой, дуговой реактор", fan: "reactor",
          base: "#09090d", glassAlpha: 1, sidebar: "#a006060a", surface: "#0dffffff",
          text: "#f4f4f6", text2: "#a9a9b3", text3: "#6c6c78", onAccent: "#ffffff",
          neon: "#e0352b", cyan: "#f2b632", amber: "#f2b632", acid: "#5fd38a", danger: "#ff5a4f",
          radius: 16, controlRadius: 10, logo: "avengers",
          skyDay: ["#e0352b", "#f2b632", "#09090d"], skyNight: ["#e0352b", "#f2b632", "#09090d"] },
        { id: "anime", name: "Аниме", tagline: "Сумерки, розовый и голубой, сакура", fan: "petals",
          base: "#0b0c1a", glassAlpha: 1, sidebar: "#a0080914", surface: "#0dffffff",
          text: "#f6f2fb", text2: "#b3acc8", text3: "#726c8c", onAccent: "#1a0b14",
          neon: "#ff7eb0", cyan: "#7fb4ff", amber: "#ffd08a", acid: "#8fe0b0", danger: "#ff6b8b",
          radius: 16, controlRadius: 10, logo: "anime",
          skyDay: ["#ff7eb0", "#7fb4ff", "#0b0c1a"], skyNight: ["#ff7eb0", "#7fb4ff", "#0b0c1a"] },
        { id: "jedi", name: "Джедай", tagline: "Чёрный космос, синий и красный свет", fan: "stars",
          base: "#05060a", glassAlpha: 1, sidebar: "#a0030407", surface: "#0dffffff",
          text: "#eef2f8", text2: "#a2aabb", text3: "#646c7e", onAccent: "#ffffff",
          neon: "#3fa4ff", cyan: "#ff4343", amber: "#ffc857", acid: "#5ef08a", danger: "#ff4d5e",
          radius: 16, controlRadius: 10, logo: "jedi",
          skyDay: ["#3fa4ff", "#ff4343", "#05060a"], skyNight: ["#3fa4ff", "#ff4343", "#05060a"] },
        { id: "gargantua", name: "Гаргантюа", tagline: "Чёрная дыра и тёплое кольцо", fan: "ring",
          base: "#060505", glassAlpha: 1, sidebar: "#a0040303", surface: "#0dffffff",
          text: "#f5efe6", text2: "#b5aa9a", text3: "#756b5e", onAccent: "#1a0f02",
          neon: "#ffad42", cyan: "#e9dcc6", amber: "#ffd27a", acid: "#9fd18a", danger: "#ff6a4a",
          radius: 16, controlRadius: 10, logo: "gargantua",
          skyDay: ["#ffad42", "#e9dcc6", "#060505"], skyNight: ["#ffad42", "#e9dcc6", "#060505"] }
    ]

    // User tweaks
    property var prefs: ({})
    readonly property var defaults: ({ skin: "glass", vignette: true, accent: "", font: "skin", textScale: 1,
        logo: "", caps: false, compact: false, autoSkin: false, daySkin: "glass", nightSkin: "jedi" })
    readonly property var opt: Object.assign({}, defaults, prefs)
    // Auto switching treats 07:00-19:00 as day.
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool daytime: clock.date.getHours() >= 7 && clock.date.getHours() < 19
    readonly property string activeSkinId: opt.autoSkin ? (daytime ? opt.daySkin : opt.nightSkin) : opt.skin
    readonly property var skin: skins.find(s => s.id === activeSkinId) || skins[0]

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/rice-theme/settings-skin.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { tokens.prefs = JSON.parse(text()); } catch (e) { tokens.prefs = {}; } }
    }
    function save(next) {
        prefs = next;
        store.setText(JSON.stringify(next, null, 2) + "\n");
    }
    function set(key, value) {
        var next = Object.assign({}, prefs);
        next[key] = value;
        save(next);
    }
    // A new skin starts from its own accent, font and logo.
    function setSkin(id) {
        var change = { font: "skin", accent: "", logo: "" };
        change[opt.autoSkin ? (daytime ? "daySkin" : "nightSkin") : "skin"] = id;
        save(Object.assign({}, prefs, change));
    }
    function randomSkin() {
        var pool = skins.filter(s => s.id !== skin.id);
        setSkin(pool[Math.floor(Math.random() * pool.length)].id);
    }
    function reset() { save({ skin: opt.skin, autoSkin: opt.autoSkin, daySkin: opt.daySkin, nightSkin: opt.nightSkin }); }

    // Resolved values
    readonly property bool mono: opt.font === "mono"
    readonly property string font: mono ? "JetBrains Mono" : Rice.Theme.fontFamily
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    // Wide face for clocks and page titles.
    readonly property string display: mono ? font : "Unbounded"
    readonly property real scale: opt.textScale || 1
    readonly property bool caps: !!opt.caps
    readonly property bool vignette: opt.vignette !== false
    readonly property bool compact: !!opt.compact
    readonly property string logo: opt.logo || skin.logo
    // Fan skins have hero art (assets/heroes/<id>.*), a background motif and two-colour gradients.
    readonly property string fan: skin.fan || ""
    readonly property bool duo: fan.length > 0

    readonly property color themeAccent: Rice.Theme.color("#c6acee")
    readonly property color neon: opt.accent ? opt.accent : skin.neon === "@accent" ? themeAccent : skin.neon
    readonly property color cyan: skin.cyan
    readonly property color amber: skin.amber
    readonly property color acid: skin.acid

    readonly property color base: skin.base
    readonly property color glass: alpha(skin.base, skin.glassAlpha)
    readonly property color sidebar: skin.sidebar
    readonly property color surface: skin.surface
    readonly property color card: alpha("#ffffff", .04)
    readonly property color cardStrong: alpha("#ffffff", .07)
    readonly property color line: "#14ffffff"
    readonly property color control: alpha(neon, .08)
    readonly property color controlHover: alpha(neon, .15)
    readonly property color controlDown: alpha(neon, .04)
    readonly property color well: "#a0000000"

    readonly property color text: skin.text
    readonly property color text2: skin.text2
    readonly property color text3: skin.text3
    readonly property color accent: neon
    readonly property color onAccent: Qt.color(skin.onAccent)
    readonly property color danger: skin.danger
    readonly property color good: acid

    readonly property int radius: skin.radius
    readonly property int controlRadius: skin.controlRadius
    readonly property int controlHeight: 32

    function px(size) { return Math.round(size * scale); }
    function alpha(c, a) { return Qt.alpha(c, a); }
    function glyph(code) { return String.fromCodePoint(code); }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function up(s) { return caps ? String(s).toUpperCase() : s; }
}
