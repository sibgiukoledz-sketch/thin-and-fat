class_name Player
extends CharacterBody3D

## Core Player controller with FPS/TPS Roblox-style camera zoom, multiplayer RPC synchronization,
## character FSM state machine, and dynamic Fat/Thin character mechanics.

signal health_changed(new_hp: float, max_hp: float)
signal stamina_changed(new_stamina: float, max_stamina: float)
signal character_switched(new_char_id: String)
signal player_died
signal player_landed(downward_velocity: float)

# Movement & FOV constants used by FSM states
const WALK_SPEED := 5.0
const SPRINT_SPEED := 9.0
const CROUCH_SPEED := 2.5
const AIR_ACCEL_FACTOR := 0.35
const NORMAL_FOV := 75.0
const SPRINT_FOV := 85.0

@export var peer_id: int = 1
@export var selected_character_id: String = "fat":
	set(val):
		var new_val := val.to_lower()
		var changed := (selected_character_id != new_val)
		selected_character_id = new_val
		if changed and is_inside_tree():
			set_character(selected_character_id)

@export var is_crouching: bool = false:
	set(val):
		if is_crouching != val:
			is_crouching = val
			if is_inside_tree():
				set_crouch_state(is_crouching)

# Attributes
@export var max_health: float = 160.0
@export var current_health: float = 160.0
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var stamina_regen_rate: float = 20.0
@export var stamina_drain_rate: float = 35.0

# Movement specs
@export var walk_speed: float = 4.5
@export var run_speed: float = 7.5
@export var jump_velocity: float = 6.5
@export var mouse_sensitivity: float = 0.0025

# Physics state
var gravity: float = 26.0
var is_dead: bool = false
var is_fall_damage_immune: bool = false
var is_carrying_heavy_object: bool = false
var is_paper_flattened: bool = false
var paper_flatten_timer: float = 0.0
var _flatten_tween: Tween = null
var is_stamina_exhausted: bool = false
var shift_must_be_released: bool = false
var target_speed: float = 0.0
@export var synced_state_name: String = "idle":
	set(val):
		var new_state := val.to_lower()
		synced_state_name = new_state
		var crouching := (synced_state_name == "crouch")
		if is_crouching != crouching:
			is_crouching = crouching
			if is_inside_tree():
				set_crouch_state(is_crouching)

		if character_model and character_model.has_method("play_anim"):
			character_model.call("play_anim", synced_state_name)

# Component & Node References
@onready var head: Node3D = $Head
@onready var spring_arm: SpringArm3D = $Head/SpringArm3D
@onready var camera_3d: Camera3D = $Head/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var overhead_ray_cast: RayCast3D = get_node_or_null("OverheadRayCast") as RayCast3D
@onready var state_machine: StateMachine = $StateMachine
@onready var hud: PlayerHUD = $HUD

# Modular Sub-Components
var camera_component: PlayerCameraComponent = null
var visual_loader: CharacterVisualLoader = null
var combat_component: PlayerCombatComponent = null
var active_mechanics: BaseCharacterMechanics = null
var vomit_component: VomitComponent = null
var surface_detector: SurfaceDetectorComponent = null

# Health & Status tracking
var nausea_intensity: float = 0.0
var _respawn_timer: float = 0.0
var _was_in_air: bool = false
var _last_air_velocity_y: float = 0.0
var _step_timer: float = 0.0

# Standing/Crouching height lerps
var stand_height: float = 1.8
var crouch_height: float = 1.0
var stand_head_y: float = 1.5
var crouch_head_y: float = 0.8

var character_model: Node3D = null
var voice_indicator_label: Label3D = null

func _enter_tree() -> void:
	var id_from_name := name.to_int()
	if id_from_name > 0:
		peer_id = id_from_name
	else:
		peer_id = multiplayer.get_unique_id()

	set_multiplayer_authority(peer_id)

