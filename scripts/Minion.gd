extends CharacterBody3D
class_name Minion
# The payoff of the whole tree (3D). Behaviour shifts entirely based on Build flags:
#   bone_riders    -> fast, charging, heavier ram damage, lance-rider mesh
#   miasma_wake    -> drops poison trail while moving
#   plague_burst   -> erupts into a plague cloud on death

var spawn_pos := Vector3.ZERO
var hp := 30.0
var max_hp := 30.0
var radius := 11.0
var base_speed := 480.0
var damage := 10.0
var attack_cd := 0.0
var miasma_cd := 0.0
var hit_flash := 0.0
var wander := Vector3.ZERO
var lifespan := 13.0   # undead rot away — keep killing to sustain the horde
var age := 0.0
var mat: StandardMaterial3D

func _ready() -> void:
	position = spawn_pos
	collision_layer = 8
	collision_mask = 1
	add_to_group("minion")
	# Bone Riders are a glass-cannon cavalry: faster and deadlier, but they burn out
	# quickly. The horde of mounted dead is a spike, not a standing army.
	if Build.has("bone_riders"):
		lifespan = 7.0
	wander = Vector3(randf_range(-45, 45), 0.0, randf_range(-45, 45))

	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = 46.0
	cs.shape = sh
	cs.position = Vector3(0.0, 23.0, 0.0)
	add_child(cs)

	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.4, 0.45)
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := MeshInstance3D.new()
	if Build.has("bone_riders"):
		# elongated lance-rider — taller and pointed
		var pm := PrismMesh.new()
		pm.size = Vector3(22.0, 64.0, 40.0)
		body.mesh = pm
		body.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		body.position = Vector3(0.0, 20.0, 0.0)
	else:
		var cm := CapsuleMesh.new()
		cm.radius = radius
		cm.height = 46.0
		body.mesh = cm
		body.position = Vector3(0.0, 23.0, 0.0)
	body.material_override = mat
	add_child(body)

func speed() -> float:
	# All summons ride alongside you — clamped to your current speed, never faster,
	# so the horde keeps formation at any pace (a small floor lets them creep when
	# you're nearly stopped). Bone Riders still hit harder; they just don't outrun you.
	var p = _player()
	var base: float = p.velocity.length() if p else base_speed
	return maxf(base, 120.0)

func _physics_process(delta: float) -> void:
	attack_cd = max(0.0, attack_cd - delta)
	miasma_cd = max(0.0, miasma_cd - delta)
	hit_flash = max(0.0, hit_flash - delta)

	age += delta
	var fade: float = clampf((lifespan - age) / 3.0, 0.0, 1.0)  # fade out over final 3s
	if hit_flash > 0.0:
		mat.albedo_color = Color(1, 0.4, 0.4, fade)
	else:
		mat.albedo_color = Color(0.85, 0.85, 0.95, fade)
	if age >= lifespan:
		_die()
		return

	var e = null
	var target_pos: Vector3
	var w = _world()
	if w and w.horde_stance() == 1:
		# HOLD THE LINE: peel off and hurl yourself into the dark to slow it.
		var wz: float = w.wall_front_z()
		if global_position.z >= wz - 80.0:
			w.on_skull_sacrificed()
			queue_free()
			return
		target_pos = Vector3(global_position.x, 0.0, wz)
	else:
		e = _nearest_enemy()
		if e:
			target_pos = e.global_position
		else:
			var p = _player()
			target_pos = (p.global_position + wander) if p else global_position

	var to := target_pos - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 6.0 else Vector3.ZERO
	velocity = velocity.lerp(dir * speed(), 0.12)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

	if e and attack_cd <= 0.0 and global_position.distance_to(e.global_position) < radius + e.radius + 50.0:
		var dmg := damage * (1.9 if Build.has("bone_riders") else 1.0)
		e.take_damage(dmg)
		attack_cd = 0.5

	if Build.has("miasma_wake") and miasma_cd <= 0.0 and velocity.length() > 60.0:
		_drop_miasma(46.0, 3.5)
		miasma_cd = 0.35

func _drop_miasma(r: float, life: float) -> void:
	var mi := Miasma.new()
	mi.spawn_pos = global_position
	mi.radius = r
	mi.life = life
	mi.max_life = life
	get_parent().add_child.call_deferred(mi)

func _nearest_enemy():
	# Only hunt rivals that are actually on screen — ignore ones still off-camera.
	var cam = _camera()
	var best = null
	var bd := 1e12
	for x in get_tree().get_nodes_in_group("enemy"):
		if cam and not cam.is_position_in_frustum(x.global_position + Vector3(0.0, 13.0, 0.0)):
			continue
		var d := global_position.distance_to(x.global_position)
		if d < bd:
			bd = d
			best = x
	return best

func _camera():
	var p = _player()
	return p.cam if p else null

func _player():
	var a := get_tree().get_nodes_in_group("player")
	return a[0] if a.size() > 0 else null

func _world():
	var a := get_tree().get_nodes_in_group("world")
	return a[0] if a.size() > 0 else null

func take_damage(d: float) -> void:
	hp -= d
	hit_flash = 0.12
	if hp <= 0.0:
		_die()

func _die() -> void:
	# However an undead falls — slain or rotted out — Plague Burst makes it count.
	if Build.has("plague_burst"):
		_drop_miasma(96.0, 6.0)
	queue_free()
