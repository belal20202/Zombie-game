class_name GlbRig
extends Node3D
## Drives the imported rigged GLB character (Ludo / Mixamo style skeleton) procedurally:
## distance-driven legs (no foot sliding), jump tuck, spine lean/pitch, two-hand weapon hold via arm IK.
## If the file or any bone is missing, setup() returns false and the Humanoid fallback is used.

const PATH := "res://assets/characters/player.glb"
const SCALE := 1.75
const NAMES := ["Hips", "Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder",
    "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]

var skel: Skeleton3D
var muzzle: Marker3D
var aim_frame: Node3D
var gun_root: Node3D
var fore_dist := 0.2

var _b := {}
var _len := {}
var _hips_rest := Vector3.ZERO
var _phase := 0.0
var _t := 0.0
var _move_k := 0.0
var _air_k := 0.0
var _kick := 0.0
var _gun_node: Node3D


static func available() -> bool:
    return ResourceLoader.exists(PATH)


func _find(short: String) -> int:
    for i in skel.get_bone_count():
        var n := skel.get_bone_name(i)
        if n == short or n.ends_with("_" + short) or n.ends_with(":" + short):
            return i
    return -1


func setup() -> bool:
    var res = load(PATH)
    if not (res is PackedScene):
        return false
    var model := Node3D.new()
    model.rotation.y = PI
    model.scale = Vector3.ONE * SCALE
    model.position.y = 0.5 * SCALE
    add_child(model)
    var inst: Node = (res as PackedScene).instantiate()
    model.add_child(inst)
    for n in inst.find_children("*", "AnimationPlayer", true, false):
        n.queue_free()
    var found := inst.find_children("*", "Skeleton3D", true, false)
    if found.is_empty():
        model.queue_free()
        return false
    skel = found[0] as Skeleton3D
    for n in NAMES:
        var idx := _find(n)
        if idx < 0:
            push_warning("GlbRig: bone not found: " + n)
            model.queue_free()
            return false
        _b[n] = idx
    for side in ["Left", "Right"]:
        _len[side + "A"] = skel.get_bone_rest(_b[side + "ForeArm"]).origin.length()
        _len[side + "B"] = skel.get_bone_rest(_b[side + "Hand"]).origin.length()
    _hips_rest = skel.get_bone_rest(_b["Hips"]).origin
    aim_frame = Node3D.new()
    aim_frame.position = Vector3(0, 1.38, 0)
    add_child(aim_frame)
    gun_root = Node3D.new()
    gun_root.position = Vector3(0.04, -0.14, -0.30)
    aim_frame.add_child(gun_root)
    set_weapon("pistol")
    return true


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


func fall_back() -> void:
    var tw := create_tween()
    tw.tween_property(self, "rotation:x", PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(self, "position:y", 0.12, 0.45)


func _parent_basis(i: int) -> Basis:
    var p := skel.get_bone_parent(i)
    if p < 0:
        return Basis.IDENTITY
    return skel.get_bone_global_pose(p).basis.orthonormalized()


## Rotate bone i so that its child bone points along dir (skeleton space).
func _point(i: int, child: int, dir: Vector3) -> void:
    var d_local := (_parent_basis(i).inverse() * dir).normalized()
    var c_local := skel.get_bone_rest(child).origin.normalized()
    skel.set_bone_pose_rotation(i, Quaternion(c_local, d_local))


func animate(delta: float, speed: float, fwd_sign: float, grounded: bool, pitch: float) -> void:
    if skel == null:
        return
    _t += delta
    _kick = move_toward(_kick, 0.0, delta * 7.0)
    _move_k = lerpf(_move_k, clampf(speed / 0.4, 0.0, 1.0), clampf(delta * 12.0, 0.0, 1.0))
    _air_k = lerpf(_air_k, 0.0 if grounded else 1.0, clampf(delta * 14.0, 0.0, 1.0))
    var step := Gait.step_length(speed)
    _phase += fwd_sign * PI * speed * delta / step
    var inv := skel.global_transform.basis.inverse()
    var up := (inv * Vector3.UP).normalized()
    var fwd := (inv * (global_transform.basis * Vector3.FORWARD)).normalized()
    var axis := fwd.cross(up).normalized()
    var lean := 0.05 + 0.1 * clampf(speed / 6.0, 0.0, 1.0)
    var spine_ang := (pitch - lean * (_move_k * 0.6 + 0.4)) / 3.0
    for n in ["Spine", "Spine1", "Spine2"]:
        var i: int = _b[n]
        var ax := (_parent_basis(i).inverse() * axis).normalized()
        skel.set_bone_pose_rotation(i, Quaternion(ax, spine_ang) * skel.get_bone_rest(i).basis.get_rotation_quaternion())
    var bob := 0.03 * absf(sin(_phase)) * _move_k * (1.0 - _air_k) + 0.02 * _air_k
    skel.set_bone_pose_position(_b["Hips"], _hips_rest - up * (bob / SCALE))
    var amp := Gait.swing_amp(step, 0.92) * _move_k * (1.0 - _air_k)
    var kmax := deg_to_rad(30.0 + 25.0 * clampf(speed / 6.0, 0.0, 1.0))
    _leg("Left", _phase, amp, kmax, up, fwd)
    _leg("Right", _phase + PI, amp, kmax, up, fwd)
    _arms(pitch)


func _leg(side: String, ph: float, amp: float, kmax: float, up: Vector3, fwd: Vector3) -> void:
    var sw := amp * Gait.tri(ph) + _air_k * 0.5
    var kn := kmax * maxf(0.0, cos(ph)) * _move_k + _air_k * 0.9
    var thigh := (-up * cos(sw) + fwd * sin(sw)).normalized()
    var sa := sw - kn
    var shin := (-up * cos(sa) + fwd * sin(sa)).normalized()
    var u: int = _b[side + "UpLeg"]
    var k: int = _b[side + "Leg"]
    var f: int = _b[side + "Foot"]
    _point(u, k, thigh)
    _point(k, f, shin)
    var rest_g := skel.get_bone_global_rest(f).basis.orthonormalized()
    skel.set_bone_pose_rotation(f, (_parent_basis(f).inverse() * rest_g).get_rotation_quaternion())


func _arms(pitch: float) -> void:
    aim_frame.rotation.x = pitch
    gun_root.position = Vector3(0.04, -0.14, -0.30 + _kick * 0.06)
    for side in ["Left", "Right"]:
        var sh: int = _b[side + "Shoulder"]
        skel.set_bone_pose_rotation(sh, skel.get_bone_rest(sh).basis.get_rotation_quaternion())
    var grip_r := aim_frame.to_global(gun_root.position)
    var grip_l := aim_frame.to_global(gun_root.position + Vector3(0, 0, -fore_dist))
    var inv := skel.global_transform.basis.inverse()
    var gb := global_transform.basis
    _arm_ik("Right", skel.to_local(grip_r), (inv * (gb * Vector3(0.5, -1.0, 0.3))).normalized())
    _arm_ik("Left", skel.to_local(grip_l), (inv * (gb * Vector3(-0.5, -1.0, 0.3))).normalized())


func _arm_ik(side: String, target: Vector3, pole: Vector3) -> void:
    var u_i: int = _b[side + "Arm"]
    var f_i: int = _b[side + "ForeArm"]
    var h_i: int = _b[side + "Hand"]
    var p1 := skel.get_bone_global_pose(u_i).origin
    var a: float = _len[side + "A"]
    var b: float = _len[side + "B"]
    var t := target - p1
    var d := t.length()
    var u := t / maxf(d, 0.0001)
    d = clampf(d, absf(a - b) + 0.002, a + b - 0.001)
    var cs := (a * a + d * d - b * b) / (2.0 * a * d)
    var sn := sqrt(maxf(0.0, 1.0 - cs * cs))
    var pp := (pole - u * pole.dot(u)).normalized()
    var e := (u * cs + pp * sn).normalized()
    var elbow := p1 + e * a
    var f := (p1 + u * d - elbow).normalized()
    _point(u_i, f_i, e)
    _point(f_i, h_i, f)
