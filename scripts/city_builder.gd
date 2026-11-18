class_name CityBuilder
extends RefCounted
## Builds one of the 10 city themes: environment, ground, roads, buildings, cars, crates, lamps, trees.

const ARENA := 60.0
static var _win_tex: ImageTexture
static var _lit_tex: ImageTexture


static func _make_textures() -> void:
    if _win_tex != null:
        return
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var lit := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    img.fill(Color(1, 1, 1))
    lit.fill(Color(0, 0, 0))
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for i in 8:
        for j in 8:
            var r := Rect2i(4 + i * 15, 4 + j * 15, 9, 10)
            img.fill_rect(r, Color(0.22, 0.27, 0.34))
            if rng.randf() < 0.4:
                lit.fill_rect(r, Color(1.0, 0.85, 0.5))
    _win_tex = ImageTexture.create_from_image(img)
    _lit_tex = ImageTexture.create_from_image(lit)


static func _flat(c: Color, emissive := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.9
    if emissive:
        m.emission_enabled = true
        m.emission = c
    return m


static func _bld_mat(c: Color, night: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.albedo_texture = _win_tex
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(0.12, 0.12, 0.12)
    m.roughness = 0.9
    if night:
        m.emission_enabled = true
        m.emission_texture = _lit_tex
        m.emission_energy_multiplier = 1.6
    return m


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi


static func _box_mesh(s: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = s
    return b


static func _body(parent: Node3D, pos: Vector3, shape: Shape3D, shape_y: float) -> StaticBody3D:
    var sb := StaticBody3D.new()
    sb.collision_layer = 1
    sb.position = pos
    var cs := CollisionShape3D.new()
    cs.shape = shape
    cs.position.y = shape_y
    sb.add_child(cs)
    parent.add_child(sb)
    return sb


static func _spot(rng: RandomNumberGenerator, used: Array) -> Vector3:
    for t in 40:
        var p := Vector3(rng.randf_range(-52.0, 52.0), 0, rng.randf_range(-52.0, 52.0))
        var p2 := Vector2(p.x, p.z)
        if p2.distance_to(Vector2(0, 44)) < 9.0:
            continue
        var ok := true
        for u in used:
            if p2.distance_to(u) < 6.0:
                ok = false
                break
        if ok:
            used.append(p2)
            return p
    return Vector3(rng.randf_range(-40.0, 40.0), 0, rng.randf_range(-40.0, 0.0))


static func build(parent: Node3D, theme: Dictionary, seed_value: int) -> void:
    _make_textures()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var night: bool = theme["night"]
    var sky: Color = theme["sky"]
    var root := Node3D.new()
    root.name = "City"
    parent.add_child(root)

    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = sky.lerp(Color(1, 1, 1), 0.35)
    env.ambient_light_energy = float(theme["light"])
    env.fog_enabled = true
    env.fog_light_color = sky
    env.fog_density = 3.0 / float(theme["fog"])
    var we := WorldEnvironment.new()
    we.environment = env
    root.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, 30, 0)
    sun.light_energy = 0.25 if night else 0.9
    root.add_child(sun)

    var gm := PlaneMesh.new()
    gm.size = Vector2(600, 600)
    _mi(root, gm, _flat(theme["ground"]), Vector3.ZERO)
    var gb := StaticBody3D.new()
    gb.collision_layer = 1
    var gs := CollisionShape3D.new()
    gs.shape = WorldBoundaryShape3D.new()
    gb.add_child(gs)
    root.add_child(gb)
    var road_mat := _flat(Color(0.1, 0.1, 0.1) if night else Color(0.17, 0.17, 0.18))
    var r1 := PlaneMesh.new()
    r1.size = Vector2(14, 600)
    _mi(root, r1, road_mat, Vector3(0, 0.02, 0))
    var r2 := _mi(root, r1, road_mat, Vector3(0, 0.02, 0))
    r2.rotation.y = PI / 2.0
    var line := PlaneMesh.new()
    line.size = Vector2(0.3, 600)
    _mi(root, line, _flat(Color(0.8, 0.72, 0.35)), Vector3(0, 0.04, 0))

    var wall := StaticBody3D.new()
    wall.collision_layer = 1
    root.add_child(wall)
    for side in 4:
        var wcs := CollisionShape3D.new()
        var wbs := BoxShape3D.new()
        var horizontal := side < 2
        var sgn := -1.0 if side % 2 == 0 else 1.0
        if horizontal:
            wbs.size = Vector3(ARENA * 2.0 + 8.0, 40.0, 2.0)
            wcs.position = Vector3(0, 20, sgn * (ARENA + 1.0))
        else:
            wbs.size = Vector3(2.0, 40.0, ARENA * 2.0 + 8.0)
            wcs.position = Vector3(sgn * (ARENA + 1.0), 20, 0)
        wcs.shape = wbs
        wall.add_child(wcs)

    var mats: Array[StandardMaterial3D] = []
    for c in theme["bld"]:
        mats.append(_bld_mat(c, night))
    var d := ARENA + 9.0
    var i := -ARENA - 14.0
    while i <= ARENA + 14.0:
        for pos in [Vector3(i, 0, -d), Vector3(i, 0, d), Vector3(-d, 0, i), Vector3(d, 0, i)]:
            var h := 14.0 + rng.randf() * 40.0
            _mi(root, _box_mesh(Vector3(14, h, 14)), mats[rng.randi() % mats.size()], pos + Vector3(0, h / 2.0, 0))
        i += 14.0
    for k in 30:
        var a := rng.randf() * TAU
        var dist := 110.0 + rng.randf() * 60.0
        var h2 := 30.0 + rng.randf() * 60.0
        _mi(root, _box_mesh(Vector3(18, h2, 18)), mats[rng.randi() % mats.size()], Vector3(cos(a) * dist, h2 / 2.0, sin(a) * dist))

    var used: Array = []
    var car_cols := [Color("#8a2a2a"), Color("#2a4a7a"), Color("#555555"), Color("#b0a060"), Color("#2a6a4a")]
    for k in 8:
        var p := _spot(rng, used)
        var cbs := BoxShape3D.new()
        cbs.size = Vector3(1.9, 1.6, 4.2)
        var car := _body(root, p, cbs, 0.8)
        car.rotation.y = rng.randf() * TAU
        _mi(car, _box_mesh(Vector3(1.9, 0.7, 4.2)), _flat(car_cols[rng.randi() % car_cols.size()]), Vector3(0, 0.55, 0))
        _mi(car, _box_mesh(Vector3(1.6, 0.6, 2.0)), _flat(Color(0.1, 0.1, 0.13)), Vector3(0, 1.2, -0.1))
    for k in 8:
        var p := _spot(rng, used)
        var xbs := BoxShape3D.new()
        xbs.size = Vector3(1.6, 1.6, 1.6)
        var crate := _body(root, p, xbs, 0.8)
        _mi(crate, _box_mesh(Vector3(1.6, 1.6, 1.6)), _flat(Color("#7a5a30")), Vector3(0, 0.8, 0))
    for k in 6:
        var p := _spot(rng, used)
        var bcy := CylinderShape3D.new()
        bcy.radius = 0.45
        bcy.height = 1.1
        var barrel := _body(root, p, bcy, 0.55)
        var bm := CylinderMesh.new()
        bm.top_radius = 0.45
        bm.bottom_radius = 0.45
        bm.height = 1.1
        _mi(barrel, bm, _flat(Color("#8a2a1a")), Vector3(0, 0.55, 0))
    for k in 8:
        var p := _spot(rng, used)
        var lcy := CylinderShape3D.new()
        lcy.radius = 0.2
        lcy.height = 6.0
        var lamp := _body(root, p, lcy, 3.0)
        var pm := CylinderMesh.new()
        pm.top_radius = 0.08
        pm.bottom_radius = 0.1
        pm.height = 6.0
        _mi(lamp, pm, _flat(Color(0.12, 0.12, 0.12)), Vector3(0, 3.0, 0))
        var sm := SphereMesh.new()
        sm.radius = 0.3
        sm.height = 0.6
        _mi(lamp, sm, _flat(Color(1.0, 0.9, 0.6) if night else Color(0.8, 0.8, 0.8), true), Vector3(0, 6.1, 0))
        if night and k < 5:
            var ol := OmniLight3D.new()
            ol.position = Vector3(0, 6.0, 0)
            ol.omni_range = 16.0
            ol.light_energy = 1.2
            ol.light_color = Color(1.0, 0.85, 0.55)
            lamp.add_child(ol)
    var deco: String = theme["deco"]
    if deco != "":
        for k in 14:
            var p := _spot(rng, used)
            var tcy := CylinderShape3D.new()
            tcy.radius = 0.5
            tcy.height = 3.0
            var tree := _body(root, p, tcy, 1.5)
            if deco == "cactus":
                var cm := CylinderMesh.new()
                cm.top_radius = 0.3
                cm.bottom_radius = 0.35
                cm.height = 2.6
                _mi(tree, cm, _flat(Color("#3f7a3a")), Vector3(0, 1.3, 0))
            else:
                var trunk := CylinderMesh.new()
                trunk.top_radius = 0.25
                trunk.bottom_radius = 0.3
                trunk.height = 2.0
                _mi(tree, trunk, _flat(Color("#4a3220")), Vector3(0, 1.0, 0))
                var cone := CylinderMesh.new()
                cone.top_radius = 0.0
                cone.bottom_radius = 1.5
                cone.height = 4.0
                _mi(tree, cone, _flat(Color("#e8f0f4") if deco == "snow" else Color("#2a5a2a")), Vector3(0, 3.6, 0))
