extends CharacterBody3D
class_name DeathCar
# A PERSISTENT summoned spectral car. The necromancer rides into the pit with two of
# these already bound to their will. They hunt rival racers and ram them to death —
# your way of killing WITHOUT touching anyone yourself. They never expire; when no
# rival is near they fall back into formation beside you.

var radius := 16.0
var damage := 8.0          # weaker than before — takes a couple hits, lets rivals slip through
var turn_rate := 2.6       # rad/s — steers its nose toward prey, arcs like a car
var attack_cd := 0.0
var slot := Vector3.ZERO   # idle formation offset beside the player

func _ready() -> void:
	collision_layer = 8     # ally — collides with walls only, combat is distance-based
	collision_mask = 1
	add_to_group("deathcar")

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(52.0, 26.0, 104.0)
	cs.shape = sh
	cs.position = Vector3(0.0, 13.0, 0.0)
	add_child(cs)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.95, 0.55, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.85, 0.4)
	mat.emission_energy_multiplier = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(52.0, 26.0, 104.0)
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0.0, 13.0, 0.0)
	add_child(body)

func _physics_process(delta: float) -> void:
	attack_cd = max(0.0, attack_cd - delta)

	var e = _nearest_enemy()
	var chasing := e != null
	var target_pos: Vector3
	if e:
		target_pos = e.global_position
	else:
		var p = _player()
		target_pos = (p.global_position + slot) if p else global_position

	var to := target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 1.0:
		var desired := atan2(-to.x, -to.z)
		rotation.y = rotate_toward(rotation.y, desired, turn_rate * delta)

	# Drive forward along the nose. When falling back into formation, ease off the
	# throttle near the slot so it settles beside you instead of circling.
	# Stay a touch faster than the player so they can keep formation and run rivals down.
	var top := Tune.player_top + 120.0
	var spd := top
	if not chasing:
		spd = clampf(dist * 2.5, 0.0, top)
	var fwd := -global_transform.basis.z
	velocity = fwd * spd
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

	if e and attack_cd <= 0.0 and global_position.distance_to(e.global_position) < radius + e.radius + 50.0:
		e.take_damage(damage)
		attack_cd = 0.5

func _nearest_enemy():
	var best = null
	var bd := 1e12
	for x in get_tree().get_nodes_in_group("enemy"):
		var d := global_position.distance_to(x.global_position)
		if d < bd:
			bd = d
			best = x
	return best

func _player():
	var a := get_tree().get_nodes_in_group("player")
	return a[0] if a.size() > 0 else null
