class_name InflationPumpStation
extends StaticBody3D

## Interactive Inflation Pump Station with a PHYSICAL 3D hose lying on the ground.
## Flow:
## 1. Fat walks to the hose lying on the ground and presses [E] to GRAB it.
## 2. Fat carries the hose (it stretches from the compressor to Fat).
## 3. Fat walks to Thin and presses [E] to CONNECT the hose and start pumping.

signal hose_grabbed(by_player: Player)
signal hose_connected(fat: Player, thin: Player)

@export var interaction_radius: float = 2.5

var is_hose_taken: bool = false
var hose_carrier: Player = null

# 3D Visual nodes
var _compressor_mesh: MeshInstance3D
var _hose_ground_node: Node3D  # The hose lying on the ground (pickup target)
var _hose_nozzle_mesh: MeshInstance3D
var _hose_coil_mesh: MeshInstance3D
var _hose_segments: Array[MeshInstance3D] = []  # Segmented hose pieces on ground
var _platform_mesh: MeshInstance3D
var _prompt_label: Label3D
var _title_label: Label3D
var _hose_pickup_area: Area3D
var _compressor_material: StandardMaterial3D
var _hose_material: StandardMaterial3D

# Stretched hose from compressor to carrier
var _stretched_rope: MeshInstance3D
var _stretched_mesh: ImmediateMesh

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_build_compressor_visuals()
	_build_hose_on_ground()
	_build_hose_pickup_area()
	_build_labels()

# =================== COMPRESSOR UNIT ===================

func _build_compressor_visuals() -> void:
	# --- Platform base (dark metal plate) ---
	_platform_mesh = MeshInstance3D.new()
	_platform_mesh.name = "PlatformMesh"
	var plat_box := BoxMesh.new()
	plat_box.size = Vector3(3.0, 0.12, 3.0)
	var plat_mat := StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.25, 0.28, 0.32, 1.0)
	plat_mat.metallic = 0.6
	plat_mat.roughness = 0.35
	plat_box.material = plat_mat
	_platform_mesh.mesh = plat_box
	_platform_mesh.position = Vector3(0, 0.06, 0)
	add_child(_platform_mesh)

	# Platform collision
	var plat_col := CollisionShape3D.new()
	var plat_shape := BoxShape3D.new()
	plat_shape.size = Vector3(3.0, 0.12, 3.0)
	plat_col.shape = plat_shape
	plat_col.position = Vector3(0, 0.06, 0)
	add_child(plat_col)

	# --- Compressor body (cylindrical tank) ---
	_compressor_mesh = MeshInstance3D.new()
	_compressor_mesh.name = "CompressorTank"
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.45
	cyl_mesh.bottom_radius = 0.5
	cyl_mesh.height = 1.2
	_compressor_material = StandardMaterial3D.new()
	_compressor_material.albedo_color = Color(0.85, 0.25, 0.15, 1.0)
	_compressor_material.metallic = 0.7
	_compressor_material.roughness = 0.25
	cyl_mesh.material = _compressor_material
	_compressor_mesh.mesh = cyl_mesh
	_compressor_mesh.position = Vector3(-0.8, 0.72, 0)
	add_child(_compressor_mesh)

	# --- Pressure gauge (small sphere on top) ---
	var gauge := MeshInstance3D.new()
	gauge.name = "PressureGauge"
	var gauge_mesh := SphereMesh.new()
	gauge_mesh.radius = 0.12
	gauge_mesh.height = 0.24
	var gauge_mat := StandardMaterial3D.new()
	gauge_mat.albedo_color = Color(0.9, 0.9, 0.85, 1.0)
	gauge_mat.metallic = 0.8
	gauge_mesh.material = gauge_mat
	gauge.mesh = gauge_mesh
	gauge.position = Vector3(-0.8, 1.45, 0.25)
	add_child(gauge)

	# --- Valve handle on the tank ---
	var valve := MeshInstance3D.new()
	valve.name = "ValveHandle"
	var valve_mesh := TorusMesh.new()
	valve_mesh.inner_radius = 0.06
	valve_mesh.outer_radius = 0.15
	var valve_mat := StandardMaterial3D.new()
	valve_mat.albedo_color = Color(0.3, 0.3, 0.35, 1.0)
	valve_mat.metallic = 0.85
	valve_mesh.material = valve_mat
	valve.mesh = valve_mesh
	valve.position = Vector3(-0.8, 1.4, -0.3)
	valve.rotation_degrees = Vector3(0, 0, 90)
	add_child(valve)

	# --- Hose outlet pipe from compressor (short stub) ---
	var outlet := MeshInstance3D.new()
	outlet.name = "HoseOutlet"
	var out_cyl := CylinderMesh.new()
	out_cyl.top_radius = 0.06
	out_cyl.bottom_radius = 0.07
	out_cyl.height = 0.4
	var out_mat := StandardMaterial3D.new()
	out_mat.albedo_color = Color(0.4, 0.42, 0.45, 1.0)
	out_mat.metallic = 0.7
	out_cyl.material = out_mat
	outlet.mesh = out_cyl
	outlet.position = Vector3(-0.35, 0.6, 0)
	outlet.rotation_degrees = Vector3(0, 0, 90)
	add_child(outlet)

	# --- Stretched hose renderer (compressor -> carrier) ---
	_stretched_mesh = ImmediateMesh.new()
	_stretched_rope = MeshInstance3D.new()
	_stretched_rope.name = "StretchedHose"
	_stretched_rope.top_level = true
	_stretched_rope.mesh = _stretched_mesh
	var rope_mat := StandardMaterial3D.new()
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_mat.albedo_color = Color(0.15, 0.75, 0.9, 1.0)
	_stretched_rope.material_override = rope_mat
	_stretched_rope.hide()
	add_child(_stretched_rope)

