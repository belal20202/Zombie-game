extends Node
## Procedural sound effects: every weapon has its own sound, plus switch/reload/zombie/UI sounds.

const RATE := 16000
var streams := {}
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    for i in 10:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _pool.append(p)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = RATE
    w.stereo = false
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in samples.size():
        bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
    w.data = bytes
    return w


func _gen(dur: float, noise: float, cutoff: float, f0: float, f1: float, tone: float, decay: float, wave := 0) -> PackedFloat32Array:
    var n := int(dur * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var lp := 0.0
    var ph := 0.0
    var a := clampf(cutoff, 0.01, 1.0)
    for i in n:
        var t := float(i) / float(n)
        var env := pow(1.0 - t, decay)
        lp += a * (randf_range(-1.0, 1.0) - lp)
        ph += TAU * lerpf(f0, f1, t) / float(RATE)
        var s := sin(ph)
        if wave == 1:
            s = signf(s) * 0.6
        elif wave == 2:
            s = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
        out[i] = (lp * noise + s * tone) * env
    return out


func _silence(dur: float) -> PackedFloat32Array:
    var a := PackedFloat32Array()
    a.resize(int(dur * RATE))
    return a


func _join(parts: Array) -> PackedFloat32Array:
    var out := PackedFloat32Array()
    for p in parts:
        out.append_array(p)
    return out


func _build() -> void:
    streams["pistol"] = _wav(_gen(0.18, 1.0, 0.35, 220.0, 60.0, 0.5, 3.0))
    streams["uzi"] = _wav(_gen(0.09, 0.9, 0.6, 320.0, 110.0, 0.3, 3.5))
    streams["shotgun"] = _wav(_gen(0.45, 1.2, 0.15, 90.0, 35.0, 0.6, 2.2))
    streams["ak"] = _wav(_gen(0.16, 1.0, 0.3, 160.0, 50.0, 0.5, 3.0, 2))
    streams["sniper"] = _wav(_gen(0.8, 1.1, 0.1, 70.0, 28.0, 0.7, 2.0))
    streams["switch"] = _wav(_join([_gen(0.04, 0.3, 0.6, 900.0, 700.0, 0.4, 2.0, 1), _silence(0.04), _gen(0.05, 0.3, 0.6, 520.0, 420.0, 0.4, 2.0, 1)]))
    streams["reload"] = _wav(_join([_gen(0.05, 0.3, 0.6, 300.0, 250.0, 0.4, 2.0, 1), _silence(0.3), _gen(0.06, 1.0, 0.4, 200.0, 150.0, 0.2, 3.0), _silence(0.3), _gen(0.06, 0.3, 0.6, 700.0, 600.0, 0.5, 2.0, 1)]))
    streams["empty"] = _wav(_gen(0.04, 0.2, 0.6, 1200.0, 1100.0, 0.4, 2.0, 1))
    streams["hit"] = _wav(_gen(0.05, 0.2, 0.6, 1500.0, 1200.0, 0.4, 2.0))
    streams["hurt"] = _wav(_gen(0.25, 0.8, 0.2, 140.0, 60.0, 0.5, 2.0, 2))
    streams["die"] = _wav(_gen(0.35, 0.8, 0.15, 110.0, 40.0, 0.4, 2.0, 1))
    streams["groan1"] = _wav(_gen(0.7, 0.15, 0.1, 95.0, 50.0, 0.5, 1.2, 2))
    streams["groan2"] = _wav(_gen(0.8, 0.15, 0.1, 120.0, 60.0, 0.5, 1.2, 2))
    streams["groan3"] = _wav(_gen(0.6, 0.2, 0.1, 80.0, 45.0, 0.5, 1.2, 2))
    streams["step"] = _wav(_gen(0.06, 1.0, 0.12, 80.0, 60.0, 0.3, 3.0))
    streams["jump"] = _wav(_gen(0.15, 0.0, 1.0, 300.0, 600.0, 0.4, 1.5))
    streams["click"] = _wav(_gen(0.03, 0.1, 0.6, 800.0, 700.0, 0.4, 2.0, 1))
    streams["coin"] = _wav(_join([_gen(0.06, 0.0, 1.0, 1300.0, 1300.0, 0.4, 1.5), _gen(0.1, 0.0, 1.0, 1800.0, 1800.0, 0.4, 1.5)]))
    streams["buy"] = _wav(_join([_gen(0.08, 0.0, 1.0, 600.0, 600.0, 0.4, 1.5), _gen(0.08, 0.0, 1.0, 900.0, 900.0, 0.4, 1.5), _gen(0.15, 0.0, 1.0, 1200.0, 1200.0, 0.4, 1.5)]))
    streams["win"] = _wav(_join([_gen(0.2, 0.0, 1.0, 523.0, 523.0, 0.4, 1.2), _gen(0.2, 0.0, 1.0, 659.0, 659.0, 0.4, 1.2), _gen(0.2, 0.0, 1.0, 784.0, 784.0, 0.4, 1.2), _gen(0.35, 0.0, 1.0, 1047.0, 1047.0, 0.4, 1.2)]))
    streams["lose"] = _wav(_join([_gen(0.3, 0.0, 1.0, 300.0, 280.0, 0.4, 1.2, 2), _gen(0.3, 0.0, 1.0, 240.0, 220.0, 0.4, 1.2, 2), _gen(0.5, 0.0, 1.0, 180.0, 120.0, 0.4, 1.2, 2)]))


func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
    if not Game.sound_on or not streams.has(sound):
        return
    for p in _pool:
        if not p.playing:
            p.stream = streams[sound]
            p.volume_db = vol_db
            p.pitch_scale = pitch
            p.play()
            return


func play3d(sound: String, pos: Vector3) -> void:
    if not Game.sound_on or not streams.has(sound):
        return
    var root := get_tree().current_scene
    if root == null:
        return
    var p := AudioStreamPlayer3D.new()
    p.stream = streams[sound]
    p.unit_size = 6.0
    p.max_distance = 45.0
    root.add_child(p)
    p.global_position = pos
    p.finished.connect(p.queue_free)
    p.play()
