class_name ThinCharacter
extends Node3D

## Thin Character Model Controller ("Худой"):
## - Formatted according to concept art (Gemini_Generated_Image_19i6b219i6b219i6.png)
## - Facing forward (-Z axis)
## - Integrated Skeleton3D & PhysicalBone3D Ragdoll simulation!

@onready var skeleton_3d: Skeleton3D = $Skeleton3D

var is_ragdoll: bool = false

func _ready() -> void:
	# Ensure character model faces forward (-Z)
	rotation_degrees.y = 0.0

func start_ragdoll(impulse_vel: Vector3 = Vector3.ZERO) -> void:
	is_ragdoll = true
	if skeleton_3d:
		skeleton_3d.physical_bones_start_simulation()

	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:z", deg_to_rad(randf_range(-90.0, 90.0)), 0.35)
	tw.parallel().tween_property(self, "rotation:x", deg_to_rad(randf_range(-45.0, 45.0)), 0.35)

func stop_ragdoll() -> void:
	is_ragdoll = false
	if skeleton_3d:
		skeleton_3d.physical_bones_stop_simulation()
	rotation = Vector3.ZERO
