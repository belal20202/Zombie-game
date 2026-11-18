extends Node3D
## One playable level: city, player, zombie spawning, pickups, win/lose/pause flow.

var player: Player
var hud: Hud
var touch: TouchControls
var zombies: Array = []
var pickups: Array = []
var spawn_left := 0
var state := "play"

var _level := 1
var _boss_pending := false
var _spawn_t := 1.0
var _is_touch := false
var _pause_modal: Control


func _ready() -> void:
    _level = Game.current_level
    _is_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    var ti := Game.theme_index(_level)
    CityBuilder.build(self, Game.THEMES[ti], ti * 977 + 13)
    hud = Hud.new()
    add_child(hud)
    if _is_touch:
        touch = TouchControls.new()
        hud.add_child(touch)
    player = Player.new()
    player.touch = touch
    player.position = Vector3(0, 0.05, 45)
    add_child(player)
    player.health_changed.connect(_on_health)
    player.hurt.connect(hud.flash_damage)
    player.ammo_changed.connect(_on_ammo)
    player.hit_confirmed.connect(hud.hit_marker)
    player.died.connect(_lose)
    hud.pause_pressed.connect(_pause)
    Game.coins_changed.connect(_on_coins)
    var prm := Game.level_params(_level)
    spawn_left = int(prm["total"])
    _boss_pending = bool(prm["boss"])
    var theme_name: String = Game.THEMES[ti]["name"]
    hud.set_level(_level, theme_name)
    _on_health(player.hp)
    _on_ammo()
    _on_coins()
    _update_count()
    hud.toast("المرحلة %d – %s" % [_level, theme_name])
    if not _is_touch:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _pause()


func _unhandled_input(event: InputEvent) -> void:
    if state != "play" or get_tree().paused:
        return
    if event.is_action_pressed("pause"):
        _pause()
    elif event is InputEventMouseButton and event.pressed and not _is_touch and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_health(hp: float) -> void:
    hud.set_health(hp)


func _on_ammo() -> void:
    hud.set_ammo(player.ammo_text())


func _on_coins() -> void:
    hud.set_coins(Game.coins)


func _update_count() -> void:
    hud.set_zombies(zombies.size() + spawn_left)


func _process(delta: float) -> void:
    if state != "play":
        return
    _spawn_t -= delta
    if spawn_left > 0 and zombies.size() < 20 and _spawn_t <= 0.0:
        _spawn_t = 0.45
        _spawn_zombie()
    for i in range(pickups.size() - 1, -1, -1):
        var k: Node3D = pickups[i]
        k.rotate_y(delta * 2.0)
        if k.global_position.distance_to(player.global_position + Vector3(0, 0.8, 0)) < 1.5:
            player.heal(30.0)
            Sfx.play("coin")
            k.queue_free()
            pickups.remove_at(i)


func _spawn_zombie() -> void:
    var prm := Game.level_params(_level)
    var kind := "walker"
    if _boss_pending:
        kind = "boss"
        _boss_pending = false
    else:
        var q := randf()
        if q < float(prm["fast_chance"]):
            kind = "fast"
        elif _level > 6 and q > 0.88:
            kind = "tank"
    var z := Zombie.new()
    z.setup(kind, _level, player, zombies)
    add_child(z)
    var a := randf() * TAU
    var r := randf_range(28.0, 45.0)
    var pos := player.global_position + Vector3(cos(a), 0.0, sin(a)) * r
    pos.x = clampf(pos.x, -57.0, 57.0)
    pos.z = clampf(pos.z, -57.0, 57.0)
    pos.y = 0.1
    z.global_position = pos
    zombies.append(z)
    z.died.connect(_on_zombie_died)
    spawn_left -= 1
    _update_count()


func _on_zombie_died(z) -> void:
    zombies.erase(z)
    Game.add_coins(z.pay)
    Sfx.play("coin", -8.0)
    if randf() < 0.14 or z.kind == "boss":
        _drop_heart(z.global_position)
    _update_count()
    if spawn_left == 0 and zombies.is_empty() and state == "play":
        _win()


func _drop_heart(pos: Vector3) -> void:
    var h := Node3D.new()
    add_child(h)
    h.global_position = Vector3(pos.x, 0.8, pos.z)
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(1.0, 0.2, 0.2)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for s in [Vector3(0.5, 0.16, 0.16), Vector3(0.16, 0.5, 0.16)]:
        var mi := MeshInstance3D.new()
        var b := BoxMesh.new()
        b.size = s
        mi.mesh = b
        mi.material_override = m
        h.add_child(mi)
    pickups.append(h)


func _freeze() -> void:
    for z in zombies:
        z.set_physics_process(false)


func _release_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _win() -> void:
    state = "win"
    player.enabled = false
    _freeze()
    var bonus := 60 + _level * 12
    Game.complete_level(_level, bonus)
    Sfx.play("win")
    _release_mouse()
    if _level >= Game.MAX_LEVEL:
        hud.show_modal("لقد فزت!", "أنهيت جميع المراحل الـ 100 وأصبحت الناجي الأخير.", [
            {"text": "الصفحة الرئيسية", "cb": _home}])
    else:
        hud.show_modal("لقد فزت!", "أنهيت المرحلة %d وكسبت %d عملة." % [_level, bonus], [
            {"text": "المرحلة التالية", "cb": _next_level},
            {"text": "الصفحة الرئيسية", "cb": _home}])


func _lose() -> void:
    if state != "play":
        return
    state = "lose"
    player.enabled = false
    _freeze()
    Game.save_game()
    Sfx.play("lose")
    _release_mouse()
    hud.show_modal("لقد متّ", "المرحلة %d" % _level, [
        {"text": "إعادة المرحلة", "cb": _retry},
        {"text": "الصفحة الرئيسية", "cb": _home}])


func _pause() -> void:
    if state != "play" or get_tree().paused:
        return
    get_tree().paused = true
    _release_mouse()
    _pause_modal = hud.show_modal("متوقف مؤقتاً", "", [
        {"text": "متابعة", "cb": _resume},
        {"text": "الصفحة الرئيسية", "cb": _home}])


func _resume() -> void:
    if _pause_modal != null:
        _pause_modal.queue_free()
        _pause_modal = null
    get_tree().paused = false
    if not _is_touch:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _next_level() -> void:
    Game.current_level = mini(_level + 1, Game.MAX_LEVEL)
    get_tree().paused = false
    get_tree().reload_current_scene()


func _retry() -> void:
    Game.current_level = _level
    get_tree().paused = false
    get_tree().reload_current_scene()


func _home() -> void:
    Game.save_game()
    get_tree().paused = false
    _release_mouse()
    get_tree().change_scene_to_file("res://scenes/menu.tscn")
