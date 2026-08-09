class_name ThinMechanics
extends BaseCharacterMechanics

## Dedicated Controller for "Thin / Худой" character mechanics:
## 1. Static Electrification (Наэлектризовывание): Rubbing against wool curtains or carpet floors charges Thin.
## 2. Magnetism (Механика Магнита и Скрепки): Electrified Thin is magnetically pulled toward metal ceilings and clings upside down (FEET ON CEILING, FACING FORWARD) to crawl over chasms.
## 3. Discharging: Discharged when touching a Grounding plate (or custom discharge surface).

signal static_charge_changed(current_charge: float, max_charge: float)
signal electrification_changed(is_electrified: bool)
signal magnetic_attachment_changed(is_attached: bool)

const MAX_STATIC_CHARGE: float = 100.0
const CHARGE_THRESHOLD: float = 15.0
const CHARGE_DECAY_RATE: float = 0.0 ## Charge stays persistent until grounded

@export var static_charge: float = 0.0:
	set(val):
		var prev_elec := is_electrified
		static_charge = clampf(val, 0.0, MAX_STATIC_CHARGE)
		var new_elec := (static_charge >= CHARGE_THRESHOLD)
		if new_elec != prev_elec:
			if player and player.is_multiplayer_authority():
				rpc_set_electrified.rpc(new_elec)
			else:
				is_electrified = new_elec
				_update_spark_visuals()
		static_charge_changed.emit(static_charge, MAX_STATIC_CHARGE)

var is_electrified: bool = false
var is_magnetized_to_ceiling: bool = false
var target_ceiling_y: float = 0.0

var _spark_particles: GPUParticles3D = null
var _plasma_particles: GPUParticles3D = null
var _electric_light: OmniLight3D = null
var _surface_detector: SurfaceDetectorComponent = null
var _crackle_sfx_timer: float = 0.0
var _spark_texture: ImageTexture = null

func _ready() -> void:
	super._ready()

func setup(p: CharacterBody3D) -> void:
	super.setup(p)
	_setup_visual_and_audio_effects()
	_setup_surface_detector()

static func _generate_lightning_spark_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw realistic jagged lightning arc filament with glowing core & plasma aura
	for y in range(64):
		var t := float(y) / 63.0
		var alpha := sin(t * PI)
		var center_x := 32 + int(sin(t * PI * 7.0) * 8.0 + sin(t * PI * 13.0) * 3.0) # Jagged lightning zig-zag
		
		for x in range(clampi(center_x - 7, 0, 63), clampi(center_x + 8, 0, 63)):
			var dist := absf(float(x - center_x)) / 7.0
			var intensity := pow(1.0 - dist, 2.2) * alpha
			var core := pow(1.0 - dist, 5.0) * alpha
			var col := Color(0.3 + core * 0.7, 0.85 + core * 0.15, 1.0, intensity)
			img.set_pixel(x, y, col)
			
	return ImageTexture.create_from_image(img)

