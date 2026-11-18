class_name GunModel
extends RefCounted
## Builds a weapon model: grip at the origin, barrel pointing to -Z.


static func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
    var mi := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = size
    mi.mesh = b
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.5
    m.metallic = 0.3
    mi.material_override = m
    mi.position = pos
    parent.add_child(mi)


static func build(id: String) -> Dictionary:
    var w: Dictionary = Game.WEAPONS[id]
    var L: float = w["len"]
    var root := Node3D.new()
    var dark := Color(0.1, 0.1, 0.11)
    var body := {
        "pistol": Color(0.35, 0.35, 0.38), "uzi": Color(0.2, 0.2, 0.22),
        "shotgun": Color(0.4, 0.27, 0.15), "ak": Color(0.33, 0.24, 0.16), "sniper": Color(0.2, 0.28, 0.2),
    }
    _box(root, Vector3(0.05, 0.09, L * 0.6), Vector3(0, 0.03, -L * 0.25), body[id])
    _box(root, Vector3(0.03, 0.03, L * 0.5), Vector3(0, 0.04, -L * 0.7), dark)
    _box(root, Vector3(0.045, 0.12, 0.05), Vector3(0, -0.06, 0.02), dark)
    if id == "shotgun" or id == "ak" or id == "sniper":
        _box(root, Vector3(0.05, 0.1, 0.22), Vector3(0, 0.0, 0.14), Color(0.35, 0.22, 0.12))
    if id == "sniper":
        _box(root, Vector3(0.045, 0.045, 0.2), Vector3(0, 0.1, -L * 0.2), dark)
    if id == "ak" or id == "uzi":
        _box(root, Vector3(0.04, 0.14, 0.06), Vector3(0, -0.1, -L * 0.15), dark)
    var muzzle := Marker3D.new()
    muzzle.position = Vector3(0, 0.04, -L * 0.97)
    root.add_child(muzzle)
    return {"node": root, "muzzle": muzzle, "fore": minf(0.2, L * 0.4)}
