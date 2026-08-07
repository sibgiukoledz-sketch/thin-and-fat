class_name Player
extends CharacterBody3D

## Core Player controller with FPS/TPS Roblox-style camera zoom, multiplayer RPC synchronization,
## character FSM state machine, and dynamic Fat/Thin character mechanics.

signal health_changed(new_hp: float, max_hp: float)
signal stamina_changed(new_stamina: float, max_stamina: float)
signal character_switched(new_char_id: String)
signal player_died
signal player_landed(downward_velocity: float)

const MOUSE_SENSITIVITY_DEFAULT := 0.0025
const ZOOM_STEP := 0.5
const MIN_ZOOM := 0.0
const MAX_ZOOM := 8.0

# Movement constants used by FSM states
const WALK_SPEED := 5.0
const SPRINT_SPEED := 9.0
const CROUCH_SPEED := 2.5
const NORMAL_FOV := 75.0
const SPRINT_FOV := 85.0
const AIR_ACCEL_FACTOR := 0.35


@export var peer_id: int = 1
@export var selected_character_id: String = "fat"

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
@export var mouse_sensitivity: float = MOUSE_SENSITIVITY_DEFAULT

# Physics state
var gravity: float = 18.0
var is_dead: bool = false
var is_carrying_heavy_object: bool = false
var is_stamina_exhausted: bool = false
var shift_must_be_released: bool = false
var target_speed: float = 0.0
var synced_state_name: String = "idle"


# Component & Node References
@onready var head: Node3D = $Head
@onready var spring_arm: SpringArm3D = $Head/SpringArm3D
@onready var camera_3d: Camera3D = $Head/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var state_machine: StateMachine = $StateMachine
var active_mechanics: BaseCharacterMechanics = null
var vomit_component: VomitComponent = null
@onready var hud: PlayerHUD = $HUD


# Health & Status overlay tracking
var nausea_intensity: float = 0.0
var _respawn_timer: float = 0.0
var _was_in_air: bool = false
var _last_air_velocity_y: float = 0.0

# Roblox-style Camera Zoom
var target_camera_zoom: float = 0.0
var current_camera_zoom: float = 0.0
var is_first_person: bool = true

# Standing/Crouching height lerps
var stand_height: float = 1.8
var crouch_height: float = 1.0
var stand_head_y: float = 1.5
var crouch_head_y: float = 0.8

func _ready() -> void:
	collision_layer = 2
	collision_mask = 7 # Layer 1 (Environment) + Layer 2 (Players) + Layer 3 (RigidBody Objects / Boulder / NPCs)
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

	var id_from_name := name.to_int()
	if id_from_name > 0:
		peer_id = id_from_name
	else:
		peer_id = multiplayer.get_unique_id()

	set_multiplayer_authority(peer_id)

	if NetworkManager:
		var chosen := NetworkManager.get_character_for_peer(peer_id)
		if chosen != "":
			selected_character_id = chosen

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if camera_3d:
			camera_3d.make_current()
		if hud:
			hud.setup(self)
	else:
		if camera_3d:
			camera_3d.current = false
		if hud:
			hud.queue_free()

	if not vomit_component:
		vomit_component = VomitComponent.new()
		vomit_component.name = "VomitComponent"
		add_child(vomit_component)

	set_character(selected_character_id)

