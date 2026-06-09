extends CanvasLayer
class_name SkillTreeUI
# The Necromancy tree. Pauses the world, lays nodes out as a real branching graph
# with connecting lines, and lets you spend souls on transformative abilities.

var center := Vector2(640, 280)
var buttons := {}        # id -> Button
var line_refs := []      # [{line, a, b}]
var desc: Label
var souls_lbl: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20

	var vp := get_viewport().get_visible_rect().size
	if vp.x < 10.0:
		vp = Vector2(1280, 720)
	center = Vector2(vp.x * 0.5, vp.y * 0.32)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06, 0.95)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := _label(Vector2(40, 22), 38)
	title.text = "NECROMANCY"
	title.modulate = Color(0.6, 1.0, 0.6)
	souls_lbl = _label(Vector2(40, 70), 28)

	# Connection lines first (drawn under the buttons).
	for s in Build.SKILLS:
		for r in s["req"]:
			var rs = Build.skill(r)
			var ln := Line2D.new()
			ln.width = 4.0
			ln.points = PackedVector2Array([center + rs["pos"], center + s["pos"]])
			ln.default_color = Color(0.3, 0.3, 0.35)
			add_child(ln)
			line_refs.append({"line": ln, "a": r, "b": s["id"]})

	# Skill nodes.
	for s in Build.SKILLS:
		var b := Button.new()
		var sz := Vector2(168, 58)
		b.size = sz
		b.custom_minimum_size = sz
		b.position = center + s["pos"] - sz * 0.5
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_pressed.bind(s["id"]))
		b.mouse_entered.connect(_on_hover.bind(s["id"]))
		add_child(b)
		buttons[s["id"]] = b

	desc = _label(Vector2(40, vp.y - 170), 22)
	desc.size = Vector2(vp.x - 80, 110)
	desc.custom_minimum_size = desc.size
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var hint := _label(Vector2(40, vp.y - 40), 14)
	hint.modulate = Color(0.7, 0.7, 0.8)
	hint.text = "Hover to inspect   ·   Click to learn   ·   TAB / ESC to return to the pit"

	_refresh()

func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()

func _on_hover(id: String) -> void:
	var s = Build.skill(id)
	var status := ""
	if Build.has(id):
		status = "[LEARNED]"
	elif not Build.reqs_met(s):
		status = "[LOCKED — needs %s]" % _req_names(s)
	elif Build.souls < int(s["cost"]):
		status = "[NEED %d SOULS]" % int(s["cost"])
	else:
		status = "[READY — costs %d]" % int(s["cost"])
	desc.text = "%s  %s\n%s" % [s["name"], status, s["desc"]]

func _on_pressed(id: String) -> void:
	if Build.try_unlock(id):
		_on_hover(id)
	else:
		_on_hover(id)
	_refresh()

func _refresh() -> void:
	souls_lbl.text = "Souls to spend:  %d" % Build.souls
	for s in Build.SKILLS:
		var b: Button = buttons[s["id"]]
		if Build.has(s["id"]):
			b.text = s["name"] + "  ✓"
			b.modulate = Color(0.45, 1.0, 0.55)
		elif Build.reqs_met(s):
			b.text = "%s\n(%d)" % [s["name"], int(s["cost"])]
			b.modulate = Color(1.0, 0.85, 0.35) if Build.souls >= int(s["cost"]) else Color(0.7, 0.6, 0.4)
		else:
			b.text = "%s\n(%d)" % [s["name"], int(s["cost"])]
			b.modulate = Color(0.45, 0.45, 0.52)
	for lr in line_refs:
		var lit: bool = Build.has(lr["a"]) and Build.has(lr["b"])
		lr["line"].default_color = Color(0.45, 1.0, 0.5) if lit else Color(0.3, 0.3, 0.35)

func _req_names(s) -> String:
	var names := []
	for r in s["req"]:
		names.append(Build.skill(r)["name"])
	return ", ".join(names)

func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l
