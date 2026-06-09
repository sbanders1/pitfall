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
var lvl_lbl: Label
var xp_back: ColorRect
var xp_fill: ColorRect
var flash_t := 0.0
var disp_level := 1
var disp_points := 0
var initialized := false
var over_bg: ColorRect
var over_lbl: Label
var game_over_on := false

const HP_BAR_W := 420.0
const HP_BAR_H := 38.0
const XP_BAR_W := 300.0
const XP_BAR_H := 16.0

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

	# Level + XP readout, top-right. Levelling is how you earn skill-tree points.
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 10.0:
		vp = Vector2(1280, 720)
	var rx := vp.x - XP_BAR_W - 24.0
	lvl_lbl = _label(Vector2(rx, 16), 32)
	lvl_lbl.modulate = Color(0.75, 0.85, 1.0)

	xp_back = ColorRect.new()
	xp_back.position = Vector2(rx, 60)
	xp_back.size = Vector2(XP_BAR_W, XP_BAR_H)
	xp_back.color = Color(0.06, 0.08, 0.14, 0.9)
	xp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_back)
	xp_fill = ColorRect.new()
	xp_fill.position = Vector2(rx + 2.0, 62)
	xp_fill.size = Vector2(XP_BAR_W - 4.0, XP_BAR_H - 4.0)
	xp_fill.color = Color(0.4, 0.6, 1.0)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_fill)

	var help := _label(Vector2(24, 680), 20)
	help.modulate = Color(0.75, 0.75, 0.85)
	help.text = "↑/W accel  ·  ↓/S brake  ·  ←→ steer  ·  SPACE raise (souls)  ·  Q hold/hunt horde  ·  TAB tree  ·  F1 tune"

	# Game-over overlay (hidden until the dark takes you).
	over_bg = ColorRect.new()
	over_bg.color = Color(0.0, 0.0, 0.0, 0.84)
	over_bg.position = Vector2.ZERO
	over_bg.size = vp
	over_bg.visible = false
	over_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over_bg)
	over_lbl = Label.new()
	over_lbl.position = Vector2(0, vp.y * 0.30)
	over_lbl.size = Vector2(vp.x, vp.y * 0.4)
	over_lbl.add_theme_font_size_override("font_size", 38)
	over_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_lbl.visible = false
	over_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over_lbl)

	Build.souls_changed.connect(_on_souls)
	Build.xp_changed.connect(_on_xp)
	Build.level_changed.connect(_on_level)
	Build.points_changed.connect(_on_points)
	_on_souls(Build.souls)
	_on_level(Build.level)
	_on_points(Build.skill_points)
	_on_xp(Build.xp, Build.xp_to_next())
	initialized = true

func _process(delta: float) -> void:
	flash_t = max(0.0, flash_t - delta)
	flash_lbl.modulate.a = clamp(flash_t, 0.0, 1.0)

	var minions := get_tree().get_nodes_in_group("minion").size()
	var cap := 24 if Build.has("legion") else 10
	var w = _world()
	var gap_m: int = int(w.gap / 10.0) if w else 0
	var holding: bool = w != null and w.horde_stance() == 1
	info_lbl.text = "ESCAPED %dm   ·   DOOM %dm back   ·   Horde %d/%d [%s]" % [_depth(), gap_m, minions, cap, "HOLD" if holding else "HUNT"]
	info_lbl.modulate = Color(1.0, 0.35, 0.35) if gap_m < 50 else Color(1, 1, 1)

	var hp := _player_hp()
	var mx := _player_maxhp()
	var frac: float = clamp(hp / mx, 0.0, 1.0) if mx > 0.0 else 0.0
	hp_fill.size.x = (HP_BAR_W - 8.0) * frac
	hp_fill.color = Color(0.9, 0.2, 0.2).lerp(Color(0.3, 0.9, 0.4), frac)
	hp_lbl.text = "HP  %d" % int(hp)

func _on_souls(amount: int) -> void:
	souls_lbl.text = "SOULS  %d" % amount
	souls_lbl.modulate = Color(0.6, 1.0, 0.6)

func _on_xp(xp: int, needed: int) -> void:
	var frac: float = clamp(float(xp) / float(needed), 0.0, 1.0) if needed > 0 else 0.0
	xp_fill.size.x = (XP_BAR_W - 4.0) * frac

func _on_level(level: int) -> void:
	disp_level = level
	_update_lvl_lbl()
	if initialized:
		flash("LEVEL %d!  +1 skill point — press TAB to spend" % level)

func _on_points(points: int) -> void:
	disp_points = points
	_update_lvl_lbl()

func _update_lvl_lbl() -> void:
	lvl_lbl.text = "LV %d   ·   %d PTS" % [disp_level, disp_points]
	lvl_lbl.modulate = Color(1.0, 0.85, 0.35) if disp_points > 0 else Color(0.75, 0.85, 1.0)

func flash(msg: String) -> void:
	flash_lbl.text = msg
	flash_t = 2.5

func game_over(reason: String, dist: int, best: int) -> void:
	game_over_on = true
	over_bg.visible = true
	over_lbl.visible = true
	over_lbl.text = "%s\n\nYou clawed up %d m.    Best: %d m\n\nPress SPACE to fall back in and try again." % [reason, dist, best]

func hide_game_over() -> void:
	game_over_on = false
	over_bg.visible = false
	over_lbl.visible = false

func _input(event: InputEvent) -> void:
	if not game_over_on:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			var w = _world()
			if w:
				w._reset_run()
			hide_game_over()
			get_viewport().set_input_as_handled()

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
