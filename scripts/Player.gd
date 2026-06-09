extends CharacterBody3D
class_name Player
# Arcade vehicle (3D). Same drift model as the old top-down build: a forward speed
# scalar drives an intended velocity and the real velocity grips toward it, so hard
# turns slide a little. Drives on the Y=0 plane; forward is the car's local -Z.
# A high chase camera rides behind so the undead horde stays readable.

# Speed / turn knobs now live in the Tune autoload so they can be edited live (F1).
var coast_pull := 0.5       # how hard the car drifts back to idle when you let go
var max_steer := deg_to_rad(72.0)  # how far off "straight ahead" you can angle
var grip := 7.0             # how fast velocity aligns to heading

var heading := 0.0          # 0 = facing forward (-Z); +ve steers right (+X)
var hp := 100.0
var max_hp := 100.0
var radius := 18.0
var invuln := 0.0
var cam: Camera3D
const CAM_HEIGHT := 360.0     # camera height above the road
const CAM_FRONT := -560.0     # camera sits this far in FRONT of the car (-Z is forward)
const CAM_LOOK := 220.0       # ...and aims at a point this far BEHIND it
const CAM_SLIDE := 300.0      # how far it drifts sideways into your steering
var _cam_x := 0.0             # smoothed lateral position of the rig
var _cam_basis: Basis         # fixed look-back orientation — never yaws with the car

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1          # collide with walls only
	add_to_group("player")

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(56.0, 28.0, 110.0)
	cs.shape = sh
	cs.position = Vector3(0.0, 14.0, 0.0)
	add_child(cs)

	# Body + headlight (no art — primitives, matching the old flat look).
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(56.0, 28.0, 110.0)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.45, 0.6)
	mat.emission_energy_multiplier = 0.6
	body.material_override = mat
	body.position = Vector3(0.0, 14.0, 0.0)
	add_child(body)

	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(16.0, 10.0, 14.0)
	nose.mesh = nb
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.albedo_color = Color(1.0, 1.0, 0.7)
	nose.material_override = nm
	nose.position = Vector3(0.0, 16.0, -58.0)
	add_child(nose)

	# High chase cam: child of the car so it always rides behind the nose, pitched
	# down enough to keep the road ahead AND the horde behind mostly in frame.
	# REAR-VIEW camera: it sits in FRONT of the car and looks BACK over the tail, so the
	# screen always shows what's chasing you. Crucially it holds a FIXED look-back angle
	# (it never yaws with the car) — _update_camera only slides it sideways into your
	# turns, which is far more comfortable than rotating a backward-facing view.
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 9000.0
	add_child(cam)
	_cam_basis = Transform3D(Basis(), Vector3(0.0, CAM_HEIGHT, CAM_FRONT)).looking_at(Vector3(0.0, 0.0, CAM_LOOK), Vector3.UP).basis
	_cam_x = global_position.x
	cam.make_current()
	_update_camera()

func current_max_speed() -> float:
	var m := Tune.player_top
	if Build.has("dark_momentum"):
		# A full horde hurls you forward fast enough to outrun the dark itself.
		m += get_tree().get_nodes_in_group("minion").size() * 60.0
	return m

func _physics_process(delta: float) -> void:
	invuln = max(0.0, invuln - delta)

	var throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): throttle -= 1.0
	# Steering is mirrored to match the rear-view camera: pressing right sends the car
	# right ON SCREEN, which is the opposite world direction now that we face backward.
	var steer := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): steer += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): steer -= 1.0

	var forward := _forward()
	var fwd_speed := velocity.dot(forward)

	# Steer within a cone around "straight ahead". No reversing, no spinning.
	var sf: float = clamp(fwd_speed / 150.0, 0.0, 1.0)
	var steer_authority: float = lerpf(0.4, 1.0, sf)
	heading += steer * Tune.player_turn * delta * steer_authority
	heading = clampf(heading, -max_steer, max_steer)
	rotation.y = -heading                 # turn the car mesh to match
	forward = _forward()

	var mx := current_max_speed()
	var idle := Tune.player_top * 0.33     # gentle no-input cruise
	var floor_spd := Tune.player_top * 0.12  # braking floor; you never fully stop
	if throttle > 0.0:
		fwd_speed = move_toward(fwd_speed, mx, Tune.player_accel * delta)
	elif throttle < 0.0:
		fwd_speed = move_toward(fwd_speed, floor_spd, Tune.player_brake * delta)
	else:
		fwd_speed = move_toward(fwd_speed, idle, Tune.player_accel * coast_pull * delta)
	fwd_speed = maxf(fwd_speed, 0.0)       # forward-only

	var target_vel := forward * fwd_speed
	velocity = velocity.lerp(target_vel, clamp(grip * delta, 0.0, 1.0))
	velocity.y = 0.0

	move_and_slide()
	global_position.y = 0.0                # stay pinned to the ground plane
	_check_ram()
	_update_camera()

func _forward() -> Vector3:
	return Vector3(sin(heading), 0.0, -cos(heading))

func _update_camera() -> void:
	# Hold the fixed look-back angle and only slide sideways in the direction you're
	# steering — the car yaws beneath it, the camera doesn't. Smoothed so it eases over.
	var slide := sin(heading) * CAM_SLIDE
	_cam_x = lerpf(_cam_x, global_position.x + slide, 0.2)
	cam.global_transform = Transform3D(_cam_basis, Vector3(_cam_x, CAM_HEIGHT, global_position.z + CAM_FRONT))

func _check_ram() -> void:
	var spd := velocity.length()
	if spd < 180.0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		# Generous pad: cars are ~110 long boxes, so bumpers meet well before centers do.
		if global_position.distance_to(e.global_position) < radius + e.radius + 80.0:
			e.take_damage(spd * 0.13)
			if not Tune.ram_keep_speed:
				velocity *= 0.55   # crunch — bleed speed on impact

func shove(impulse: Vector3) -> void:
	# A rival trying to run us off the road bumps our momentum sideways. The grip
	# model bleeds it off over the next moment, so it's a nudge, not a teleport.
	velocity += impulse

func take_damage(d: float) -> void:
	if invuln > 0.0:
		return
	hp -= d
	invuln = 0.6
	if hp <= 0.0:
		hp = 0.0
		var w := get_tree().get_nodes_in_group("world")
		if w.size() > 0:
			w[0].end_run("WRECKED BY THE PACK")