func _ready() -> void:
	add_to_group("players")
	collision_layer = 2
	collision_mask = 7
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING

	_setup_sub_components()
	_setup_voice_indicator()

	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		var default_g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		gravity = maxf(default_g * 2.6, 26.0)

	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.mesh = mesh_instance.mesh.duplicate()

	if NetworkManager:
		var chosen := NetworkManager.get_character_for_peer(peer_id)
		if chosen != "":
			selected_character_id = chosen

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if camera_3d:
			camera_3d.make_current()
			var listener := camera_3d.get_node_or_null("AudioListener3D") as AudioListener3D
			if not listener:
				listener = AudioListener3D.new()
				listener.name = "AudioListener3D"
				camera_3d.add_child(listener)
			listener.make_current()
		if hud:
			hud.setup(self)
	else:
		if camera_3d:
			camera_3d.current = false
		if hud:
			hud.queue_free()
		if mesh_instance:
			mesh_instance.show()

	set_character(selected_character_id)

func _setup_sub_components() -> void:
	camera_component = PlayerCameraComponent.new()
	camera_component.name = "CameraComponent"
	add_child(camera_component)
	camera_component.setup(self, head, spring_arm, camera_3d)

	visual_loader = CharacterVisualLoader.new()
	visual_loader.name = "CharacterVisualLoader"
	add_child(visual_loader)

	combat_component = PlayerCombatComponent.new()
	combat_component.name = "CombatComponent"
	add_child(combat_component)

	if not vomit_component:
		vomit_component = VomitComponent.new()
		vomit_component.name = "VomitComponent"
		add_child(vomit_component)

	if not surface_detector:
		surface_detector = SurfaceDetectorComponent.new()
		surface_detector.name = "SurfaceDetectorComponent"
		add_child(surface_detector)
		surface_detector.setup(self)

func _setup_voice_indicator() -> void:
	if not voice_indicator_label:
		voice_indicator_label = Label3D.new()
		voice_indicator_label.name = "VoiceIndicatorLabel3D"
		voice_indicator_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		voice_indicator_label.text = "🔊 [ГОВОРИТ]"
		voice_indicator_label.modulate = Color(0.2, 1.0, 0.4)
		voice_indicator_label.font_size = 34
		voice_indicator_label.outline_size = 8
		voice_indicator_label.position = Vector3(0, 2.3, 0)
		voice_indicator_label.hide()
		add_child(voice_indicator_label)

func set_voice_indicator(is_speaking: bool) -> void:
	if not voice_indicator_label:
		_setup_voice_indicator()
	if voice_indicator_label:
		voice_indicator_label.visible = is_speaking

func set_character(char_id: String) -> void:
	selected_character_id = char_id.to_lower()
	var is_fat := (selected_character_id == "fat")

	if is_fat:
		max_health = 160.0
		max_stamina = 100.0
		walk_speed = 3.6
		run_speed = 5.8
		jump_velocity = 3.2
		stamina_drain_rate = 35.0
		stamina_regen_rate = 22.0
		stand_height = 1.8
		crouch_height = 1.0
		stand_head_y = 1.50
		crouch_head_y = 0.85

		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.65
		cap_shape.height = 1.8
		if collision_shape:
			collision_shape.shape = cap_shape

		_build_character_visuals(true)
		_attach_mechanics_component("res://scripts/player/characters/fat_mechanics.gd")

	else: # Thin
		max_health = 80.0
		max_stamina = 120.0
		walk_speed = 6.5
		run_speed = 10.5
		jump_velocity = 8.5
		stamina_drain_rate = 18.0
		stamina_regen_rate = 30.0
		stand_height = 2.4
		crouch_height = 1.2
		stand_head_y = 2.05
		crouch_head_y = 1.0

		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.35
		cap_shape.height = 2.4
		if collision_shape:
			collision_shape.shape = cap_shape

		_build_character_visuals(false)
		_attach_mechanics_component("res://scripts/player/characters/thin_mechanics.gd")

	current_health = max_health
	current_stamina = max_stamina

	if collision_shape:
		collision_shape.position.y = stand_height * 0.5
	if mesh_instance:
		mesh_instance.position.y = 0.0
	if head:
		head.position.y = stand_head_y

	character_switched.emit(selected_character_id)

