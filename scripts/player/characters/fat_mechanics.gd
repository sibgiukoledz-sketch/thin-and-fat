class_name FatMechanics
extends BaseCharacterMechanics

## Controller for "Fat / Жирдяй" character mechanics: Stench accumulation, Toxic Gas Aura & Shower mechanics.

signal stench_changed(current: float, max_stench: float)

@export var max_stench: float = 100.0
@export var stench_level: float = 0.0
@export var stench_walk_rate: float = 3.5
@export var stench_sprint_rate: float = 8.0
@export var stench_damage_threshold: float = 75.0
@export var stench_damage_per_sec: float = 10.0
@export var stench_aura_radius: float = 4.5

var _damage_timer: float = 0.0
var _stench_particles: GPUParticles3D

func _ready() -> void:
	_create_stench_particles()

func _create_stench_particles() -> void:
	_stench_particles = GPUParticles3D.new()
	_stench_particles.name = "StenchGasParticles"
	_stench_particles.emitting = false
	_stench_particles.amount = 24
	_stench_particles.lifetime = 1.2

	var mat_proc := ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat_proc.emission_sphere_radius = 1.2
	mat_proc.direction = Vector3(0, 1, 0)
	mat_proc.spread = 45.0
	mat_proc.initial_velocity_min = 0.5
	mat_proc.initial_velocity_max = 1.5
	mat_proc.gravity = Vector3(0, 0.4, 0)
	mat_proc.scale_min = 0.15
	mat_proc.scale_max = 0.35
	mat_proc.color = Color(0.3, 0.85, 0.2, 0.7) # Toxic Green

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.35, 0.85, 0.2, 0.6)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.material = draw_mat
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3

	_stench_particles.process_material = mat_proc
	_stench_particles.draw_pass_1 = sphere_mesh
	add_child(_stench_particles)

func update_mechanics(delta: float) -> void:
	if not player or not player.is_multiplayer_authority() or player.is_dead:
		return

	# Accumulate stench when moving
	var input_dir := player.get_movement_input()
	if input_dir.length_squared() > 0.01:
		var is_sprinting := (player.synced_state_name.to_lower() == "sprint")
		var rate := stench_sprint_rate if is_sprinting else stench_walk_rate
		stench_level = clampf(stench_level + rate * delta, 0.0, max_stench)
		stench_changed.emit(stench_level, max_stench)

	_update_gas_visuals()
	_update_aoe_poison_damage(delta)

func wash_stench() -> void:
	stench_level = 0.0
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()
	print("🦛 FAT: Stench completely washed off in shower!")

func _update_gas_visuals() -> void:
	if _stench_particles:
		var should_emit := (stench_level >= 35.0)
		if _stench_particles.emitting != should_emit:
			_stench_particles.emitting = should_emit

func _update_aoe_poison_damage(delta: float) -> void:
	if stench_level < stench_damage_threshold:
		return

	_damage_timer += delta
	if _damage_timer >= 1.0:
		_damage_timer = 0.0
		_apply_aoe_damage_tick()

func _apply_aoe_damage_tick() -> void:
	if not player:
		return

	var space_state := player.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = stench_aura_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = player.global_transform
	query.collision_mask = 2 | 4 # Players & NPCs

	var results := space_state.intersect_shape(query)
	for res in results:
		var collider: Object = res.get("collider")
		if collider and collider != player and collider.has_method("take_damage"):
			collider.take_damage(stench_damage_per_sec, player.global_position)
			print("🤢 STENCH AURA: Dealt %f damage to %s" % [stench_damage_per_sec, collider.name])
