class_name InflationSystem
extends Node

## Comprehensive Controller for "Balloon Inflation & Tethering" Mega-Mechanic:
## 1. Fat goes to the pump station and grabs the 3D hose from the ground [E].
## 2. Fat carries the hose to Thin (visible stretched hose from compressor).
## 3. Fat connects the hose to Thin [E] -> starts QTE Rhythm Pump mini-game.
## 4. Successful pumps inflate Thin into a floating balloon.
## 5. Fat holds Thin by a tether rope and uses him as a hot air balloon!

signal inflation_progress_changed(progress: float)
signal balloon_mode_changed(active: bool)

var player: Player
var tether_partner: Player

var is_carrying_hose: bool = false
var hose_station: InflationPumpStation = null  # Reference to the station we grabbed hose from
var is_inflating: bool = false
var is_balloon_mode: bool = false
var inflation_progress: float = 0.0

# QTE Rhythm Mini-game state
var qte_cursor_pos: float = 0.0
var qte_cursor_dir: float = 1.0
var qte_speed: float = 1.6
var qte_zone_min: float = 0.38
var qte_zone_max: float = 0.62

# 3D Tether Rope Renderer (for balloon mode)
var _rope_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _rope_material: StandardMaterial3D

# Particles
var _air_puff_particles: GPUParticles3D


func setup(p: Player) -> void:
	player = p
	_setup_3d_rope_renderer()
	_setup_vfx()

func _setup_3d_rope_renderer() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_rope_mesh_instance = MeshInstance3D.new()
	_rope_mesh_instance.name = "TetherRopeMesh"
	_rope_mesh_instance.top_level = true
	_rope_mesh_instance.mesh = _immediate_mesh

	_rope_material = StandardMaterial3D.new()
	_rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope_material.albedo_color = Color(0.92, 0.65, 0.15, 1.0)
	_rope_mesh_instance.material_override = _rope_material

	add_child(_rope_mesh_instance)

func _setup_vfx() -> void:
	_air_puff_particles = GPUParticles3D.new()
	_air_puff_particles.name = "AirPuffParticles"
	_air_puff_particles.amount = 40
	_air_puff_particles.lifetime = 0.6
	_air_puff_particles.one_shot = true
	_air_puff_particles.explosiveness = 0.9
	_air_puff_particles.emitting = false

	var mat_proc := ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat_proc.emission_sphere_radius = 0.6
	mat_proc.direction = Vector3(0, 1, 0)
	mat_proc.spread = 180.0
	mat_proc.initial_velocity_min = 2.0
	mat_proc.initial_velocity_max = 6.0
	mat_proc.gravity = Vector3(0, -2.0, 0)
	mat_proc.scale_min = 0.05
	mat_proc.scale_max = 0.25
	mat_proc.color = Color(0.9, 0.95, 1.0, 0.7)

	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.6)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.material = draw_mat
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.2

	_air_puff_particles.process_material = mat_proc
	_air_puff_particles.draw_pass_1 = sphere_mesh
	add_child(_air_puff_particles)

func _process(delta: float) -> void:
	if not player:
		return

	# 1. QTE Cursor Movement when Fat is inflating
	if is_inflating and player.is_multiplayer_authority():
		qte_cursor_pos += qte_cursor_dir * qte_speed * delta
		if qte_cursor_pos >= 1.0:
			qte_cursor_pos = 1.0
			qte_cursor_dir = -1.0
		elif qte_cursor_pos <= 0.0:
			qte_cursor_pos = 0.0
			qte_cursor_dir = 1.0

	# 2. Draw 3D Tether Rope between Fat and Thin (only in balloon mode)
	_update_3d_rope_mesh()

	# 3. Handle Floating Balloon Flying Mechanics
	_update_balloon_physics(delta)

func _update_3d_rope_mesh() -> void:
	if not _immediate_mesh:
		return

	_immediate_mesh.clear_surfaces()

	if not is_balloon_mode or not tether_partner or not is_instance_valid(tether_partner):
		_rope_mesh_instance.hide()
		return

	_rope_mesh_instance.show()
	_rope_material.albedo_color = Color(0.92, 0.65, 0.15, 1.0)

	var start_p: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var end_p: Vector3 = tether_partner.global_position + Vector3(0, 0.3, 0)

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = 12
	var sag: float = 0.2

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var pos: Vector3 = start_p.lerp(end_p, t)
		pos.y -= sin(t * PI) * sag
		_immediate_mesh.surface_add_vertex(pos)

	_immediate_mesh.surface_end()

func _update_balloon_physics(delta: float) -> void:
	if not is_balloon_mode or not player:
		return

	var is_thin := (player.selected_character_id.to_lower() == "thin")

	if is_thin:
		if not player.is_on_ceiling():
			player.velocity.y = lerpf(player.velocity.y, 2.8, 6.0 * delta)

		if player.mesh_instance:
			player.mesh_instance.scale = Vector3(2.3, 2.3, 2.3)
			player.mesh_instance.position.y = 1.15

		if player.collision_shape:
			var balloon_cap := CapsuleShape3D.new()
			balloon_cap.radius = 1.1
			balloon_cap.height = 2.2
			player.collision_shape.shape = balloon_cap
			player.collision_shape.position.y = 1.15

	if tether_partner and is_instance_valid(tether_partner):
		var is_partner_fat := (tether_partner.selected_character_id.to_lower() == "fat")
		if is_thin and is_partner_fat:
			var target_fat_pos: Vector3 = player.global_position - Vector3(0, 2.2, 0)
			var dist: float = tether_partner.global_position.distance_to(target_fat_pos)
			if dist > 0.4:
				var pull_dir: Vector3 = (target_fat_pos - tether_partner.global_position).normalized()
				tether_partner.velocity = tether_partner.velocity.lerp(pull_dir * minf(dist * 6.0, 10.0), 12.0 * delta)

