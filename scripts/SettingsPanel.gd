extends CanvasLayer
class_name SettingsPanel
# Live tuning overlay (toggle with F1). Sliders write straight into the Tune autoload
# while you drive, so you can dial in handling and difficulty without restarting.

var root: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06, 0.92)
	bg.position = Vector2(832, 14)
	bg.size = Vector2(432, 486)
	add_child(bg)

	root = VBoxContainer.new()
	root.position = Vector2(852, 26)
	root.custom_minimum_size = Vector2(394, 0)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_header("TUNING — F1 to close", Color(0.6, 1.0, 0.6))
	_header("Player", Color(0.5, 0.85, 1.0))
	_row("Acceleration", "player_accel", 200.0, 5000.0, 50.0, 0)
	_row("Top Speed", "player_top", 300.0, 3000.0, 50.0, 0)
	_row("Braking", "player_brake", 300.0, 5000.0, 50.0, 0)
	_row("Turn Speed", "player_turn", 1.0, 8.0, 0.1, 1)
	_header("Enemies", Color(1.0, 0.5, 0.5))
	_row("Top Speed", "enemy_top", 200.0, 3000.0, 50.0, 0)
	_row("Turn Rate", "enemy_turn", 0.5, 6.0, 0.1, 1)
	_header("Combat", Color(0.9, 0.8, 0.4))
	_check("Keep my speed when I ram", "ram_keep_speed")

func toggle() -> void:
	visible = not visible

func _header(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", 22)
	root.add_child(l)

func _row(title: String, prop: String, minv: float, maxv: float, step: float, decimals: int) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var name := Label.new()
	name.text = title
	name.custom_minimum_size = Vector2(150, 32)
	name.add_theme_font_size_override("font_size", 18)

	var sl := HSlider.new()
	sl.min_value = minv
	sl.max_value = maxv
	sl.step = step
	sl.value = Tune.get(prop)
	sl.custom_minimum_size = Vector2(180, 32)
	sl.focus_mode = Control.FOCUS_NONE   # don't let arrow keys hijack steering

	var val := Label.new()
	val.custom_minimum_size = Vector2(56, 32)
	val.add_theme_font_size_override("font_size", 18)
	val.text = _fmt(Tune.get(prop), decimals)

	sl.value_changed.connect(func(v):
		Tune.set(prop, v)
		val.text = _fmt(v, decimals)
	)

	hb.add_child(name)
	hb.add_child(sl)
	hb.add_child(val)
	root.add_child(hb)

func _check(title: String, prop: String) -> void:
	var cb := CheckButton.new()
	cb.text = title
	cb.button_pressed = Tune.get(prop)
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(func(pressed): Tune.set(prop, pressed))
	root.add_child(cb)

func _fmt(v: float, decimals: int) -> String:
	if decimals <= 0:
		return "%d" % int(round(v))
	return "%.1f" % v
