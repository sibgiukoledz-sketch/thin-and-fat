class_name InflationPumpStation
extends StaticBody3D

## High-Quality Physical 3D Inflation Hose Object (Standalone Hose on Floor).
## Flow:
## 1. Fat walks up to the 3D hose on the floor and presses [F] to GRAB IT.
## 2. Fat carries the hose (3D flexible hose stretches from the hose reel to Fat).
## 3. Fat walks to Thin and presses [F] to CONNECT the hose and start pumping!

signal hose_grabbed(by_player: Player)
signal hose_connected(fat: Player, thin: Player)

@export var interaction_radius: float = 3.0

var is_hose_taken: bool = false
var hose_carrier: Player = null

# 3D Visual nodes for pure standalone hose
var _hose_ground_node: Node3D
var _hose_nozzle_mesh: MeshInstance3D
var _hose_coil_mesh: MeshInstance3D
var _hose_segments: Array[MeshInstance3D] = []
var _prompt_label: Label3D
var _title_label: Label3D
var _hose_pickup_area: Area3D
var _hose_material: StandardMaterial3D
var _brass_material: StandardMaterial3D

# Stretched hose from floor origin -> Fat's hand
var _stretched_rope: MeshInstance3D
var _stretched_mesh: ImmediateMesh

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_setup_materials()
	_build_3d_hose_visuals()
	_build_hose_pickup_area()
	_build_labels()

func _setup_materials() -> void:
	# Flexible industrial cyan/yellow rubber hose material
	_hose_material = StandardMaterial3D.new()
	_hose_material.albedo_color = Color(0.12, 0.78, 0.92, 1.0)
	_hose_material.roughness = 0.45
	_hose_material.metallic = 0.1

	# Polished brass nozzle connector material
	_brass_material = StandardMaterial3D.new()
	_brass_material.albedo_color = Color(0.95, 0.82, 0.22, 1.0)
	_brass_material.metallic = 0.85
	_brass_material.roughness = 0.2

func _build_3d_hose_visuals() -> void:
	_hose_ground_node = Node3D.new()
	_hose_ground_node.name = "StandaloneHose3D"
	add_child(_hose_ground_node)

	# --- 1. Hose Floor Mount Ring Base ---
	var mount := MeshInstance3D.new()
	mount.name = "HoseMountBase"
	var mount_mesh := CylinderMesh.new()
	mount_mesh.top_radius = 0.35
	mount_mesh.bottom_radius = 0.4
	mount_mesh.height = 0.1
	var mount_mat := StandardMaterial3D.new()
	mount_mat.albedo_color = Color(0.2, 0.22, 0.26, 1.0)
	mount_mat.metallic = 0.7
	mount_mesh.material = mount_mat
	mount.mesh = mount_mesh
	mount.position = Vector3(0, 0.05, 0)
	_hose_ground_node.add_child(mount)

	# Mount collision
	var mount_col := CollisionShape3D.new()
	var mount_shape := CylinderShape3D.new()
	mount_shape.radius = 0.4
	mount_shape.height = 0.1
	mount_col.shape = mount_shape
	mount_col.position = Vector3(0, 0.05, 0)
	add_child(mount_col)

	# --- 2. Coiled Rubber Hose on floor (2 layered rings) ---
	_hose_coil_mesh = MeshInstance3D.new()
	_hose_coil_mesh.name = "HoseCoilRing1"
	var coil1 := TorusMesh.new()
	coil1.inner_radius = 0.22
	coil1.outer_radius = 0.38
	coil1.material = _hose_material
	_hose_coil_mesh.mesh = coil1
	_hose_coil_mesh.position = Vector3(0, 0.12, 0)
	_hose_coil_mesh.rotation_degrees = Vector3(90, 0, 0)
	_hose_ground_node.add_child(_hose_coil_mesh)

	var coil2 := MeshInstance3D.new()
	coil2.name = "HoseCoilRing2"
	var coil2_mesh := TorusMesh.new()
	coil2_mesh.inner_radius = 0.18
	coil2_mesh.outer_radius = 0.34
	coil2_mesh.material = _hose_material
	coil2.mesh = coil2_mesh
	coil2.position = Vector3(0, 0.20, 0)
	coil2.rotation_degrees = Vector3(90, 15, 0)
	_hose_ground_node.add_child(coil2)

	# --- 3. Curved Winding Hose Segments extending from coil ---
	var hose_path: Array[Vector3] = [
		Vector3(0.0, 0.18, 0.0),
		Vector3(0.35, 0.18, 0.2),
		Vector3(0.75, 0.18, 0.0),
		Vector3(1.15, 0.18, 0.35),
		Vector3(1.6, 0.18, 0.15),
		Vector3(2.0, 0.18, -0.1),
		Vector3(2.35, 0.18, 0.15),
	]

	for i in range(hose_path.size() - 1):
		var seg_start: Vector3 = hose_path[i]
		var seg_end: Vector3 = hose_path[i + 1]
		var seg_mid: Vector3 = (seg_start + seg_end) * 0.5
		var seg_len: float = seg_start.distance_to(seg_end)

		var seg := MeshInstance3D.new()
		seg.name = "HoseSeg_%d" % i
		var seg_cyl := CylinderMesh.new()
		seg_cyl.top_radius = 0.05
		seg_cyl.bottom_radius = 0.05
		seg_cyl.height = seg_len
		seg_cyl.material = _hose_material
		seg.mesh = seg_cyl
		seg.position = seg_mid

		var dir := (seg_end - seg_start).normalized()
		if absf(dir.x) > 0.001 or absf(dir.z) > 0.001:
			seg.look_at(seg.global_position + dir, Vector3.UP)
			seg.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

		_hose_segments.append(seg)
		_hose_ground_node.add_child(seg)

	# --- 4. High-Quality Brass Nozzle & Air Meter Valve at tip ---
	_hose_nozzle_mesh = MeshInstance3D.new()
	_hose_nozzle_mesh.name = "BrassHoseNozzle"

	var nozzle_body := CylinderMesh.new()
	nozzle_body.top_radius = 0.035
	nozzle_body.bottom_radius = 0.065
	nozzle_body.height = 0.32
	nozzle_body.material = _brass_material
	_hose_nozzle_mesh.mesh = nozzle_body
	_hose_nozzle_mesh.position = Vector3(2.35, 0.28, 0.15)
	_hose_nozzle_mesh.rotation_degrees = Vector3(0, 0, 90)
	_hose_ground_node.add_child(_hose_nozzle_mesh)

	# Rubber grip handle on nozzle
	var grip := MeshInstance3D.new()
	grip.name = "NozzleGrip"
	var grip_mesh := TorusMesh.new()
	grip_mesh.inner_radius = 0.04
	grip_mesh.outer_radius = 0.08
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.15, 0.15, 0.18, 1.0)
	grip_mesh.material = grip_mat
	grip.mesh = grip_mesh
	grip.position = Vector3(2.25, 0.28, 0.15)
	grip.rotation_degrees = Vector3(0, 0, 90)
	_hose_ground_node.add_child(grip)

	# --- 5. Stretched Hose Renderer (from ground mount -> Fat's hands) ---
	_stretched_mesh = ImmediateMesh.new()
	_stretched_rope = MeshInstance3D.new()
	_stretched_rope.name = "StretchedHoseLine"
	_stretched_rope.top_level = true
	_stretched_rope.mesh = _stretched_mesh
	var rope_mat := StandardMaterial3D.new()
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_mat.albedo_color = Color(0.12, 0.78, 0.92, 1.0)
	_stretched_rope.material_override = rope_mat
	_stretched_rope.hide()
	add_child(_stretched_rope)

