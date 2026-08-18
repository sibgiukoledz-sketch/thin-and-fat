class_name ThinCharacter
extends Node3D

## Thin Character ("Худой") — R.E.P.O. & Human Fall Flat Style Controller:
## - Full connected humanoid joint hierarchy with real parent-child bone sockets.
## - Active secondary spring physics (spindly noodle limb wobble and spring-damped bobblehead).
## - Responsive animation player (idle, walk, sprint, crouch, jump).
## - Floppy bouncy ragdoll simulation.

@onready var skeleton_3d: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

# Connected Joint Sockets
@onready var pelvis: Node3D = get_node_or_null("Skeleton3D/Pelvis") as Node3D
@onready var torso: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso") as Node3D
@onready var neck: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Neck") as Node3D
@onready var head_pivot: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Neck/HeadPivot") as Node3D

@onready var arm_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_L") as Node3D
@onready var arm_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_R") as Node3D
@onready var forearm_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_L/Forearm_L") as Node3D
@onready var forearm_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Torso/Arm_R/Forearm_R") as Node3D

@onready var hip_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_L") as Node3D
@onready var hip_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_R") as Node3D
@onready var shin_l: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_L/Shin_L") as Node3D
@onready var shin_r: Node3D = get_node_or_null("Skeleton3D/Pelvis/Hip_R/Shin_R") as Node3D

var is_ragdoll: bool = false
var current_anim: String = "idle"

# Procedural Spring Physics State (Active Ragdoll Wobble)
var _head_velocity: Vector3 = Vector3.ZERO
var _head_spring_rot: Vector3 = Vector3.ZERO

var _torso_velocity: Vector3 = Vector3.ZERO
var _torso_spring_rot: Vector3 = Vector3.ZERO

var _last_parent_pos: Vector3 = Vector3.ZERO
var _last_parent_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	process_priority = 100
	rotation_degrees.y = 0.0
	play_anim("idle")
	_last_parent_pos = global_position

func play_anim(anim_name: String) -> void:
	if is_ragdoll:
		return
	var new_anim := anim_name.to_lower()
	if current_anim != new_anim:
		current_anim = new_anim
		if animation_player and animation_player.has_animation(new_anim):
			animation_player.play(new_anim)

func _physics_process(delta: float) -> void:
	if is_ragdoll:
		return

	# 1. Compute parent linear velocity & acceleration for active inertia
	var current_pos := global_position
	var current_vel := (current_pos - _last_parent_pos) / maxf(delta, 0.001)
	var accel := (current_vel - _last_parent_vel) / maxf(delta, 0.001)
	_last_parent_pos = current_pos
	_last_parent_vel = current_vel

	# 2. Active Spring Wobble on Thin Bobblehead (Goofy Human Fall Flat noodle head)
	if head_pivot:
		var target_tilt := Vector3(
			clampf(-accel.z * 0.022, -0.35, 0.35),
			clampf(current_vel.x * 0.025, -0.25, 0.25),
			clampf(-accel.x * 0.022, -0.35, 0.35)
		)
		var spring_k := 150.0
		var damp := 11.0
		var force := (target_tilt - _head_spring_rot) * spring_k - (_head_velocity * damp)
		_head_velocity += force * delta
		_head_spring_rot += _head_velocity * delta
		head_pivot.rotation = _head_spring_rot

	# 3. Active Torso Sway on sharp turns & acceleration
	if torso:
		var target_sway := Vector3(
			clampf(-accel.z * 0.008, -0.15, 0.15),
			0.0,
			clampf(-accel.x * 0.008, -0.15, 0.15)
		)
		var t_k := 160.0
		var t_damp := 13.0
		var t_force := (target_sway - _torso_spring_rot) * t_k - (_torso_velocity * t_damp)
		_torso_velocity += t_force * delta
		_torso_spring_rot += _torso_velocity * delta
		torso.rotation = _torso_spring_rot

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
		tw.parallel().tween_property(pelvis, "position:y", 0.25, 0.3)

func stop_ragdoll() -> void:
	is_ragdoll = false
	rotation = Vector3.ZERO
	if pelvis:
		pelvis.position = Vector3.ZERO
	current_anim = "idle"
	play_anim("idle")
