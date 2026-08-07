class_name InflationSystem
extends Node

## Controller for "Balloon Inflation & Tethering" Mega-Mechanic:
## Supports BOTH Thin Players AND DummyNPC Mannequins!
## 1. Fat grabs physical 3D hose from ground [F].
## 2. End 1 -> Fat's mouth, End 2 -> Brass Nozzle in Fat's right hand.
## 3. Fat walks to Thin or DummyNPC mannequin and connects nozzle [F].
## 4. QTE Rhythm Pump mini-game inflates target into a floating balloon!
## 5. Fat walks freely on the ground holding the long 8-meter tether leash, guiding Thin/DummyNPC above him!

signal inflation_progress_changed(progress: float)
signal balloon_mode_changed(active: bool)

var player: Player
var tether_partner: Node3D # Can be Player OR DummyNPC!

var is_carrying_hose: bool = false
var hose_station: InflationPumpStation = null
var is_inflating: bool = false
var is_balloon_mode: bool = false
var inflation_progress: float = 0.0

# QTE Rhythm Mini-game state
var qte_cursor_pos: float = 0.0
var qte_cursor_dir: float = 1.0
var qte_speed: float = 1.6
var qte_zone_min: float = 0.38
var qte_zone_max: float = 0.62

# 3D Volumetric Tether Rope Renderer (8-meter long tether leash!)
var _rope_mesh_instance: MeshInstance3D
var _rope_material: StandardMaterial3D

# VFX
var _air_puff_particles: GPUParticles3D


func setup(p: Player) -> void:
	player = p
	_setup_3d_rope_renderer()
	_setup_vfx()

func _setup_3d_rope_renderer() -> void:
	_rope_mesh_instance = MeshInstance3D.new()
	_rope_mesh_instance.name = "TetherRopeMesh"
	_rope_mesh_instance.top_level = true

	_rope_material = StandardMaterial3D.new()
	_rope_material.albedo_color = Color(0.92, 0.65, 0.15, 1.0) # Golden Tether Rope
	_rope_material.roughness = 0.5
	_rope_mesh_instance.material_override = _rope_material
	_rope_mesh_instance.hide()

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

	# 2. Draw 3D Tether Rope between Fat and Target (Player or DummyNPC)
	_update_3d_tether_rope()

	# 3. Handle Floating Balloon Flying Physics
	_update_balloon_physics(delta)

func _update_3d_tether_rope() -> void:
	if not is_balloon_mode or not tether_partner or not is_instance_valid(tether_partner):
		_rope_mesh_instance.hide()
		return

	var start_p: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var end_p: Vector3 = tether_partner.global_position + Vector3(0, 0.3, 0)

	var pts: Array[Vector3] = []
	var segs: int = 16
	var sag: float = 0.4

	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var p: Vector3 = start_p.lerp(end_p, t)
		p.y -= sin(t * PI) * sag
		pts.append(p)

	_render_volumetric_tube(_rope_mesh_instance, pts, 0.04, 8)
	_rope_mesh_instance.show()

func _render_volumetric_tube(mesh_inst: MeshInstance3D, points: Array[Vector3], radius: float, sides: int) -> void:
	if points.size() < 2:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_verts: Array[Array] = []

	for i in range(points.size()):
		var p: Vector3 = points[i]
		var fwd: Vector3 = Vector3.FORWARD
		if i < points.size() - 1:
			fwd = (points[i + 1] - p).normalized()
		elif i > 0:
			fwd = (p - points[i - 1]).normalized()

		var right: Vector3 = fwd.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.001:
			right = Vector3.RIGHT
		var up: Vector3 = right.cross(fwd).normalized()

		var ring: Array[Vector3] = []
		for s in range(sides):
			var angle: float = (float(s) / float(sides)) * TAU
			var offset: Vector3 = right * (cos(angle) * radius) + up * (sin(angle) * radius)
			ring.append(p + offset)
		ring_verts.append(ring)

	for i in range(points.size() - 1):
		var r1: Array = ring_verts[i]
		var r2: Array = ring_verts[i + 1]

		for s in range(sides):
			var next_s: int = (s + 1) % sides
			var v1: Vector3 = r1[s]
			var v2: Vector3 = r1[next_s]
			var v3: Vector3 = r2[next_s]
			var v4: Vector3 = r2[s]

			st.set_normal((v2 - v1).cross(v4 - v1).normalized())
			st.add_vertex(v1)
			st.add_vertex(v2)
			st.add_vertex(v4)

			st.set_normal((v3 - v2).cross(v4 - v2).normalized())
			st.add_vertex(v2)
			st.add_vertex(v3)
			st.add_vertex(v4)

	mesh_inst.mesh = st.commit()

