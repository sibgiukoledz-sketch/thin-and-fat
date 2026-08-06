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
@onready var stench_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/StenchBar
@onready var stench_label: Label = $HUD/MarginContainer/VBoxContainer/StenchLabel
@onready var crosshair: Control = $HUD/Crosshair
@onready var nausea_overlay: ColorRect = $HUD/NauseaOverlay
@onready var death_overlay: Control = $HUD/DeathOverlay
@onready var respawn_label: Label = $HUD/DeathOverlay/VBox/RespawnLabel

# Runtime state
var active_character_data: CharacterData
var active_mechanics: BaseCharacterMechanics
var mouse_sensitivity: float = 0.002
var gravity: float = 12.0
var target_speed: float = WALK_SPEED
var is_dead: bool = false
var is_stamina_exhausted: bool = false
var nausea_intensity: float = 0.0
var _respawn_timer: float = 0.0

# Roblox-style Camera Zoom
var target_camera_zoom: float = 0.0
var current_camera_zoom: float = 0.0

# Standing/Crouching height lerps
var stand_height: float = 1.8
var crouch_height: float = 1.0
var stand_head_y: float = 1.5
var crouch_head_y: float = 0.8

# Vomit Mechanics Runtime State
var _vomit_particles: GPUParticles3D
var _vomit_splatter: GPUParticles3D
var _vomit_chunks: GPUParticles3D
var _vomit_cooldown_timer: float = 0.0
var _vomit_anim_timer: float = 0.0
var _severe_nausea_duration: float = 0.0

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

	_setup_vomit_particles()

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

	active_mechanics.player = self
	add_child(active_mechanics)

# Health & Combat System Methods
func take_damage(amount: float) -> void:
	rpc_take_damage.rpc(amount)

@rpc("any_peer", "call_local", "reliable")
func rpc_take_damage(amount: float) -> void:
	current_health -= amount
	trigger_nausea(0.6)
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
	if is_dead:
		return
	is_dead = true
	_respawn_timer = 3.0
	player_died.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if mesh_instance:
		mesh_instance.hide()
	if death_overlay and is_multiplayer_authority():
		death_overlay.show()
	print("💀 PLAYER DIED: %s" % name)

func respawn() -> void:
	current_health = max_health
	current_stamina = max_stamina
	is_stamina_exhausted = false
	is_dead = false
	nausea_intensity = 0.0

	if active_mechanics and active_mechanics.has_method("wash_stench"):
		active_mechanics.wash_stench()

	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.show()
	if death_overlay:
		death_overlay.hide()

	# Move to random spawn point in map
	var sp_nodes := get_tree().get_nodes_in_group("spawn_points")
	if sp_nodes.size() > 0:
		var sp: Node3D = sp_nodes.pick_random()
		global_position = sp.global_position
	else:
		global_position = Vector3(randf_range(-4.0, 4.0), 1.5, randf_range(-4.0, 4.0))

	print("✨ PLAYER RESPAWNED: %s" % name)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	# Re-capture mouse on left click if uncaptured, or perform attack if captured
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_perform_melee_attack()

	# Handle mouse look with nauseous sluggishness
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * (1.0 - nausea_intensity * 0.60)
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-event.relative.y * sens)
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
			var dmg: float = 35.0 if selected_character_id == "fat" else 20.0
			hit_collider.take_damage(dmg, hit_pos)

