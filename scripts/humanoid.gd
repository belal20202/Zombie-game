class_name Humanoid
extends Node3D
## Procedural articulated human: hips, torso, head, shoulders, elbows, hips, knees.
## Walk cycle is driven by distance travelled, so feet stay planted. Also used for zombies.

const LEG_UP := 0.46
const LEG_LO := 0.46
const ARM_UP := 0.29
const ARM_LO := 0.27
const HIP_H := 0.96

var zombie := false
var with_gun := false
var hips: Node3D
var torso: Node3D
var head: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var aim_frame: Node3D
var gun_root: Node3D
var muzzle: Marker3D
var fore_dist := 0.2

var _phase := 0.0
var _t := 0.0
var _move_k := 0.0
var _air_k := 0.0
var _kick := 0.0
var _attack_t := 0.0
var _mats: Array[StandardMaterial3D] = []
var _gun_node: Node3D


func _mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.85
    _mats.append(m)
    return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    parent.add_child(mi)
    return mi


func _caps(r: float, h: float) -> CapsuleMesh:
    var m := CapsuleMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = 10
    m.rings = 3
    return m


func _ball(r: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = r
    m.height = r * 2.0
    m.radial_segments = 12
    m.rings = 6
    return m


func _box(s: Vector3) -> BoxMesh:
    var m := BoxMesh.new()
    m.size = s
    return m


func _make_arm(side: float, sleeve: Material, skin: Material) -> Array:
    var sh := Node3D.new()
    sh.position = Vector3(side * 0.21, 0.52, 0)
    torso.add_child(sh)
    _part(sh, _caps(0.055, 0.31), sleeve, Vector3(0, -0.15, 0))
    var el := Node3D.new()
    el.position = Vector3(0, -ARM_UP, 0)
    sh.add_child(el)
    _part(el, _caps(0.047, 0.29), skin, Vector3(0, -0.14, 0))
    _part(el, _ball(0.05), skin, Vector3(0, -ARM_LO, 0))
    return [sh, el]


func _make_leg(side: float, pants: Material, shoe: Material) -> Array:
    var hp := Node3D.new()
    hp.position = Vector3(side * 0.1, 0, 0)
    hips.add_child(hp)
    _part(hp, _caps(0.085, 0.47), pants, Vector3(0, -0.23, 0))
    var kn := Node3D.new()
    kn.position = Vector3(0, -LEG_UP, 0)
    hp.add_child(kn)
    _part(kn, _caps(0.065, 0.47), pants, Vector3(0, -0.23, 0))
    _part(kn, _box(Vector3(0.12, 0.07, 0.27)), shoe, Vector3(0, -LEG_LO + 0.02, -0.06))
    return [hp, kn]


func build(skin: Color, shirt: Color, pants: Color, is_zombie: bool, gun: bool) -> void:
    zombie = is_zombie
    with_gun = gun
    var skin_m := _mat(skin)
    var shirt_m := _mat(shirt)
    var pants_m := _mat(pants)
    var shoe_m := _mat(Color(0.1, 0.1, 0.1))
    hips = Node3D.new()
    hips.position.y = HIP_H
    add_child(hips)
    _part(hips, _box(Vector3(0.32, 0.16, 0.2)), pants_m, Vector3.ZERO)
    torso = Node3D.new()
    hips.add_child(torso)
    _part(torso, _caps(0.15, 0.6), shirt_m, Vector3(0, 0.33, 0), Vector3(1.3, 1.0, 0.8))
    _part(torso, _caps(0.045, 0.14), skin_m, Vector3(0, 0.64, 0))
    head = Node3D.new()
    head.position = Vector3(0, 0.7, 0)
    torso.add_child(head)
    _part(head, _ball(0.11), skin_m, Vector3(0, 0.1, 0), Vector3(1.0, 1.15, 1.05))
    var eye_m := StandardMaterial3D.new()
    if is_zombie:
        eye_m.albedo_color = Color(0.9, 0.1, 0.05)
        eye_m.emission_enabled = true
        eye_m.emission = Color(1.0, 0.1, 0.0)
    else:
        eye_m.albedo_color = Color(0.08, 0.08, 0.08)
    for sx in [-1.0, 1.0]:
        _part(head, _ball(0.018), eye_m, Vector3(sx * 0.04, 0.12, -0.1))
    if is_zombie:
        _part(head, _box(Vector3(0.07, 0.03, 0.02)), _mat(Color(0.25, 0.03, 0.03)), Vector3(0, 0.03, -0.1))
        _part(torso, _box(Vector3(0.14, 0.18, 0.02)), _mat(Color(0.35, 0.03, 0.03)), Vector3(0.05, 0.4, -0.115))
    else:
        _part(head, _ball(0.118), _mat(Color(0.15, 0.1, 0.07)), Vector3(0, 0.15, 0.015), Vector3(1.0, 0.7, 1.05))
    var a := _make_arm(-1.0, shirt_m, skin_m)
    shoulder_l = a[0]
    elbow_l = a[1]
    a = _make_arm(1.0, shirt_m, skin_m)
    shoulder_r = a[0]
    elbow_r = a[1]
    var l := _make_leg(-1.0, pants_m, shoe_m)
    hip_l = l[0]
    knee_l = l[1]
    l = _make_leg(1.0, pants_m, shoe_m)
    hip_r = l[0]
    knee_r = l[1]
    if gun:
        aim_frame = Node3D.new()
        aim_frame.position = Vector3(0, 0.52, 0)
        torso.add_child(aim_frame)
        gun_root = Node3D.new()
        gun_root.position = Vector3(0.04, -0.14, -0.30)
        aim_frame.add_child(gun_root)
        set_weapon("pistol")


func set_weapon(id: String) -> void:
    if _gun_node != null:
        _gun_node.queue_free()
    var g := GunModel.build(id)
    _gun_node = g["node"]
    muzzle = g["muzzle"]
    fore_dist = g["fore"]
    gun_root.add_child(_gun_node)


func kick() -> void:
    _kick = 1.0


func attack_anim() -> void:
    _attack_t = 0.5


func animate(delta: float, speed: float, fwd_sign: float, grounded: bool, pitch: float) -> void:
    _t += delta
    _kick = move_toward(_kick, 0.0, delta * 7.0)
    _attack_t = maxf(0.0, _attack_t - delta)
    _move_k = lerpf(_move_k, clampf(speed / 0.4, 0.0, 1.0), clampf(delta * 12.0, 0.0, 1.0))
    _air_k = lerpf(_air_k, 0.0 if grounded else 1.0, clampf(delta * 14.0, 0.0, 1.0))
    var step := Gait.step_length(speed)
    _phase += fwd_sign * PI * speed * delta / step
    var amp := Gait.swing_amp(step, LEG_UP + LEG_LO) * _move_k * (1.0 - _air_k)
    var kmax := deg_to_rad(30.0 + 25.0 * clampf(speed / 6.0, 0.0, 1.0))
    var pl := _phase
    var pr := _phase + PI
    var drag := 0.75 if zombie else 1.0
    hip_l.rotation.x = amp * Gait.tri(pl) + _air_k * 0.55
    hip_r.rotation.x = amp * Gait.tri(pr) * drag + _air_k * 0.2
    knee_l.rotation.x = -(kmax * maxf(0.0, cos(pl)) * _move_k + _air_k * 0.9)
    knee_r.rotation.x = -(kmax * maxf(0.0, cos(pr)) * _move_k * drag + _air_k * 0.6)
    var lean := 0.05 + 0.1 * clampf(speed / 6.0, 0.0, 1.0)
    if zombie:
        lean = 0.3
    torso.rotation.x = -lean * (_move_k * 0.6 + 0.4)
    torso.rotation.y = sin(_phase) * 0.12 * _move_k
    hips.position.y = HIP_H - 0.03 * absf(sin(_phase)) * _move_k * (1.0 - _air_k) + sin(_t * 1.7) * 0.004
    if with_gun:
        head.rotation.x = pitch * 0.5
        _aim_arms(pitch)
    elif zombie:
        var sway := sin(_t * 2.2) * 0.08
        var lunge := 0.0
        if _attack_t > 0.0:
            lunge = sin(_attack_t / 0.5 * PI) * 0.6
        shoulder_l.rotation.x = 1.35 + sway + lunge
        shoulder_r.rotation.x = 1.3 - sway + lunge
        shoulder_l.rotation.z = 0.1
        shoulder_r.rotation.z = -0.1
        elbow_l.rotation.x = 0.25
        elbow_r.rotation.x = 0.35
        head.rotation.x = 0.2
        head.rotation.z = sin(_t * 1.3) * 0.15


func _aim_arms(pitch: float) -> void:
    aim_frame.rotation.x = pitch
    gun_root.position = Vector3(0.04, -0.14, -0.30 + _kick * 0.06)
    gun_root.rotation.x = _kick * 0.08
    var xf := aim_frame.transform
    var grip_r := xf * gun_root.position
    var grip_l := xf * (gun_root.position + Vector3(0, 0, -fore_dist))
    _ik_arm(shoulder_r, elbow_r, grip_r, Vector3(0.5, -1.0, 0.3).normalized())
    _ik_arm(shoulder_l, elbow_l, grip_l, Vector3(-0.5, -1.0, 0.3).normalized())


## Two-bone IK in torso space: positions the elbow, then aims the forearm at the target.
func _ik_arm(shoulder: Node3D, elbow: Node3D, target: Vector3, pole: Vector3) -> void:
    var p1 := shoulder.position
    var a := ARM_UP
    var b := ARM_LO
    var t := target - p1
    var d := t.length()
    var u := t / maxf(d, 0.0001)
    d = clampf(d, absf(a - b) + 0.01, a + b - 0.005)
    var cs := (a * a + d * d - b * b) / (2.0 * a * d)
    var sn := sqrt(maxf(0.0, 1.0 - cs * cs))
    var pp := (pole - u * pole.dot(u)).normalized()
    var e := (u * cs + pp * sn).normalized()
    var elbow_pos := p1 + e * a
    var f := (p1 + u * d - elbow_pos).normalized()
    shoulder.basis = Basis(Quaternion(Vector3.DOWN, e))
    elbow.basis = Basis(Quaternion(Vector3.DOWN, shoulder.basis.inverse() * f))


func hit_flash() -> void:
    for m in _mats:
        m.emission_enabled = true
        m.emission = Color(0.7, 0.05, 0.05)
    get_tree().create_timer(0.08).timeout.connect(_unflash)


func _unflash() -> void:
    for m in _mats:
        m.emission_enabled = false


func fall_back() -> void:
    var tw := create_tween()
    tw.tween_property(self, "rotation:x", PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(self, "position:y", 0.12, 0.45)
