class_name TouchControls
extends Control
## On-screen controls for phones: floating move stick (left), look drag (right), fire/jump/reload/switch buttons.

const STICK_R := 90.0

var move_vec := Vector2.ZERO
var fire_held := false

var _look := Vector2.ZERO
var _jump := false
var _reload := false
var _switch := false
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _look_id := -1
var _fire_id := -1


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.full(self)


func take_look() -> Vector2:
    var r := _look
    _look = Vector2.ZERO
    return r


func consume_jump() -> bool:
    var r := _jump
    _jump = false
    return r


func consume_reload() -> bool:
    var r := _reload
    _reload = false
    return r


func consume_switch() -> bool:
    var r := _switch
    _switch = false
    return r


func _layout() -> Dictionary:
    var s := get_viewport_rect().size
    return {
        "fire": [Vector2(s.x - 130.0, s.y - 150.0), 72.0],
        "jump": [Vector2(s.x - 290.0, s.y - 100.0), 50.0],
        "switch": [Vector2(s.x - 250.0, s.y - 240.0), 44.0],
        "reload": [Vector2(s.x - 110.0, s.y - 310.0), 44.0],
    }


func _hit(pos: Vector2) -> String:
    var l := _layout()
    for k in l:
        var c: Vector2 = l[k][0]
        var r: float = l[k][1]
        if pos.distance_to(c) <= r + 14.0:
            return k
    return ""


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            var h := _hit(event.position)
            if h == "fire":
                fire_held = true
                _fire_id = event.index
            elif h == "jump":
                _jump = true
            elif h == "reload":
                _reload = true
            elif h == "switch":
                _switch = true
            elif event.position.x < size.x * 0.45:
                if _stick_id == -1:
                    _stick_id = event.index
                    _stick_origin = event.position
            elif _look_id == -1:
                _look_id = event.index
        else:
            if event.index == _fire_id:
                fire_held = false
                _fire_id = -1
            if event.index == _stick_id:
                _stick_id = -1
                move_vec = Vector2.ZERO
            if event.index == _look_id:
                _look_id = -1
        queue_redraw()
    elif event is InputEventScreenDrag:
        if event.index == _stick_id:
            move_vec = ((event.position - _stick_origin) / STICK_R).limit_length(1.0)
        elif event.index == _look_id:
            _look += event.relative
        queue_redraw()


func _draw() -> void:
    var l := _layout()
    var ring := Color(1, 1, 1, 0.55)
    for k in l:
        var c: Vector2 = l[k][0]
        var r: float = l[k][1]
        var f := Color(1, 1, 1, 0.12)
        if k == "fire":
            f = Color(0.8, 0.15, 0.1, 0.6 if fire_held else 0.35)
        draw_circle(c, r, f)
        draw_arc(c, r, 0.0, TAU, 40, ring, 3.0)
        _icon(k, c, r)
    if _stick_id != -1:
        draw_arc(_stick_origin, STICK_R, 0.0, TAU, 48, ring, 3.0)
        draw_circle(_stick_origin + move_vec * STICK_R, 34.0, Color(1, 1, 1, 0.35))
    else:
        draw_arc(Vector2(170.0, size.y - 150.0), STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.2), 2.0)


func _icon(k: String, c: Vector2, r: float) -> void:
    var w := Color(1, 1, 1, 0.9)
    match k:
        "fire":
            for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
                draw_line(c + d * r * 0.2, c + d * r * 0.6, w, 4.0)
            draw_circle(c, 5.0, w)
        "jump":
            draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.5, r * 0.35), c + Vector2(-r * 0.5, r * 0.35)]), w)
        "reload":
            draw_arc(c, r * 0.45, 0.5, TAU - 0.5, 24, w, 4.0)
            draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.55, -r * 0.4), c + Vector2(r * 0.15, -r * 0.4), c + Vector2(r * 0.4, 0.0)]), w)
        "switch":
            draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.3), Vector2(r * 0.7, r * 0.2)), w)
            draw_rect(Rect2(c + Vector2(-r * 0.2, r * 0.1), Vector2(r * 0.7, r * 0.2)), w)