# =================== 3D HOSE ON THE GROUND ===================

func _build_hose_on_ground() -> void:
	_hose_material = StandardMaterial3D.new()
	_hose_material.albedo_color = Color(0.15, 0.75, 0.9, 1.0)
	_hose_material.roughness = 0.65

	_hose_ground_node = Node3D.new()
	_hose_ground_node.name = "HoseOnGround"
	add_child(_hose_ground_node)

	# Hose is a series of short cylinders laid out in a winding path on the ground
	# Starting from the compressor outlet, curving on the floor

	var hose_path: Array[Vector3] = [
		Vector3(-0.1, 0.18, 0),
		Vector3(0.3, 0.18, 0.15),
		Vector3(0.7, 0.18, -0.1),
		Vector3(1.0, 0.18, 0.2),
		Vector3(1.3, 0.18, 0.0),
		Vector3(1.6, 0.18, 0.25),
		Vector3(1.9, 0.18, 0.1),
		Vector3(2.2, 0.18, -0.15),
		Vector3(2.5, 0.18, 0.1),
	]

	for i in range(hose_path.size() - 1):
		var seg_start: Vector3 = hose_path[i]
		var seg_end: Vector3 = hose_path[i + 1]
		var seg_mid: Vector3 = (seg_start + seg_end) * 0.5
		var seg_len: float = seg_start.distance_to(seg_end)

		var seg := MeshInstance3D.new()
		seg.name = "HoseSeg_%d" % i
		var seg_cyl := CylinderMesh.new()
		seg_cyl.top_radius = 0.045
		seg_cyl.bottom_radius = 0.045
		seg_cyl.height = seg_len
		seg_cyl.material = _hose_material
		seg.mesh = seg_cyl
		seg.position = seg_mid

		# Rotate cylinder to align between two points
		var dir := (seg_end - seg_start).normalized()
		seg.rotation = Vector3(0, 0, -acos(dir.dot(Vector3.UP)))
		if absf(dir.x) > 0.001 or absf(dir.z) > 0.001:
			seg.look_at(seg.global_position + dir, Vector3.UP)
			seg.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

		_hose_segments.append(seg)
		_hose_ground_node.add_child(seg)

	# --- Nozzle at the end of the hose (the part Fat grabs) ---
	_hose_nozzle_mesh = MeshInstance3D.new()
	_hose_nozzle_mesh.name = "HoseNozzle"
	var nozzle_cyl := CylinderMesh.new()
	nozzle_cyl.top_radius = 0.035
	nozzle_cyl.bottom_radius = 0.065
	nozzle_cyl.height = 0.25
	var nozzle_mat := StandardMaterial3D.new()
	nozzle_mat.albedo_color = Color(0.9, 0.85, 0.2, 1.0)  # Yellow/gold nozzle tip
	nozzle_mat.metallic = 0.6
	nozzle_cyl.material = nozzle_mat
	_hose_nozzle_mesh.mesh = nozzle_cyl
	_hose_nozzle_mesh.position = Vector3(2.5, 0.3, 0.1)
	_hose_nozzle_mesh.rotation_degrees = Vector3(0, 0, 90)
	_hose_ground_node.add_child(_hose_nozzle_mesh)

	# --- Hose coil ring near the compressor ---
	_hose_coil_mesh = MeshInstance3D.new()
	_hose_coil_mesh.name = "HoseCoil"
	var coil_mesh := TorusMesh.new()
	coil_mesh.inner_radius = 0.2
	coil_mesh.outer_radius = 0.4
	coil_mesh.material = _hose_material
	_hose_coil_mesh.mesh = coil_mesh
	_hose_coil_mesh.position = Vector3(0.4, 0.16, -0.5)
	_hose_coil_mesh.rotation_degrees = Vector3(90, 0, 0)
	_hose_ground_node.add_child(_hose_coil_mesh)

