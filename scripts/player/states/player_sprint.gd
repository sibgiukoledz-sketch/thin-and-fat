class_name PlayerSprint
extends PlayerState

func enter(_msg: Dictionary = {}) -> void:
	if player:
		player.target_speed = player.run_speed
		player.set_target_fov(player.SPRINT_FOV)

func exit() -> void:
	if player:
		player.set_target_fov(player.NORMAL_FOV)

func physics_update(delta: float) -> void:
	if not player:
		return

	if not player.is_on_floor():
		state_machine.transition_to("Air")
		return

	if player.is_jump_requested():
		state_machine.transition_to("Air", {"do_jump": true})
		return

	if player.is_crouch_requested():
		state_machine.transition_to("Crouch")
		return

	var input_dir: Vector3 = player.get_movement_input()
	if input_dir.length_squared() < 0.01:

		state_machine.transition_to("Idle")
		return

	if not player.is_sprint_requested():
		state_machine.transition_to("Walk")
		return

	player.apply_movement(input_dir, player.run_speed, delta)
