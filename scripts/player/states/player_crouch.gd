class_name PlayerCrouch
extends PlayerState

func enter(_msg: Dictionary = {}) -> void:
	if player:
		player.target_speed = player.CROUCH_SPEED
		player.set_crouch_state(true)

func exit() -> void:
	if player:
		player.set_crouch_state(false)

func physics_update(delta: float) -> void:
	if not player:
		return

	if not player.is_on_floor() and player.velocity.y < -0.1:
		state_machine.transition_to("Air")
		return

	var input_dir: Vector3 = player.get_movement_input()


	# Can uncrouch if button released and head raycast is clear
	if not player.is_crouch_requested() and player.can_uncrouch():
		if input_dir.length_squared() > 0.01:
			if player.is_sprint_requested():
				state_machine.transition_to("Sprint")
			else:
				state_machine.transition_to("Walk")
		else:
			state_machine.transition_to("Idle")
		return

	if player.is_jump_requested() and player.can_uncrouch():
		state_machine.transition_to("Air", {"do_jump": true})
		return

	player.apply_movement(input_dir, player.CROUCH_SPEED, delta)
