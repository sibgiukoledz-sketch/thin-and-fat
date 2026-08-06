class_name Player
extends CharacterBody3D

## FPS CharacterBody3D controller with state machine & multiplayer support.

signal player_state_changed(state_name: String)

# Movement Constants
const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.5
const CROUCH_SPEED: float = 2.5
const JUMP_VELOCITY: float = 4.8
const AIR_ACCEL_FACTOR: float = 0.4

const NORMAL_FOV: float = 75.0
const SPRINT_FOV: float = 88.0

# Exported / Synced Variables
@export var synced_state_name: String = "Idle"
@export var is_crouching: bool = false
@export var peer_id: int = 1

# Node references
@onready var head: Node3D = $Head
@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var uncrouch_ray: RayCast3D = $UncrouchRay
@onready var hud: CanvasLayer = $HUD

# HUD sub-elements
@onready var state_label: Label = $HUD/MarginContainer/VBoxContainer/StateLabel
@onready var authority_label: Label = $HUD/MarginContainer/VBoxContainer/AuthorityLabel

# Runtime state
var mouse_sensitivity: float = 0.002
var gravity: float = 12.0
var target_speed: float = WALK_SPEED

# Standing/Crouching height lerps
var stand_height: float = 1.8
var crouch_height: float = 1.0
var stand_head_y: float = 1.5
var crouch_head_y: float = 0.8

func _ready() -> void:
	# Get gravity setting
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

	# Set multiplayer authority based on node name (e.g. "1", "248231")
	var id_from_name := name.to_int()
	if id_from_name > 0:
		peer_id = id_from_name
		set_multiplayer_authority(peer_id)

	# Configure local player vs remote peer
	if is_multiplayer_authority():
		camera_3d.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if hud:
			hud.show()
	else:
		camera_3d.current = false
		if hud:
			hud.hide()

	# Connect FSM signals
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)

	update_hud_display()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw (left/right) on player body
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Pitch (up/down) on camera head
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	# Toggle mouse lock with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	# Smoothly interpolate crouch height
	_update_crouch_geometry(delta)
	update_hud_display()

# Movement helpers called by State instances
func get_movement_input() -> Vector3:
	if not is_multiplayer_authority():
		return Vector3.ZERO

	var input_vec := Vector2.ZERO
	# Support both standard InputMap actions and key fallbacks
	input_vec.x = Input.get_axis("move_left", "move_right")
	input_vec.y = Input.get_axis("move_forward", "move_backward")

	# Fallback key checks if input map isn't triggered
	if input_vec == Vector2.ZERO:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			input_vec.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			input_vec.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			input_vec.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			input_vec.x += 1.0

	input_vec = input_vec.normalized()
	# Transform input relative to camera yaw rotation
	var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	return direction

func is_jump_requested() -> bool:
	if not is_multiplayer_authority():
		return false
	return Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)

func is_sprint_requested() -> bool:
	if not is_multiplayer_authority():
		return false
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)

func is_crouch_requested() -> bool:
	if not is_multiplayer_authority():
		return false
	return Input.is_action_pressed("crouch") or Input.is_physical_key_pressed(KEY_CTRL)

func apply_movement(direction: Vector3, speed: float, delta: float, accel_factor: float = 1.0) -> void:
	if not is_multiplayer_authority():
		return

	var accel := 10.0 * accel_factor
	var target_vel := direction * speed

	velocity.x = lerpf(velocity.x, target_vel.x, accel * delta)
	velocity.z = lerpf(velocity.z, target_vel.z, accel * delta)

	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

func apply_jump_impulse() -> void:
	if is_multiplayer_authority():
		velocity.y = JUMP_VELOCITY

func set_target_fov(target_fov: float) -> void:
	if is_multiplayer_authority() and camera_3d:
		var tween := get_tree().create_tween()
		tween.tween_property(camera_3d, "fov", target_fov, 0.2)

func set_crouch_state(crouch: bool) -> void:
	is_crouching = crouch

func can_uncrouch() -> bool:
	if uncrouch_ray:
		return not uncrouch_ray.is_colliding()
	return true

func _update_crouch_geometry(delta: float) -> void:
	var target_h := crouch_height if is_crouching else stand_height
	var target_head := crouch_head_y if is_crouching else stand_head_y

	head.position.y = lerpf(head.position.y, target_head, 12.0 * delta)

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var caps := collision_shape.shape as CapsuleShape3D
		caps.height = lerpf(caps.height, target_h, 12.0 * delta)

func _on_state_changed(_from: String, to_state: String) -> void:
	synced_state_name = to_state
	player_state_changed.emit(to_state)
	update_hud_display()

func update_hud_display() -> void:
	if not is_multiplayer_authority() or not hud:
		return

	if state_label and state_machine:
		state_label.text = "FSM STATE: %s" % state_machine.current_state_name.to_upper()
	if authority_label:
		authority_label.text = "PEER ID: %d (AUTHORITY)" % peer_id
