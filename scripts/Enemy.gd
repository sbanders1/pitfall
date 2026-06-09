extends CharacterBody3D
class_name Enemy
# A rival KILLER (3D). No longer placid traffic — it actively HUNTS the player,
# homing in at high speed and ramming for heavy damage. There are only ever a few on
# screen, but each one wants you dead. Dies into a raiseable corpse for your legion.

var spawn_pos := Vector3.ZERO
var hp := 16.0
var max_hp := 16.0
var radius := 16.0
var pace_factor := 1.0     # per-rival multiplier on Tune.enemy_top (so they vary)
var turn_factor := 1.0     # per-rival multiplier on Tune.enemy_turn
var damage := 18.0         # heavy hit when it rams you
var attack_cd := 0.0
var hit_flash := 0.0
var color := Color(0.9, 0.35, 0.25)
var mat: StandardMaterial3D

func _ready() -> void:
	position = spawn_pos
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemy")
	pace_factor = randf_range(0.85, 1.18)
	turn_factor = randf_range(0.85, 1.18)
	var palette := [Color(0.95, 0.3, 0.25), Color(0.95, 0.55, 0.15), Color(0.9, 0.2, 0.45), Color(0.85, 0.3, 0.9)]
	color = palette[randi() % palette.size()]

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

	# Hunt the player like a real car: steer the NOSE toward them at a limited turn
	# rate and always drive forward along it. Can't pivot in place — it arcs, and
	# overshoots into a loop when you juke, so the front always leads the turn.
	var p = _player()
	if p:
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		if to.length() > 1.0:
			var desired := atan2(-to.x, -to.z)
			rotation.y = rotate_toward(rotation.y, desired, Tune.enemy_turn * turn_factor * delta)
	var fwd := -global_transform.basis.z
	velocity = fwd * (Tune.enemy_top * pace_factor)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

	# Slam the player on contact — this is how they kill you.
	if p and attack_cd <= 0.0 and global_position.distance_to(p.global_position) < radius + p.radius + 40.0:
		p.take_damage(damage)
		attack_cd = 0.8

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
	Build.add_souls(2)
	var c := Corpse.new()
	c.spawn_pos = global_position
	get_parent().add_child.call_deferred(c)
	queue_free()
