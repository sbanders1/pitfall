extends Node3D
# World root (3D). An ENDLESS forward corridor built as a treadmill: the road and
# rails ride with the player, the roadside pylons snap to a fixed grid so they stream
# past, and the whole world is periodically rebased back toward the origin so float
# coordinates never grow large. Rivals spawn behind and surge up into view.
#
# Coordinate convention: X = lateral / lanes,  Y = up (ground = Y0),  -Z = forward.

var num_lanes := 4
var lane_w := 190.0
var road_half := 380.0     # half-width of the drivable road (= num_lanes * lane_w / 2)
var player: Player
var hud: HUD
var skill_ui: SkillTreeUI
var settings_ui: SettingsPanel
var spawn_timer := 0.0
var raise_radius := 360.0

# Treadmill bookkeeping
var surface: Node3D        # road + rails; rides with the player (uniform, so invisible)
var pylons: Node3D         # roadside markers; snaps to a grid so they appear planted
var accum := 0.0           # total distance rebased away — keeps depth continuous
const VIEW_AHEAD := 8000.0    # little is shown ahead now — the rear-view camera looks back
const VIEW_BEHIND := 20000.0  # deep coverage of the road BEHIND you, so it fades into fog
const PYL_SPACING := 300.0
const REBASE_STEP := 18000.0   # must be a whole number of PYL_SPACING

# Descent goal: drive deep enough to clear the layer. Each clear pays souls (feeding
# the build) and drops you into a deeper, busier layer — the rogue-lite descent.
var layer := 1
var goal_depth := 1000     # absolute depth (m) that clears the current layer
const LAYER_STRIDE := 1000  # each layer is this much deeper than the last

# The Doom — a wall of dark that chases you up out of the pit. Stay ahead of it or the
# run ends. Kills and skeletons hurled into it (Q = HOLD) buy back distance.
var wall: Node3D
var wall_mat: StandardMaterial3D
var gap := 1200.0          # distance from you to the wall's leading edge
var run_time := 0.0
var wall_flash := 0.0      # brief emission spike when the horde slams it back
var dead := false
var best := 0
var stance := 0            # 0 = HUNT (chase rivals), 1 = HOLD (hurl horde at the wall)
const GAP_START := 1200.0
const GAP_MAX := 1700.0
const STANCE_HUNT := 0
const STANCE_HOLD := 1

func _ready() -> void:
	randomize()
	road_half = num_lanes * lane_w / 2.0
	add_to_group("world")
	_build_environment()

	surface = Node3D.new()
	add_child(surface)
	_build_road(surface)
	_build_walls(surface)

	pylons = Node3D.new()
	add_child(pylons)
	_build_scenery(pylons)

	player = Player.new()
	add_child(player)

	# The necromancer rides in with two persistent summoned death cars — your means
	# of killing rivals without ever touching them yourself.
	_spawn_death_cars()
	_build_wall()
	gap = GAP_START

	hud = HUD.new()
	add_child(hud)

	skill_ui = SkillTreeUI.new()
	add_child(skill_ui)
	skill_ui.hide()

	settings_ui = SettingsPanel.new()
	add_child(settings_ui)

	# A pool of starting souls so you can raise the dead from the very first corpse.
	Build.add_souls(12)
	_treadmill()

func _process(delta: float) -> void:
	if get_tree().paused or dead:
		return
	_treadmill()
	_update_wall(delta)
	if dead:
		return
	spawn_timer -= delta
	var count := get_tree().get_nodes_in_group("enemy").size()
	# Only a handful of hunters at once — 4 at the surface, creeping up as you descend.
	var traffic_cap := 4 + int((layer - 1) / 2)
	if spawn_timer <= 0.0 and count < traffic_cap:
		spawn_timer = 1.1
		_spawn_enemy()
	_cull_behind()
	_check_goal()

func _treadmill() -> void:
	var pz := player.global_position.z
	# Rebase the whole world back toward the origin when you've travelled a full step.
	# Player + every entity shift together, so it's visually seamless.
	if pz <= -REBASE_STEP:
		var shift := Vector3(0.0, 0.0, REBASE_STEP)
		player.global_position += shift
		for g in ["enemy", "minion", "corpse", "deathcar", "miasma"]:
			for n in get_tree().get_nodes_in_group(g):
				n.global_position += shift
		accum += REBASE_STEP
		pz = player.global_position.z
	# Road + rails ride with you (uniform along Z, so the slide can't be seen).
	surface.position.z = pz
	# Pylons snap to a fixed grid so they look planted and rush past as you move.
	pylons.position.z = round(pz / PYL_SPACING) * PYL_SPACING

func depth_m() -> int:
	return int(maxf(0.0, accum - player.global_position.z) / 10.0)

func _check_goal() -> void:
	if depth_m() < goal_depth:
		return
	layer += 1   # tracked for the traffic-density ramp
	goal_depth += LAYER_STRIDE
	Build.add_souls(8)
	hud.flash("CHECKPOINT — +8 souls. Keep climbing out!")

