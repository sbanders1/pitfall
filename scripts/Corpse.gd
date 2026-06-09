extends Node3D
class_name Corpse
# A raiseable remains (3D). A flat marker on the road that lingers a while, then
# rots away if you don't reap it.

var spawn_pos := Vector3.ZERO
var life := 14.0
var max_life := 14.0
var radius := 13.0
var mat: StandardMaterial3D

func _ready() -> void:
	position = spawn_pos
	add_to_group("corpse")

	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.7, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 1.4
	cm.bottom_radius = radius * 1.4
	cm.height = 3.0
	disc.mesh = cm
	disc.material_override = mat
	disc.position = Vector3(0.0, 2.0, 0.0)
	add_child(disc)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var a: float = clamp(life / max_life, 0.15, 0.85)
	mat.albedo_color = Color(0.4, 0.9, 0.4, a)

func raise_into_minion(count: int = 1) -> void:
	for i in count:
		var m := Minion.new()
		var off := Vector3.ZERO if count <= 1 else Vector3(randf_range(-45, 45), 0.0, randf_range(-45, 45))
		m.spawn_pos = global_position + off
		get_parent().add_child.call_deferred(m)
	queue_free()
