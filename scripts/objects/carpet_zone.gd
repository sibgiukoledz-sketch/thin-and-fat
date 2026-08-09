class_name CarpetZone
extends Node3D

## Carpet Floor Zone: Charges Thin character with static electricity when walked upon.

@export var charge_rate: float = 45.0

@onready var area_3d: Area3D = $Area3D
@onready var surface_mat_3d: SurfaceMaterial3D = $SurfaceMaterial3D

func _ready() -> void:
	if area_3d:
		area_3d.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and (body as Player).selected_character_id.to_lower() == "thin":
		if AudioManager:
			AudioManager.play_sfx_3d("static_spark", global_position, 25.0)
