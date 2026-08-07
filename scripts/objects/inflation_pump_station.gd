class_name InflationPumpStation
extends StaticBody3D

## Physical 3D Inflation Hose Object (Standalone Hose on Floor Scene).
## Flow:
## 1. Hose is visible on the floor on ready.
## 2. Fat walks up to the hose on floor and presses [F] to GRAB IT.
## 3. End 1 -> Fat's mouth (rotates with Fat), End 2 -> Brass Nozzle in Fat's right hand!
## 4. Fat walks to Thin/DummyNPC and presses [F] -> Connects nozzle to start pumping!

signal hose_grabbed(by_player: Player)
signal hose_connected(fat: Player, target: Node3D)

@export var interaction_radius: float = 3.5

var is_hose_taken: bool = false
var hose_carrier: Player = null

@onready var hose_ground_node: Node3D = $StandaloneHose3D
@onready var hose_pickup_area: Area3D = $HosePickupArea
@onready var prompt_label: Label3D = $PromptLabel
@onready var title_label: Label3D = $TitleLabel

# Volumetric 3D Stretched Hose Renderers (Thick 3D Rubber Tubes!)
var _stretched_hose_mouth: MeshInstance3D
var _stretched_hose_hand: MeshInstance3D

# Hand-held 3D Brass Nozzle mesh (shown when Fat carries hose)
var _hand_nozzle_mesh: Node3D

var _hose_mat: StandardMaterial3D
var _brass_mat: StandardMaterial3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_setup_materials()
	_build_3d_hose_visuals()
	_setup_volumetric_hoses()
	_setup_hand_nozzle()

func _setup_materials() -> void:
	_hose_mat = StandardMaterial3D.new()
	_hose_mat.albedo_color = Color(0.12, 0.78, 0.92, 1.0)
	_hose_mat.roughness = 0.35
	_hose_mat.metallic = 0.15

	_brass_mat = StandardMaterial3D.new()
	_brass_mat.albedo_color = Color(0.95, 0.82, 0.22, 1.0)
	_brass_mat.metallic = 0.85
	_brass_mat.roughness = 0.2

func _build_3d_hose_visuals() -> void:
	if not hose_ground_node:
		hose_ground_node = Node3D.new()
		hose_ground_node.name = "StandaloneHose3D"
		add_child(hose_ground_node)

	# Build continuous smooth 3D tube on floor
	var path_points: Array[Vector3] = []
	var total_steps: int = 30
	var start_p := global_position + Vector3(0.35, 0.08, 0.0)
	var end_p := global_position + Vector3(2.2, 0.08, 0.25)

	for i in range(total_steps + 1):
		var t: float = float(i) / float(total_steps)
		var pos: Vector3 = start_p.lerp(end_p, t)
		pos.z += sin(t * PI * 2.5) * 0.32
		path_points.append(pos)

	_render_volumetric_tube_local(hose_ground_node, path_points, 0.05, 10, _hose_mat)

func _setup_volumetric_hoses() -> void:
	_stretched_hose_mouth = MeshInstance3D.new()
	_stretched_hose_mouth.name = "VolumetricHoseMouth"
	_stretched_hose_mouth.top_level = true
	_stretched_hose_mouth.material_override = _hose_mat
	_stretched_hose_mouth.hide()
	add_child(_stretched_hose_mouth)

	_stretched_hose_hand = MeshInstance3D.new()
	_stretched_hose_hand.name = "VolumetricHoseHand"
	_stretched_hose_hand.top_level = true
	_stretched_hose_hand.material_override = _hose_mat
	_stretched_hose_hand.hide()
	add_child(_stretched_hose_hand)

func _setup_hand_nozzle() -> void:
	_hand_nozzle_mesh = Node3D.new()
	_hand_nozzle_mesh.name = "HandHeldBrassNozzle"

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.065
	cyl.height = 0.32
	cyl.material = _brass_mat
	body.mesh = cyl
	body.rotation_degrees = Vector3(0, 0, 90)
	_hand_nozzle_mesh.add_child(body)

	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.075
	grip_cyl.bottom_radius = 0.075
	grip_cyl.height = 0.12
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.12, 0.14, 0.18, 1.0)
	grip_cyl.material = grip_mat
	grip.mesh = grip_cyl
	grip.position = Vector3(-0.06, 0, 0)
	grip.rotation_degrees = Vector3(0, 0, 90)
	_hand_nozzle_mesh.add_child(grip)

	_hand_nozzle_mesh.hide()
	add_child(_hand_nozzle_mesh)