func set_character(char_id: String) -> void:
	selected_character_id = char_id.to_lower()
	var is_fat := (selected_character_id == "fat")

	if is_fat:
		max_health = 160.0
		max_stamina = 100.0
		walk_speed = 3.6
		run_speed = 5.8
		jump_velocity = 3.2 # Extremely heavy low hop (~20 cm height!)
		stamina_drain_rate = 35.0
		stamina_regen_rate = 22.0
		stand_height = 1.5
		crouch_height = 0.95
		stand_head_y = 1.25
		crouch_head_y = 0.75

		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.65
		cap_shape.height = 1.5
		if collision_shape:
			collision_shape.shape = cap_shape

		var cap_mesh := CapsuleMesh.new()
		cap_mesh.radius = 0.65
		cap_mesh.height = 1.5

		var fat_mat := StandardMaterial3D.new()
		fat_mat.albedo_color = Color(0.88, 0.48, 0.18, 1.0) # Warm Amber Heavy Physique
		fat_mat.roughness = 0.45
		cap_mesh.material = fat_mat

		if mesh_instance:
			mesh_instance.mesh = cap_mesh

		# Attach Fat Mechanics Component
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
		cap_shape.radius = 0.28
		cap_shape.height = 2.4
		if collision_shape:
			collision_shape.shape = cap_shape

		var cap_mesh := CapsuleMesh.new()
		cap_mesh.radius = 0.28
		cap_mesh.height = 2.4

		var thin_mat := StandardMaterial3D.new()
		thin_mat.albedo_color = Color(0.18, 0.65, 0.95, 1.0) # Neon Cyan Athletic Physique
		thin_mat.roughness = 0.3
		cap_mesh.material = thin_mat

		if mesh_instance:
			mesh_instance.mesh = cap_mesh

		# Attach Thin Mechanics Component
		_attach_mechanics_component("res://scripts/player/characters/thin_mechanics.gd")

	current_health = max_health
	current_stamina = max_stamina

	if collision_shape:
		collision_shape.position.y = stand_height * 0.5
	if mesh_instance:
		mesh_instance.position.y = stand_height * 0.5
	if head:
		head.position.y = stand_head_y

	character_switched.emit(selected_character_id)

func _attach_mechanics_component(script_path: String) -> void:
	if active_mechanics:
		active_mechanics.queue_free()
		active_mechanics = null

	var scr := load(script_path) as Script
	if scr:
		var comp := Node.new()
		comp.name = "CharacterMechanics"
		comp.set_script(scr)
		add_child(comp)
		active_mechanics = comp as BaseCharacterMechanics

		if active_mechanics and active_mechanics.has_method("setup"):
			active_mechanics.setup(self)

func take_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

	if is_multiplayer_authority() and hud:
		hud.update_display()

	if current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	if is_dead:
		return

	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

	if is_multiplayer_authority() and hud:
		hud.update_display()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	_respawn_timer = 3.0
	player_died.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if mesh_instance:
		mesh_instance.hide()
	if hud and "death_overlay" in hud and hud.death_overlay and is_multiplayer_authority():
		hud.death_overlay.show()
	print("💀 PLAYER DIED: %s" % name)

func respawn() -> void:
	current_health = max_health
	current_stamina = max_stamina
	is_stamina_exhausted = false
	is_dead = false
	nausea_intensity = 0.0
	if vomit_component:
		vomit_component.nausea_intensity = 0.0

	if active_mechanics and active_mechanics.has_method("wash_stench"):
		active_mechanics.wash_stench()

	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.show()
	if hud and "death_overlay" in hud and hud.death_overlay:
		hud.death_overlay.hide()

	var sp_nodes := get_tree().get_nodes_in_group("spawn_points")
	if sp_nodes.size() > 0:
		var sp: Node3D = sp_nodes.pick_random()
		global_position = sp.global_position
	else:
		global_position = Vector3(randf_range(-4.0, 4.0), 1.5, randf_range(-4.0, 4.0))

	print("✨ PLAYER RESPAWNED: %s" % name)

@rpc("any_peer", "call_local", "reliable")
func rpc_respawn() -> void:
	respawn()

@rpc("any_peer", "call_local", "reliable")
func rpc_toggle_character() -> void:
	if selected_character_id.to_lower() == "fat":
		set_character("thin")
	else:
		set_character("fat")
	respawn()

# Nausea & Vomit Delegation
func trigger_vomit() -> void:
	if vomit_component:
		vomit_component.trigger_vomit()

func trigger_nausea(amount: float) -> void:
	if vomit_component:
		vomit_component.trigger_nausea(amount)
		nausea_intensity = vomit_component.nausea_intensity

