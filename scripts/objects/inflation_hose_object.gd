class_name InflationHoseObject
extends StaticBody3D

## Clean 3D Standalone Hose Object on the Floor.
## When Fat presses [F] nearby, Fat picks up the hose:
## - End 1 attaches to Fat's mouth.
## - End 2 (Brass Nozzle) is held in Fat's right hand.

signal hose_picked_up(by_fat: Player)
signal hose_returned()

@export var pickup_radius: float = 3.5

var is_taken: bool = false
var carrier: Player = null

@onready var hose_visuals: Node3D = $HoseVisuals
@onready var pickup_area: Area3D = $PickupArea
@onready var prompt_label: Label3D = $PromptLabel
@onready var title_label: Label3D = $TitleLabel

# Volumetric 3D Stretched Hose Renderers
var _tube_mouth: MeshInstance3D
var _tube_hand: MeshInstance3D
var _hand_nozzle: Node3D

var _mat_rubber: StandardMaterial3D
var _mat_brass: StandardMaterial3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("inflation_hoses")

	_init_materials()
	_init_stretched_tubes()
	_init_hand_nozzle()

func _init_materials() -> void:
	_mat_rubber = StandardMaterial3D.new()
	_mat_rubber.albedo_color = Color(0.1, 0.82, 0.95, 1.0)
	_mat_rubber.roughness = 0.3
	_mat_rubber.metallic = 0.15

	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.98, 0.85, 0.2, 1.0)
	_mat_brass.metallic = 0.9
	_mat_brass.roughness = 0.15

func _init_stretched_tubes() -> void:
	_tube_mouth = MeshInstance3D.new()
	_tube_mouth.name = "TubeOriginToMouth"
	_tube_mouth.top_level = true
	_tube_mouth.material_override = _mat_rubber
	_tube_mouth.hide()
	add_child(_tube_mouth)

	_tube_hand = MeshInstance3D.new()
	_tube_hand.name = "TubeMouthToHand"
	_tube_hand.top_level = true
	_tube_hand.material_override = _mat_rubber
	_tube_hand.hide()
	add_child(_tube_hand)

func _init_hand_nozzle() -> void:
	_hand_nozzle = Node3D.new()
	_hand_nozzle.name = "HandHeldBrassNozzle"

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.15
	cyl.height = 0.6
	cyl.material = _mat_brass
	body.mesh = cyl
	body.rotation_degrees = Vector3(0, 0, 90)
	_hand_nozzle.add_child(body)

	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.15
	grip_cyl.bottom_radius = 0.15
	grip_cyl.height = 0.25
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.12, 0.14, 0.18, 1.0)
	grip_cyl.material = grip_mat
	grip.mesh = grip_cyl
	grip.position = Vector3(-0.15, 0, 0)
	grip.rotation_degrees = Vector3(0, 0, 90)
	_hand_nozzle.add_child(grip)

	_hand_nozzle.hide()
	add_child(_hand_nozzle)

func _process(_delta: float) -> void:
	_update_prompt()
	_update_stretched_hoses()

func _update_prompt() -> void:
	if not pickup_area or not prompt_label:
		return

	if is_taken:
		prompt_label.hide()
		return

	var show := false
	for body in pickup_area.get_overlapping_bodies():
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat" and p.is_multiplayer_authority():
				show = true
				break
	prompt_label.visible = show

func _update_stretched_hoses() -> void:
	if not is_taken or not carrier or not is_instance_valid(carrier):
		_tube_mouth.hide()
		_tube_hand.hide()
		_hand_nozzle.hide()
		return

	# End 1 -> Fat's Mouth, End 2 -> Fat's Right Hand
	var floor_origin: Vector3 = global_position + Vector3(0, 0.2, 0)
	var mouth_pos: Vector3 = carrier.global_transform * Vector3(0, 1.45, 0.35)
	var hand_pos: Vector3 = carrier.global_transform * Vector3(0.55, 0.75, 0.45)

	# Position Nozzle in Fat's Hand
	_hand_nozzle.show()
	_hand_nozzle.global_position = hand_pos
	_hand_nozzle.global_rotation = carrier.global_rotation

	# Check if connected to target for inflation
	var fat_mech: FatMechanics = carrier.get_node_or_null("FatMechanics") as FatMechanics
	var target_pos: Vector3 = hand_pos

	if fat_mech and fat_mech.is_pumping and fat_mech.inflation_target and is_instance_valid(fat_mech.inflation_target):
		target_pos = fat_mech.inflation_target.global_position + Vector3(0, 1.0, 0)
		_hand_nozzle.global_position = target_pos

	# Draw Tube 1: Floor Origin -> Mouth
	var pts1: Array[Vector3] = []
	var segs1: int = 14
	var sag1: float = 0.6
	for i in range(segs1 + 1):
		var t: float = float(i) / float(segs1)
		var p: Vector3 = floor_origin.lerp(mouth_pos, t)
		p.y -= sin(t * PI) * sag1 * (1.0 - t * 0.4)
		pts1.append(p)
	_draw_tube_mesh(_tube_mouth, pts1, 0.11)
	_tube_mouth.show()

	# Draw Tube 2: Mouth -> Hand / Target
	var pts2: Array[Vector3] = []
	var segs2: int = 10
	var sag2: float = 0.25
	for i in range(segs2 + 1):
		var t: float = float(i) / float(segs2)
		var p: Vector3 = mouth_pos.lerp(target_pos, t)
		p.y -= sin(t * PI) * sag2
		pts2.append(p)
	_draw_tube_mesh(_tube_hand, pts2, 0.09)
	_tube_hand.show()

func _draw_tube_mesh(mesh_inst: MeshInstance3D, points: Array[Vector3], radius: float) -> void:
	if points.size() < 2:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_verts: Array[Array] = []
	var sides: int = 8

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

			st.add_vertex(v1)
			st.add_vertex(v2)
			st.add_vertex(v4)

			st.add_vertex(v2)
			st.add_vertex(v3)
			st.add_vertex(v4)

	st.generate_normals()
	mesh_inst.mesh = st.commit()

@rpc("any_peer", "call_local", "reliable")
func rpc_pickup_hose(fat_path: NodePath) -> void:
	var fat: Player = get_node_or_null(fat_path) as Player
	if not fat or is_taken:
		return

	is_taken = true
	carrier = fat
	if hose_visuals:
		hose_visuals.hide()

	hose_picked_up.emit(fat)
	print("🎈 Hose picked up by %s! End 1 -> Mouth, End 2 -> Hand!" % fat.name)

@rpc("any_peer", "call_local", "reliable")
func rpc_return_hose() -> void:
	is_taken = false
	carrier = null
	if hose_visuals:
		hose_visuals.show()
	_tube_mouth.hide()
	_tube_hand.hide()
	_hand_nozzle.hide()

	hose_returned.emit()
	print("🎈 Hose returned to floor.")

func get_nozzle_world_pos() -> Vector3:
	return global_position + Vector3(2.95, 0.18, 0.35)
