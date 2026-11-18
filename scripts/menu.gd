extends Node3D
## Main menu: 3D city background, Play/Continue, level select (100), shop, settings, privacy policy.

var cam: Camera3D
var content: Control
var _t := 0.0
var _cur := "main"
var _reset_armed := false


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().paused = false
    var ti := Game.theme_index(Game.unlocked)
    CityBuilder.build(self, Game.THEMES[ti], 99)
    cam = Camera3D.new()
    cam.far = 400.0
    add_child(cam)
    cam.make_current()
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.theme = UI.make_theme()
    root.layout_direction = Control.LAYOUT_DIRECTION_RTL
    layer.add_child(root)
    UI.full(root)
    content = Control.new()
    root.add_child(content)
    UI.full(content)
    _badge(root)
    _show_main()


func _process(delta: float) -> void:
    _t += delta * 0.12
    cam.global_position = Vector3(cos(_t) * 38.0, 10.0, sin(_t) * 38.0)
    cam.look_at(Vector3(0, 4, 0))


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if _cur != "main":
            _show_main()
        else:
            get_tree().quit()


func _badge(root: Control) -> void:
    var mc := MarginContainer.new()
    mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for s in ["left", "right", "top", "bottom"]:
        mc.add_theme_constant_override("margin_" + s, 20)
    root.add_child(mc)
    UI.full(mc)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    hb.size_flags_vertical = Control.SIZE_SHRINK_END
    hb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    mc.add_child(hb)
    var flag := VBoxContainer.new()
    flag.add_theme_constant_override("separation", 0)
    for c in [Color("#ce1126"), Color.WHITE, Color.BLACK]:
        var r := ColorRect.new()
        r.color = c
        r.custom_minimum_size = Vector2(54, 12)
        flag.add_child(r)
    hb.add_child(flag)
    hb.add_child(UI.label("صنع في العراق", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
    hb.add_child(UI.label("v1.0.0", 18, Color(1, 1, 1, 0.5)))


func _screen(id: String, width := 600.0) -> VBoxContainer:
    _cur = id
    for c in content.get_children():
        c.queue_free()
    var cc := CenterContainer.new()
    content.add_child(cc)
    UI.full(cc)
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(width, 0)
    cc.add_child(pc)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    pc.add_child(vb)
    return vb


func _show_main() -> void:
    _reset_armed = false
    var vb := _screen("main", 620.0)
    vb.add_child(UI.label("الناجي", 72, UI.GOLD))
    vb.add_child(UI.label("البقاء ضد الزومبي", 28, Color(0.8, 0.85, 0.8)))
    var ti := Game.theme_index(Game.unlocked)
    vb.add_child(UI.label("المرحلة %d من %d  |  %s" % [Game.unlocked, Game.MAX_LEVEL, Game.THEMES[ti]["name"]], 24, Color(0.9, 0.9, 0.7)))
    vb.add_child(UI.label("العملات: %d" % Game.coins, 24, UI.GOLD))
    var play_txt := "ابدأ اللعب"
    if Game.unlocked > 1:
        play_txt = "متابعة (المرحلة %d)" % Game.unlocked
    vb.add_child(UI.button(play_txt, _start.bind(Game.unlocked)))
    vb.add_child(UI.button("اختيار المرحلة", _show_levels))
    vb.add_child(UI.button("المتجر", _show_shop))
    vb.add_child(UI.button("الإعدادات", _show_settings))
    vb.add_child(UI.button("سياسة الخصوصية", _show_privacy))
    if not OS.has_feature("web"):
        vb.add_child(UI.button("خروج", _quit))


func _start(level: int) -> void:
    Game.current_level = level
    Game.save_game()
    get_tree().change_scene_to_file("res://scenes/level.tscn")


func _quit() -> void:
    Game.save_game()
    get_tree().quit()


func _show_levels() -> void:
    var vb := _screen("levels", 1000.0)
    vb.add_child(UI.label("اختيار المرحلة", 44, UI.GOLD))
    var sc := ScrollContainer.new()
    sc.custom_minimum_size = Vector2(940, 400)
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(sc)
    var grid := GridContainer.new()
    grid.columns = 10
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    sc.add_child(grid)
    for i in range(1, Game.MAX_LEVEL + 1):
        var b := Button.new()
        b.text = str(i)
        b.custom_minimum_size = Vector2(84, 56)
        b.disabled = i > Game.unlocked
        b.pressed.connect(_start.bind(i))
        grid.add_child(b)
    vb.add_child(UI.button("رجوع", _show_main))


func _show_shop() -> void:
    var vb := _screen("shop", 780.0)
    vb.add_child(UI.label("المتجر", 44, UI.GOLD))
    vb.add_child(UI.label("العملات: %d" % Game.coins, 28, UI.GOLD))
    var sc := ScrollContainer.new()
    sc.custom_minimum_size = Vector2(740, 330)
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(sc)
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 8)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(list)
    list.add_child(UI.label("الأسلحة", 30))
    for id in Game.WEAPON_ORDER:
        var w: Dictionary = Game.WEAPONS[id]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        var info := UI.label("%s\nضرر %d × %d  |  مخزن %d" % [w["name"], w["dmg"], w["pellets"], w["mag"]], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        var is_owned := Game.owned.has(id)
        var txt := "شراء %d" % w["price"]
        if is_owned:
            txt = "مُجهّز" if Game.current_weapon == id else "تجهيز"
        var b := UI.button(txt, _buy_weapon.bind(id), 22, Vector2(170, 56))
        b.disabled = is_owned and Game.current_weapon == id
        row.add_child(b)
        list.add_child(row)
    list.add_child(UI.label("القدرات", 30))
    for k in ["hp", "dmg", "spd"]:
        var u: Dictionary = Game.UPGRADES[k]
        var n: int = Game.upgrades[k]
        var row2 := HBoxContainer.new()
        row2.add_theme_constant_override("separation", 12)
        var info2 := UI.label("%s\nالمستوى %d/10" % [u["name"], n], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
        info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row2.add_child(info2)
        var txt2 := "أقصى مستوى" if n >= 10 else "ترقية %d" % Game.upgrade_price(k)
        var b2 := UI.button(txt2, _buy_upgrade.bind(k), 22, Vector2(170, 56))
        b2.disabled = n >= 10
        row2.add_child(b2)
        list.add_child(row2)
    vb.add_child(UI.button("رجوع", _show_main))


func _buy_weapon(id: String) -> void:
    if Game.buy_weapon(id):
        Sfx.play("buy")
    else:
        Sfx.play("empty")
    _show_shop()


func _buy_upgrade(k: String) -> void:
    if Game.buy_upgrade(k):
        Sfx.play("buy")
    else:
        Sfx.play("empty")
    _show_shop()


func _show_settings() -> void:
    var vb := _screen("settings", 640.0)
    vb.add_child(UI.label("الإعدادات", 44, UI.GOLD))
    var snd := CheckButton.new()
    snd.text = "الصوت"
    snd.button_pressed = Game.sound_on
    snd.toggled.connect(_set_sound)
    vb.add_child(snd)
    vb.add_child(UI.label("حساسية التصويب", 24))
    var sl := HSlider.new()
    sl.min_value = 0.4
    sl.max_value = 2.0
    sl.step = 0.05
    sl.value = Game.sensitivity
    sl.custom_minimum_size = Vector2(400, 32)
    sl.value_changed.connect(_set_sens)
    vb.add_child(sl)
    var glb := CheckButton.new()
    glb.text = "الشخصية الاحترافية (GLB)"
    glb.button_pressed = Game.use_glb
    glb.toggled.connect(_set_glb)
    vb.add_child(glb)
    var rst := "اضغط مرة أخرى لتأكيد المسح" if _reset_armed else "مسح كل التقدّم"
    vb.add_child(UI.button(rst, _reset))
    vb.add_child(UI.button("رجوع", _show_main))


func _set_sound(v: bool) -> void:
    Game.sound_on = v
    Game.save_game()


func _set_sens(v: float) -> void:
    Game.sensitivity = v
    Game.save_game()


func _set_glb(v: bool) -> void:
    Game.use_glb = v
    Game.save_game()


func _reset() -> void:
    if not _reset_armed:
        _reset_armed = true
        _show_settings()
        return
    Game.reset_progress()
    _show_main()


func _show_privacy() -> void:
    var vb := _screen("privacy", 900.0)
    vb.add_child(UI.label("سياسة الخصوصية", 44, UI.GOLD))
    var sc := ScrollContainer.new()
    sc.custom_minimum_size = Vector2(860, 380)
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(sc)
    var t := UI.label(Game.PRIVACY_AR + "\n\n" + Game.PRIVACY_EN, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
    t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    t.custom_minimum_size = Vector2(840, 0)
    sc.add_child(t)
    vb.add_child(UI.button("رجوع", _show_main))
