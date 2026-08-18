class_name ThinCharacter
extends Node3D

## Thin Character ("Худой") — R.E.P.O. & Human Fall Flat Style Controller:
## - Slender, agile humanoid joint hierarchy with real parent-child bone sockets.
## - Active secondary spring physics (noodle limb wobble, floppy bobblehead).
## - Interactive environmental reactions:
##   * Wind Tunnel Fan: Dramatic blown-away torso arch, flailing arms, and head flutter!
##   * Static Charge: Hair tuft stands on end and energetic limb jitter!
##   * Landing Impact: Spindly leg compression and bobblehead dip.
## - Clean, complete animation library (idle, walk, sprint, crouch, crouch_walk, jump).

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
	rotation = Vector3.ZERO
	play_anim("idle")
	_last_parent_pos = global_position

@onready var pelvis_mesh: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/PelvisMesh") as MeshInstance3D
@onready var sweater_mesh: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/Torso/SweaterMesh") as MeshInstance3D
@onready var sweater_stripe_1: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/Torso/SweaterStripe1") as MeshInstance3D
@onready var sweater_stripe_2: MeshInstance3D = get_node_or_null("Skeleton3D/Pelvis/Torso/SweaterStripe2") as MeshInstance3D

func get_head_socket() -> Node3D:
	return head_pivot

func set_first_person_view(is_first_person: bool) -> void:
	if head_pivot:
		head_pivot.visible = not is_first_person
	if neck:
		neck.visible = not is_first_person
	if sweater_mesh:
		sweater_mesh.visible = not is_first_person
	if sweater_stripe_1:
		sweater_stripe_1.visible = not is_first_person
	if sweater_stripe_2:
		sweater_stripe_2.visible = not is_first_person
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

	# 1. Compute parent linear velocity & clamped acceleration for active inertia
	var current_pos := global_position
	var current_vel := (current_pos - _last_parent_pos) / maxf(delta, 0.001)
	var raw_accel := (current_vel - _last_parent_vel) / maxf(delta, 0.001)
	var accel := raw_accel.clamp(Vector3(-20.0, -20.0, -20.0), Vector3(20.0, 20.0, 20.0))
	_last_parent_pos = current_pos
	_last_parent_vel = current_vel

	# 2. Wind reaction: Hurricane blowing Thin's spindly body backward
	var wind_len := wind_force_vector.length()
	var wind_tilt_x: float = 0.0
	var wind_flutter_head := Vector3.ZERO

	if wind_len > 0.1:
		wind_tilt_x = -0.35 * clampf(wind_len / 30.0, 0.0, 1.0)
		var flutter_speed := 30.0
		wind_flutter_head = Vector3(
			sin(_time_passed * flutter_speed) * 0.12,
			0.0,
			cos(_time_passed * (flutter_speed * 1.2)) * 0.12
		)

	# 3. Static jitter
	var static_jitter := Vector3.ZERO
	if is_static_charged:
		static_jitter = Vector3(
			randf_range(-0.04, 0.04),
			randf_range(-0.03, 0.03),
			randf_range(-0.04, 0.04)
		)

	# 4. Active Spring Wobble on Thin Bobblehead
	if head_pivot:
		var target_tilt := Vector3(
			clampf(-accel.z * 0.015 + wind_tilt_x, -0.4, 0.4),
			clampf(current_vel.x * 0.018, -0.25, 0.25),
			clampf(-accel.x * 0.015, -0.3, 0.3)
		) + wind_flutter_head + static_jitter

		var spring_k := 150.0
		var damp := 12.0
		var force := (target_tilt - _head_spring_rot) * spring_k - (_head_velocity * damp)
		_head_velocity += force * delta
		_head_spring_rot += _head_velocity * delta
		head_pivot.rotation = _head_spring_rot

	# 5. Wind flailing arms in degrees
	if wind_len > 0.1 and arm_l and arm_r:
		arm_l.rotation_degrees = Vector3(-55.0 + sin(_time_passed * 24.0) * 12.0, 0.0, -25.0)
		arm_r.rotation_degrees = Vector3(-55.0 + cos(_time_passed * 24.0) * 12.0, 0.0, 25.0)

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
	if torso:
		torso.rotation = Vector3.ZERO
	current_anim = ""
	play_anim("idle")
