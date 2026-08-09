class_name ThinMechanics
extends BaseCharacterMechanics

## Dedicated Controller for "Thin / Худой" character mechanics:
## 1. Static Electrification (Наэлектризовывание): Rubbing against wool curtains or carpet floors charges Thin.
## 2. Magnetism (Механика Магнита и Скрепки): Electrified Thin is magnetically pulled toward metal ceilings and clings upside down (FEET ON CEILING) to crawl over chasms.
## 3. Discharging: Discharged when Fat flips a Breaker switch or when touching a Grounding plate.

signal static_charge_changed(current_charge: float, max_charge: float)
signal electrification_changed(is_electrified: bool)
signal magnetic_attachment_changed(is_attached: bool)

const MAX_STATIC_CHARGE: float = 100.0
const CHARGE_THRESHOLD: float = 15.0
const CHARGE_DECAY_RATE: float = 0.0 ## Charge stays persistent until discharged by lever or grounded plate

@export var static_charge: float = 0.0:
	set(val):
		var prev_elec := is_electrified
		static_charge = clampf(val, 0.0, MAX_STATIC_CHARGE)
		is_electrified = (static_charge >= CHARGE_THRESHOLD)
		if is_electrified != prev_elec:
			electrification_changed.emit(is_electrified)
			_update_spark_visuals()
		static_charge_changed.emit(static_charge, MAX_STATIC_CHARGE)

var is_electrified: bool = false
var is_magnetized_to_ceiling: bool = false
var target_ceiling_y: float = 0.0

var _spark_particles: GPUParticles3D = null
var _electric_light: OmniLight3D = null
var _surface_detector: SurfaceDetectorComponent = null
var _crackle_sfx_timer: float = 0.0

func _ready() -> void:
	super._ready()

func setup(p: CharacterBody3D) -> void:
	super.setup(p)
	_setup_visual_and_audio_effects()
	_setup_surface_detector()

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
func rpc_discharge() -> void:
	discharge()

func discharge() -> void:
	var was_attached := is_magnetized_to_ceiling
	static_charge = 0.0
	is_magnetized_to_ceiling = false
	magnetic_attachment_changed.emit(false)
	_set_upside_down(false)

	if player:
		if was_attached:
			player.velocity.y = -5.0

		if AudioManager:
			AudioManager.play_sfx_3d("discharge_zap", player.global_position, 40.0, 3.0)

func update_mechanics(delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	_surface_detector.check_surfaces(delta)
	_update_spark_visuals()
	_set_upside_down(is_magnetized_to_ceiling)

func physics_update_mechanics(delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	if is_electrified:
		_check_and_apply_magnetic_attraction(delta)
	else:
		if is_magnetized_to_ceiling:
			is_magnetized_to_ceiling = false
			magnetic_attachment_changed.emit(false)
			_set_upside_down(false)

func _check_and_apply_magnetic_attraction(delta: float) -> void:
	var ceil_mat := _surface_detector.current_ceiling_material
	var is_metal_ceiling := (ceil_mat != null and ceil_mat.is_metallic)

	var overhead_ray := _surface_detector.get_node_or_null("OverheadMaterialRay") as RayCast3D
	
	if (is_metal_ceiling or (overhead_ray and overhead_ray.is_colliding())) and overhead_ray.is_colliding():
		var col_point := overhead_ray.get_collision_point()
		var dist_to_ceiling := col_point.y - player.global_position.y

		# Strong magnetic pull upwards toward metal ceiling within 6.0 meters
		if dist_to_ceiling > 0.0 and dist_to_ceiling < 6.0:
			var pull_accel := 18.0
			player.velocity.y = lerpf(player.velocity.y, pull_accel, 12.0 * delta)

			# Snap to ceiling magnetic crawl state when close enough
			if dist_to_ceiling <= 3.2:
				if not is_magnetized_to_ceiling:
					is_magnetized_to_ceiling = true
					magnetic_attachment_changed.emit(true)
					_set_upside_down(true)
					if AudioManager:
						AudioManager.play_sfx_3d("magnetic_attach", player.global_position, 30.0)

				# Position player collision shape cleanly below ceiling (zero penetration)
				target_ceiling_y = col_point.y - 2.4
				player.global_position.y = lerpf(player.global_position.y, target_ceiling_y, 22.0 * delta)
				player.velocity.y = 0.0
	else:
		if is_magnetized_to_ceiling:
			is_magnetized_to_ceiling = false
			magnetic_attachment_changed.emit(false)
			_set_upside_down(false)
			if AudioManager:
				AudioManager.play_sfx_3d("magnetic_detach", player.global_position, 25.0)

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	# Press jump while clung to metal ceiling to release/drop down
	if is_magnetized_to_ceiling and event.is_action_pressed("jump"):
		is_magnetized_to_ceiling = false
		magnetic_attachment_changed.emit(false)
		_set_upside_down(false)
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
			player.mesh_instance.rotation_degrees.x = 180.0
			player.mesh_instance.rotation_degrees.y = 0.0
			player.mesh_instance.rotation_degrees.z = 0.0
			player.mesh_instance.position.y = 2.4
	else:
		if player.mesh_instance:
			player.mesh_instance.rotation_degrees.x = 0.0
			player.mesh_instance.rotation_degrees.y = 0.0
			player.mesh_instance.rotation_degrees.z = 0.0
			player.mesh_instance.position.y = 0.0

func _update_spark_visuals() -> void:
	if _electric_light:
		var target_energy := (static_charge / MAX_STATIC_CHARGE) * 2.5 if is_electrified else 0.0
		_electric_light.light_energy = lerpf(_electric_light.light_energy, target_energy, 0.1)
