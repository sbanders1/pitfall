extends Node3D
class_name Miasma
# Lingering poison pool (3D). Damages enemies inside over time and reshapes the
# track. With necrotic_bloom, pools periodically birth new minions from nothing.

var spawn_pos := Vector3.ZERO
var radius := 48.0
var life := 4.0
var max_life := 4.0
var dps := 16.0
var tick := 0.0
var bloom_cd := 4.0
var bloomed := 0
var mat: StandardMaterial3D

func _ready() -> void:
	position = spawn_pos
	add_to_group("miasma")

	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.95, 0.32, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.78, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 6.0
	disc.mesh = cm
	disc.material_override = mat
	disc.position = Vector3(0.0, 3.0, 0.0)
	add_child(disc)

func _process(delta: float) -> void:
	life -= delta
	tick -= delta
	if tick <= 0.0:
		tick = 0.25
		for e in get_tree().get_nodes_in_group("enemy"):
			if global_position.distance_to(e.global_position) < radius:
				e.take_damage(dps * 0.25)

	if Build.has("necrotic_bloom") and bloomed < 2:
		bloom_cd -= delta
		if bloom_cd <= 0.0:
			bloom_cd = 5.0
			bloomed += 1
			var m := Minion.new()
			m.spawn_pos = global_position + Vector3(randf_range(-20, 20), 0.0, randf_range(-20, 20))
			get_parent().add_child.call_deferred(m)

	if life <= 0.0:
		queue_free()
		return
	var a: float = clamp(life / max_life, 0.0, 1.0)
	mat.albedo_color = Color(0.4, 0.95, 0.32, 0.22 * a)
