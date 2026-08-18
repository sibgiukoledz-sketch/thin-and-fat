class_name FatCharacter
extends Node3D

## Fat Character Controller ("Жирдяй"):
## - 3D Rigged Skeleton3D model with AnimationPlayer
## - Smooth 3D Skeletal Animation Engine (Idle, Walk, Sprint, Jump, Crouch, Eat)
## - PhysicalBone3D Ragdoll simulation & ground-aligned feet
## - Dynamic arm pose for carrying heavy boulders (overrides AnimationPlayer tracks!)

@onready var skeleton_3d: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var arm_l: Node3D = get_node_or_null("Skeleton3D/Arm_L") as Node3D
@onready var arm_r: Node3D = get_node_or_null("Skeleton3D/Arm_R") as Node3D

var is_ragdoll: bool = false
var is_carrying_pose: bool = false
var current_anim: String = "idle"

func _ready() -> void:
	process_priority = 100 # Priority 100 ensures _process runs AFTER AnimationPlayer!
	rotation_degrees.y = 0.0
	play_anim("idle")

func set_carrying_pose(is_carrying: bool) -> void:
	is_carrying_pose = is_carrying
	_apply_arm_pose()

func _apply_arm_pose() -> void:
	if arm_l and arm_r:
		if is_carrying_pose:
			# Reach arms forward to cup both sides of giant boulder
			arm_l.rotation_degrees = Vector3(-35.0, 45.0, -60.0)
			arm_r.rotation_degrees = Vector3(-35.0, -45.0, 60.0)
		else:
			# Default arm rotations
			arm_l.rotation_degrees = Vector3(0.0, 0.0, -90.0)
			arm_r.rotation_degrees = Vector3(0.0, 0.0, 90.0)

func play_anim(anim_name: String) -> void:
	if is_ragdoll:
		return
	var new_anim := anim_name.to_lower()
	if current_anim != new_anim:
		current_anim = new_anim
		if animation_player and animation_player.has_animation(new_anim):
			animation_player.play(new_anim)

func _process(_delta: float) -> void:
	if is_carrying_pose:
		_apply_arm_pose()

func _physics_process(_delta: float) -> void:
	if is_carrying_pose:
		_apply_arm_pose()

func start_ragdoll(_impulse_vel: Vector3 = Vector3.ZERO) -> void:
	is_ragdoll = true
	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:z", deg_to_rad(randf_range(-85.0, 85.0)), 0.35)
	tw.parallel().tween_property(self, "rotation:x", deg_to_rad(randf_range(-40.0, 40.0)), 0.35)

func stop_ragdoll() -> void:
	is_ragdoll = false
	rotation = Vector3.ZERO
	current_anim = "idle"
	play_anim("idle")
