class_name Zombie
extends CharacterBody3D
## Zombie: chases the player, attacks, takes damage (headshots), dies with a fall animation.

signal died(z)

var hp := 50.0
var max_hp := 50.0
var speed := 1.5
var dmg := 8.0
var pay := 4
var kind := "walker"
var dead := false
var head_y := 1.4
var reach := 1.0
var scale_k := 1.0
var target: Node3D
var others: Array = []
var visual: Humanoid

var _cd := 0.5
var _stun := 0.0
var _groan := 2.0
var _bar_root: Node3D
var _bar_fg: MeshInstance3D


func setup(p_kind: String, level: int, p_target: Node3D, p_others: Array) -> void:
    kind = p_kind
    target = p_target
    others = p_others
    var prm := Game.level_params(level)
    hp = float(prm["hp"])
    speed = float(prm["speed"])
    dmg = float(prm["dmg"])
    pay = int(prm["pay"])
    scale_k = randf_range(0.95, 1.08)
    var wide := 1.0
    match kind:
        "fast":
            speed *= 1.7
            hp *= 0.6
            scale_k = 0.95
        "tank":
            hp *= 3.0
            speed *= 0.75
            dmg *= 1.6
            pay *= 3
            scale_k = 1.25
            wide = 1.25
        "boss":
            hp *= 14.0
            speed = 2.6 + level * 0.01
            dmg *= 3.0
            pay = 150 + level * 5
            scale_k = 1.9
            wide = 1.1
    max_hp = hp
    head_y = 1.42 * scale_k
    reach = 1.0 * scale_k
    collision_layer = 2
    collision_mask = 1
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.32 * scale_k
    cap.height = 1.75 * scale_k
    cs.shape = cap
    cs.position.y = 0.875 * scale_k
    add_child(cs)
    var skins := [Color("#8c9c7c"), Color("#9aa38c"), Color("#7d8a70"), Color("#a39b88")]
    var shirts := [Color("#4a3a3a"), Color("#3a4a5a"), Color("#5a5a4a"), Color("#6a2a2a"), Color("#2a3a2a"), Color("#555555")]
    var pants := [Color("#2a2a35"), Color("#3a3226"), Color("#222222"), Color("#33401f")]
    var skin: Color = skins[randi() % skins.size()]
    if kind == "tank":
        skin = Color("#6f7d63")
    elif kind == "boss":
        skin = Color("#6b5a78")
    visual = Humanoid.new()
    add_child(visual)
    visual.build(skin, shirts[randi() % shirts.size()], pants[randi() % pants.size()], true, false)
    visual.scale = Vector3(scale_k * wide, scale_k, scale_k)
    _bar_root = Node3D.new()
    _bar_root.position = Vector3(0, 2.05 * scale_k, 0)
    _bar_root.visible = false
    add_child(_bar_root)
    _bar_root.add_child(_bar_quad(Color(0, 0, 0, 0.7), 0.7, 0))
    _bar_fg = _bar_quad(Color(0.85, 0.1, 0.1), 0.66, 1)
    _bar_root.add_child(_bar_fg)
    _groan = randf_range(1.0, 6.0)


func _bar_quad(c: Color, w: float, prio: int) -> MeshInstance3D:
    var q := QuadMesh.new()
    q.size = Vector2(w, 0.07)
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.render_priority = prio
    q.material = m
    var mi := MeshInstance3D.new()
    mi.mesh = q
    return mi


func _physics_process(delta: float) -> void:
    if dead or target == null:
        return
    _cd -= delta
    _stun -= delta
    var to := target.global_position - global_position
    to.y = 0.0
    var dist := to.length()
    var dir := to / maxf(dist, 0.001)
    rotation.y = atan2(-dir.x, -dir.z)
    var v := Vector3.ZERO
    if dist > reach:
        v = dir * speed * (0.3 if _stun > 0.0 else 1.0)
    for o in others:
        if o != self and not o.dead:
            var dd: Vector3 = global_position - o.global_position
            dd.y = 0.0
            var l := dd.length()
            if l < 0.8 * scale_k and l > 0.001:
                v += dd / l * 1.5
    velocity.x = v.x
    velocity.z = v.z
    if is_on_floor():
        velocity.y = -0.5
    else:
        velocity.y -= 24.0 * delta
    move_and_slide()
    visual.animate(delta, Vector2(velocity.x, velocity.z).length(), 1.0, true, 0.0)
    if dist < reach + 0.35 and _cd <= 0.0 and target.has_method("take_damage"):
        _cd = 0.9
        visual.attack_anim()
        target.take_damage(dmg)
    _groan -= delta
    if _groan <= 0.0:
        _groan = randf_range(3.0, 8.0)
        Sfx.play3d("groan%d" % (1 + randi() % 3), global_position)


func take_damage(amount: float, pos: Vector3, headshot: bool) -> void:
    if dead:
        return
    hp -= amount
    _stun = 0.2
    _bar_root.visible = true
    _bar_fg.scale.x = maxf(0.0, hp / max_hp)
    visual.hit_flash()
    _blood(pos, 14 if headshot else 8)
    if hp <= 0.0:
        _die()


func _blood(pos: Vector3, count: int) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = count
    p.lifetime = 0.45
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 70.0
    p.initial_velocity_min = 1.5
    p.initial_velocity_max = 4.0
    p.gravity = Vector3(0, -12, 0)
    var sm := SphereMesh.new()
    sm.radius = 0.03
    sm.height = 0.06
    sm.radial_segments = 4
    sm.rings = 2
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.6, 0.02, 0.02)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.material = m
    p.mesh = sm
    get_tree().current_scene.add_child(p)
    p.global_position = pos
    p.emitting = true
    get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _die() -> void:
    dead = true
    collision_layer = 0
    _bar_root.visible = false
    visual.fall_back()
    Sfx.play3d("die", global_position)
    died.emit(self)
    get_tree().create_timer(5.0).timeout.connect(queue_free)