func _setup_vomit_particles() -> void:
	if not head or _vomit_particles:
		return

	# === 1. MAIN VOMIT STREAM (thick glistening fluid jet) ===
	_vomit_particles = GPUParticles3D.new()
	_vomit_particles.name = "VomitStream"
	_vomit_particles.amount = 100
	_vomit_particles.lifetime = 1.4
	_vomit_particles.one_shot = true
	_vomit_particles.explosiveness = 0.7
	_vomit_particles.emitting = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -0.35, -1.0)
	mat.spread = 16.0
	mat.initial_velocity_min = 4.5
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -11.0, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.5
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.52, 0.62, 0.1, 0.95)

	var mesh := SphereMesh.new()
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.48, 0.58, 0.08, 0.92)
	draw_mat.roughness = 0.06 # Wet glossy shine!
	draw_mat.metallic = 0.1
	draw_mat.metallic_specular = 0.7
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	mesh.radius = 0.08
	mesh.height = 0.16

	_vomit_particles.process_material = mat
	_vomit_particles.draw_pass_1 = mesh
	_vomit_particles.transform.origin = Vector3(0, -0.15, -0.38)
	head.add_child(_vomit_particles)

	# === 2. SPLATTER SPRAY DROPLETS (fine wide mist) ===
	var splatter := GPUParticles3D.new()
	splatter.name = "VomitSplatter"
	splatter.amount = 50
	splatter.lifetime = 1.0
	splatter.one_shot = true
	splatter.explosiveness = 0.88
	splatter.emitting = false

	var smat := ParticleProcessMaterial.new()
	smat.direction = Vector3(0, -0.2, -1.0)
	smat.spread = 42.0
	smat.initial_velocity_min = 2.5
	smat.initial_velocity_max = 6.0
	smat.gravity = Vector3(0, -14.0, 0)
	smat.scale_min = 0.03
	smat.scale_max = 0.09
	smat.color = Color(0.68, 0.78, 0.18, 0.88)

	var smesh := SphereMesh.new()
	var sdraw := StandardMaterial3D.new()
	sdraw.albedo_color = Color(0.65, 0.75, 0.18, 0.88)
	sdraw.roughness = 0.1
	sdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smesh.material = sdraw
	smesh.radius = 0.04
	smesh.height = 0.08

	splatter.process_material = smat
	splatter.draw_pass_1 = smesh
	splatter.transform.origin = Vector3(0, -0.15, -0.38)
	head.add_child(splatter)
	_vomit_splatter = splatter

	# === 3. HEAVY FOOD CHUNKS (solid brown-yellow lumps) ===
	var chunks := GPUParticles3D.new()
	chunks.name = "VomitChunks"
	chunks.amount = 25
	chunks.lifetime = 1.2
	chunks.one_shot = true
	chunks.explosiveness = 0.92
	chunks.emitting = false

	var cmat := ParticleProcessMaterial.new()
	cmat.direction = Vector3(0, -0.3, -1.0)
	cmat.spread = 22.0
	cmat.initial_velocity_min = 3.5
	cmat.initial_velocity_max = 7.0
	cmat.gravity = Vector3(0, -13.0, 0)
	cmat.scale_min = 0.08
	cmat.scale_max = 0.22
	cmat.color = Color(0.55, 0.42, 0.12, 1.0)

	var cmesh := SphereMesh.new()
	var cdraw := StandardMaterial3D.new()
	cdraw.albedo_color = Color(0.55, 0.42, 0.12, 1.0)
	cdraw.roughness = 0.15
	cdraw.metallic = 0.1
	cmesh.material = cdraw
	cmesh.radius = 0.06
	cmesh.height = 0.12

	chunks.process_material = cmat
	chunks.draw_pass_1 = cmesh
	chunks.transform.origin = Vector3(0, -0.15, -0.38)
	head.add_child(chunks)
	_vomit_chunks = chunks

func trigger_vomit() -> void:
	_severe_nausea_duration = 0.0
	_vomit_cooldown_timer = 8.0
	_vomit_anim_timer = 1.8 # Duration of full retch animation

	# Temporary stomach relief after vomiting
	nausea_intensity = maxf(nausea_intensity - 0.35, 0.15)

	# Emit all 3 particle passes
	if _vomit_particles:
		_vomit_particles.restart()
		_vomit_particles.emitting = true
	if _vomit_splatter:
		_vomit_splatter.restart()
		_vomit_splatter.emitting = true
	if _vomit_chunks:
		_vomit_chunks.restart()
		_vomit_chunks.emitting = true

	# Violent retch: Camera pitch jerk & temporary FOV punch
	if head:
		head.rotation.x = clampf(head.rotation.x + deg_to_rad(42.0), deg_to_rad(-89.0), deg_to_rad(89.0))
	if camera_3d:
		camera_3d.fov = 68.0 # FOV contraction during retch!

	# Screen flash green bile burst on shader
	if nausea_overlay and nausea_overlay.material:
		nausea_overlay.material.set_shader_parameter("intensity", 1.0)

	# Raycast forward & down from mouth to project vomit onto ANY surface (floors, walls, boxes, or OTHER PLAYERS!)
	if is_multiplayer_authority():
		var mouth_pos := head.global_position if head else global_position + Vector3(0, 1.5, 0)
		var forward := -global_transform.basis.z
		var ray_end := mouth_pos + forward * 3.5 + Vector3(0, -2.5, 0)

		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(mouth_pos, ray_end)
		query.exclude = [self]

		var hit := space_state.intersect_ray(query)
		var hit_pos: Vector3
		var hit_normal: Vector3 = Vector3.UP
		var hit_node_path: NodePath = NodePath()

		if hit:
			hit_pos = hit.position
			hit_normal = hit.normal
			if hit.collider is Node:
				hit_node_path = hit.collider.get_path()
		else:
			hit_pos = global_position + forward * 1.5

		rpc_spawn_vomit_puddle.rpc(hit_pos, hit_normal, hit_node_path)

	print("🤮 AAA VOMIT BURST: %s vomited!" % name)

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

func trigger_nausea(amount: float) -> void:
	if not is_dead:
		nausea_intensity = clampf(nausea_intensity + amount, 0.0, 1.0)

