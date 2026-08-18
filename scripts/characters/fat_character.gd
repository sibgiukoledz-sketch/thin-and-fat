class_name FatCharacter
extends Node3D

## Fat Character ("Толстяк / Жирдяй") — R.E.P.O. & Human Fall Flat Style Controller:
## - Full connected humanoid joint hierarchy with real parent-child bone sockets.
## - Active secondary spring physics (wobbly bobblehead, bouncy pear belly, and natural arm sway).
## - Overhead boulder lifting pose.
## - Clean, complete animation library (idle, walk, sprint, crouch, crouch_walk, jump).

@onready var skeleton_3d: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

# Connected Joint Sockets
@onready var pelvis: Node3D = get_node_or_null("Skeleton3D/Pelvis") as Node3D
@onready var torso: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso") as Node3D
@onready var head_pivot: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/HeadPivot") as Node3D

@onready var arm_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_L") as Node3D
@onready var arm_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_R") as Node3D
@onready var forearm_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_L/Forearm_L") as Node3D
@onready var forearm_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_R/Forearm_R") as Node3D

@onready var hip_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_L") as Node3D
@onready var hip_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_R") as Node3D
@onready var shin_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_L/Shin_L") as Node3D
@onready var shin_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_R/Shin_R") as Node3D

const PELVIS_REST_Y: float = 0.82

var is_ragdoll: bool = false
var is_carrying_pose: bool = false
var is_trampoline_pose: bool = false
var current_anim: String = "idle"

# Environmental Reaction States
var wind_force_vector: Vector3 = Vector3.ZERO
var stench_amount: float = 0.0

# Procedural Spring Physics State (Active Ragdoll Wobble)
var _head_velocity: Vector3 = Vector3.ZERO
var _head_spring_rot: Vector3 = Vector3.ZERO

var _belly_velocity: float = 0.0
var _belly_spring_scale_y: float = 1.0

var _last_parent_pos: Vector3 = Vector3.ZERO
var _last_parent_vel: Vector3 = Vector3.ZERO
var _time_passed: float = 0.0

func _ready() -> void:
	process_priority = 100
	rotation = Vector3.ZERO
	play_anim("idle")
	_last_parent_pos = global_position

@onready var pelvis_mesh: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/PelvisMesh") as MeshInstance3D
@onready var pear_belly_mesh: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/Torso/PearBellyMesh") as MeshInstance3D

func get_head_socket() -> Node3D:
	return head_pivot

func set_first_person_view(is_first_person: bool) -> void:
	if head_pivot:
		head_pivot.visible = not is_first_person
	if pear_belly_mesh:
		pear_belly_mesh.visible = not is_first_person
	if pelvis_mesh:
		pelvis_mesh.visible = not is_first_person
	if hip_l:
		hip_l.visible = not is_first_person
	if hip_r:
		hip_r.visible = not is_first_person
	# Hands and arms stay always visible in 1st person!
	if arm_l:
		arm_l.visible = true
	if arm_r:
		arm_r.visible = true

func set_carrying_pose(is_carrying: bool) -> void:
	is_carrying_pose = is_carrying
	_apply_arm_pose()

func set_trampoline_pose(active: bool) -> void:
	is_trampoline_pose = active
	if is_trampoline_pose:
		if animation_player:
			animation_player.stop()
		var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation_degrees:x", 85.0, 0.22)
		if pelvis:
			tw.parallel().tween_property(pelvis, "position:y", 0.42, 0.22)
		if arm_l and arm_r:
			arm_l.rotation_degrees = Vector3(-30, 0, -45)
			arm_r.rotation_degrees = Vector3(-30, 0, 45)
	else:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation_degrees:x", 0.0, 0.2)
		if pelvis:
			tw.parallel().tween_property(pelvis, "position:y", PELVIS_REST_Y, 0.2)
		current_anim = ""
		play_anim("idle")

func set_wind_reaction(wind_vec: Vector3) -> void:
	wind_force_vector = wind_vec

func set_stench_level(amount: float) -> void:
	stench_amount = amount

func play_anim(anim_name: String) -> void:
	if is_ragdoll or is_trampoline_pose:
		return
	var new_anim := anim_name.to_lower()
	if current_anim != new_anim:
		current_anim = new_anim
		if animation_player and animation_player.has_animation(new_anim):
			animation_player.play(new_anim)