func _setup_visual_and_audio_effects() -> void:
	if not player:
		return

	# Electric aura light
	_electric_light = player.get_node_or_null("ElectricAuraLight") as OmniLight3D
	if not _electric_light:
		_electric_light = OmniLight3D.new()
		_electric_light.name = "ElectricAuraLight"
		_electric_light.light_color = Color(0.3, 0.85, 1.0)
		_electric_light.light_energy = 0.0
		_electric_light.omni_range = 4.5
		_electric_light.position = Vector3(0, 1.2, 0)
		player.add_child(_electric_light)

	if not _spark_texture:
		_spark_texture = _generate_lightning_spark_texture()

	# Layer 1: Velocity-aligned jagged lightning arc needles
	_spark_particles = player.get_node_or_null("ElectricSparksParticles") as GPUParticles3D
	if not _spark_particles:
		_spark_particles = GPUParticles3D.new()
		_spark_particles.name = "ElectricSparksParticles"
		_spark_particles.amount = 54
		_spark_particles.lifetime = 0.28
		_spark_particles.explosiveness = 0.2
		_spark_particles.randomness = 0.9
		_spark_particles.emitting = false

		var p_mat := ParticleProcessMaterial.new()
		p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p_mat.emission_box_extents = Vector3(0.35, 0.95, 0.35)
		p_mat.direction = Vector3(0, 1, 0)
		p_mat.spread = 180.0
		p_mat.initial_velocity_min = 1.2
		p_mat.initial_velocity_max = 3.8
		p_mat.gravity = Vector3(0, 1.5, 0)
		p_mat.particle_flag_align_y = true # Stretches lightning bolts in direction of velocity!

		var quad := QuadMesh.new()
		quad.size = Vector2(0.06, 0.42) # Stretched lightning arc needle!
		var spark_mat := StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		spark_mat.albedo_color = Color(0.4, 0.95, 1.0, 0.95)
		spark_mat.albedo_texture = _spark_texture
		quad.material = spark_mat
		_spark_particles.draw_pass_1 = quad

		_spark_particles.process_material = p_mat
		_spark_particles.position = Vector3(0, 1.1, 0)
		player.add_child(_spark_particles)

	# Layer 2: Floating plasma micro-orbs glowing around Thin's skeleton
	_plasma_particles = player.get_node_or_null("ElectricPlasmaParticles") as GPUParticles3D
	if not _plasma_particles:
		_plasma_particles = GPUParticles3D.new()
		_plasma_particles.name = "ElectricPlasmaParticles"
		_plasma_particles.amount = 32
		_plasma_particles.lifetime = 0.45
		_plasma_particles.explosiveness = 0.05
		_plasma_particles.randomness = 0.7
		_plasma_particles.emitting = false

		var p_mat2 := ParticleProcessMaterial.new()
		p_mat2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p_mat2.emission_box_extents = Vector3(0.4, 1.0, 0.4)
		p_mat2.direction = Vector3(0, 1, 0)
		p_mat2.spread = 180.0
		p_mat2.initial_velocity_min = 0.2
		p_mat2.initial_velocity_max = 1.0
		p_mat2.gravity = Vector3(0, 2.0, 0)

		var quad2 := QuadMesh.new()
		quad2.size = Vector2(0.08, 0.08)
		var plasma_mat := StandardMaterial3D.new()
		plasma_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plasma_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		plasma_mat.albedo_color = Color(0.2, 0.8, 1.0, 0.8)
		plasma_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		quad2.material = plasma_mat
		_plasma_particles.draw_pass_1 = quad2

		_plasma_particles.process_material = p_mat2
		_plasma_particles.position = Vector3(0, 1.1, 0)
		player.add_child(_plasma_particles)

func _setup_surface_detector() -> void:
	if not player:
		return
	_surface_detector = player.get_node_or_null("SurfaceDetectorComponent") as SurfaceDetectorComponent
	if not _surface_detector:
		_surface_detector = SurfaceDetectorComponent.new()
		_surface_detector.name = "SurfaceDetectorComponent"
		player.add_child(_surface_detector)
		_surface_detector.setup(player)

	if not _surface_detector.touched_static_charger.is_connected(_on_touched_static_charger):
		_surface_detector.touched_static_charger.connect(_on_touched_static_charger)
	if not _surface_detector.touched_grounded_surface.is_connected(_on_touched_grounded_surface):
		_surface_detector.touched_grounded_surface.connect(_on_touched_grounded_surface)

