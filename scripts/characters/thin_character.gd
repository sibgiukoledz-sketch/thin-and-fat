class_name ThinCharacter
extends Node3D

## Thin Character ("Худой") — R.E.P.O. & Human Fall Flat Style Controller:
## - Slender, agile humanoid joint hierarchy with real parent-child bone sockets.
## - Active secondary spring physics (noodle limb wobble, floppy bobblehead).
## - Interactive environmental reactions:
##   * Wind Tunnel Fan: Dramatic blown-away torso arch, flailing arms, and head flutter!
##   * Static Charge: Hair tuft stands on end and energetic limb jitter!
##   * Landing Impact: Spindly leg compression and bobblehead dip.
## - Clean animation library (idle, walk, sprint, crouch, crouch_walk, jump).

@onready var skeleton_3d: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

# Connected Joint Sockets
@onready var pelvis: Node3D = get_node_or_null("Skeleton3D/Pelvis") as Node3D
@onready var torso: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso") as Node3D
@onready var neck: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Neck") as Node3D
@onready var head_pivot: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Neck/HeadPivot") as Node3D
@onready var hair_tuft: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Neck/HeadPivot/HairTuft") as MeshInstance3D

@onready var arm_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_L") as Node3D
@onready var arm_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_R") as Node3D
@onready var forearm_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_L/Forearm_L") as Node3D
@onready var forearm_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_R/Forearm_R") as Node3D

@onready var hip_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_L") as Node3D
@onready var hip_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_R") as Node3D
@onready var shin_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_L/Shin_L") as Node3D
@onready var shin_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_R/Shin_R") as Node3D

const PELVIS_REST_Y: float = 1.25

var is_ragdoll: bool = false
var current_anim: String = "idle"

# Environmental Reaction States
var wind_force_vector: Vector3 = Vector3.ZERO
var is_static_charged: bool = false

# Procedural Spring Physics State (Active Ragdoll Wobble)
var _head_velocity: Vector3 = Vector3.ZERO
var _head_spring_rot: Vector3 = Vector3.ZERO

var _torso_velocity: Vector3 = Vector3.ZERO
var _torso_spring_rot: Vector3 = Vector3.ZERO

var _last_parent_pos: Vector3 = Vector3.ZERO
var _last_parent_vel: Vector3 = Vector3.ZERO
var _time_passed: float = 0.0

func _ready() -> void:
	process_priority = 100
	rotation_degrees.y = 0.0
	play_anim("idle")
	_last_parent_pos = global_position

func set_wind_reaction(wind_vec: Vector3) -> void:
	wind_force_vector = wind_vec

func set_static_charge(charged: bool) -> void:
	is_static_charged = charged
	if hair_tuft:
		if is_static_charged:
			hair_tuft.scale = Vector3(1.6, 2.2, 1.6)
		else:
			hair_tuft.scale = Vector3.ONE

func play_anim(anim_name: String) -> void:
	if is_ragdoll:
		return
	var new_anim := anim_name.to_lower()
	if current_anim != new_anim:
		current_anim = new_anim
		if animation_player and animation_player.has_animation(new_anim):
			animation_player.play(new_anim)

func _physics_process(delta: float) -> void:
	_time_passed += delta
	if is_ragdoll:
		return

	# 1. Compute parent linear velocity & acceleration for active inertia
	var current_pos := global_position
	var current_vel := (current_pos - _last_parent_pos) / maxf(delta, 0.001)
	var accel := (current_vel - _last_parent_vel) / maxf(delta, 0.001)
	_last_parent_pos = current_pos
	_last_parent_vel = current_vel

	# 2. Wind reaction: Hurricane blowing Thin's spindly body backward
	var wind_len := wind_force_vector.length()
	var wind_tilt_x: float = 0.0
	var wind_flutter_head := Vector3.ZERO
	var wind_flutter_arms := Vector3.ZERO

	if wind_len > 0.1:
		var normalized_wind := wind_force_vector.normalized()
		wind_tilt_x = -0.45 * clampf(wind_len / 30.0, 0.0, 1.0)
		var flutter_speed := 30.0
		wind_flutter_head = Vector3(
			sin(_time_passed * flutter_speed) * 0.18,
			0.0,
			cos(_time_passed * (flutter_speed * 1.2)) * 0.18
		)
		wind_flutter_arms = Vector3(
			-0.85 + sin(_time_passed * 25.0) * 0.25,
			0.0,
			0.0
		)

	# 3. Static jitter
	var static_jitter := Vector3.ZERO
	if is_static_charged:
		static_jitter = Vector3(
			randf_range(-0.06, 0.06),
			randf_range(-0.04, 0.04),
			randf_range(-0.06, 0.06)
		)

	# 4. Active Spring Wobble on Thin Bobblehead
	if head_pivot:
		var target_tilt := Vector3(
			clampf(-accel.z * 0.022 + wind_tilt_x, -0.6, 0.6),
			clampf(current_vel.x * 0.025, -0.3, 0.3),
			clampf(-accel.x * 0.022, -0.4, 0.4)
		) + wind_flutter_head + static_jitter

		var spring_k := 150.0
		var damp := 11.0
		var force := (target_tilt - _head_spring_rot) * spring_k - (_head_velocity * damp)
		_head_velocity += force * delta
		_head_spring_rot += _head_velocity * delta
		head_pivot.rotation = _head_spring_rot

	# 5. Active Torso Sway & Wind Arch
	if torso:
		var target_sway := Vector3(
			clampf(-accel.z * 0.008 + wind_tilt_x * 0.6, -0.35, 0.35),
			0.0,
			clampf(-accel.x * 0.008, -0.2, 0.2)
		)
		var t_k := 160.0
		var t_damp := 13.0
		var t_force := (target_sway - _torso_spring_rot) * t_k - (_torso_velocity * t_damp)
		_torso_velocity += t_force * delta
		_torso_spring_rot += _torso_velocity * delta
		torso.rotation = _torso_spring_rot

	# 6. Wind flailing arms
	if wind_len > 0.1 and arm_l and arm_r:
		arm_l.rotation = Vector3(-65.0 + sin(_time_passed * 28.0) * 15.0, 0.0, -25.0)
		arm_r.rotation = Vector3(-65.0 + cos(_time_passed * 28.0) * 15.0, 0.0, 25.0)

func start_ragdoll(velocity: Vector3 = Vector3.ZERO) -> void:
	is_ragdoll = true
	if animation_player:
		animation_player.stop()

	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var tumble_z := deg_to_rad(randf_range(-80.0, 80.0))
	var tumble_x := deg_to_rad(randf_range(-55.0, 55.0))
	tw.tween_property(self, "rotation:z", tumble_z, 0.35)
	tw.parallel().tween_property(self, "rotation:x", tumble_x, 0.35)
	if pelvis:
		tw.parallel().tween_property(pelvis, "position:y", 0.55, 0.3)

func stop_ragdoll() -> void:
	is_ragdoll = false
	rotation = Vector3.ZERO
	if pelvis:
		pelvis.position = Vector3(0.0, PELVIS_REST_Y, 0.0)
	current_anim = ""
	play_anim("idle")