# =================== INTERACTION AREA (near the nozzle) ===================

func _build_hose_pickup_area() -> void:
	_hose_pickup_area = Area3D.new()
	_hose_pickup_area.name = "HosePickupArea"
	_hose_pickup_area.collision_layer = 0
	_hose_pickup_area.collision_mask = 2  # Players layer

	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = interaction_radius
	area_col.shape = area_shape
	# Area centered near the nozzle end of the hose
	area_col.position = Vector3(2.5, 0.5, 0.1)
	_hose_pickup_area.add_child(area_col)
	add_child(_hose_pickup_area)

# =================== LABELS ===================

func _build_labels() -> void:
	_title_label = Label3D.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "🎈 СТАНЦИЯ НАКАЧКИ"
	_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title_label.position = Vector3(0, 2.6, 0)
	_title_label.font_size = 32
	_title_label.outline_size = 10
	_title_label.modulate = Color(0.2, 0.9, 1.0, 1.0)
	add_child(_title_label)

	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = "💨 [E] ВЗЯТЬ ШЛАНГ"
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.position = Vector3(2.5, 1.2, 0.1)
	_prompt_label.font_size = 24
	_prompt_label.outline_size = 8
	_prompt_label.modulate = Color(1.0, 0.95, 0.4, 1.0)
	_prompt_label.hide()
	add_child(_prompt_label)

# =================== PROCESS ===================

func _process(_delta: float) -> void:
	_update_prompt_visibility()
	_update_stretched_hose()

func _update_prompt_visibility() -> void:
	if not _hose_pickup_area or not _prompt_label:
		return

	if is_hose_taken:
		_prompt_label.hide()
		return

	var show := false
	var bodies := _hose_pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat" and p.is_multiplayer_authority():
				show = true
				break

	_prompt_label.visible = show

func _update_stretched_hose() -> void:
	if not _stretched_mesh or not _stretched_rope:
		return

	_stretched_mesh.clear_surfaces()

	if not is_hose_taken or not hose_carrier or not is_instance_valid(hose_carrier):
		_stretched_rope.hide()
		return

	_stretched_rope.show()

	# Draw hose from compressor outlet to the carrier's hand position
	var compressor_outlet: Vector3 = global_position + Vector3(-0.15, 0.6, 0)
	var carrier_hand: Vector3 = hose_carrier.global_position + Vector3(0, 0.8, 0)

	_stretched_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = 16
	var sag: float = 0.8

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var pos: Vector3 = compressor_outlet.lerp(carrier_hand, t)
		# Catenary sag
		pos.y -= sin(t * PI) * sag * (1.0 - t * 0.5)
		_stretched_mesh.surface_add_vertex(pos)

	_stretched_mesh.surface_end()

# =================== RPC: GRAB / RETURN HOSE ===================

@rpc("any_peer", "call_local", "reliable")
func rpc_grab_hose(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p or is_hose_taken:
		return

	is_hose_taken = true
	hose_carrier = p

	# Hide hose on ground, show stretched hose
	if _hose_ground_node:
		_hose_ground_node.hide()

	print("🎈 HOSE GRABBED by %s!" % p.name)
	hose_grabbed.emit(p)

@rpc("any_peer", "call_local", "reliable")
func rpc_return_hose() -> void:
	is_hose_taken = false
	hose_carrier = null

	# Show hose back on ground
	if _hose_ground_node:
		_hose_ground_node.show()

	_stretched_rope.hide()
	print("🎈 HOSE RETURNED to station.")

func get_hose_nozzle_world_pos() -> Vector3:
	return global_position + Vector3(2.5, 0.3, 0.1)
