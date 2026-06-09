extends CharacterBody3D
class_name Enemy
# A rival KILLER (3D) whose handling is defined RELATIVE to the player. It paces
# around your speed (drifting a little faster/slower), tries to draw alongside, and
# noses you toward the nearest wall to run you off the road. Because its limits track
# yours within tunable ± bands, it never rockets off-screen and stays catchable.

var spawn_pos := Vector3.ZERO
var hp := 16.0
var max_hp := 16.0
var radius := 16.0
var damage := 12.0         # bite when it slams into you (alongside the shove)
var attack_cd := 0.0
var hit_flash := 0.0
var color := Color(0.9, 0.35, 0.25)
var mat: StandardMaterial3D

# Fixed per-rival spots inside the divergence bands (rolled at spawn, in -1..1), so
# each rival is a touch faster/slower/punchier — but live sliders still reshape them.
var r_top := 0.0
var r_accel := 0.0
var r_brake := 0.0
var r_side := 1.0          # which way it prefers to herd you when you're centered

var spd := 0.0             # current forward speed scalar
var pace_wobble := 1.0     # re-rolled pacing multiplier on your speed
var wobble_t := 0.0

func _ready() -> void:
	position = spawn_pos
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemy")
	r_top = randf_range(-1.0, 1.0)
	r_accel = randf_range(-1.0, 1.0)
	r_brake = randf_range(-1.0, 1.0)
	r_side = 1.0 if randf() < 0.5 else -1.0
	spd = Tune.player_top * 0.4
	color = Color(0.92, 0.26, 0.24)   # all rivals share one colour for visual clarity

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(52.0, 26.0, 104.0)
	cs.shape = sh
	cs.position = Vector3(0.0, 13.0, 0.0)
	add_child(cs)

	mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.4
	mat.roughness = 0.6
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(52.0, 26.0, 104.0)
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0.0, 13.0, 0.0)
	add_child(body)

func _physics_process(delta: float) -> void:
	hit_flash = max(0.0, hit_flash - delta)
	attack_cd = max(0.0, attack_cd - delta)

	var p = _player()
	if p == null:
		move_and_slide()
		return

	var pz: float = p.global_position.z
	var pspeed: float = p.velocity.length()

	# Rival limits, tracked live off your handling within the ± bands.
	var emax: float = Tune.player_top * (1.0 + r_top * Tune.enemy_speed_div)
	var eaccel: float = Tune.player_accel * (1.0 + r_accel * Tune.enemy_accel_div)
	var ebrake: float = Tune.player_brake * (1.0 + r_brake * Tune.enemy_brake_div)

	# Re-roll the pacing wobble now and then — this is the "slightly faster/slower".
	wobble_t -= delta
	if wobble_t <= 0.0:
		wobble_t = randf_range(1.2, 2.8)
		pace_wobble = 1.0 + randf_range(-1.0, 1.0) * Tune.enemy_speed_div

	# Target speed = your speed (wobbled) plus a term that closes the gap so it hangs
	# right around you instead of pulling ahead or dropping behind.
	var dz: float = global_position.z - pz   # +behind you, -ahead of you
	var closing: float = clampf(dz, -600.0, 600.0) * 1.2
	# Rubber-band: when dropped behind you (every spawn starts back there), let it
	# briefly exceed its normal top speed to surge into view; the boost fades to nothing
	# as it draws level, so the duel up close stays fair.
	var hardcap: float = emax
	if dz > 300.0:
		hardcap = emax + clampf(dz - 300.0, 0.0, 1500.0) * 0.6
	var target: float = clampf(pspeed * pace_wobble + closing, 60.0, hardcap)
	if spd < target:
		spd = move_toward(spd, target, eaccel * delta)
	else:
		spd = move_toward(spd, target, ebrake * delta)

	# Aim slightly ahead and to the wall-side of you — herds you outward into the rail.
	var side: float = signf(p.global_position.x)
	if absf(p.global_position.x) < 40.0:
		side = r_side
	var aim: Vector3 = p.global_position
	aim.x += side * 220.0
	aim.z -= 40.0
	var to: Vector3 = aim - global_position
	to.y = 0.0
	if to.length() > 1.0:
		var desired := atan2(-to.x, -to.z)
		rotation.y = rotate_toward(rotation.y, desired, Tune.enemy_turn * delta)

	var fwd := -global_transform.basis.z
	velocity = fwd * spd
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

	# Slam: damage you AND shove your momentum toward the wall you're nearest.
	if attack_cd <= 0.0 and global_position.distance_to(p.global_position) < radius + p.radius + 40.0:
		p.take_damage(damage)
		p.shove(Vector3(side * 520.0, 0.0, 0.0))
		attack_cd = 0.6

	mat.albedo_color = Color(1, 1, 1) if hit_flash > 0.0 else color

func _player():
	var a := get_tree().get_nodes_in_group("player")
	return a[0] if a.size() > 0 else null

func take_damage(d: float) -> void:
	hp -= d
	hit_flash = 0.12
	if hp <= 0.0:
		_die()

func _die() -> void:
	Build.add_souls(2)   # harvested fuel for raising the dead
	Build.add_xp(4)      # and progress toward your next level
	var w := get_tree().get_nodes_in_group("world")
	if w.size() > 0:
		w[0].on_kill()   # a felled pursuer buys ground against the dark
	var c := Corpse.new()
	c.spawn_pos = global_position
	get_parent().add_child.call_deferred(c)
	queue_free()