func _on_touched_static_charger(surface: SurfaceMaterial, delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	var speed_factor := 1.0
	if player.velocity.length() > 0.5:
		speed_factor = 2.2
	
	var gain := surface.static_charge_rate * speed_factor * delta
	add_static_charge(gain)

func _on_touched_grounded_surface(_surface: SurfaceMaterial) -> void:
	if not player or not player.is_multiplayer_authority():
		return
	if static_charge > 0.0:
		rpc_discharge.rpc()

func add_static_charge(amount: float) -> void:
	static_charge += amount
	_crackle_sfx_timer -= 0.016
	if _crackle_sfx_timer <= 0.0 and is_electrified:
		_crackle_sfx_timer = 0.45
		if AudioManager and player:
			AudioManager.play_sfx_3d("static_spark", player.global_position, 25.0, -4.0)

@rpc("any_peer", "call_local", "reliable")
func rpc_set_electrified(state: bool) -> void:
	is_electrified = state
	electrification_changed.emit(is_electrified)
	_update_spark_visuals()

@rpc("any_peer", "call_local", "reliable")
func rpc_discharge() -> void:
	discharge()

func discharge() -> void:
	var was_attached := is_magnetized_to_ceiling
	static_charge = 0.0
	is_electrified = false
	is_magnetized_to_ceiling = false
	electrification_changed.emit(false)
	magnetic_attachment_changed.emit(false)
	_update_spark_visuals()
	_set_upside_down(false)

	if player:
		if was_attached:
			player.velocity.y = -5.0

		if AudioManager:
			AudioManager.play_sfx_3d("discharge_zap", player.global_position, 40.0, 3.0)

@rpc("any_peer", "call_local", "reliable")
func rpc_set_magnetized_to_ceiling(state: bool) -> void:
	is_magnetized_to_ceiling = state
	magnetic_attachment_changed.emit(state)
	_set_upside_down(state)

func update_mechanics(delta: float) -> void:
	if not player:
		return

	# Visual model and spark updates for ALL clients (authority + non-authority peers)
	_update_spark_visuals()
	_set_upside_down(is_magnetized_to_ceiling)

	if not player.is_multiplayer_authority():
		return

	if _surface_detector:
		_surface_detector.check_surfaces(delta)

func physics_update_mechanics(delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	if is_electrified:
		_check_and_apply_magnetic_attraction(delta)
	else:
		if is_magnetized_to_ceiling:
			rpc_set_magnetized_to_ceiling.rpc(false)

func _check_and_apply_magnetic_attraction(delta: float) -> void:
	var ceil_mat := _surface_detector.current_ceiling_material
	var is_magnetic_surface := (ceil_mat != null and ceil_mat.is_magnetic)

	var overhead_ray := _surface_detector.get_node_or_null("OverheadMaterialRay") as RayCast3D
	
	if is_magnetic_surface and overhead_ray and overhead_ray.is_colliding():
		var col_point := overhead_ray.get_collision_point()
		var dist_to_ceiling := col_point.y - player.global_position.y

		# Smooth, floaty magnetic attraction upwards toward magnetic ceiling within 5.5 meters
		if dist_to_ceiling > 0.0 and dist_to_ceiling < 5.5:
			var target_pull_speed := 8.0
			player.velocity.y = lerpf(player.velocity.y, target_pull_speed, 5.0 * delta)

			# Snap to ceiling magnetic crawl state smoothly when close enough
			if dist_to_ceiling <= 3.0:
				if not is_magnetized_to_ceiling:
					rpc_set_magnetized_to_ceiling.rpc(true)
					if AudioManager:
						AudioManager.play_sfx_3d("magnetic_attach", player.global_position, 30.0)

				# Position player collision shape smoothly below ceiling
				target_ceiling_y = col_point.y - 2.4
				player.global_position.y = lerpf(player.global_position.y, target_ceiling_y, 8.0 * delta)
				player.velocity.y = 0.0
	else:
		if is_magnetized_to_ceiling:
			rpc_set_magnetized_to_ceiling.rpc(false)
			if AudioManager:
				AudioManager.play_sfx_3d("magnetic_detach", player.global_position, 25.0)

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	# Press jump while clung to metal ceiling to release/drop down
	if is_magnetized_to_ceiling and event.is_action_pressed("jump"):
		rpc_set_magnetized_to_ceiling.rpc(false)
		player.velocity.y = -5.0
		if AudioManager:
			AudioManager.play_sfx_3d("magnetic_detach", player.global_position, 25.0)

func is_movement_blocked() -> bool:
	return false

func _set_upside_down(upside_down: bool) -> void:
	if not player:
		return

	if upside_down:
		if player.mesh_instance:
			player.mesh_instance.rotation_degrees.x = 0.0
			player.mesh_instance.rotation_degrees.y = 0.0
			player.mesh_instance.rotation_degrees.z = 180.0
			player.mesh_instance.position.y = 2.4
	else:
		if player.mesh_instance:
			player.mesh_instance.rotation_degrees.x = 0.0
			player.mesh_instance.rotation_degrees.y = 0.0
			player.mesh_instance.rotation_degrees.z = 0.0
			player.mesh_instance.position.y = 0.0

func _update_spark_visuals() -> void:
	if _electric_light:
		if is_electrified:
			var base_energy := (static_charge / MAX_STATIC_CHARGE) * 3.2
			_electric_light.light_energy = base_energy + randf_range(-0.4, 0.4) # Realistic electric arc flicker!
			_electric_light.light_color = Color(0.25, 0.85 + randf_range(-0.1, 0.1), 1.0)
		else:
			_electric_light.light_energy = lerpf(_electric_light.light_energy, 0.0, 0.2)

	if _spark_particles:
		_spark_particles.emitting = is_electrified

	if _plasma_particles:
		_plasma_particles.emitting = is_electrified
