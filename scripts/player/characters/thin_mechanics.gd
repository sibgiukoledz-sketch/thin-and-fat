class_name ThinMechanics
extends BaseCharacterMechanics

## Dedicated Controller for "Thin / Худой" character mechanics:
## - "Paper Flattening" ("Сплющивание в бумагу"): Toggle flat paper mode on [Q] key
## - Enables sliding through narrow slits, under low doors, and beneath heavy boulders
## - Glides under low ceilings and inflates back to 3D on [Q] or [Jump]

func update_mechanics(_delta: float) -> void:
	pass

func physics_update_mechanics(_delta: float) -> void:
	pass

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority() or player.is_dead:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_toggle_paper_flatten()

func _toggle_paper_flatten() -> void:
	if not player:
		return

	if player.is_paper_flattened:
		if player.is_overhead_clear():
			player.rpc_inflate_back_to_normal.rpc()
			if AudioManager:
				AudioManager.play_sfx_3d("pop_inflate", player.global_position)
		else:
			print("⚠️ Overhead not clear! Cannot unflatten yet.")
	else:
		player.apply_paper_flatten(15.0)
		if AudioManager:
			AudioManager.play_sfx_3d("paper_squish", player.global_position)
