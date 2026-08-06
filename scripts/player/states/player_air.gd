class_name PlayerAir
extends PlayerState

func enter(msg: Dictionary = {}) -> void:
	if player and msg.get("do_jump", false):
		player.apply_jump_impulse()

func physics_update(delta: float) -> void:
	if not player:
		return

	# Apply gravity
	player.apply_gravity(delta)

	# Air control (slightly lower acceleration)
	var input_dir: Vector3 = player.get_movement_input()

	player.apply_movement(input_dir, player.WALK_SPEED, delta, player.AIR_ACCEL_FACTOR)

	# Check landing
	if player.is_on_floor():
		if input_dir.length_squared() > 0.01:
			if player.is_sprint_requested():
				state_machine.transition_to("Sprint")
			else:
				state_machine.transition_to("Walk")
		elif player.is_crouch_requested():
			state_machine.transition_to("Crouch")
		else:
			state_machine.transition_to("Idle")
