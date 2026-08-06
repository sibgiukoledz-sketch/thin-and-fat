class_name FatMechanics
extends BaseCharacterMechanics

## Controller for "Fat / Жирдяй" character mechanics: Stench accumulation, Toxic Gas Aura & Shower mechanics.

signal stench_changed(current: float, max_stench: float)

@export var max_stench: float = 100.0
@export var stench_level: float = 0.0
@export var stench_walk_rate: float = 12.0
@export var stench_sprint_rate: float = 24.0
@export var stench_damage_threshold: float = 75.0
@export var stench_damage_per_sec: float = 15.0
@export var stench_aura_radius: float = 5.0

var _damage_timer: float = 0.0
var _stench_particles: GPUParticles3D
var _aura_mesh: MeshInstance3D
var _aura_material: StandardMaterial3D

func _ready() -> void:
	# Defer particle & aura creation until player parent is set
	call_deferred("_setup_visual_nodes")

func _setup_visual_nodes() -> void:
	if not player:
		return

	# 1. Create GPUParticles3D attached directly to player 3D node
	_stench_particles = GPUParticles3D.new()
	_stench_particles.name = "StenchGasParticles"
	_stench_particles.emitting = false
	_stench_particles.amount = 40
	_stench_particles.lifetime = 1.4

	var mat_proc := ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat_proc.emission_sphere_radius = 1.5
	mat_proc.direction = Vector3(0, 1, 0)
	mat_proc.spread = 60.0
	mat_proc.initial_velocity_min = 0.8
	mat_proc.initial_velocity_max = 2.2
	mat_proc.gravity = Vector3(0, 0.6, 0)
	mat_proc.scale_min = 0.2
	mat_proc.scale_max = 0.5
	mat_proc.color = Color(0.3, 0.95, 0.2, 0.85) # Vivid Toxic Green

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.35, 0.95, 0.2, 0.8)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.material = draw_mat
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36

	_stench_particles.process_material = mat_proc
	_stench_particles.draw_pass_1 = sphere_mesh
	_stench_particles.position = Vector3(0, 1.0, 0)
	player.add_child(_stench_particles)

	# 2. Create 3D Toxic Aura Sphere mesh around player
	_aura_mesh = MeshInstance3D.new()
	_aura_mesh.name = "ToxicAuraSphere"
	var aura_sphere := SphereMesh.new()
	aura_sphere.radius = stench_aura_radius
	aura_sphere.height = stench_aura_radius * 2.0

	_aura_material = StandardMaterial3D.new()
	_aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_material.albedo_color = Color(0.2, 0.85, 0.15, 0.18) # Translucent green sphere
	_aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_aura_mesh.mesh = aura_sphere
	_aura_mesh.material_override = _aura_material
	_aura_mesh.position = Vector3(0, 1.0, 0)
	_aura_mesh.visible = false
	player.add_child(_aura_mesh)

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	# Quick Test Key K or G: Instantly add +30% Stench
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K or event.keycode == KEY_G:
			add_stench(35.0)
			print("🧪 TEST KEY: Added +35% Stench! Current: ", int(stench_level))

func add_stench(amount: float) -> void:
	stench_level = clampf(stench_level + amount, 0.0, max_stench)
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()

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
		var should_emit := (stench_level >= 25.0)
		if _stench_particles.emitting != should_emit:
			_stench_particles.emitting = should_emit

	if _aura_mesh and _aura_material:
		var is_toxic := (stench_level >= stench_damage_threshold)
		_aura_mesh.visible = is_toxic
		if is_toxic:
			# Pulsate alpha slightly
			var alpha := 0.18 + sin(Time.get_ticks_msec() * 0.005) * 0.06
			_aura_material.albedo_color.a = alpha

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
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]

	var results := space_state.intersect_shape(query)
	for res in results:
		var collider: Object = res.get("collider")
		if collider and collider != player and collider.has_method("take_damage"):
			var hit_pos: Vector3 = collider.global_position if collider is Node3D else player.global_position
			collider.take_damage(stench_damage_per_sec, hit_pos)
			print("🤢 STENCH AURA: Dealt %f damage to %s" % [stench_damage_per_sec, collider.name])