# =================== HOSE GRAB / DROP ===================

func try_grab_hose_from_station() -> bool:
	if is_carrying_hose or is_inflating or is_balloon_mode:
		return false
	if not player or player.selected_character_id.to_lower() != "fat":
		return false

	# Find nearest pump station
	var stations := player.get_tree().get_nodes_in_group("inflation_stations")
	# Fallback: search by class
	if stations.is_empty():
		for node in player.get_tree().root.get_children():
			_find_stations_recursive(node, stations)

	var closest_station: InflationPumpStation = null
	var closest_dist: float = 4.0

	for s in stations:
		if s is InflationPumpStation:
			var station: InflationPumpStation = s as InflationPumpStation
			if station.is_hose_taken:
				continue
			var nozzle_pos: Vector3 = station.get_hose_nozzle_world_pos()
			var dist: float = player.global_position.distance_to(nozzle_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_station = station

	if closest_station:
		hose_station = closest_station
		closest_station.rpc_grab_hose.rpc(player.get_path())
		is_carrying_hose = true
		print("🎈 Fat grabbed hose from pump station!")
		return true

	return false

func _find_stations_recursive(node: Node, result: Array) -> void:
	if node is InflationPumpStation:
		result.append(node)
	for child in node.get_children():
		_find_stations_recursive(child, result)

func drop_hose() -> void:
	if not is_carrying_hose:
		return
	is_carrying_hose = false
	if hose_station and is_instance_valid(hose_station):
		hose_station.rpc_return_hose.rpc()
	hose_station = null

# =================== RPC: CONNECT HOSE TO THIN & INFLATE ===================

@rpc("any_peer", "call_local", "reliable")
func rpc_start_inflation(partner_path: NodePath) -> void:
	var partner: Player = get_node_or_null(partner_path) as Player
	if not partner:
		return

	is_inflating = true
	is_carrying_hose = false  # Hose is now connected, not "carried"
	tether_partner = partner
	inflation_progress = 0.15
	qte_cursor_pos = 0.0
	qte_cursor_dir = 1.0

	print("🎈 HOSE CONNECTED: %s plugged hose into %s! Start pumping!" % [player.name, partner.name])

@rpc("any_peer", "call_local", "reliable")
func rpc_perform_pump_qte(is_success: bool) -> void:
	if not is_inflating:
		return

	if is_success:
		inflation_progress = minf(1.0, inflation_progress + 0.25)
		_trigger_puff_vfx()
		print("🎯 PERFECT PUMP! Inflation: %.0f%%" % (inflation_progress * 100.0))
	else:
		inflation_progress = maxf(0.05, inflation_progress - 0.12)
		print("💨 PUMP MISSED! Inflation: %.0f%%" % (inflation_progress * 100.0))

	inflation_progress_changed.emit(inflation_progress)

	# Dynamic Mesh Swell preview
	if tether_partner and tether_partner.mesh_instance:
		var target_s: float = lerpf(1.0, 2.3, inflation_progress)
		var tw := tether_partner.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(tether_partner.mesh_instance, "scale", Vector3(target_s, target_s, target_s), 0.12)

	if inflation_progress >= 1.0:
		rpc_activate_balloon_mode.rpc()

@rpc("any_peer", "call_local", "reliable")
func rpc_activate_balloon_mode() -> void:
	is_inflating = false
	is_balloon_mode = true
	balloon_mode_changed.emit(true)

	if tether_partner:
		var partner_infl := tether_partner.get_node_or_null("InflationSystem") as InflationSystem
		if partner_infl:
			partner_infl.is_balloon_mode = true
			partner_infl.tether_partner = player

	_trigger_puff_vfx()
	print("🎈 BALLOON MODE ACTIVATED!")

@rpc("any_peer", "call_local", "reliable")
func rpc_stop_inflation() -> void:
	is_inflating = false
	is_balloon_mode = false
	is_carrying_hose = false
	inflation_progress = 0.0

	if tether_partner:
		if tether_partner.mesh_instance:
			tether_partner.mesh_instance.scale = Vector3.ONE
			tether_partner.mesh_instance.position.y = tether_partner.stand_height * 0.5

		var partner_infl := tether_partner.get_node_or_null("InflationSystem") as InflationSystem
		if partner_infl:
			partner_infl.is_balloon_mode = false
		tether_partner = null

	# Return hose to station
	if hose_station and is_instance_valid(hose_station):
		hose_station.rpc_return_hose.rpc()
	hose_station = null

	balloon_mode_changed.emit(false)
	print("🎈 DEFLATED. Hose returned to station.")

func _trigger_puff_vfx() -> void:
	if _air_puff_particles and tether_partner:
		_air_puff_particles.global_position = tether_partner.global_position + Vector3(0, 1.0, 0)
		_air_puff_particles.restart()
		_air_puff_particles.emitting = true
