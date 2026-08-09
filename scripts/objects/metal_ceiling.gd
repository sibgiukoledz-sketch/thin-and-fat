class_name MetalCeiling
extends Node3D

## Metal Ceiling Platform: Electrified Thin character clings to this ceiling to crawl over chasms.

@onready var magnetic_area: Area3D = get_node_or_null("MagneticArea") as Area3D
@onready var magnetic_light: OmniLight3D = get_node_or_null("MagneticLight") as OmniLight3D

func _ready() -> void:
	if magnetic_area:
		magnetic_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if p.selected_character_id.to_lower() == "thin" and p.active_mechanics:
			if "is_electrified" in p.active_mechanics and bool(p.active_mechanics.is_electrified):
				if AudioManager:
					AudioManager.play_sfx_3d("magnetic_attach", global_position, 30.0)
