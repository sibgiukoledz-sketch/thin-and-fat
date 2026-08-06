class_name FatMechanics
extends BaseCharacterMechanics

## Controller for "Fat / Жирдяй" character mechanics: Stench accumulation, Toxic Gas & Flies Visuals, & AoE Damage.

signal stench_changed(current: float, max_stench: float)

@export var max_stench: float = 100.0
@export var stench_level: float = 0.0

# Balanced Accumulation Rates (Slow & Realistic)
@export var stench_walk_rate: float = 0.6
@export var stench_sprint_rate: float = 3.0

@export var stench_damage_threshold: float = 75.0
@export var stench_damage_per_sec: float = 20.0
@export var stench_aura_radius: float = 8.0

var _damage_timer: float = 0.0
var _gas_particles: GPUParticles3D
var _flies_particles: GPUParticles3D
var _toxic_ring_mesh: MeshInstance3D
var _ring_material: StandardMaterial3D

func _ready() -> void:
	super._ready()
	if not player and get_parent() is Player:
		player = get_parent() as Player
	_setup_visual_nodes()

func _setup_visual_nodes() -> void:
	var parent_3d: Node3D = player if player else (get_parent() as Node3D)
	if not parent_3d:
		return

	# 1. Rising Toxic Gas Puffs Particles
	if not _gas_particles:
		_gas_particles = GPUParticles3D.new()
		_gas_particles.name = "StenchGasParticles"
		_gas_particles.emitting = false
		_gas_particles.amount = 32
		_gas_particles.lifetime = 1.5

		var mat_proc := ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat_proc.emission_sphere_radius = 1.1
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 45.0
		mat_proc.initial_velocity_min = 0.4
		mat_proc.initial_velocity_max = 1.2
		mat_proc.gravity = Vector3(0, 0.3, 0)
		mat_proc.scale_min = 0.15
		mat_proc.scale_max = 0.4
		mat_proc.color = Color(0.4, 0.9, 0.2, 0.7) # Bright Toxic Green

		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = Color(0.4, 0.9, 0.2, 0.65)
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var sphere_mesh := SphereMesh.new()
		sphere_mesh.material = draw_mat
		sphere_mesh.radius = 0.15
		sphere_mesh.height = 0.3

		_gas_particles.process_material = mat_proc
		_gas_particles.draw_pass_1 = sphere_mesh
		_gas_particles.position = Vector3(0, 0.8, 0)
		parent_3d.add_child(_gas_particles)

	# 2. Buzzing Stink Flies Particles
	if not _flies_particles:
		_flies_particles = GPUParticles3D.new()
		_flies_particles.name = "StenchFliesParticles"
		_flies_particles.emitting = false
		_flies_particles.amount = 20
		_flies_particles.lifetime = 0.8

		var mat_proc := ParticleProcessMaterial.new()
		mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat_proc.emission_sphere_radius = 1.3
		mat_proc.direction = Vector3(0, 1, 0)
		mat_proc.spread = 180.0
		mat_proc.initial_velocity_min = 1.2
		mat_proc.initial_velocity_max = 3.0
		mat_proc.gravity = Vector3(0, 0, 0)
		mat_proc.scale_min = 0.04
		mat_proc.scale_max = 0.08

		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = Color(0.1, 0.25, 0.05, 0.95) # Dark Fly Dots

		var fly_mesh := SphereMesh.new()
		fly_mesh.material = draw_mat
		fly_mesh.radius = 0.04
		fly_mesh.height = 0.08

		_flies_particles.process_material = mat_proc
		_flies_particles.draw_pass_1 = fly_mesh
		_flies_particles.position = Vector3(0, 1.2, 0)
		parent_3d.add_child(_flies_particles)

	# 3. Ground Toxic Damage Ring Emitter
	if not _toxic_ring_mesh:
		_toxic_ring_mesh = MeshInstance3D.new()
		_toxic_ring_mesh.name = "ToxicDamageRing"
		var torus := TorusMesh.new()
		torus.inner_radius = stench_aura_radius - 0.2
		torus.outer_radius = stench_aura_radius

		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.albedo_color = Color(0.4, 0.95, 0.2, 0.5)
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		_toxic_ring_mesh.mesh = torus
		_toxic_ring_mesh.material_override = _ring_material
		_toxic_ring_mesh.position = Vector3(0, 0.1, 0)
		_toxic_ring_mesh.visible = false
		parent_3d.add_child(_toxic_ring_mesh)

func handle_ability_input(event: InputEvent) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority():
		return

	# Quick Test Key K or G: Instantly add +35% Stench
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K or event.keycode == KEY_G:
			add_stench(35.0)
			print("🧪 TEST KEY: Added +35% Stench! Current: ", int(stench_level))

func add_stench(amount: float) -> void:
	stench_level = clampf(stench_level + amount, 0.0, max_stench)
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()

func update_mechanics(delta: float) -> void:
	if not _ensure_player_ref() or not player.is_multiplayer_authority() or player.is_dead:
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

func wash_stench_gradual(amount: float) -> void:
	stench_level = clampf(stench_level - amount, 0.0, max_stench)
	stench_changed.emit(stench_level, max_stench)
	_update_gas_visuals()
	print("🦛 FAT: Stench completely washed off in shower!")

func _update_gas_visuals() -> void:
	if _gas_particles:
		var should_emit := (stench_level >= 25.0)
		if _gas_particles.emitting != should_emit:
			_gas_particles.emitting = should_emit

	if _flies_particles:
		var should_flies := (stench_level >= 45.0)
		if _flies_particles.emitting != should_flies:
			_flies_particles.emitting = should_flies

	if _toxic_ring_mesh and _ring_material:
		var is_toxic := (stench_level >= stench_damage_threshold)
		_toxic_ring_mesh.visible = is_toxic
		if is_toxic:
			var alpha := 0.4 + sin(Time.get_ticks_msec() * 0.008) * 0.2
			_ring_material.albedo_color.a = alpha

func _update_aoe_poison_damage(delta: float) -> void:
	if stench_level < stench_damage_threshold:
		return

	_damage_timer += delta
	if _damage_timer >= 1.0:
		_damage_timer = 0.0
		_apply_aoe_damage_tick()

func _apply_aoe_damage_tick() -> void:
	if not _ensure_player_ref():
		return

	var center := player.global_position
	var root := get_tree().root
	_damage_nodes_recursive(root, center)

func _damage_nodes_recursive(node: Node, center: Vector3) -> void:
	if not node:
		return

	if node is Node3D and node != player and node.has_method("take_damage"):
		var n3d := node as Node3D
		var dist := center.distance_to(n3d.global_position)
		if dist <= stench_aura_radius:
			node.take_damage(stench_damage_per_sec, n3d.global_position)
			print("🤢 STENCH AURA: Dealt %f damage to %s (dist: %.1fm)" % [stench_damage_per_sec, node.name, dist])

	for child in node.get_children():
		_damage_nodes_recursive(child, center)

func _ensure_player_ref() -> bool:
	if not player and get_parent() is Player:
		player = get_parent() as Player
	return player != null
