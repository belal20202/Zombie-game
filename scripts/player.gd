class_name Player
extends CharacterBody3D
## Third-person player: movement, jump, camera (spring arm), hitscan weapons, health.

signal health_changed(hp: float)
signal hurt
signal ammo_changed
signal hit_confirmed(head: bool)
signal died

const GRAVITY := 24.0
const BASE_SPEED := 5.0
const JUMP_V := 7.2

var hp := 100.0
var max_hp := 100.0
var yaw := 0.0
var pitch := 0.0
var rig
var cam: Camera3D
var touch: TouchControls
var enabled := true
var alive := true
var ammo := {}
var weapon_id := "pistol"

var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var _cool := 0.0
var _reload_left := 0.0
var _step_acc := 0.0
var _flash: MeshInstance3D


func _ready() -> void:
    collision_layer = 4
    collision_mask = 1
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.32
    cap.height = 1.75
    cs.shape = cap
    cs.position.y = 0.875
    add_child(cs)
    _build_rig()
    _yaw_node = Node3D.new()
    add_child(_yaw_node)
    _pitch_node = Node3D.new()
    _pitch_node.position = Vector3(0.85, 1.6, 0.0)
    _yaw_node.add_child(_pitch_node)
    _arm = SpringArm3D.new()
    _arm.spring_length = 3.4
    _arm.margin = 0.25
    _arm.collision_mask = 1
    _pitch_node.add_child(_arm)
    cam = Camera3D.new()
    cam.fov = 70.0
    cam.near = 0.05
    cam.far = 250.0
    _arm.add_child(cam)
    cam.make_current()
    max_hp = Game.max_hp()
    hp = max_hp
    for id in Game.WEAPON_ORDER:
        ammo[id] = Game.WEAPONS[id]["mag"]
    weapon_id = Game.current_weapon if Game.owned.has(Game.current_weapon) else "pistol"
    rig.set_weapon(weapon_id)
    _flash = MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.07
    sm.height = 0.14
    _flash.mesh = sm
    var fm := StandardMaterial3D.new()
    fm.albedo_color = Color(1.0, 0.8, 0.3)
    fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _flash.material_override = fm
    _flash.visible = false
    _attach_flash()


func _attach_flash() -> void:
    if _flash.get_parent() != null:
        _flash.get_parent().remove_child(_flash)
    rig.muzzle.add_child(_flash)


func _build_rig() -> void:
    if Game.use_glb and GlbRig.available():
        var g := GlbRig.new()
        add_child(g)
        if g.setup():
            rig = g
            return
        g.queue_free()
    var h := Humanoid.new()
    add_child(h)
    h.build(Color("#d9a577"), Color("#2f4f7f"), Color("#2a3550"), false, true)
    rig = h


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
        var k := 0.0022 * Game.sensitivity
        yaw -= event.relative.x * k
        pitch = clampf(pitch - event.relative.y * k, -0.6, 0.9)


func _process(_delta: float) -> void:
    if touch != null and enabled:
        var ld := touch.take_look()
        var k := 0.0045 * Game.sensitivity
        yaw -= ld.x * k
        pitch = clampf(pitch - ld.y * k, -0.6, 0.9)
    _yaw_node.rotation.y = yaw
    _pitch_node.rotation.x = pitch


func _physics_process(delta: float) -> void:
    if not alive:
        return
    var move := Vector2.ZERO
    var jump := false
    var sprint := false
    var firing := false
    if enabled:
        move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
        jump = Input.is_action_just_pressed("jump")
        sprint = Input.is_action_pressed("sprint")
        firing = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
        if Input.is_action_just_pressed("reload"):
            reload()
        if Input.is_action_just_pressed("switch_weapon"):
            switch_next()
        if touch != null:
            if touch.move_vec.length() > 0.05:
                move = touch.move_vec
            if touch.consume_jump():
                jump = true
            if touch.fire_held:
                firing = true
            if touch.consume_reload():
                reload()
            if touch.consume_switch():
                switch_next()
    var dir := _yaw_node.global_transform.basis * Vector3(move.x, 0.0, move.y)
    dir.y = 0.0
    if dir.length() > 1.0:
        dir = dir.normalized()
    var speed := BASE_SPEED * Game.speed_mult() * (1.35 if sprint else 1.0)
    velocity.x = move_toward(velocity.x, dir.x * speed, 45.0 * delta)
    velocity.z = move_toward(velocity.z, dir.z * speed, 45.0 * delta)
    if is_on_floor():
        if jump:
            velocity.y = JUMP_V
            Sfx.play("jump")
        else:
            velocity.y = -0.5
    else:
        velocity.y -= GRAVITY * delta
    move_and_slide()

    _cool = maxf(0.0, _cool - delta)
    if _reload_left > 0.0:
        _reload_left -= delta
        if _reload_left <= 0.0:
            ammo[weapon_id] = Game.WEAPONS[weapon_id]["mag"]
            ammo_changed.emit()
    if firing:
        _try_fire()

    var hv := Vector2(velocity.x, velocity.z)
    var spd := hv.length()
    var fwd3 := -_yaw_node.global_transform.basis.z
    var fdot := Vector2(fwd3.x, fwd3.z).dot(hv)
    var sgn := -1.0 if fdot < -0.1 * spd else 1.0
    rig.rotation.y = yaw
    rig.animate(delta, spd, sgn, is_on_floor(), pitch)
    if is_on_floor() and spd > 0.5:
        _step_acc += spd * delta
        if _step_acc > Gait.step_length(spd):
            _step_acc = 0.0
            Sfx.play("step", -16.0, randf_range(0.9, 1.1))