func is_movement_blocked() -> bool:
	if active_mechanics and active_mechanics.is_movement_blocked():
		return true
	return false

func get_movement_input() -> Vector3:
	if is_movement_blocked():
		return Vector3.ZERO
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if active_mechanics and "is_magnetized_to_ceiling" in active_mechanics and bool(active_mechanics.is_magnetized_to_ceiling):
		raw_input.x = -raw_input.x

	var dir := (transform.basis * Vector3(raw_input.x, 0, raw_input.y)).normalized()
	return dir

func apply_gravity(delta: float) -> void:
	if active_mechanics and "is_magnetized_to_ceiling" in active_mechanics and bool(active_mechanics.is_magnetized_to_ceiling):
		return
	if not is_on_floor():
		var fall_mult := 1.45 if velocity.y < 0.0 else 1.0
		velocity.y -= gravity * fall_mult * delta

func apply_movement(input_dir: Vector3, target_spd: float, delta: float, accel_factor: float = 1.0) -> void:
	if is_movement_blocked():
		velocity.x = lerpf(velocity.x, 0.0, 18.0 * delta)
		velocity.z = lerpf(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		return

	var effective_speed := 3.4 if is_paper_flattened else target_spd
	var accel := 14.0 * accel_factor if input_dir.length_squared() > 0.01 else 10.0
	velocity.x = lerpf(velocity.x, input_dir.x * effective_speed, accel * delta)
	velocity.z = lerpf(velocity.z, input_dir.z * effective_speed, accel * delta)
	move_and_slide()

	var max_spd := effective_speed * 1.3
	var horiz_v := Vector2(velocity.x, velocity.z)
	if horiz_v.length() > max_spd:
		var clamped := horiz_v.normalized() * max_spd
		velocity.x = clamped.x
		velocity.z = clamped.y

	if selected_character_id.to_lower() == "fat":
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider is RigidBody3D:
				var rb := collider as RigidBody3D
				if col.get_normal().y < 0.5:
					var push_dir := -col.get_normal()
					push_dir.y = 0.0
					if push_dir.length_squared() > 0.001:
						push_dir = push_dir.normalized()
						var push_impulse := push_dir * (rb.mass * 12.0 * delta)
						rb.apply_central_impulse(push_impulse)

func apply_jump_impulse() -> void:
	velocity.y = jump_velocity
	if AudioManager:
		AudioManager.play_sfx_3d("jump_" + selected_character_id.to_lower(), global_position)

func is_jump_requested() -> bool:
	if is_paper_flattened:
		return false
	if is_movement_blocked():
		if is_multiplayer_authority() and Input.is_action_just_pressed("jump"):
			if active_mechanics and active_mechanics.has_method("rpc_toggle_belly_trampoline"):
				active_mechanics.rpc_toggle_belly_trampoline.rpc(false)
		return false
	return Input.is_action_just_pressed("jump")

func is_crouch_requested() -> bool:
	if is_movement_blocked():
		return false
	return Input.is_action_pressed("crouch")

func can_uncrouch() -> bool:
	return is_overhead_clear()

func set_target_fov(_fov: float) -> void:
	pass

func trigger_nausea(amount: float) -> void:
	if vomit_component:
		vomit_component.trigger_nausea(amount)

func _attach_mechanics_component(script_path: String) -> void:
	if active_mechanics:
		active_mechanics.queue_free()
		active_mechanics = null

	if ResourceLoader.exists(script_path):
		var script := load(script_path) as Script
		if script:
			active_mechanics = script.new() as BaseCharacterMechanics
			active_mechanics.name = "CharacterMechanics"
			add_child(active_mechanics)
			active_mechanics.setup(self)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	if event.is_action_pressed("ui_cancel"):
		if hud and hud.has_method("toggle_pause_menu"):
			hud.toggle_pause_menu()
		else:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if hud and hud.has_method("is_pause_menu_open") and hud.is_pause_menu_open():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			if combat_component:
				combat_component.perform_melee_attack(self, camera_3d, selected_character_id)

	if camera_component:
		var is_ceiling_crawling := false
		if active_mechanics and "is_magnetized_to_ceiling" in active_mechanics:
			is_ceiling_crawling = bool(active_mechanics.is_magnetized_to_ceiling)
		camera_component.handle_input(event, mouse_sensitivity, nausea_intensity, is_ceiling_crawling)

	if active_mechanics:
		active_mechanics.handle_ability_input(event)

@rpc("any_peer", "call_local", "reliable")
func rpc_toggle_character() -> void:
	if selected_character_id.to_lower() == "fat":
		set_character("thin")
	else:
		set_character("fat")
	respawn()

@rpc("any_peer", "call_local", "reliable")
func rpc_flatten_into_paper(duration: float = 20.0) -> void:
	if is_dead or is_paper_flattened:
		return
	apply_paper_flatten(duration)

var _last_carry_state: bool = false

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		if mesh_instance and not is_dead and not mesh_instance.visible:
			mesh_instance.show()

	if camera_component:
		var is_sprinting := (synced_state_name.to_lower() == "sprint" or is_sprint_requested())
		var is_ceiling_crawling := false
		if active_mechanics and "is_magnetized_to_ceiling" in active_mechanics:
			is_ceiling_crawling = bool(active_mechanics.is_magnetized_to_ceiling)
		camera_component.update_camera(delta, is_sprinting, is_ceiling_crawling)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if _last_carry_state != is_carrying_heavy_object:
		_last_carry_state = is_carrying_heavy_object
		_update_carried_boulder_collision_shape()

	if is_dead:
		if is_multiplayer_authority():
			_respawn_timer -= delta
			if hud:
				hud.update_death_display(true, _respawn_timer)
			if _respawn_timer <= 0.0:
				rpc_respawn.rpc()
		return

	if is_on_floor() and _was_in_air:
		var fall_impact: float = absf(_last_air_velocity_y)
		player_landed.emit(fall_impact)
		if surface_detector:
			surface_detector.play_landing_sound(selected_character_id, fall_impact)
		elif AudioManager and fall_impact > 1.5:
			AudioManager.play_sfx_3d("land", global_position)

		if not is_fall_damage_immune:
			# High fall threshold: 23.0 m/s (~10 meters drop) with gentle scaling
			if fall_impact > 23.0:
				var dmg_mult: float = 0.5 if selected_character_id.to_lower() == "fat" else 1.0
				var fall_dmg: float = (fall_impact - 23.0) * 1.8 * dmg_mult
				take_damage(fall_dmg)
		else:
			is_fall_damage_immune = false

	_was_in_air = not is_on_floor()
	if not is_on_floor():
		_last_air_velocity_y = velocity.y
	else:
		var horiz_vel := Vector2(velocity.x, velocity.z).length()
		if horiz_vel > 0.5:
			var step_interval := 0.48 if selected_character_id.to_lower() == "fat" else 0.32
			if synced_state_name.to_lower() == "sprint":
				step_interval *= 0.7
			_step_timer += delta
			if _step_timer >= step_interval:
				_step_timer = 0.0
				if surface_detector:
					surface_detector.play_footstep_sound(selected_character_id, synced_state_name.to_lower() == "sprint")
				elif AudioManager:
					AudioManager.play_sfx_3d("step_" + selected_character_id.to_lower(), global_position)

	_handle_stamina_regen(delta)

	# Dynamic animation state updates
	var state_lower := synced_state_name.to_lower()
	var target_anim := "idle"

	if active_mechanics and "is_magnetized_to_ceiling" in active_mechanics and bool(active_mechanics.is_magnetized_to_ceiling):
		if state_lower == "walk" or state_lower == "sprint" or (is_multiplayer_authority() and Vector2(velocity.x, velocity.z).length() > 0.6):
			target_anim = "walk"
		else:
			target_anim = "idle"
	elif not is_on_floor():
		target_anim = "jump"
	elif is_crouching or state_lower == "crouch":
		target_anim = "crouch"
	elif state_lower == "sprint":
		target_anim = "sprint"
	elif state_lower == "walk":
		target_anim = "walk"
	elif is_multiplayer_authority() and Vector2(velocity.x, velocity.z).length() > 0.6:
		if is_sprint_requested():
			target_anim = "sprint"
		else:
			target_anim = "walk"

	if character_model and character_model.has_method("play_anim"):
		character_model.call("play_anim", target_anim)

	if is_paper_flattened:
		var overhead_open := is_overhead_clear()
		if overhead_open:
			paper_flatten_timer -= delta
			if paper_flatten_timer <= 0.0:
				rpc_inflate_back_to_normal.rpc()
			elif is_multiplayer_authority() and Input.is_action_just_pressed("jump"):
				rpc_inflate_back_to_normal.rpc()
		else:
			paper_flatten_timer = maxf(paper_flatten_timer, 15.0)

	if active_mechanics:
		active_mechanics.update_mechanics(delta)
		active_mechanics.physics_update_mechanics(delta)

	if vomit_component:
		vomit_component.update_nausea_effects(delta)

	if is_multiplayer_authority() and hud:
		hud.update_display()
		if nausea_intensity > 0.0:
			hud.set_nausea_intensity(nausea_intensity)

func _update_carried_boulder_collision_shape() -> void:
	if not collision_shape or is_movement_blocked():
		return
	var is_fat := (selected_character_id.to_lower() == "fat")
	var cap_shape := CapsuleShape3D.new()

	if is_fat:
		if is_carrying_heavy_object:
			cap_shape.radius = 1.65
			cap_shape.height = 2.8
		else:
			cap_shape.radius = 0.65
			cap_shape.height = 1.8
	else:
		cap_shape.radius = 0.35
		cap_shape.height = 2.4

	collision_shape.shape = cap_shape

func is_sprint_requested() -> bool:
	if is_movement_blocked():
		return false
	return Input.is_action_pressed("sprint") and not is_stamina_exhausted

func drain_stamina(amount: float) -> void:
	current_stamina = clampf(current_stamina - amount, 0.0, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0:
		is_stamina_exhausted = true

func _handle_stamina_regen(delta: float) -> void:
	var is_moving := (velocity.length() > 0.1)
	var is_sprinting := (synced_state_name.to_lower() == "sprint")

	if is_sprinting and is_moving:
		drain_stamina(stamina_drain_rate * delta)
	else:
		if current_stamina < max_stamina:
			current_stamina = clampf(current_stamina + stamina_regen_rate * delta, 0.0, max_stamina)
			stamina_changed.emit(current_stamina, max_stamina)
			if current_stamina >= max_stamina * 0.30:
				is_stamina_exhausted = false

func set_crouch_state(crouch: bool) -> void:
	is_crouching = crouch
	var target_h := crouch_height if is_crouching else stand_height
	var target_head := crouch_head_y if is_crouching else stand_head_y

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var cap := collision_shape.shape as CapsuleShape3D
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cap, "height", target_h, 0.2)
		tw.parallel().tween_property(collision_shape, "position:y", target_h * 0.5, 0.2)

	if head:
		var tw_head := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_head.tween_property(head, "position:y", target_head, 0.2)

func is_overhead_clear() -> bool:
	if not overhead_ray_cast:
		return true
	overhead_ray_cast.force_raycast_update()
	return not overhead_ray_cast.is_colliding()

func apply_paper_flatten(duration: float = 10.0) -> void:
	if not is_multiplayer_authority():
		return
	rpc_apply_paper_flatten.rpc(duration)

@rpc("any_peer", "call_local", "reliable")
func rpc_apply_paper_flatten(duration: float = 10.0) -> void:
	is_paper_flattened = true
	paper_flatten_timer = duration

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var flat_cap := collision_shape.shape as CapsuleShape3D
		flat_cap.height = 0.25
		collision_shape.shape = flat_cap
		collision_shape.position.y = 0.125

	if mesh_instance:
		if _flatten_tween and _flatten_tween.is_valid():
			_flatten_tween.kill()

		_flatten_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_flatten_tween.tween_property(mesh_instance, "scale", Vector3(1.7, 0.08, 1.7), 0.3)
		_flatten_tween.parallel().tween_property(mesh_instance, "position:y", 0.04, 0.3)

	if head:
		var tw_head := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_head.tween_property(head, "position:y", 0.35, 0.3)

@rpc("any_peer", "call_local", "reliable")
func rpc_inflate_back_to_normal() -> void:
	if not is_paper_flattened:
		return

	is_paper_flattened = false
	paper_flatten_timer = 0.0

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var normal_cap := collision_shape.shape as CapsuleShape3D
		normal_cap.height = stand_height
		collision_shape.shape = normal_cap
		collision_shape.position.y = stand_height * 0.5

	if mesh_instance:
		var orig_pos_y: float = 0.0
		_flatten_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_flatten_tween.tween_property(mesh_instance, "scale", Vector3(1.25, 1.25, 1.25), 0.15)
		_flatten_tween.parallel().tween_property(mesh_instance, "position:y", 0.1, 0.15)
		_flatten_tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.25)
		_flatten_tween.parallel().tween_property(mesh_instance, "position:y", orig_pos_y, 0.25)

	if head:
		var tw_head := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_head.tween_property(head, "position:y", stand_head_y, 0.25)

