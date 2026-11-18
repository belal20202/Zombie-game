extends Node
## Global data: save/load, weapons, upgrades, city themes, level difficulty, privacy text.

signal coins_changed

const SAVE_PATH := "user://survivor_save.json"
const MAX_LEVEL := 100
const DEV_NAME := "بلال النعيمي"
const DEV_EMAIL := "your-email@example.com"

var coins := 0
var unlocked := 1
var current_level := 1
var owned: Array = ["pistol"]
var current_weapon := "pistol"
var upgrades := {"hp": 0, "dmg": 0, "spd": 0}
var sound_on := true
var sensitivity := 1.0
var use_glb := true

const WEAPON_ORDER := ["pistol", "uzi", "shotgun", "ak", "sniper"]
const WEAPONS := {
    "pistol": {"name": "مسدس", "dmg": 25.0, "rate": 0.35, "spread": 0.004, "pellets": 1, "mag": 12, "reload": 0.9, "price": 0, "len": 0.22, "pierce": false, "recoil": 0.012},
    "uzi": {"name": "رشاش صغير", "dmg": 13.0, "rate": 0.085, "spread": 0.02, "pellets": 1, "mag": 30, "reload": 1.3, "price": 400, "len": 0.34, "pierce": false, "recoil": 0.006},
    "shotgun": {"name": "بندقية صيد", "dmg": 15.0, "rate": 0.8, "spread": 0.06, "pellets": 7, "mag": 6, "reload": 1.5, "price": 900, "len": 0.85, "pierce": false, "recoil": 0.04},
    "ak": {"name": "كلاشنكوف", "dmg": 30.0, "rate": 0.12, "spread": 0.012, "pellets": 1, "mag": 30, "reload": 1.5, "price": 1800, "len": 0.85, "pierce": false, "recoil": 0.01},
    "sniper": {"name": "قناص", "dmg": 170.0, "rate": 1.1, "spread": 0.0, "pellets": 1, "mag": 5, "reload": 2.0, "price": 3500, "len": 1.1, "pierce": true, "recoil": 0.05},
}
const UPGRADES := {
    "hp": {"name": "صحة أعلى (+25)", "price": 200},
    "dmg": {"name": "قوة الضرر (+15%)", "price": 300},
    "spd": {"name": "سرعة الحركة", "price": 150},
}

var THEMES: Array = [
    {"name": "الأحياء القديمة", "sky": Color("#d18a5a"), "ground": Color("#45423e"), "bld": [Color("#9a8670"), Color("#7a7468"), Color("#a8997c")], "night": false, "light": 0.9, "deco": "", "fog": 150.0},
    {"name": "الصحراء", "sky": Color("#e8c98a"), "ground": Color("#c9a46a"), "bld": [Color("#c9a878"), Color("#b89462"), Color("#d8bb8a")], "night": false, "light": 1.0, "deco": "cactus", "fog": 170.0},
    {"name": "الثلوج", "sky": Color("#cfd9e6"), "ground": Color("#e8eef2"), "bld": [Color("#8a98a8"), Color("#aab6c4"), Color("#7a8696")], "night": false, "light": 1.0, "deco": "snow", "fog": 110.0},
    {"name": "المدينة الليلية", "sky": Color("#070b1a"), "ground": Color("#1a1c22"), "bld": [Color("#2a3050"), Color("#1f2540"), Color("#343a5a")], "night": true, "light": 0.35, "deco": "", "fog": 80.0},
    {"name": "المنطقة الصناعية", "sky": Color("#8a8f94"), "ground": Color("#4a4a46"), "bld": [Color("#6a6a68"), Color("#7a5a48"), Color("#555a5e")], "night": false, "light": 0.85, "deco": "", "fog": 120.0},
    {"name": "الغابة المهجورة", "sky": Color("#9ec28a"), "ground": Color("#3f6b35"), "bld": [Color("#6a6a58"), Color("#5a6a50"), Color("#7a7a66")], "night": false, "light": 0.9, "deco": "tree", "fog": 110.0},
    {"name": "المدينة المحترقة", "sky": Color("#4a1a10"), "ground": Color("#2a1a16"), "bld": [Color("#3a2a24"), Color("#4a2a20"), Color("#2e2420")], "night": false, "light": 0.6, "deco": "", "fog": 90.0},
    {"name": "الميناء الضبابي", "sky": Color("#8aa0aa"), "ground": Color("#4a5a60"), "bld": [Color("#5a6a70"), Color("#6a7a80"), Color("#4a5a62")], "night": false, "light": 0.8, "deco": "", "fog": 55.0},
    {"name": "ليلة الدم", "sky": Color("#1a0508"), "ground": Color("#1a0e10"), "bld": [Color("#3a1218"), Color("#2a0e12"), Color("#4a1820")], "night": true, "light": 0.4, "deco": "", "fog": 70.0},
    {"name": "مدينة النهاية", "sky": Color("#120a22"), "ground": Color("#15101e"), "bld": [Color("#2a1a40"), Color("#3a2458"), Color("#201432")], "night": true, "light": 0.45, "deco": "", "fog": 65.0},
]

