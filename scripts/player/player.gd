class_name Player
extends CharacterBody3D

## FPS / TPS CharacterBody3D controller with health, stamina, Roblox-style camera, FSM & modular character mechanics.

signal player_state_changed(state_name: String)
signal health_changed(current_hp: float, max_hp: float)
signal stamina_changed(current_stm: float, max_stm: float)
signal player_died

# Preloaded Character Data & Mechanics
const CHAR_THIN := preload("res://resources/characters/thin_character.tres")
const CHAR_FAT := preload("res://resources/characters/fat_character.tres")

# Camera Zoom Constants
const MIN_ZOOM: float = 0.0
const MAX_ZOOM: float = 6.0
const ZOOM_STEP: float = 0.5

# Dynamic Movement & Stamina Variables (populated from CharacterData)
var WALK_SPEED: float = 5.0
var SPRINT_SPEED: float = 8.5
var CROUCH_SPEED: float = 2.5
var JUMP_VELOCITY: float = 4.8
var AIR_ACCEL_FACTOR: float = 0.4

var stamina_drain_rate: float = 20.0
var stamina_regen_rate: float = 20.0

const NORMAL_FOV: float = 75.0
const SPRINT_FOV: float = 88.0

# Exported / Synced Variables for Networking
@export var selected_character_id: String = "fat":
	set(val):
		selected_character_id = val
		_apply_character_by_id(selected_character_id)

@export var max_health: float = 100.0:
	set(val):
		max_health = maxf(val, 1.0)
		current_health = clampf(current_health, 0.0, max_health)
		health_changed.emit(current_health, max_health)

@export var current_health: float = 100.0:
	set(val):
		current_health = clampf(val, 0.0, max_health)
		health_changed.emit(current_health, max_health)

