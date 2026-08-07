class_name InflationPumpStation
extends StaticBody3D

## High-Quality Physical 3D Inflation Hose Object (Standalone Hose on Floor).
## Features:
## - Continuous, ultra-smooth 3D procedural rubber tube lying flush on the floor.
## - Metallic hose reel mounting spool on the floor.
## - Polished brass pump nozzle at the tip.
## - Stretched 3D hose when carried by Fat.

signal hose_grabbed(by_player: Player)
signal hose_connected(fat: Player, thin: Player)

@export var interaction_radius: float = 3.0

var is_hose_taken: bool = false
var hose_carrier: Player = null

# 3D Visual nodes
var _hose_ground_node: Node3D
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
	# Flexible industrial cyan rubber hose material
	_hose_material = StandardMaterial3D.new()
	_hose_material.albedo_color = Color(0.12, 0.78, 0.92, 1.0)
	_hose_material.roughness = 0.35
	_hose_material.metallic = 0.15

	# Polished brass nozzle connector material
	_brass_material = StandardMaterial3D.new()
	_brass_material.albedo_color = Color(0.95, 0.82, 0.22, 1.0)
	_brass_material.metallic = 0.85
	_brass_material.roughness = 0.2

func _build_3d_hose_visuals() -> void:
	_hose_ground_node = Node3D.new()
	_hose_ground_node.name = "StandaloneHose3D"
	add_child(_hose_ground_node)

	# --- 1. Metallic Floor Mount Spool Base ---
	var mount := MeshInstance3D.new()
	mount.name = "HoseSpoolBase"
	var mount_box := BoxMesh.new()
	mount_box.size = Vector3(1.0, 0.08, 1.0)
	var mount_mat := StandardMaterial3D.new()
	mount_mat.albedo_color = Color(0.22, 0.25, 0.3, 1.0)
	mount_mat.metallic = 0.75
	mount_mat.roughness = 0.3
	mount_box.material = mount_mat
	mount.mesh = mount_box
	mount.position = Vector3(0, 0.04, 0)
	_hose_ground_node.add_child(mount)

	# Central hub cylinder on floor
	var hub := MeshInstance3D.new()
	var hub_cyl := CylinderMesh.new()
	hub_cyl.top_radius = 0.22
	hub_cyl.bottom_radius = 0.24
	hub_cyl.height = 0.14
	hub_cyl.material = mount_mat
	hub.mesh = hub_cyl
	hub.position = Vector3(0, 0.11, 0)
	_hose_ground_node.add_child(hub)

	# Mount collision
	var mount_col := CollisionShape3D.new()
	var mount_shape := BoxShape3D.new()
	mount_shape.size = Vector3(1.0, 0.12, 1.0)
	mount_col.shape = mount_shape
	mount_col.position = Vector3(0, 0.06, 0)
	add_child(mount_col)

	# --- 2. Coiled Hose Rings lying FLAT on floor spool ---
	var coil1 := MeshInstance3D.new()
	coil1.name = "HoseCoilFlat1"
	var coil1_mesh := TorusMesh.new()
	coil1_mesh.inner_radius = 0.22
	coil1_mesh.outer_radius = 0.38
	coil1_mesh.material = _hose_material
	coil1.mesh = coil1_mesh
	coil1.position = Vector3(0, 0.12, 0) # Default TorusMesh lies flat in XZ plane!
	_hose_ground_node.add_child(coil1)

	var coil2 := MeshInstance3D.new()
	coil2.name = "HoseCoilFlat2"
	var coil2_mesh := TorusMesh.new()
	coil2_mesh.inner_radius = 0.26
	coil2_mesh.outer_radius = 0.42
	coil2_mesh.material = _hose_material
	coil2.mesh = coil2_mesh
	coil2.position = Vector3(0, 0.16, 0)
	_hose_ground_node.add_child(coil2)

	# --- 3. Continuous 3D Smooth Rubber Tube Mesh along curved path ---
	var path_points: Array[Vector3] = []
	var total_steps: int = 30
	var start_p := Vector3(0.35, 0.08, 0.0)
	var end_p := Vector3(2.2, 0.08, 0.25)

	# Generate smooth s-curve hose path on floor
	for i in range(total_steps + 1):
		var t: float = float(i) / float(total_steps)
		var pos: Vector3 = start_p.lerp(end_p, t)
		# Add realistic winding S-curve offset
		pos.z += sin(t * PI * 2.5) * 0.32
		path_points.append(pos)

	_build_continuous_tube_mesh(_hose_ground_node, path_points, 0.05, 10, _hose_material)

	# --- 4. High-Quality Brass Nozzle & Handle lying flat at tip ---
	_hose_nozzle_mesh = MeshInstance3D.new()
	_hose_nozzle_mesh.name = "BrassHoseNozzle"

	var nozzle_body := CylinderMesh.new()
	nozzle_body.top_radius = 0.035
	nozzle_body.bottom_radius = 0.065
	nozzle_body.height = 0.35
	nozzle_body.material = _brass_material
	_hose_nozzle_mesh.mesh = nozzle_body
	_hose_nozzle_mesh.position = Vector3(2.38, 0.08, 0.25)
	_hose_nozzle_mesh.rotation_degrees = Vector3(0, 0, 90) # Lying horizontal on floor
	_hose_ground_node.add_child(_hose_nozzle_mesh)

	# Rubber grip handle on nozzle
	var grip := MeshInstance3D.new()
	grip.name = "NozzleGripHandle"
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.075
	grip_cyl.bottom_radius = 0.075
	grip_cyl.height = 0.12
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.12, 0.14, 0.18, 1.0)
	grip_mat.roughness = 0.8
	grip_cyl.material = grip_mat
	grip.mesh = grip_cyl
	grip.position = Vector3(2.24, 0.08, 0.25)
	grip.rotation_degrees = Vector3(0, 0, 90)
	_hose_ground_node.add_child(grip)

	# Small pressure dial on nozzle
	var dial := MeshInstance3D.new()
	var dial_mesh := SphereMesh.new()
	dial_mesh.radius = 0.04
	dial_mesh.height = 0.08
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_color = Color(0.9, 0.9, 0.85, 1.0)
	dial_mesh.material = dial_mat
	dial.mesh = dial_mesh
	dial.position = Vector3(2.28, 0.15, 0.25)
	_hose_ground_node.add_child(dial)

	# --- 5. Stretched Hose Renderer (from floor mount -> Fat's hands) ---
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

