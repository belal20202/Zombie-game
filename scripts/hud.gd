class_name Hud
extends CanvasLayer
## In-game HUD: health, ammo, level, zombies left, coins, crosshair, damage vignette, modal panels.

signal pause_pressed

var _root: Control
var _hp_bar: ProgressBar
var _lvl_lbl: Label
var _zom_lbl: Label
var _coin_lbl: Label
var _ammo_lbl: Label
var _toast: Label
var _vignette: TextureRect
var _cross: Control
var _cross_hit := 0.0
var _low := false


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.theme = UI.make_theme()
    add_child(_root)
    UI.full(_root)
    _build_vignette()
    _build_top()
    _build_cross()
    _toast = UI.label("", 40, UI.GOLD)
    _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_toast)
    _toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _toast.offset_top = 150.0
    _toast.offset_bottom = 210.0
    _toast.modulate.a = 0.0


func _build_vignette() -> void:
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(0.8, 0, 0, 0), Color(0.8, 0, 0, 0.9)])
    g.offsets = PackedFloat32Array([0.5, 1.0])
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    gt.width = 256
    gt.height = 256
    _vignette = TextureRect.new()
    _vignette.texture = gt
    _vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _vignette.stretch_mode = TextureRect.STRETCH_SCALE
    _vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_vignette)
    UI.full(_vignette)
    _vignette.modulate.a = 0.0


func _build_top() -> void:
    var mc := MarginContainer.new()
    mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for s in ["left", "right", "top", "bottom"]:
        mc.add_theme_constant_override("margin_" + s, 16)
    _root.add_child(mc)
    UI.full(mc)
    var vb := VBoxContainer.new()
    vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mc.add_child(vb)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 24)
    vb.add_child(row)
    _hp_bar = ProgressBar.new()
    _hp_bar.custom_minimum_size = Vector2(280, 28)
    _hp_bar.show_percentage = false
    _hp_bar.max_value = 100.0
    _hp_bar.value = 100.0
    row.add_child(_hp_bar)
    _lvl_lbl = UI.label("", 26)
    _zom_lbl = UI.label("", 26, Color(0.7, 1.0, 0.6))
    _coin_lbl = UI.label("", 26, UI.GOLD)
    row.add_child(_lvl_lbl)
    row.add_child(_zom_lbl)
    row.add_child(_coin_lbl)
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(sp)
    row.add_child(UI.button("||", _on_pause, 24, Vector2(64, 56)))
    _ammo_lbl = UI.label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
    vb.add_child(_ammo_lbl)


func _on_pause() -> void:
    pause_pressed.emit()


func _build_cross() -> void:
    _cross = Control.new()
    _cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _cross.custom_minimum_size = Vector2(44, 44)
    _root.add_child(_cross)
    _cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _cross.draw.connect(_draw_cross)


func _draw_cross() -> void:
    var c := Color(1.0, 0.25, 0.2) if _cross_hit > 0.0 else Color(1, 1, 1, 0.9)
    var ctr := Vector2(22, 22)
    for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
        _cross.draw_line(ctr + d * 6.0, ctr + d * 16.0, c, 2.5)


func _process(delta: float) -> void:
    if _cross_hit > 0.0:
        _cross_hit -= delta
        if _cross_hit <= 0.0:
            _cross.queue_redraw()
    var floor_a := 0.3 if _low else 0.0
    _vignette.modulate.a = maxf(floor_a, _vignette.modulate.a - delta * 1.5)


func set_level(level: int, _theme_name: String) -> void:
    _lvl_lbl.text = "المرحلة %d/%d" % [level, Game.MAX_LEVEL]


func set_health(hp: float) -> void:
    _hp_bar.max_value = Game.max_hp()
    _hp_bar.value = maxf(0.0, hp)
    _low = hp < Game.max_hp() * 0.3


func set_ammo(text: String) -> void:
    _ammo_lbl.text = text


func set_coins(n: int) -> void:
    _coin_lbl.text = "العملات: %d" % n


func set_zombies(n: int) -> void:
    _zom_lbl.text = "الزومبي: %d" % n


func flash_damage() -> void:
    _vignette.modulate.a = 0.9


func hit_marker(_head: bool) -> void:
    _cross_hit = 0.15
    _cross.queue_redraw()


func toast(text: String) -> void:
    _toast.text = text
    _toast.modulate.a = 1.0
    var tw := create_tween()
    tw.tween_interval(1.6)
    tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Shows a modal panel. buttons: [{"text": String, "cb": Callable}, ...]. Returns the panel root.
func show_modal(title: String, body: String, buttons: Array) -> Control:
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.72)
    _root.add_child(dim)
    UI.full(dim)
    var cc := CenterContainer.new()
    dim.add_child(cc)
    UI.full(cc)
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(620, 0)
    cc.add_child(pc)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 14)
    pc.add_child(vb)
    vb.add_child(UI.label(title, 52, UI.GOLD))
    if body != "":
        var b := UI.label(body, 26)
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.custom_minimum_size = Vector2(560, 0)
        vb.add_child(b)
    for bd in buttons:
        vb.add_child(UI.button(bd["text"], bd["cb"]))
    return dim
