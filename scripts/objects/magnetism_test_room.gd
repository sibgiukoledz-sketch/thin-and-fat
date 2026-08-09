class_name MagnetismTestRoom
extends Node3D

## Magnetism & Surface Materials Showcase Room Scene:
## Demonstrates static electrification, surface audio, magnetic ceiling crawling, and heavy lever discharge.

func discharge_thin_players() -> void:
	if AudioManager:
		AudioManager.play_sfx_3d("discharge_zap", global_position, 40.0, 2.0)

	var players := get_tree().get_nodes_in_group("players")
	for node in players:
		if node is Player:
			var p := node as Player
			if p.selected_character_id.to_lower() == "thin" and p.active_mechanics:
				if p.active_mechanics.has_method("rpc_discharge"):
					p.active_mechanics.rpc_discharge.rpc()
