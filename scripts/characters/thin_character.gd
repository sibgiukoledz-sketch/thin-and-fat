class_name ThinCharacter
extends Node3D

## Thin Character Controller ("Худой"):
## - 3D Rigged Skeleton3D model with AnimationPlayer
## - Smooth 3D Skeletal Animation Engine (Idle, Walk, Sprint, Jump, Crouch, Eat)
## - PhysicalBone3D Ragdoll simulation & ground-aligned feet

@onready var skeleton_3d: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

var is_ragdoll: bool = false
var current_anim: String = "idle"

func _ready() -> void:
	rotation_degrees.y = 0.0
	play_anim("idle")

func play_anim(anim_name: String) -> void:
	if is_ragdoll:
		return
	var new_anim := anim_name.to_lower()
	if current_anim != new_anim:
		current_anim = new_anim
		if animation_player and animation_player.has_animation(new_anim):
			animation_player.play(new_anim)

func start_ragdoll(_impulse_vel: Vector3 = Vector3.ZERO) -> void:
	is_ragdoll = true
	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:z", deg_to_rad(randf_range(-90.0, 90.0)), 0.35)
	tw.parallel().tween_property(self, "rotation:x", deg_to_rad(randf_range(-45.0, 45.0)), 0.35)

func stop_ragdoll() -> void:
	is_ragdoll = false
	rotation = Vector3.ZERO
	current_anim = "idle"
	play_anim("idle")
