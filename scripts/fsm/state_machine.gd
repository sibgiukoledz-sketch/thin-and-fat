class_name StateMachine
extends Node

## Generic Finite State Machine controller for Godot 4.

signal state_changed(from_state: String, to_state: String)

@export var initial_state: State

var current_state: State = null
var current_state_name: String = "None"
var states: Dictionary = {}

func _ready() -> void:
	# Wait for owner node to fully initialize
	await owner.ready
	
	# Register child states
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.process_mode = Node.PROCESS_MODE_DISABLED

	if initial_state:
		transition_to(initial_state.name)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	var key := target_state_name.to_lower()
	if not states.has(key):
		push_warning("StateMachine: State '%s' not found!" % target_state_name)
		return

	var previous_name := current_state_name
	if current_state:
		current_state.exit()
		current_state.process_mode = Node.PROCESS_MODE_DISABLED

	current_state = states[key]
	current_state_name = current_state.name
	current_state.process_mode = Node.PROCESS_MODE_INHERIT
	current_state.enter(msg)

	state_changed.emit(previous_name, current_state_name)