func _update_wall(delta: float) -> void:
	run_time += delta
	# The wall paces YOUR top speed and relentlessly accelerates past it — early on you
	# can pull ahead by flooring it, but soon raw speed alone won't keep you clear.
	var wall_speed := Tune.player_top * Tune.wall_base + Tune.wall_ramp * run_time
	var pspeed := player.velocity.length()
	gap += (pspeed - wall_speed) * delta
	gap = minf(gap, GAP_MAX)
	if gap <= 0.0:
		end_run("THE DARK SWALLOWED YOU")
		return
	wall.position = Vector3(0.0, 0.0, player.global_position.z + gap + 70.0)
	wall_flash = maxf(0.0, wall_flash - delta)
	wall_mat.emission_energy_multiplier = 1.6 + 0.6 * sin(run_time * 6.0) + wall_flash * 12.0

func wall_front_z() -> float:
	return player.global_position.z + gap

func horde_stance() -> int:
	return stance

func on_kill() -> void:
	# A felled pursuer buys you ground against the dark.
	gap = minf(gap + Tune.wall_push_kill, GAP_MAX)

func on_skull_sacrificed() -> void:
	# A skeleton hurled into the wall shoves it back, and the dark recoils with a flash.
	gap = minf(gap + Tune.wall_push_skull, GAP_MAX)
	wall_flash = 0.18

func end_run(reason: String) -> void:
	if dead:
		return
	dead = true
	var dist := depth_m()
	best = max(best, dist)
	get_tree().paused = true
	hud.game_over(reason, dist, best)

func _reset_run() -> void:
	for g in ["enemy", "minion", "corpse", "deathcar", "miasma"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()
	Build.reset()
	Build.add_souls(12)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.hp = player.max_hp
	player.heading = 0.0
	_spawn_death_cars()
	gap = GAP_START
	run_time = 0.0
	accum = 0.0
	layer = 1
	goal_depth = 1000
	stance = STANCE_HUNT
	spawn_timer = 0.0
	dead = false
	get_tree().paused = false
	_treadmill()

func _spawn_death_cars() -> void:
	for off in [Vector3(-150.0, 0.0, 80.0), Vector3(150.0, 0.0, 80.0)]:
		var d := DeathCar.new()
		d.slot = off
		d.position = player.global_position + off
		add_child(d)

func _build_wall() -> void:
	wall = Node3D.new()
	add_child(wall)
	var w := road_half * 2.0 + 3200.0
	# Dark towering slab that blots out the road behind you.
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 1600.0, 140.0)
	slab.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.0, 0.02)
	dm.roughness = 1.0
	slab.material_override = dm
	slab.position = Vector3(0.0, 600.0, 0.0)
	wall.add_child(slab)
	# Molten glowing bands up the leading face — the dark, churning and hungry.
	wall_mat = StandardMaterial3D.new()
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_mat.albedo_color = Color(0.95, 0.12, 0.06)
	wall_mat.emission_enabled = true
	wall_mat.emission = Color(1.0, 0.2, 0.05)
	wall_mat.emission_energy_multiplier = 2.0
	for i in range(0, 6):
		var band := MeshInstance3D.new()
		var bmm := BoxMesh.new()
		bmm.size = Vector3(w, 60.0 if i == 0 else 24.0, 24.0)
		band.mesh = bmm
		band.material_override = wall_mat
		band.position = Vector3(0.0, 40.0 + i * 230.0, -78.0)
		wall.add_child(band)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			skill_ui.open()
		elif event.keycode == KEY_SPACE:
			_raise_dead()
		elif event.keycode == KEY_F1:
			settings_ui.toggle()
		elif event.keycode == KEY_Q:
			stance = STANCE_HOLD if stance == STANCE_HUNT else STANCE_HUNT
			hud.flash("Horde: %s" % ("HOLD THE LINE — hurl them at the dark!" if stance == STANCE_HOLD else "HUNT the pack"))

const SOUL_PER_RAISE := 2   # souls burned to tear each skeleton out of the dirt

func _raise_dead() -> void:
	if not Build.has("raise_dead"):
		hud.flash("Unlock RAISE DEAD first — press TAB")
		return
	if Build.souls < SOUL_PER_RAISE:
		hud.flash("Not enough souls — kill rivals to harvest more (%d per skeleton)" % SOUL_PER_RAISE)
		return
	var cap := 24 if Build.has("legion") else 10
	var current := get_tree().get_nodes_in_group("minion").size()
	if current >= cap:
		hud.flash("Horde at capacity (%d) — unlock LEGION for a bigger army" % cap)
		return
	# Summon anywhere: skeletons claw up at your wheels, no corpse required. You raise
	# as many as both the horde cap AND your soul reserve allow (3 at once with Legion).
	var want: int = 3 if Build.has("legion") else 1
	var affordable: int = Build.souls / SOUL_PER_RAISE
	var count: int = min(want, min(cap - current, affordable))
	if count <= 0:
		return
	Build.spend_souls(count * SOUL_PER_RAISE)
	for i in count:
		var m := Minion.new()
		var off := Vector3(randf_range(-130.0, 130.0), 0.0, randf_range(60.0, 240.0))
		m.spawn_pos = player.global_position + off
		add_child(m)
	hud.flash("Raised %d undead  (-%d souls)" % [count, count * SOUL_PER_RAISE])