# =================== PROCEDURAL CONTINUOUS TUBE BUILDER ===================

func _build_continuous_tube_mesh(parent: Node3D, points: Array[Vector3], radius: float, sides: int, mat: Material) -> void:
	if points.size() < 2:
		return

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "ContinuousHoseMesh"
	mesh_inst.material_override = mat

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

		var current_ring: Array[Vector3] = []
		for s in range(sides):
			var angle: float = (float(s) / float(sides)) * TAU
			var offset: Vector3 = right * (cos(angle) * radius) + up * (sin(angle) * radius)
			current_ring.append(p + offset)
		ring_verts.append(current_ring)

	for i in range(points.size() - 1):
		var r1: Array = ring_verts[i]
		var r2: Array = ring_verts[i + 1]

		for s in range(sides):
			var next_s: int = (s + 1) % sides

			var v1: Vector3 = r1[s]
			var v2: Vector3 = r1[next_s]
			var v3: Vector3 = r2[next_s]
			var v4: Vector3 = r2[s]

			# Triangle 1
			st.set_normal((v2 - v1).cross(v4 - v1).normalized())
			st.add_vertex(v1)
			st.add_vertex(v2)
			st.add_vertex(v4)

			# Triangle 2
			st.set_normal((v3 - v2).cross(v4 - v2).normalized())
			st.add_vertex(v2)
			st.add_vertex(v3)
			st.add_vertex(v4)

	mesh_inst.mesh = st.commit()
	parent.add_child(mesh_inst)

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
	area_col.position = Vector3(2.38, 0.5, 0.25)
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
	_prompt_label.position = Vector3(2.38, 1.1, 0.25)
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

	var hose_origin: Vector3 = global_position + Vector3(0, 0.12, 0)
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
	return global_position + Vector3(2.38, 0.08, 0.25)
