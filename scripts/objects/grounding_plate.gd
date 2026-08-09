class_name GroundingPlate
extends Node3D

## Grounded Plate: Instantly grounds and discharges static electricity when Thin steps on it.

@onready var area_3d: Area3D = $Area3D

func _ready() -> void:
	if area_3d:
		area_3d.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if p.selected_character_id.to_lower() == "thin" and p.active_mechanics:
			if p.active_mechanics.has_method("rpc_discharge"):
				p.active_mechanics.rpc_discharge.rpc()