func _update_balloon_physics(delta: float) -> void:
	if not is_balloon_mode or not tether_partner or not is_instance_valid(tether_partner):
		return

	# --- FAT WALKS FREELY ON GROUND (Zero vertical pull on Fat!) ---
	# Fat stays on ground and guides/drags Thin / DummyNPC balloon above him!
	var target_pos: Vector3 = tether_partner.global_position
	var fat_pos: Vector3 = player.global_position

	# 1. Target (Thin or DummyNPC) floats 7.5 meters high into the air!
	var target_height: float = fat_pos.y + 7.5
	if tether_partner is Player:
		var p: Player = tether_partner as Player
		if p.selected_character_id.to_lower() == "thin":
			if p.global_position.y < target_height and not p.is_on_ceiling():
				p.velocity.y = lerpf(p.velocity.y, 3.5, 5.0 * delta)
			if p.mesh_instance:
				p.mesh_instance.scale = Vector3(2.3, 2.3, 2.3)
				p.mesh_instance.position.y = 1.15
	elif tether_partner is DummyNPC:
		var dummy: DummyNPC = tether_partner as DummyNPC
		if dummy.global_position.y < target_height:
			dummy.velocity.y = lerpf(dummy.velocity.y, 3.5, 5.0 * delta)
		if dummy.mesh_instance:
			dummy.mesh_instance.scale = Vector3(2.3, 2.3, 2.3)
			dummy.mesh_instance.position.y = 1.15

	# 2. Horizontal 8-Meter Tether Leash: Fat on ground DRAGS balloon above!
	var horiz_dist: float = Vector2(target_pos.x - fat_pos.x, target_pos.z - fat_pos.z).length()
	if horiz_dist > 6.0:
		var drag_dir := Vector3(fat_pos.x - target_pos.x, 0, fat_pos.z - target_pos.z).normalized()
		var pull_force: float = (horiz_dist - 6.0) * 8.0

		if tether_partner is Player:
			var p: Player = tether_partner as Player
			p.velocity.x += drag_dir.x * pull_force * delta
			p.velocity.z += drag_dir.z * pull_force * delta
		elif tether_partner is DummyNPC:
			var dummy: DummyNPC = tether_partner as DummyNPC
			dummy.velocity.x += drag_dir.x * pull_force * delta
			dummy.velocity.z += drag_dir.z * pull_force * delta

# =================== HOSE GRAB / DROP ===================

func try_grab_hose_from_station() -> bool:
	if is_carrying_hose or is_inflating or is_balloon_mode:
		return false
	if not player or player.selected_character_id.to_lower() != "fat":
		return false

	var stations := player.get_tree().get_nodes_in_group("inflation_stations")
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
		print("🎈 Fat grabbed hose! End 1 -> Mouth, End 2 -> Brass Nozzle in Hand!")
		return true

	return false

func _find_stations_recursive(node: Node, result: Array) -> void:
	if node is InflationPumpStation:
		result.append(node)
	for child in node.get_children():
		_find_stations_recursive(child, result)

# =================== RPC: CONNECT & INFLATE ===================

@rpc("any_peer", "call_local", "reliable")
func rpc_start_inflation(target_path: NodePath) -> void:
	var target: Node3D = get_node_or_null(target_path) as Node3D
	if not target:
		return

	is_inflating = true
	is_carrying_hose = false
	tether_partner = target
	inflation_progress = 0.15
	qte_cursor_pos = 0.0
	qte_cursor_dir = 1.0

	print("🎈 HOSE CONNECTED to %s! Pumping started!" % target.name)

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

	# Swell target mesh (Player or DummyNPC)
	var target_mesh: MeshInstance3D = null
	if tether_partner:
		target_mesh = tether_partner.get_node_or_null("MeshInstance3D") as MeshInstance3D

	if target_mesh:
		var target_s: float = lerpf(1.0, 2.3, inflation_progress)
		var tw := tether_partner.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(target_mesh, "scale", Vector3(target_s, target_s, target_s), 0.12)

	if inflation_progress >= 1.0:
		rpc_activate_balloon_mode.rpc()

@rpc("any_peer", "call_local", "reliable")
func rpc_activate_balloon_mode() -> void:
	is_inflating = false
	is_balloon_mode = true
	balloon_mode_changed.emit(true)

	if tether_partner and tether_partner is Player:
		var partner_infl := tether_partner.get_node_or_null("InflationSystem") as InflationSystem
		if partner_infl:
			partner_infl.is_balloon_mode = true
			partner_infl.tether_partner = player

	_trigger_puff_vfx()
	print("🎈 BALLOON MODE ACTIVATED! Long 8m tether leash active!")

@rpc("any_peer", "call_local", "reliable")
func rpc_stop_inflation() -> void:
	is_inflating = false
	is_balloon_mode = false
	is_carrying_hose = false
	inflation_progress = 0.0

	if tether_partner:
		var target_mesh: MeshInstance3D = tether_partner.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if target_mesh:
			target_mesh.scale = Vector3.ONE
			target_mesh.position.y = 0.9

		if tether_partner is Player:
			var partner_infl := tether_partner.get_node_or_null("InflationSystem") as InflationSystem
			if partner_infl:
				partner_infl.is_balloon_mode = false
		tether_partner = null

	if hose_station and is_instance_valid(hose_station):
		hose_station.rpc_return_hose.rpc()
	hose_station = null

	balloon_mode_changed.emit(false)
	print("🎈 DEFLATED.")

func _trigger_puff_vfx() -> void:
	if _air_puff_particles and tether_partner:
		_air_puff_particles.global_position = tether_partner.global_position + Vector3(0, 1.0, 0)
		_air_puff_particles.restart()
		_air_puff_particles.emitting = true
