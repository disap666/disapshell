.pragma library

function copy(config) { return JSON.parse(JSON.stringify(config)); }
function combine(config, zone, indices, name, drawer) {
    var key = "group/" + name;
    if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error("Название группы: латинские буквы, цифры, _ или -");
    if (config[key]) throw new Error("Группа с таким именем уже существует");
    var list = config["modules-" + zone] || [];
    var selected = indices.filter(function(i) { return i >= 0 && i < list.length; }).sort(function(a,b) { return a-b; });
    selected = selected.filter(function(i,n) { return n === 0 || selected[n-1] !== i; });
    if (selected.length < 2) throw new Error("Выбери хотя бы два модуля");
    var result = copy(config);
    result[key] = {orientation: "inherit", modules: selected.map(function(i) { return list[i]; })};
    if (drawer) result[key].drawer = {"transition-duration": 300, "children-class": "rice-group-hidden"};
    var next = [];
    list.forEach(function(item,i) { if (i === selected[0]) next.push(key); if (selected.indexOf(i) < 0) next.push(item); });
    result["modules-" + zone] = next;
    return result;
}
function ungroup(config, key) {
    var result = copy(config), children = (result[key] || {}).modules;
    if (!key.startsWith("group/") || !Array.isArray(children)) throw new Error("Группа не найдена");
    function expand(list) {
        var next = [];
        list.forEach(function(item) { if (item === key) next = next.concat(children); else next.push(item); });
        return next;
    }
    ["left","center","right"].forEach(function(zone) { var k = "modules-"+zone; result[k] = expand(result[k] || []); });
    Object.keys(result).forEach(function(k) {
        if (k !== key && k.startsWith("group/") && Array.isArray(result[k].modules)) result[k].modules = expand(result[k].modules);
    });
    delete result[key];
    return result;
}
function install(config, extension, zone) {
    var result = copy(config);
    if (!result[extension.id]) result[extension.id] = copy(extension.settings);
    var list = (result["modules-" + zone] || []).slice();
    if (list.indexOf(extension.id) < 0) list.push(extension.id);
    result["modules-" + zone] = list;
    return result;
}
function active(config, id) {
    var seen = {};
    function contains(list) {
        return list.some(function(key) {
            if (key === id) return true;
            if (!key.startsWith("group/") || seen[key]) return false;
            seen[key] = true;
            return contains((config[key] || {}).modules || []);
        });
    }
    return ["left","center","right"].some(function(zone) { return contains(config["modules-"+zone] || []); });
}
var extensions = [
    {id:"cpu", name:"Процессор", icon:"󰍛", description:"Загрузка CPU в процентах", settings:{format:"󰍛 {usage}%", interval:3, "on-click":"kitty -e btop"}},
    {id:"memory", name:"Оперативная память", icon:"󰘚", description:"Использование RAM", settings:{format:"󰘚 {percentage}%", interval:5, "tooltip-format":"{used:0.1f} / {total:0.1f} GiB"}},
    {id:"disk", name:"Накопитель", icon:"󰋊", description:"Занятое и свободное место на диске", settings:{path:"/", format:"󰋊 {percentage_used}%", interval:30}},
    {id:"backlight", name:"Яркость", icon:"󰃠", description:"Яркость экрана и регулировка колёсиком", settings:{format:"󰃠 {percent}%", "scroll-step":5}},
    {id:"tray", name:"Системный трей", icon:"󰀻", description:"Значки фоновых приложений", settings:{"icon-size":16, spacing:8}},
    {id:"idle_inhibitor", name:"Не засыпать", icon:"󰒳", description:"Переключатель запрета сна и гашения экрана", settings:{format:"{icon}", "format-icons":{activated:"󰅶", deactivated:"󰾪"}}},
    {id:"hyprland/window", name:"Активное окно", icon:"󰖯", description:"Заголовок текущего окна", settings:{format:"{}", "max-length":25, "separate-outputs":true}},
    {id:"wlr/taskbar", name:"Панель приложений", icon:"󰕰", description:"Запущенные приложения с переключением по клику", settings:{format:"{icon}", "icon-size":18, "on-click":"activate", "on-click-middle":"close", "tooltip-format":"{title}"}},
    {id:"mpris", name:"Медиаплеер", icon:"󰎆", description:"Музыка из совместимых плееров", settings:{format:"󰎆 {artist} - {title}", "format-paused":"󰏤 {title}", "max-length":28}},
    {id:"pulseaudio/slider", name:"Ползунок громкости", icon:"󰕾", description:"Регулировка звука прямо на панели", settings:{min:0, max:100}},
    {id:"network#speed", name:"Скорость сети", icon:"󰓅", description:"Входящий и исходящий трафик", settings:{format:"↓ {bandwidthDownBytes} ↑ {bandwidthUpBytes}", interval:2, "tooltip-format":"{ifname}"}},
    {id:"custom/rice-settings", name:"Настройки райса", icon:"󰒓", description:"Кнопка открытия этого окна", settings:{format:"󰒓", "on-click":"~/.local/bin/rice-settings", "tooltip-format":"Настройки райса"}}
];