# =================== INTERACTION AREA ===================

func _build_hose_pickup_area() -> void:
	_hose_pickup_area = Area3D.new()
	_hose_pickup_area.name = "HosePickupArea"
	_hose_pickup_area.collision_layer = 0
	_hose_pickup_area.collision_mask = 2 # Players layer

	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = interaction_radius
	area_col.shape = area_shape
	area_col.position = Vector3(2.35, 0.5, 0.15)
	_hose_pickup_area.add_child(area_col)
	add_child(_hose_pickup_area)

# =================== LABELS ===================

func _build_labels() -> void:
	_title_label = Label3D.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "🎈 ВОЗДУШНЫЙ ШЛАНГ"
	_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title_label.position = Vector3(0, 1.8, 0)
	_title_label.font_size = 28
	_title_label.outline_size = 8
	_title_label.modulate = Color(0.2, 0.85, 0.95, 1.0)
	add_child(_title_label)

	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = "💨 [F] ВЗЯТЬ ШЛАНГ!"
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.position = Vector3(2.35, 1.1, 0.15)
	_prompt_label.font_size = 26
	_prompt_label.outline_size = 8
	_prompt_label.modulate = Color(1.0, 0.92, 0.25, 1.0)
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

	var hose_origin: Vector3 = global_position + Vector3(0, 0.15, 0)
	var carrier_hand: Vector3 = hose_carrier.global_position + Vector3(0, 0.8, 0)

	_stretched_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = 16
	var sag: float = 0.75

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var pos: Vector3 = hose_origin.lerp(carrier_hand, t)
		pos.y -= sin(t * PI) * sag * (1.0 - t * 0.4)
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

	if _hose_ground_node:
		_hose_ground_node.hide()

	print("🎈 HOSE GRABBED by %s!" % p.name)
	hose_grabbed.emit(p)

@rpc("any_peer", "call_local", "reliable")
func rpc_return_hose() -> void:
	is_hose_taken = false
	hose_carrier = null

	if _hose_ground_node:
		_hose_ground_node.show()

	_stretched_rope.hide()
	print("🎈 HOSE RETURNED to floor.")

func get_hose_nozzle_world_pos() -> Vector3:
	return global_position + Vector3(2.35, 0.28, 0.15)
