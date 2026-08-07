class_name PlayerCombatComponent
extends Node

## Player Combat Component:
## - Handles 4m Raycast Melee Attack execution
## - Applies Fat (35 dmg) and Thin (20 dmg) melee damage to target colliders
## - Integrates with AudioManager SFX and multiplayer authority validation

func perform_melee_attack(player: CharacterBody3D, camera_3d: Camera3D, selected_character_id: String) -> void:
	if not player or not player.is_multiplayer_authority() or not camera_3d:
		return

	var space_state := player.get_world_3d().direct_space_state
	var cam_pos := camera_3d.global_position
	var ray_dir := -camera_3d.global_transform.basis.z
	var ray_end := cam_pos + ray_dir * 4.0

	var query := PhysicsRayQueryParameters3D.create(cam_pos, ray_end)
	query.exclude = [player]

	var result := space_state.intersect_ray(query)
	if result:
		var hit_collider: Object = result.collider
		var hit_pos: Vector3 = result.position
		if hit_collider and hit_collider.has_method("take_damage"):
			var dmg: float = 35.0 if selected_character_id.to_lower() == "fat" else 20.0
			hit_collider.take_damage(dmg, hit_pos)
			print("🥊 MELEE HIT: %s dealt %.1f damage to %s" % [player.name, dmg, hit_collider.name])