func take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_multiplayer_authority():
		return
	if is_multiplayer_authority():
		_apply_damage_internal(amount, hit_pos)
	else:
		rpc_take_damage.rpc_id(get_multiplayer_authority(), amount, hit_pos)

func _apply_damage_internal(amount: float, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

	if is_multiplayer_authority() and hud:
		hud.update_display()

	if current_health <= 0.0:
		rpc_die.rpc()

func heal(amount: float) -> void:
	if is_dead:
		return

	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

	if is_multiplayer_authority() and hud:
		hud.update_display()

@rpc("any_peer", "call_local", "reliable")
func rpc_die() -> void:
	die()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	_respawn_timer = 3.0
	player_died.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	_start_ragdoll()

	if hud and "death_overlay" in hud and hud.death_overlay and is_multiplayer_authority():
		hud.death_overlay.show()

	if AudioManager:
		AudioManager.play_sfx_3d("player_die", global_position)

@rpc("any_peer", "call_local", "reliable")
func rpc_respawn() -> void:
	respawn()

func respawn() -> void:
	current_health = max_health
	current_stamina = max_stamina
	is_stamina_exhausted = false
	is_dead = false
	nausea_intensity = 0.0
	if vomit_component:
		vomit_component.nausea_intensity = 0.0

	_stop_ragdoll()

	if collision_shape:
		collision_shape.disabled = false
		collision_shape.position.y = stand_height * 0.5

	if hud and "death_overlay" in hud and hud.death_overlay:
		hud.death_overlay.hide()

	if NetworkManager and NetworkManager.has_method("get_spawn_position_for_peer"):
		var spawn_pos: Vector3 = NetworkManager.get_spawn_position_for_peer(peer_id)
		global_position = spawn_pos
	else:
		global_position = Vector3(0, 2, 0)

	velocity = Vector3.ZERO
	if head:
		head.rotation = Vector3.ZERO

	if is_multiplayer_authority() and hud:
		hud.update_display()

@rpc("any_peer", "call_local", "unreliable")
func rpc_take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO) -> void:
	_apply_damage_internal(amount, hit_pos)

func _start_ragdoll() -> void:
	if visual_loader:
		visual_loader.start_ragdoll(velocity, mesh_instance)

func _stop_ragdoll() -> void:
	if visual_loader:
		visual_loader.stop_ragdoll(mesh_instance)

func _build_character_visuals(is_fat: bool) -> void:
	if visual_loader:
		character_model = visual_loader.build_visuals(mesh_instance, is_fat)