func _update_nausea_effects(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Handle death screen countdown timer
	if is_dead:
		_respawn_timer -= delta
		if respawn_label:
			respawn_label.text = "ВОЗРОЖДЕНИЕ ЧЕРЕЗ %d СЕК..." % int(ceil(_respawn_timer))
		if _respawn_timer <= 0.0:
			respawn()
		return

	# Handle prolonged severe nausea -> Vomiting burst!
	if nausea_intensity >= 0.75:
		_severe_nausea_duration += delta
		if _severe_nausea_duration >= 3.0 and _vomit_cooldown_timer <= 0.0:
			trigger_vomit()
	else:
		_severe_nausea_duration = maxf(_severe_nausea_duration - delta, 0.0)

	if _vomit_cooldown_timer > 0.0:
		_vomit_cooldown_timer -= delta

	# Slowly decay nausea when away from stench (lasts ~12 seconds)
	nausea_intensity = maxf(nausea_intensity - 0.08 * delta, 0.0)

	# Update Shader Parameter for Nausea post-processing (Wave distortion, double vision & bile vignette)
	if nausea_overlay and nausea_overlay.material:
		nausea_overlay.material.set_shader_parameter("intensity", nausea_intensity)

	# 1st Person Camera Vertigo Sway & Periodic Gag / Retch Heaves
	if camera_3d and head:
		if nausea_intensity > 0.01:
			var t := Time.get_ticks_msec() * 0.001
			# Asymmetric Lissajous Vertigo Roll & Pitch (Stronger sway)
			var roll_z := sin(t * 2.4) * deg_to_rad(15.0) * nausea_intensity
			var pitch_sway := cos(t * 3.6) * deg_to_rad(6.0) * nausea_intensity

			# Periodic gag heave (downward head jerk simulating stomach retch)
			var gag_heave := -pow(maxf(sin(t * 3.2), 0.0), 6.0) * deg_to_rad(10.0) * nausea_intensity

			camera_3d.rotation.z = roll_z
			head.rotation.x = clampf(head.rotation.x + gag_heave * delta * 4.0 + pitch_sway * delta * 2.0, deg_to_rad(-89.0), deg_to_rad(89.0))
		else:
			camera_3d.rotation.z = lerpf(camera_3d.rotation.z, 0.0, 8.0 * delta)

func _process(delta: float) -> void:
	_update_camera_zoom(delta)
	_update_crouch_geometry(delta)
	_update_stamina_logic(delta)
	_update_nausea_effects(delta)

	if active_mechanics:
		active_mechanics.update_mechanics(delta)

	update_hud_display()

func _physics_process(delta: float) -> void:
	if active_mechanics:
		active_mechanics.physics_update_mechanics(delta)

var shift_must_be_released: bool = false

func _update_stamina_logic(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	var is_currently_sprinting := (synced_state_name.to_lower() == "sprint")
	var is_holding_sprint_key := Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)

	if is_currently_sprinting:
		current_stamina -= stamina_drain_rate * delta
		if current_stamina <= 0.0:
			current_stamina = 0.0
			is_stamina_exhausted = true
			shift_must_be_released = true
			if state_machine:
				state_machine.transition_to("Walk")
	else:
		current_stamina += stamina_regen_rate * delta

		# Reset release requirement if player lets go of Shift key
		if not is_holding_sprint_key:
			shift_must_be_released = false

		# Clear exhaustion if Shift released and stamina recovered > 20%, or if stamina reached 100%
		if is_stamina_exhausted:
			if not is_holding_sprint_key and current_stamina >= (max_stamina * 0.20):
				is_stamina_exhausted = false
			elif current_stamina >= max_stamina:
				is_stamina_exhausted = false
				shift_must_be_released = false

func _update_camera_zoom(delta: float) -> void:
	current_camera_zoom = lerpf(current_camera_zoom, target_camera_zoom, 14.0 * delta)
	if spring_arm:
		spring_arm.spring_length = current_camera_zoom
	if camera_3d and camera_3d.fov < 74.9:
		camera_3d.fov = lerpf(camera_3d.fov, 75.0, 4.0 * delta)

	var is_first_person := (current_camera_zoom < 0.25)

	if is_multiplayer_authority():
		if mesh_instance:
			mesh_instance.visible = not is_first_person
		if crosshair:
			crosshair.visible = is_first_person
	else:
		if mesh_instance:
			mesh_instance.visible = true
		if crosshair:
			crosshair.visible = false

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

	# Drunken/Nauseous Control Wobble & Heavy Stumble Drift (Only while actively walking)
	if nausea_intensity > 0.05 and input_vec != Vector2.ZERO:
		var t := Time.get_ticks_msec() * 0.003
		var drift_x := sin(t * 2.2) * 1.6 * nausea_intensity
		var drift_y := cos(t * 1.6) * 1.0 * nausea_intensity
		input_vec.x += drift_x
		input_vec.y += drift_y

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
	if is_stamina_exhausted or shift_must_be_released or current_stamina <= 0.0:
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

	if active_mechanics and active_mechanics is FatMechanics:
		var fat_mech := active_mechanics as FatMechanics
		if stench_bar and stench_label:
			stench_bar.show()
			stench_label.show()
			stench_bar.max_value = fat_mech.max_stench
			stench_bar.value = fat_mech.stench_level
			if fat_mech.stench_level >= fat_mech.stench_damage_threshold:
				stench_label.text = "ВОНЬ: %d%% (ОПАСНАЯ АУРА!)" % int(fat_mech.stench_level)
			else:
				stench_label.text = "ВОНЬ: %d%%" % int(fat_mech.stench_level)
	else:
		if stench_bar and stench_label:
			stench_bar.hide()
			stench_label.hide()
