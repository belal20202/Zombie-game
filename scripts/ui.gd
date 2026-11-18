class_name UI
extends RefCounted
## Shared UI helpers: dark theme, rounded buttons, labels.

const GOLD := Color(0.88, 0.70, 0.25)
const RED := Color(0.75, 0.2, 0.15)
const PANEL := Color(0.06, 0.08, 0.06, 0.88)

static var _theme: Theme


static func _sb(bg: Color, border: Color, radius := 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(14)
    return s


static func make_theme() -> Theme:
    if _theme != null:
        return _theme
    var t := Theme.new()
    if ResourceLoader.exists("res://assets/fonts/arabic.ttf"):
        t.default_font = load("res://assets/fonts/arabic.ttf")
    t.default_font_size = 26
    t.set_stylebox("normal", "Button", _sb(Color(0.14, 0.17, 0.13), Color(0.4, 0.45, 0.3)))
    t.set_stylebox("hover", "Button", _sb(Color(0.2, 0.24, 0.17), GOLD))
    t.set_stylebox("pressed", "Button", _sb(Color(0.6, 0.45, 0.12), GOLD))
    t.set_stylebox("disabled", "Button", _sb(Color(0.1, 0.1, 0.1), Color(0.25, 0.25, 0.25)))
    t.set_stylebox("focus", "Button", _sb(Color(0.14, 0.17, 0.13), GOLD))
    t.set_color("font_color", "Button", Color.WHITE)
    t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
    t.set_stylebox("panel", "PanelContainer", _sb(PANEL, Color(0.4, 0.45, 0.3), 18))
    t.set_stylebox("fill", "ProgressBar", _sb(RED, RED, 8))
    t.set_stylebox("background", "ProgressBar", _sb(Color(0, 0, 0, 0.6), Color(0.3, 0.3, 0.3), 8))
    _theme = t
    return t


static func full(c: Control) -> void:
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func label(text: String, size := 26, color := Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = align
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    l.add_theme_constant_override("outline_size", 4)
    return l


static func button(text: String, cb: Callable, size := 28, min_size := Vector2(320, 64)) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", size)
    b.pressed.connect(Sfx.play.bind("click"))
    b.pressed.connect(cb)
    return b