@export var max_stamina: float = 100.0:
	set(val):
		max_stamina = maxf(val, 1.0)
		current_stamina = clampf(current_stamina, 0.0, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

@export var current_stamina: float = 100.0:
	set(val):
		current_stamina = clampf(val, 0.0, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

@export var synced_state_name: String = "Idle"
@export var is_crouching: bool = false
@export var peer_id: int = 1

# Node references
@onready var head: Node3D = $Head
@onready var spring_arm: SpringArm3D = $Head/SpringArm3D
@onready var camera_3d: Camera3D = $Head/SpringArm3D/Camera3D
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var uncrouch_ray: RayCast3D = $UncrouchRay
@onready var hud: CanvasLayer = $HUD

# HUD sub-elements
@onready var state_label: Label = $HUD/MarginContainer/VBoxContainer/StateLabel
@onready var authority_label: Label = $HUD/MarginContainer/VBoxContainer/AuthorityLabel
@onready var char_info_label: Label = $HUD/MarginContainer/VBoxContainer/CharInfoLabel
@onready var health_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $HUD/MarginContainer/VBoxContainer/HealthLabel
@onready var stamina_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/StaminaBar
@onready var stamina_label: Label = $HUD/MarginContainer/VBoxContainer/StaminaLabel

# Runtime state
var active_character_data: CharacterData
var active_mechanics: BaseCharacterMechanics
var mouse_sensitivity: float = 0.002
var gravity: float = 12.0
var target_speed: float = WALK_SPEED
var is_dead: bool = false
var is_stamina_exhausted: bool = false

# Roblox-style Camera Zoom
var target_camera_zoom: float = 0.0
var current_camera_zoom: float = 0.0

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

	# Fetch chosen character from NetworkManager if local authority
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

	if uncrouch_ray:
		uncrouch_ray.add_exception(self)

	update_hud_display()

func apply_character_data(data: CharacterData) -> void:
	if not data:
		return
	active_character_data = data

	# Apply health stats
	max_health = data.max_health
	current_health = max_health

	# Apply stamina stats
	max_stamina = data.max_stamina
	current_stamina = max_stamina
	stamina_drain_rate = data.stamina_drain_rate
	stamina_regen_rate = data.stamina_regen_rate

	# Apply movement stats
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

	# Bind modular character mechanics component
	_setup_character_mechanics(data.character_id)
	update_hud_display()

func _apply_character_by_id(id: String) -> void:
	match id.to_lower():
		"thin":
			apply_character_data(CHAR_THIN)
		_:
			apply_character_data(CHAR_FAT)

func _setup_character_mechanics(id: String) -> void:
	if active_mechanics and is_instance_valid(active_mechanics):
		active_mechanics.queue_free()
		active_mechanics = null

	if id.to_lower() == "thin":
		active_mechanics = ThinMechanics.new()
		active_mechanics.name = "ThinMechanics"
	else:
		active_mechanics = FatMechanics.new()
		active_mechanics.name = "FatMechanics"

	add_child(active_mechanics)

# Health & Combat System Methods
func take_damage(amount: float) -> void:
	rpc_take_damage.rpc(amount)

@rpc("any_peer", "call_local", "reliable")
func rpc_take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0 and not is_dead:
		die()

func heal(amount: float) -> void:
	rpc_heal.rpc(amount)

@rpc("any_peer", "call_local", "reliable")
func rpc_heal(amount: float) -> void:
	current_health += amount

func is_alive() -> bool:
	return current_health > 0.0 and not is_dead

func die() -> void:
	is_dead = true
	player_died.emit()

func respawn() -> void:
	current_health = max_health
	current_stamina = max_stamina
	is_stamina_exhausted = false
	is_dead = false
	global_position = Vector3(randf_range(-4.0, 4.0), 1.5, randf_range(-4.0, 4.0))

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	# Roblox-style Camera Zoom on Mouse Wheel
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_camera_zoom = clampf(target_camera_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_camera_zoom = clampf(target_camera_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

	# Toggle mouse lock with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if active_mechanics:
		active_mechanics.handle_ability_input(event)

func _process(delta: float) -> void:
	_update_camera_zoom(delta)
	_update_crouch_geometry(delta)
	_update_stamina_logic(delta)

	if active_mechanics:
		active_mechanics.update_mechanics(delta)

	update_hud_display()

func _physics_process(delta: float) -> void:
	if active_mechanics:
		active_mechanics.physics_update_mechanics(delta)

func _update_stamina_logic(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	var is_currently_sprinting := (synced_state_name.to_lower() == "sprint")

	if is_currently_sprinting:
		current_stamina -= stamina_drain_rate * delta
		if current_stamina <= 0.0:
			current_stamina = 0.0
			is_stamina_exhausted = true
			if state_machine:
				state_machine.transition_to("Walk")
	else:
		current_stamina += stamina_regen_rate * delta
		# Recover from exhaustion only after reaching 35% threshold
		if is_stamina_exhausted and current_stamina >= (max_stamina * 0.35):
			is_stamina_exhausted = false

func _update_camera_zoom(delta: float) -> void:
	current_camera_zoom = lerpf(current_camera_zoom, target_camera_zoom, 14.0 * delta)
	if spring_arm:
		spring_arm.spring_length = current_camera_zoom

	if is_multiplayer_authority():
		if mesh_instance:
			mesh_instance.visible = (current_camera_zoom >= 0.25)
	else:
		if mesh_instance:
			mesh_instance.visible = true

# Movement helpers
func get_movement_input() -> Vector3:
	if not is_multiplayer_authority() or is_dead:
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
	if not is_multiplayer_authority() or is_dead:
		return false
	return Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)

func is_sprint_requested() -> bool:
	if not is_multiplayer_authority() or is_dead:
		return false
	if is_stamina_exhausted or current_stamina < 5.0:
		return false
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)

func is_crouch_requested() -> bool:
	if not is_multiplayer_authority() or is_dead:
		return false
	return Input.is_action_pressed("crouch") or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)

func apply_movement(direction: Vector3, speed: float, delta: float, accel_factor: float = 1.0) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	var target_vel := direction * speed
	var rate: float

	if direction.length_squared() > 0.01:
		rate = 9.0 * accel_factor
	else:
		rate = 4.5 * accel_factor

	velocity.x = lerpf(velocity.x, target_vel.x, rate * delta)
	velocity.z = lerpf(velocity.z, target_vel.z, rate * delta)

	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

func apply_jump_impulse() -> void:
	if is_multiplayer_authority() and not is_dead:
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

	head.position.y = lerpf(head.position.y, target_head, 14.0 * delta)

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var caps := collision_shape.shape as CapsuleShape3D
		caps.height = lerpf(caps.height, target_h, 14.0 * delta)
		collision_shape.position.y = caps.height / 2.0

	if mesh_instance:
		mesh_instance.position.y = collision_shape.position.y

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
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label:
		health_label.text = "HP: %d / %d" % [int(current_health), int(max_health)]
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
	if stamina_label:
		if is_stamina_exhausted:
			stamina_label.text = "STAMINA: EXHAUSTED!"
		else:
			stamina_label.text = "STAMINA: %d%%" % int((current_stamina / max_stamina) * 100.0)
	if char_info_label and active_character_data:
		var view_mode := "1ST PERSON" if current_camera_zoom < 0.25 else "3RD PERSON (%.1fm)" % current_camera_zoom
		char_info_label.text = "CHAR: %s | VIEW: %s" % [active_character_data.character_name, view_mode]
