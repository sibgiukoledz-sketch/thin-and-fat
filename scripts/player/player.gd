class_name Player
extends CharacterBody3D

## FPS CharacterBody3D controller with extensible CharacterData & FSM support.

signal player_state_changed(state_name: String)

# Preloaded Character Data Resources
const CHAR_THIN := preload("res://resources/characters/thin_character.tres")
const CHAR_FAT := preload("res://resources/characters/fat_character.tres")

# Dynamic Movement Variables (populated from CharacterData)
var WALK_SPEED: float = 5.0
var SPRINT_SPEED: float = 8.5
var CROUCH_SPEED: float = 2.5
var JUMP_VELOCITY: float = 4.8
var AIR_ACCEL_FACTOR: float = 0.4

const NORMAL_FOV: float = 75.0
const SPRINT_FOV: float = 88.0

# Exported / Synced Variables
@export var selected_character_id: String = "thin":
	set(val):
		selected_character_id = val
		_apply_character_by_id(selected_character_id)

@export var synced_state_name: String = "Idle"
@export var is_crouching: bool = false
@export var peer_id: int = 1

# Node references
@onready var head: Node3D = $Head
@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var uncrouch_ray: RayCast3D = $UncrouchRay
@onready var hud: CanvasLayer = $HUD

# HUD sub-elements
@onready var state_label: Label = $HUD/MarginContainer/VBoxContainer/StateLabel
@onready var authority_label: Label = $HUD/MarginContainer/VBoxContainer/AuthorityLabel
@onready var char_info_label: Label = $HUD/MarginContainer/VBoxContainer/CharInfoLabel

# Runtime state
var active_character_data: CharacterData
var mouse_sensitivity: float = 0.002
var gravity: float = 12.0
var target_speed: float = WALK_SPEED

# Standing/Crouching height lerps
var stand_height: float = 1.8
var crouch_height: float = 1.0
var stand_head_y: float = 1.5
var crouch_head_y: float = 0.8

func _ready() -> void:
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

	var id_from_name := name.to_int()
	if id_from_name > 0:
		peer_id = id_from_name
		set_multiplayer_authority(peer_id)

	# Fetch chosen character from NetworkManager if local
	if is_multiplayer_authority() and NetworkManager:
		selected_character_id = NetworkManager.local_character_id
	else:
		_apply_character_by_id(selected_character_id)

	if is_multiplayer_authority():
		camera_3d.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if hud:
			hud.show()
	else:
		camera_3d.current = false
		if hud:
			hud.hide()

	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)

	update_hud_display()

func apply_character_data(data: CharacterData) -> void:
	if not data:
		return
	active_character_data = data

	# Apply stats
	WALK_SPEED = data.walk_speed
	SPRINT_SPEED = data.sprint_speed
	CROUCH_SPEED = data.crouch_speed
	JUMP_VELOCITY = data.jump_velocity
	AIR_ACCEL_FACTOR = data.air_accel_factor

	stand_height = data.stand_height
	crouch_height = data.crouch_height
	stand_head_y = data.stand_head_y
	crouch_head_y = data.crouch_head_y

	# Update collision shape
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var caps := collision_shape.shape as CapsuleShape3D
		caps.radius = data.capsule_radius
		caps.height = data.stand_height
		collision_shape.position.y = data.stand_height / 2.0

	# Update visual mesh scale & material color
	if mesh_instance:
		mesh_instance.scale = data.mesh_scale
		mesh_instance.position.y = data.stand_height / 2.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = data.body_color
		mat.roughness = 0.4
		mesh_instance.material_override = mat

	if head:
		head.position.y = data.stand_head_y

	update_hud_display()

func _apply_character_by_id(id: String) -> void:
	match id.to_lower():
		"fat":
			apply_character_data(CHAR_FAT)
		_:
			apply_character_data(CHAR_THIN)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_update_crouch_geometry(delta)
	update_hud_display()

# Movement helpers
func get_movement_input() -> Vector3:
	if not is_multiplayer_authority():
		return Vector3.ZERO

	var input_vec := Vector2.ZERO
	input_vec.x = Input.get_axis("move_left", "move_right")
	input_vec.y = Input.get_axis("move_forward", "move_backward")

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
	if char_info_label and active_character_data:
		char_info_label.text = "CHAR: %s (SPD: %.1f)" % [active_character_data.character_name, WALK_SPEED]