func ammo_text() -> String:
    var w: Dictionary = Game.WEAPONS[weapon_id]
    if _reload_left > 0.0:
        return "%s  ..." % w["name"]
    return "%s  %d/%d" % [w["name"], ammo[weapon_id], w["mag"]]


func reload() -> void:
    var w: Dictionary = Game.WEAPONS[weapon_id]
    if _reload_left > 0.0 or ammo[weapon_id] >= w["mag"]:
        return
    _reload_left = float(w["reload"])
    Sfx.play("reload")
    ammo_changed.emit()


func switch_next() -> void:
    var list: Array = []
    for id in Game.WEAPON_ORDER:
        if Game.owned.has(id):
            list.append(id)
    if list.size() < 2:
        return
    var i := list.find(weapon_id)
    weapon_id = list[(i + 1) % list.size()]
    Game.current_weapon = weapon_id
    _reload_left = 0.0
    rig.set_weapon(weapon_id)
    _attach_flash()
    Sfx.play("switch")
    ammo_changed.emit()


func _try_fire() -> void:
    var w: Dictionary = Game.WEAPONS[weapon_id]
    if _cool > 0.0 or _reload_left > 0.0:
        return
    if ammo[weapon_id] <= 0:
        Sfx.play("empty")
        _cool = 0.3
        reload()
        return
    ammo[weapon_id] -= 1
    _cool = float(w["rate"])
    Sfx.play(weapon_id)
    var cb := cam.global_transform.basis
    var origin := cam.global_position
    var muz: Vector3 = rig.muzzle.global_position
    var space := get_world_3d().direct_space_state
    var sp: float = w["spread"]
    for i in int(w["pellets"]):
        var d := (-cb.z + cb.x * randf_range(-sp, sp) + cb.y * randf_range(-sp, sp)).normalized()
        _shoot_ray(space, origin, d, muz, w)
    rig.kick()
    pitch = minf(0.9, pitch + float(w["recoil"]))
    _flash.visible = true
    get_tree().create_timer(0.04).timeout.connect(_hide_flash)
    ammo_changed.emit()
    if ammo[weapon_id] <= 0:
        reload()


func _hide_flash() -> void:
    _flash.visible = false


func _shoot_ray(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, muz: Vector3, w: Dictionary) -> void:
    var from := origin
    var exclude: Array[RID] = [get_rid()]
    var pierce: bool = w["pierce"]
    var hits := 0
    var end := origin + dir * 90.0
    var dmg: float = float(w["dmg"]) * Game.dmg_mult()
    while hits < (3 if pierce else 1):
        var q := PhysicsRayQueryParameters3D.create(from, origin + dir * 90.0, 3)
        q.exclude = exclude
        var r := space.intersect_ray(q)
        if r.is_empty():
            break
        end = r["position"]
        var col = r["collider"]
        if col is Zombie and not col.dead:
            var head: bool = (r["position"].y - col.global_position.y) > col.head_y
            col.take_damage(dmg * (2.5 if head else 1.0), r["position"], head)
            Sfx.play("hit")
            hit_confirmed.emit(head)
            hits += 1
            if not pierce:
                break
            exclude.append(col.get_rid())
            from = r["position"] + dir * 0.05
        else:
            break
    _tracer(muz, end)


func _tracer(a: Vector3, b: Vector3) -> void:
    var dist := a.distance_to(b)
    if dist < 0.5:
        return
    var holder := Node3D.new()
    get_tree().current_scene.add_child(holder)
    holder.global_position = (a + b) / 2.0
    var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
    holder.look_at(b, up)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.008
    cm.bottom_radius = 0.008
    cm.height = dist
    mi.mesh = cm
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(1.0, 0.88, 0.5)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = m
    mi.rotation.x = PI / 2.0
    holder.add_child(mi)
    get_tree().create_timer(0.05).timeout.connect(holder.queue_free)


func heal(amount: float) -> void:
    hp = minf(max_hp, hp + amount)
    health_changed.emit(hp)


func take_damage(amount: float) -> void:
    if not alive:
        return
    hp -= amount
    Sfx.play("hurt")
    hurt.emit()
    health_changed.emit(maxf(0.0, hp))
    if hp <= 0.0:
        alive = false
        rig.fall_back()
        died.emit()