@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_vomit_puddle(spawn_pos: Vector3, normal: Vector3, target_path: NodePath) -> void:
	var puddle_scene := load("res://scenes/vomit_puddle.tscn") as PackedScene
	if puddle_scene:
		var puddle := puddle_scene.instantiate() as VomitPuddle
		get_tree().root.add_child(puddle)

		var target_node: Node3D = null
		if not target_path.is_empty() and has_node(target_path):
			target_node = get_node_or_null(target_path) as Node3D

		if puddle.has_method("align_to_surface"):
			puddle.align_to_surface(spawn_pos, normal, target_node)

# Input & Movement Controls
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

	# When Pause Menu is open, ignore game inputs so UI buttons can be clicked cleanly!
	if hud and hud.has_method("is_pause_menu_open") and hud.is_pause_menu_open():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_perform_melee_attack()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * (1.0 - nausea_intensity * 0.60)
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-event.relative.y * sens)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_camera_zoom = clampf(target_camera_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_camera_zoom = clampf(target_camera_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

	if active_mechanics:
		active_mechanics.handle_ability_input(event)

func _perform_melee_attack() -> void:
	if not is_multiplayer_authority() or not camera_3d:
		return

	var space_state := get_world_3d().direct_space_state
	var cam_pos := camera_3d.global_position
	var ray_dir := -camera_3d.global_transform.basis.z
	var ray_end := cam_pos + ray_dir * 4.0

	var query := PhysicsRayQueryParameters3D.create(cam_pos, ray_end)
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result:
		var hit_collider: Object = result.collider
		var hit_pos: Vector3 = result.position
		if hit_collider and hit_collider.has_method("take_damage"):
			var dmg: float = 35.0 if selected_character_id.to_lower() == "fat" else 20.0
			hit_collider.take_damage(dmg, hit_pos)
			print("🥊 MELEE HIT: %s dealt %.1f damage to %s" % [name, dmg, hit_collider.name])

var _last_carry_state: bool = false

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
				respawn()
		return

	# Landing impact calculation
	if is_on_floor() and _was_in_air:
		var fall_impact: float = absf(_last_air_velocity_y)
		player_landed.emit(fall_impact)
		if fall_impact > 12.0:
			var fall_dmg: float = (fall_impact - 12.0) * 4.0
			take_damage(fall_dmg)

	_was_in_air = not is_on_floor()
	if not is_on_floor():
		_last_air_velocity_y = velocity.y

	_handle_stamina_regen(delta)
	_update_camera_zoom(delta)

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
	if not collision_shape:
		return
	var is_fat := (selected_character_id.to_lower() == "fat")
	var cap_shape := CapsuleShape3D.new()

	if is_fat:
		if is_carrying_heavy_object:
			# Expand Fat's capsule radius to 1.65m (3.3m total width) matching 3.5m boulder size!
			cap_shape.radius = 1.65
			cap_shape.height = 2.8
		else:
			cap_shape.radius = 0.65
			cap_shape.height = 1.5
	else:
		cap_shape.radius = 0.28
		cap_shape.height = 2.4

	collision_shape.shape = cap_shape

func _handle_stamina_regen(delta: float) -> void:
	if state_machine:
		synced_state_name = state_machine.current_state_name
		var cur_state: String = synced_state_name.to_lower()
		if cur_state == "sprint":
			current_stamina = clampf(current_stamina - stamina_drain_rate * delta, 0.0, max_stamina)
			stamina_changed.emit(current_stamina, max_stamina)
			if current_stamina <= 0.001:
				is_stamina_exhausted = true
				shift_must_be_released = true
		else:
			if current_stamina < max_stamina:
				current_stamina = clampf(current_stamina + stamina_regen_rate * delta, 0.0, max_stamina)
				stamina_changed.emit(current_stamina, max_stamina)
			elif current_stamina >= max_stamina:
				is_stamina_exhausted = false
				shift_must_be_released = false

func _update_camera_zoom(delta: float) -> void:
	current_camera_zoom = lerpf(current_camera_zoom, target_camera_zoom, 14.0 * delta)
	if spring_arm:
		spring_arm.spring_length = current_camera_zoom
	if camera_3d and camera_3d.fov < 74.9:
		camera_3d.fov = lerpf(camera_3d.fov, 75.0, 4.0 * delta)

	is_first_person = (current_camera_zoom < 0.25)
	var crosshair: Control = hud.crosshair if (hud and "crosshair" in hud) else null

	if is_multiplayer_authority():
		if mesh_instance:
			mesh_instance.visible = not is_first_person
		if crosshair:
			crosshair.visible = is_first_person
	else:
		if mesh_instance:
			mesh_instance.show()

func get_movement_input() -> Vector3:
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir := (global_transform.basis * Vector3(raw_input.x, 0.0, raw_input.y)).normalized()
	return dir

func get_effective_speed(base_spd: float) -> float:
	var spd := base_spd
	if is_carrying_heavy_object:
		spd *= 0.50 # 50% speed penalty when carrying heavy boulder!
	return spd

func apply_movement(dir: Vector3, move_spd: float, delta: float, accel_factor: float = 1.0) -> void:
	var final_spd := get_effective_speed(move_spd)
	var target_vel_x := dir.x * final_spd
	var target_vel_z := dir.z * final_spd
	var accel := 14.0 * accel_factor
	velocity.x = lerpf(velocity.x, target_vel_x, accel * delta)
	velocity.z = lerpf(velocity.z, target_vel_z, accel * delta)
	move_and_slide()
	_handle_rigidbody_pushing(delta)

func _handle_rigidbody_pushing(delta: float) -> void:
	var is_fat := (selected_character_id.to_lower() == "fat")

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			if rb.freeze:
				continue

			var is_heavy := (rb is HeavyBoulder or rb.mass >= 100.0 or rb.is_in_group("heavy_objects"))

			if is_heavy:
				if not is_fat:
					# Thin player CANNOT push heavy objects (like 450kg HeavyBoulder)!
					rb.linear_velocity = Vector3.ZERO
					rb.angular_velocity = Vector3.ZERO
				else:
					# Fat player CAN push heavy objects!
					var push_dir := -collision.get_normal()
					push_dir.y = 0.0
					if push_dir.length_squared() > 0.001:
						push_dir = push_dir.normalized()
						rb.apply_central_force(push_dir * 1800.0)

					# Regulate max rolling speed when Fat pushes it
					if rb.linear_velocity.length() > 3.5:
						rb.linear_velocity = rb.linear_velocity.normalized() * 3.5
						rb.angular_velocity = rb.angular_velocity.normalized() * minf(rb.angular_velocity.length(), 4.5)
			else:
				# Light rigidbodies (mass < 100.0)
				var push_dir := -collision.get_normal()
				push_dir.y = 0.0
				push_dir = push_dir.normalized()
				var push_force := 20.0 if is_fat else 8.0
				rb.apply_central_impulse(push_dir * push_force * delta * 60.0)



func is_jump_requested() -> bool:
	return Input.is_action_just_pressed("jump")

func is_crouch_requested() -> bool:
	return Input.is_action_pressed("crouch") or Input.is_action_pressed("ui_down")

func is_sprint_requested() -> bool:
	return Input.is_action_pressed("sprint") and not is_stamina_exhausted

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var grav_mult: float = 1.45 if selected_character_id.to_lower() == "fat" else 1.0
		velocity.y -= gravity * grav_mult * delta

func apply_jump_impulse() -> void:
	if is_carrying_heavy_object:
		velocity.y = jump_velocity * 0.55
	else:
		velocity.y = jump_velocity

func set_target_fov(fov_val: float) -> void:
	if camera_3d:
		var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(camera_3d, "fov", fov_val, 0.25)

func set_crouch_state(crouching: bool) -> void:
	var target_h: float = crouch_height if crouching else stand_height
	var target_head_y: float = crouch_head_y if crouching else stand_head_y
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		(collision_shape.shape as CapsuleShape3D).height = target_h
		collision_shape.position.y = target_h * 0.5
	if mesh_instance and mesh_instance.mesh is CapsuleMesh:
		(mesh_instance.mesh as CapsuleMesh).height = target_h
		mesh_instance.position.y = target_h * 0.5
	if head:
		head.position.y = target_head_y

func can_uncrouch() -> bool:
	if not head:
		return true
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, crouch_height, 0)
	var to: Vector3 = global_position + Vector3(0, stand_height + 0.1, 0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()
