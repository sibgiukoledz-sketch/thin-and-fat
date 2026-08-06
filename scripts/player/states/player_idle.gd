class_name PlayerIdle
extends PlayerState

func enter(_msg: Dictionary = {}) -> void:
	if player:
		player.target_speed = 0.0

func physics_update(delta: float) -> void:
	if not player:
		return
		
	# Apply gravity if off-floor
	if not player.is_on_floor():
		state_machine.transition_to("Air")
		return

	# Handle jump input
	if player.is_jump_requested():
		state_machine.transition_to("Air", {"do_jump": true})
		return

	# Handle crouch input
	if player.is_crouch_requested():
		state_machine.transition_to("Crouch")
		return

	# Check movement direction
	var input_dir := player.get_movement_input()
	if input_dir.length_squared() > 0.01:
		if player.is_sprint_requested():
			state_machine.transition_to("Sprint")
		else:
			state_machine.transition_to("Walk")
		return

	# Apply deceleration to zero
	player.apply_movement(input_dir, 0.0, delta)