func lane_center(i: int) -> float:
	return -road_half + lane_w * (float(i) + 0.5)

func _spawn_enemy() -> void:
	var e := Enemy.new()
	# Spawn BEHIND the player (larger Z = further back), in a lane. The rival's
	# rubber-band then surges it up into view to hunt you.
	var behind := randf_range(700.0, 1500.0)
	behind = minf(behind, maxf(300.0, gap - 300.0))   # always spawn between you and the wall
	var x := lane_center(randi() % num_lanes)
	e.spawn_pos = Vector3(x, 0.0, player.global_position.z + behind)
	add_child(e)

func _cull_behind() -> void:
	# Racers left well behind (overtaken) or far ahead (they outran you) despawn —
	# keeps the action local and the spawn budget free.
	var pz := player.global_position.z
	for e in get_tree().get_nodes_in_group("enemy"):
		var dz: float = e.global_position.z - pz
		# Generous behind-window so fresh spawns (which start ~1500 back) get time to
		# rubber-band up; cull only ones truly abandoned or that shot far ahead.
		if dz > 2700.0 or dz < -2000.0:
			e.queue_free()

# --- World construction -----------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.55)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.02, 0.05)
	env.fog_density = 0.00018
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.9)
	add_child(sun)

func _lit_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.0
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _build_road(parent: Node3D) -> void:
	var depth := VIEW_AHEAD + VIEW_BEHIND
	var center_z := (VIEW_BEHIND - VIEW_AHEAD) * 0.5

	# Shoulders (wide dark ground) then the asphalt strip on top.
	var shoulder := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(road_half * 2.0 + 4000.0, depth)
	shoulder.mesh = sp
	shoulder.material_override = _lit_mat(Color(0.05, 0.05, 0.07))
	shoulder.position = Vector3(0.0, -0.5, center_z)
	parent.add_child(shoulder)

	var road := MeshInstance3D.new()
	var rp := PlaneMesh.new()
	rp.size = Vector2(road_half * 2.0, depth)
	road.mesh = rp
	road.material_override = _lit_mat(Color(0.11, 0.11, 0.13))
	road.position = Vector3(0.0, 0.0, center_z)
	parent.add_child(road)

	# Solid edge lines (yellow) and lane dividers (white) as long thin glowing strips.
	var edge := _glow_mat(Color(0.85, 0.85, 0.45))
	_box(parent, Vector3(6.0, 1.0, depth), Vector3(-road_half + 6.0, 1.0, center_z), edge)
	_box(parent, Vector3(6.0, 1.0, depth), Vector3(road_half - 6.0, 1.0, center_z), edge)
	var lane := _glow_mat(Color(0.9, 0.9, 0.92))
	for i in range(1, num_lanes):
		var x := -road_half + lane_w * float(i)
		_box(parent, Vector3(5.0, 1.0, depth), Vector3(x, 1.0, center_z), lane)

	# Glowing barrier rails sitting on top of the walls.
	var rail := _glow_mat(Color(0.55, 0.22, 0.66))
	_box(parent, Vector3(8.0, 8.0, depth), Vector3(-road_half - 30.0, 90.0, center_z), rail)
	_box(parent, Vector3(8.0, 8.0, depth), Vector3(road_half + 30.0, 90.0, center_z), rail)

func _build_scenery(parent: Node3D) -> void:
	# A stream of tall glowing pylons just outside each shoulder. They're snapped to a
	# fixed grid by the treadmill, so as you fly forward they rush past — the parallax
	# that sells real speed. One MultiMeshInstance3D draws them all in a single call.
	var x_off := road_half + 160.0
	var positions: Array[Vector3] = []
	var z := VIEW_BEHIND
	while z > -VIEW_AHEAD:
		positions.append(Vector3(-x_off, 180.0, z))
		positions.append(Vector3(x_off, 180.0, z))
		z -= PYL_SPACING

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(28.0, 360.0, 28.0)
	mm.mesh = bm
	mm.instance_count = positions.size()
	for i in positions.size():
		mm.set_instance_transform(i, Transform3D(Basis(), positions[i]))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _glow_mat(Color(0.25, 0.7, 0.95))
	parent.add_child(mmi)

func _build_walls(parent: Node3D) -> void:
	var t := 60.0
	var depth := VIEW_AHEAD + VIEW_BEHIND
	var center_z := (VIEW_BEHIND - VIEW_AHEAD) * 0.5
	var h := 120.0
	var rail_mat := _lit_mat(Color(0.16, 0.10, 0.20))
	var sides := [-road_half - t * 0.5, road_half + t * 0.5]
	for x in sides:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.position = Vector3(x, h * 0.5, center_z)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(t, h, depth)
		cs.shape = sh
		sb.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(t, h, depth)
		mi.mesh = bm
		mi.material_override = rail_mat
		sb.add_child(mi)
		parent.add_child(sb)