const PRIVACY_AR := """سياسة الخصوصية – لعبة «الناجي»

1. لا نجمع أي بيانات شخصية. اللعبة لا تطلب اسمك أو بريدك أو موقعك.
2. تُحفظ بيانات اللعب (المرحلة، العملات، الأسلحة، الإعدادات) على جهازك فقط، ولا تُرسل إلى أي خادم.
3. لا تحتوي اللعبة على إعلانات ولا أدوات تحليل ولا تتبع، ولا تتصل بالإنترنت.
4. لا تطلب اللعبة أي أذونات (الكاميرا، الميكروفون، الموقع، جهات الاتصال، التخزين).
5. تحتوي اللعبة على عنف خيالي ضد زومبي، ولا تجمع أي معلومات عن الأطفال.
6. لحذف بياناتك احذف اللعبة أو امسح بياناتها من إعدادات الجهاز.
7. إذا أضفنا لاحقاً ميزات تتطلب بيانات (مثل الإعلانات) فسنحدّث هذه السياسة قبل ذلك.
8. للتواصل: بلال النعيمي – your-email@example.com"""

const PRIVACY_EN := """Privacy Policy – "Survivor"

1. We collect no personal data.
2. Progress is stored only on your device and never sent anywhere.
3. No ads, no analytics, no tracking, no internet use.
4. The game requests no permissions.
5. Fictional violence against zombies; no information about children is collected.
6. Uninstall the game or clear its data to delete everything.
7. This policy will be updated before any feature that needs data is added.
8. Contact: your-email@example.com"""


func _ready() -> void:
    _setup_input()
    load_game()


func _act(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for k in keys:
        var e := InputEventKey.new()
        e.physical_keycode = k
        InputMap.action_add_event(action, e)


func _setup_input() -> void:
    _act("move_forward", [KEY_W, KEY_UP])
    _act("move_back", [KEY_S, KEY_DOWN])
    _act("move_left", [KEY_A, KEY_LEFT])
    _act("move_right", [KEY_D, KEY_RIGHT])
    _act("jump", [KEY_SPACE])
    _act("sprint", [KEY_SHIFT])
    _act("reload", [KEY_R])
    _act("switch_weapon", [KEY_Q])
    _act("pause", [KEY_ESCAPE])
    if not InputMap.has_action("fire"):
        InputMap.add_action("fire")
        var m := InputEventMouseButton.new()
        m.button_index = MOUSE_BUTTON_LEFT
        InputMap.action_add_event("fire", m)


func save_game() -> void:
    var d := {
        "coins": coins, "unlocked": unlocked, "owned": owned, "weapon": current_weapon,
        "up": upgrades, "sound": sound_on, "sens": sensitivity, "glb": use_glb,
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(d))


func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var d = JSON.parse_string(f.get_as_text())
    if typeof(d) != TYPE_DICTIONARY:
        return
    coins = int(d.get("coins", 0))
    unlocked = clampi(int(d.get("unlocked", 1)), 1, MAX_LEVEL)
    var o = d.get("owned", ["pistol"])
    if typeof(o) == TYPE_ARRAY and o.size() > 0:
        owned = o
    current_weapon = str(d.get("weapon", "pistol"))
    var u = d.get("up", {})
    if typeof(u) == TYPE_DICTIONARY:
        for k in ["hp", "dmg", "spd"]:
            upgrades[k] = int(u.get(k, 0))
    sound_on = bool(d.get("sound", true))
    sensitivity = float(d.get("sens", 1.0))
    use_glb = bool(d.get("glb", true))


func reset_progress() -> void:
    coins = 0
    unlocked = 1
    current_level = 1
    owned = ["pistol"]
    current_weapon = "pistol"
    upgrades = {"hp": 0, "dmg": 0, "spd": 0}
    save_game()
    coins_changed.emit()


func max_hp() -> float:
    return 100.0 + float(upgrades["hp"]) * 25.0


func dmg_mult() -> float:
    return 1.0 + float(upgrades["dmg"]) * 0.15


func speed_mult() -> float:
    return 1.0 + float(upgrades["spd"]) * 0.035


func theme_index(level: int) -> int:
    return clampi(int(float(level - 1) / 10.0), 0, 9)


func upgrade_price(k: String) -> int:
    return int(UPGRADES[k]["price"]) * (int(upgrades[k]) + 1)


func buy_weapon(id: String) -> bool:
    if owned.has(id):
        current_weapon = id
        save_game()
        return true
    var price: int = WEAPONS[id]["price"]
    if coins < price:
        return false
    coins -= price
    owned.append(id)
    current_weapon = id
    save_game()
    coins_changed.emit()
    return true


func buy_upgrade(k: String) -> bool:
    if int(upgrades[k]) >= 10:
        return false
    var price := upgrade_price(k)
    if coins < price:
        return false
    coins -= price
    upgrades[k] = int(upgrades[k]) + 1
    save_game()
    coins_changed.emit()
    return true


func add_coins(n: int) -> void:
    coins += n
    coins_changed.emit()


func complete_level(level: int, bonus: int) -> void:
    coins += bonus
    if level >= unlocked and level < MAX_LEVEL:
        unlocked = level + 1
    save_game()
    coins_changed.emit()


func level_params(level: int) -> Dictionary:
    var total := 5 + int(level * 1.3)
    var boss := level % 10 == 0
    if boss:
        total = int(total * 0.5) + 1
    return {
        "total": total,
        "boss": boss,
        "hp": 40.0 + level * 5.5,
        "speed": 1.5 + minf(level * 0.025, 1.9),
        "dmg": 6.0 + level * 0.3,
        "pay": 4 + int(float(level) / 5.0),
        "fast_chance": minf(0.08 + level * 0.004, 0.35),
    }