func _process(_delta: float) -> void:
	_update_prompt_visibility()
	_update_volumetric_hoses()

func _update_prompt_visibility() -> void:
	if not hose_pickup_area or not prompt_label:
		return

	if is_hose_taken:
		prompt_label.hide()
		return

	var show := false
	var bodies := hose_pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat" and p.is_multiplayer_authority():
				show = true
				break

	prompt_label.visible = show

func _update_volumetric_hoses() -> void:
	if not is_hose_taken or not hose_carrier or not is_instance_valid(hose_carrier):
		_stretched_hose_mouth.hide()
		_stretched_hose_hand.hide()
		_hand_nozzle_mesh.hide()
		return

	# Exact Mouth and Hand attachment points using Fat's global_transform!
	var hose_origin: Vector3 = global_position + Vector3(0, 0.12, 0)
	var fat_mouth: Vector3 = hose_carrier.global_transform * Vector3(0, 1.45, 0.25)
	var fat_hand: Vector3 = hose_carrier.global_transform * Vector3(0.42, 0.75, 0.35)

	# Position the Brass Nozzle cleanly in Fat's right hand!
	_hand_nozzle_mesh.show()
	_hand_nozzle_mesh.global_position = fat_hand
	_hand_nozzle_mesh.global_rotation = hose_carrier.global_rotation

	var infl_sys := hose_carrier.get_node_or_null("InflationSystem") as InflationSystem
	var target_end: Vector3 = fat_hand

	# If connected to target (Thin or DummyNPC), End 2 goes into target!
	if infl_sys and infl_sys.is_inflating and infl_sys.tether_partner and is_instance_valid(infl_sys.tether_partner):
		target_end = infl_sys.tether_partner.global_position + Vector3(0, 1.0, 0)
		_hand_nozzle_mesh.global_position = target_end

	# 1. Build Thick Volumetric 3D Hose: Origin -> Fat's Mouth
	var pts1: Array[Vector3] = []
	var segs1: int = 14
	var sag1: float = 0.65
	for i in range(segs1 + 1):
		var t: float = float(i) / float(segs1)
		var p: Vector3 = hose_origin.lerp(fat_mouth, t)
		p.y -= sin(t * PI) * sag1 * (1.0 - t * 0.4)
		pts1.append(p)

	_render_volumetric_tube_world(_stretched_hose_mouth, pts1, 0.045, 8)
	_stretched_hose_mouth.show()

	# 2. Build Thick Volumetric 3D Hose: Fat's Mouth -> Fat's Hand (or Target)
	var pts2: Array[Vector3] = []
	var segs2: int = 10
	var sag2: float = 0.25
	for i in range(segs2 + 1):
		var t: float = float(i) / float(segs2)
		var p: Vector3 = fat_mouth.lerp(target_end, t)
		p.y -= sin(t * PI) * sag2
		pts2.append(p)

	_render_volumetric_tube_world(_stretched_hose_hand, pts2, 0.04, 8)
	_stretched_hose_hand.show()

func _render_volumetric_tube_world(mesh_inst: MeshInstance3D, points: Array[Vector3], radius: float, sides: int) -> void:
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

func _render_volumetric_tube_local(parent: Node3D, points: Array[Vector3], radius: float, sides: int, mat: Material) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "ContinuousHoseMesh"
	mesh_inst.material_override = mat
	_render_volumetric_tube_world(mesh_inst, points, radius, sides)
	parent.add_child(mesh_inst)

# =================== RPC: GRAB / RETURN HOSE ===================

@rpc("any_peer", "call_local", "reliable")
func rpc_grab_hose(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p or is_hose_taken:
		return

	is_hose_taken = true
	hose_carrier = p

	if hose_ground_node:
		hose_ground_node.hide()

	print("🎈 HOSE GRABBED by %s! End 1 -> Mouth, End 2 -> Hand Nozzle!" % p.name)
	hose_grabbed.emit(p)

@rpc("any_peer", "call_local", "reliable")
func rpc_return_hose() -> void:
	is_hose_taken = false
	hose_carrier = null

	if hose_ground_node:
		hose_ground_node.show()

	_stretched_hose_mouth.hide()
	_stretched_hose_hand.hide()
	_hand_nozzle_mesh.hide()
	print("🎈 HOSE RETURNED to floor.")

func get_hose_nozzle_world_pos() -> Vector3:
	return global_position + Vector3(2.38, 0.08, 0.25)
