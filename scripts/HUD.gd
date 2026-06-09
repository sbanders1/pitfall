extends CanvasLayer
class_name HUD
# Souls / layer / horde readout, a prominent HP bar, and transient flash messages.
# Fonts are deliberately large for at-a-glance reading while driving.

var souls_lbl: Label
var info_lbl: Label
var flash_lbl: Label
var hp_back: ColorRect
var hp_fill: ColorRect
var hp_lbl: Label
var flash_t := 0.0

const HP_BAR_W := 420.0
const HP_BAR_H := 38.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	souls_lbl = _label(Vector2(24, 16), 42)
	info_lbl = _label(Vector2(24, 78), 28)

	# HP bar
	hp_back = ColorRect.new()
	hp_back.position = Vector2(24, 124)
	hp_back.size = Vector2(HP_BAR_W, HP_BAR_H)
	hp_back.color = Color(0.12, 0.04, 0.06, 0.9)
	hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.position = Vector2(28, 128)
	hp_fill.size = Vector2(HP_BAR_W - 8.0, HP_BAR_H - 8.0)
	hp_fill.color = Color(0.3, 0.9, 0.4)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_fill)
	hp_lbl = _label(Vector2(36, 126), 24)

	flash_lbl = _label(Vector2(24, 178), 32)
	flash_lbl.modulate = Color(1, 0.9, 0.4)

	var help := _label(Vector2(24, 680), 22)
	help.modulate = Color(0.75, 0.75, 0.85)
	help.text = "↑/W accelerate   ·   ↓/S brake   ·   ←→/AD steer   ·   SPACE raise dead   ·   TAB tree   ·   F1 tune"

	Build.souls_changed.connect(_on_souls)
	_on_souls(Build.souls)

func _process(delta: float) -> void:
	flash_t = max(0.0, flash_t - delta)
	flash_lbl.modulate.a = clamp(flash_t, 0.0, 1.0)

	var minions := get_tree().get_nodes_in_group("minion").size()
	var cap := 24 if Build.has("legion") else 10
	var w = _world()
	var layer = w.layer if w else 1
	var goal = w.goal_depth if w else 1000
	info_lbl.text = "LAYER %d   ·   Descent %d / %dm   ·   Horde %d/%d" % [layer, _depth(), goal, minions, cap]

	var hp := _player_hp()
	var mx := _player_maxhp()
	var frac: float = clamp(hp / mx, 0.0, 1.0) if mx > 0.0 else 0.0
	hp_fill.size.x = (HP_BAR_W - 8.0) * frac
	hp_fill.color = Color(0.9, 0.2, 0.2).lerp(Color(0.3, 0.9, 0.4), frac)
	hp_lbl.text = "HP  %d" % int(hp)

func _on_souls(amount: int) -> void:
	souls_lbl.text = "SOULS  %d" % amount
	souls_lbl.modulate = Color(0.6, 1.0, 0.6)

func flash(msg: String) -> void:
	flash_lbl.text = msg
	flash_t = 2.5

func _world():
	var a := get_tree().get_nodes_in_group("world")
	return a[0] if a.size() > 0 else null

func _player_hp() -> float:
	var a := get_tree().get_nodes_in_group("player")
	return a[0].hp if a.size() > 0 else 0.0

func _player_maxhp() -> float:
	var a := get_tree().get_nodes_in_group("player")
	return a[0].max_hp if a.size() > 0 else 1.0

func _depth() -> int:
	var w = _world()
	return w.depth_m() if w else 0

func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l