func _physics_process(delta: float) -> void:
	_time_passed += delta
	if is_ragdoll or is_trampoline_pose:
		return

	# 1. Compute parent linear velocity & clamped acceleration for active inertia
	var current_pos := global_position
	var current_vel := (current_pos - _last_parent_pos) / maxf(delta, 0.001)
	var raw_accel := (current_vel - _last_parent_vel) / maxf(delta, 0.001)
	var accel := raw_accel.clamp(Vector3(-15.0, -15.0, -15.0), Vector3(15.0, 15.0, 15.0))
	_last_parent_pos = current_pos
	_last_parent_vel = current_vel

	# 2. Wind reaction
	var wind_tilt_x: float = 0.0
	if wind_force_vector.length_squared() > 0.01:
		wind_tilt_x = clampf(wind_force_vector.z * 0.015, -0.25, 0.25)

	# 3. Active Spring Wobble on Bobblehead
	if head_pivot:
		var target_tilt := Vector3(
			clampf(-accel.z * 0.010 + wind_tilt_x, -0.25, 0.25),
			clampf(current_vel.x * 0.012, -0.2, 0.2),
			clampf(-accel.x * 0.010, -0.25, 0.25)
		)
		var spring_k := 140.0
		var damp := 14.0
		var force := (target_tilt - _head_spring_rot) * spring_k - (_head_velocity * damp)
		_head_velocity += force * delta
		_head_spring_rot += _head_velocity * delta
		head_pivot.rotation = _head_spring_rot

	# 4. Active Squash & Stretch on Pear Belly
	if torso and not is_carrying_pose:
		var target_scale_y := 1.0
		if accel.y > 6.0:
			target_scale_y = 0.90
		elif accel.y < -6.0:
			target_scale_y = 1.08

		var belly_k := 160.0
		var belly_damp := 14.0
		var b_force := (target_scale_y - _belly_spring_scale_y) * belly_k - (_belly_velocity * belly_damp)
		_belly_velocity += b_force * delta
		_belly_spring_scale_y = clampf(_belly_spring_scale_y + _belly_velocity * delta, 0.85, 1.15)

		var squish_xz := 1.0 / sqrt(_belly_spring_scale_y)
		torso.scale = Vector3(squish_xz, _belly_spring_scale_y, squish_xz)
	elif torso and is_carrying_pose:
		torso.scale = Vector3.ONE

	# 5. Carrying pose override (lifts boulder overhead with raised arms)
	if is_carrying_pose:
		_apply_arm_pose()

func _apply_arm_pose() -> void:
	if arm_l and arm_r:
		if is_carrying_pose:
			# Hands raised high above head holding the giant rock overhead
			arm_l.rotation_degrees = Vector3(-150.0, 18.0, -22.0)
			arm_r.rotation_degrees = Vector3(-150.0, -18.0, 22.0)
			if forearm_l:
				forearm_l.rotation_degrees = Vector3(30.0, 0.0, 0.0)
			if forearm_r:
				forearm_r.rotation_degrees = Vector3(30.0, 0.0, 0.0)
		elif current_anim == "idle":
			arm_l.rotation_degrees = Vector3(0.0, 0.0, -12.0)
			arm_r.rotation_degrees = Vector3(0.0, 0.0, 12.0)
			if forearm_l:
				forearm_l.rotation_degrees = Vector3.ZERO
			if forearm_r:
				forearm_r.rotation_degrees = Vector3.ZERO

func start_ragdoll(velocity: Vector3 = Vector3.ZERO) -> void:
	is_ragdoll = true
	if animation_player:
		animation_player.stop()

	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var tumble_z := deg_to_rad(randf_range(-70.0, 70.0))
	var tumble_x := deg_to_rad(randf_range(-45.0, 45.0))
	tw.tween_property(self, "rotation:z", tumble_z, 0.4)
	tw.parallel().tween_property(self, "rotation:x", tumble_x, 0.4)
	if pelvis:
		tw.parallel().tween_property(pelvis, "position:y", 0.42, 0.3)

func stop_ragdoll() -> void:
	is_ragdoll = false
	rotation = Vector3.ZERO
	if pelvis:
		pelvis.position = Vector3(0.0, PELVIS_REST_Y, 0.0)
	if torso:
		torso.rotation = Vector3.ZERO
		torso.scale = Vector3.ONE
	current_anim = ""
	play_anim("idle")
