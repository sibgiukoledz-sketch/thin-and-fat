class_name FatCharacter
extends Node3D

## Fat Character ("Толстяк") — Human Fall Flat style.
## High quality continuous skinned geometry bound to a real Skeleton3D rig.
## 100% solid matte clay aesthetic, pear-shaped body with red hoodie,
## denim jeans, snapback cap with gold visor, expressive cartoon face,
## chubby hands, and chunky skate sneakers.

const PELVIS_REST_Y: float = 0.82

# Matte cartoon clay palette (vertex colors)
const COL_SKIN := Color(0.92, 0.65, 0.52)
const COL_CHEEK := Color(0.94, 0.52, 0.48)
const COL_HOODIE := Color(0.85, 0.20, 0.20)
const COL_HOODIE_DARK := Color(0.68, 0.14, 0.14)
const COL_DENIM := Color(0.18, 0.32, 0.58)
const COL_CAP := Color(0.12, 0.55, 0.78)
const COL_VISOR := Color(0.92, 0.70, 0.12)
const COL_SNEAKER := Color(0.80, 0.18, 0.18)
const COL_WHITE := Color(0.95, 0.95, 0.95)
const COL_DARK := Color(0.10, 0.10, 0.14)

var skeleton: Skeleton3D
var animation_player: AnimationPlayer

var is_ragdoll: bool = false
var is_carrying_pose: bool = false
var is_trampoline_pose: bool = false
var current_anim: String = ""

# Environmental reaction states
var wind_force_vector: Vector3 = Vector3.ZERO
var stench_amount: float = 0.0

var _bones := {}
var _head_socket: Node3D
var _torso_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _arms_mesh: MeshInstance3D
var _legs_mesh: MeshInstance3D
var _material: StandardMaterial3D

# Procedural spring physics state
var _head_velocity := Vector3.ZERO
var _head_spring_rot := Vector3.ZERO
var _belly_velocity := 0.0
var _belly_spring_scale_y := 1.0
var _last_parent_pos := Vector3.ZERO
var _last_parent_vel := Vector3.ZERO
var _time_passed := 0.0
var _pelvis_drop := 0.0
var _pelvis_drop_target := 0.0


func _ready() -> void:
	process_priority = 100
	rotation = Vector3.ZERO
	_build_skeleton()
	_build_material()
	_build_meshes()
	_build_animations()
	_head_socket = Node3D.new()
	_head_socket.name = "HeadSocket"
	add_child(_head_socket)
	play_anim("idle")
	_last_parent_pos = global_position


# ---------------------------------------------------------------- skeleton --

func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	var defs := [
		["Pelvis", "", Vector3(0, 0.82, 0)],
		["Torso", "Pelvis", Vector3(0, 0.35, 0)],
		["TorsoS", "Torso", Vector3.ZERO],
		["HeadPivot", "TorsoS", Vector3(0, 0.65, 0)],
		["HeadS", "HeadPivot", Vector3.ZERO],
		["Arm_L", "TorsoS", Vector3(-0.55, 0.38, 0)],
		["ArmS_L", "Arm_L", Vector3.ZERO],
		["Forearm_L", "ArmS_L", Vector3(-0.10, -0.34, 0)],
		["ForearmS_L", "Forearm_L", Vector3.ZERO],
		["Arm_R", "TorsoS", Vector3(0.55, 0.38, 0)],
		["ArmS_R", "Arm_R", Vector3.ZERO],
		["Forearm_R", "ArmS_R", Vector3(0.10, -0.34, 0)],
		["ForearmS_R", "Forearm_R", Vector3.ZERO],
		["Hip_L", "Pelvis", Vector3(-0.24, -0.05, 0)],
		["Shin_L", "Hip_L", Vector3(0, -0.36, 0)],
		["Hip_R", "Pelvis", Vector3(0.24, -0.05, 0)],
		["Shin_R", "Hip_R", Vector3(0, -0.36, 0)],
	]
	for d in defs:
		var idx := skeleton.get_bone_count()
		skeleton.add_bone(d[0])
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, d[2]))
		_bones[d[0]] = idx
	for d in defs:
		skeleton.set_bone_parent(_bones[d[0]], _bones.get(d[1], -1))
	for i in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(i)
		skeleton.set_bone_pose_position(i, rest.origin)
		skeleton.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(i, rest.basis.get_scale())


func _b(bone_name: String) -> int:
	return _bones[bone_name]


func _w1(bone_name: String) -> Array:
	return [[_b(bone_name), 1.0]]


func _mix_w(a: String, b: String, k: float) -> Array:
	return HFFMeshBuilder.mix(_w1(a), _w1(b), clampf(k, 0.0, 1.0))


# ------------------------------------------------------------------ meshes --

func _build_material() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.85
	_material.metallic = 0.0
	_material.rim_enabled = false
	_material.diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
	_material.specular_mode = StandardMaterial3D.SPECULAR_SCHLICK_GGX
	_material.cull_mode = BaseMaterial3D.CULL_BACK


func _mesh_instance(part: HFFMeshBuilder.Part, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = part.commit()
	mi.material_override = _material
	mi.skeleton = NodePath("../Skeleton3D")
	add_child(mi)
	return mi


func _build_meshes() -> void:
	_build_torso_mesh()
	_build_head_mesh()
	_build_arms_mesh()
	_build_legs_mesh()


func _build_torso_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	# Torso spans from waist (y = 0.68) up to shoulders and neck (y = 1.74).
	# Bulging chubby belly in front (-Z), denim jeans at bottom, red hoodie at top.
	var profile := [
		{"y": 0.68, "offset": Vector3(0, 0, 0.02), "r": Vector2(0.38, 0.36), "w": _w1("Pelvis"), "c": COL_DENIM},
		{"y": 0.78, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.48, 0.46), "w": _mix_w("Pelvis", "TorsoS", 0.3), "c": COL_DENIM.lerp(COL_HOODIE, 0.5)},
		{"y": 0.92, "offset": Vector3(0, 0, -0.08), "r": Vector2(0.56, 0.54), "w": _w1("TorsoS"), "c": COL_HOODIE},
		{"y": 1.10, "offset": Vector3(0, 0, -0.12), "r": Vector2(0.58, 0.56), "w": _w1("TorsoS"), "c": COL_HOODIE},
		{"y": 1.30, "offset": Vector3(0, 0, -0.08), "r": Vector2(0.54, 0.50), "w": _w1("TorsoS"), "c": COL_HOODIE},
		{"y": 1.48, "offset": Vector3(0, 0, -0.03), "r": Vector2(0.46, 0.42), "w": _w1("TorsoS"), "c": COL_HOODIE},
		{"y": 1.62, "offset": Vector3(0, 0, 0.00), "r": Vector2(0.34, 0.32), "w": _w1("TorsoS"), "c": COL_HOODIE},
		{"y": 1.74, "offset": Vector3(0, 0, 0.00), "r": Vector2(0.18, 0.18), "w": _mix_w("TorsoS", "HeadS", 0.3), "c": COL_HOODIE},
	]
	part.add_offset_lathe(profile, 28, 20)

	# Kangaroo pocket on belly
	var torso_s := _w1("TorsoS")
	part.add_ball(Vector3(0, 1.05, -0.66), Vector3(0.22, 0.10, 0.04), torso_s, COL_HOODIE_DARK, 12, 6)

	_torso_mesh = _mesh_instance(part, "TorsoMesh")


func _build_head_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	var head := _w1("HeadS")

	# Continuous head lathe: face/skin on bottom half, blue snapback cap on top half.
	# ZERO duplicate spheres, ZERO Z-fighting, 100% solid opaque!
	var head_profile := [
		{"y": 1.62, "offset": Vector3(0, 0, 0), "r": Vector2(0.16, 0.16), "w": head, "c": COL_SKIN},
		{"y": 1.72, "offset": Vector3(0, 0, -0.01), "r": Vector2(0.28, 0.28), "w": head, "c": COL_SKIN},
		{"y": 1.84, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.34, 0.33), "w": head, "c": COL_SKIN},
		{"y": 1.96, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.33, 0.32), "w": head, "c": COL_SKIN.lerp(COL_CAP, 0.5)},
		{"y": 2.04, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.32, 0.31), "w": head, "c": COL_CAP},
		{"y": 2.14, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.27, 0.26), "w": head, "c": COL_CAP},
		{"y": 2.22, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.16, 0.15), "w": head, "c": COL_CAP},
	]
	part.add_offset_lathe(head_profile, 24, 20)

	# Cap gold top button
	part.add_ball(Vector3(0, 2.24, -0.02), Vector3(0.045, 0.030, 0.045), head, COL_VISOR, 10, 5)

	# Cap gold visor sticking forward
	part.add_rounded_slab(Vector3(0, 1.98, -0.40), Vector3(0.36, 0.036, 0.22), head, COL_VISOR, 14)

	# Chubby rosy cheeks
	for sx in [-1.0, 1.0]:
		part.add_ball(Vector3(0.18 * sx, 1.84, -0.26), Vector3(0.075, 0.055, 0.055), head, COL_CHEEK, 10, 5)

	# Big expressive cartoon eyes with dark pupils, highlights, and eyebrows
	part.add_cartoon_eyes(Vector3(0, 1.90, 0), 0.10, 0.02, -0.30, Vector3(0.052, 0.058, 0.040), head, COL_DARK, COL_WHITE)

	# Cheerful cartoon smile
	part.add_ball(Vector3(0, 1.76, -0.30), Vector3(0.070, 0.016, 0.020), head, COL_DARK, 8, 4)

	_head_mesh = _mesh_instance(part, "HeadMesh")


func _build_arms_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	for sx in [-1.0, 1.0]:
		var side := "_L" if sx < 0 else "_R"
		var is_left: bool = (sx < 0.0)

		# Arm tube: shoulder starts outside torso, hangs naturally along the side
		var points := [
			Vector3(0.50 * sx, 1.54, 0),
			Vector3(0.56 * sx, 1.40, 0),
			Vector3(0.64 * sx, 1.12, 0),
			Vector3(0.64 * sx, 0.82, 0),
			Vector3(0.64 * sx, 0.70, 0),
		]
		var radii := [
			Vector2(0.16, 0.15), Vector2(0.17, 0.16), Vector2(0.14, 0.13),
			Vector2(0.12, 0.11), Vector2(0.11, 0.10),
		]
		var wf := func(t: float) -> Array:
			if t < 0.18:
				return _mix_w("TorsoS", "ArmS" + side, t / 0.18)
			if t < 0.48:
				return _w1("ArmS" + side)
			if t < 0.68:
				return _mix_w("ArmS" + side, "ForearmS" + side, (t - 0.48) / 0.20)
			return _w1("ForearmS" + side)
		var cf := func(t: float) -> Color:
			if t < 0.70:
				return COL_HOODIE
			if t < 0.85:
				return COL_HOODIE_DARK
			return COL_SKIN
		part.add_tube(points, radii, 16, 8, wf, cf)

		# Stylized cartoon hand with palm, articulated thumb, and curved mitten fingers!
		var forearm := _w1("ForearmS" + side)
		var wrist_pos := Vector3(0.64 * sx, 0.68, 0)
		part.add_stylized_hand(wrist_pos, Vector3.DOWN, is_left, forearm, COL_SKIN, COL_HOODIE_DARK, 1.20)

	_arms_mesh = _mesh_instance(part, "ArmsMesh")


func _build_legs_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	for sx in [-1.0, 1.0]:
		var side := "_L" if sx < 0 else "_R"
		var is_left: bool = (sx < 0.0)

		# Leg tube: starts at hips (y = 0.75) down to ankles (y = 0.14)
		var points := [
			Vector3(0.24 * sx, 0.76, 0),
			Vector3(0.24 * sx, 0.62, 0),
			Vector3(0.24 * sx, 0.38, 0),
			Vector3(0.24 * sx, 0.14, 0),
		]
		var radii := [
			Vector2(0.19, 0.19), Vector2(0.18, 0.18),
			Vector2(0.15, 0.15), Vector2(0.12, 0.12),
		]
		var wf := func(t: float) -> Array:
			if t < 0.20:
				return _mix_w("Pelvis", "Hip" + side, t / 0.20)
			if t < 0.52:
				return _w1("Hip" + side)
			if t < 0.74:
				return _mix_w("Hip" + side, "Shin" + side, (t - 0.52) / 0.22)
			return _w1("Shin" + side)
		var cf := func(_t: float) -> Color:
			return COL_DENIM
		part.add_tube(points, radii, 16, 8, wf, cf)

		# Stylized chunky skate sneaker (rubber outsole resting flat, red canvas body, white toe cap, white laces)
		var shin := _w1("Shin" + side)
		var ankle_pos := Vector3(0.24 * sx, 0.14, -0.02)
		part.add_stylized_sneaker(ankle_pos, is_left, shin, COL_SNEAKER, COL_WHITE, COL_WHITE, COL_WHITE, 1.10)

	_legs_mesh = _mesh_instance(part, "LegsMesh")


# ------------------------------------------------------------- animations --

func _build_animations() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.add_animation_library("", HFFAnimFactory.build_library(_anim_table()))


func _anim_table() -> Dictionary:
	var zero := [[0.0, Vector3.ZERO]]
	var zeros2 := [[0.0, Vector3.ZERO], [2.0, Vector3.ZERO]]
	return {
		"idle": {
			"len": 2.0, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.82, 0)], [1.0, Vector3(0, 0.835, 0)], [2.0, Vector3(0, 0.82, 0)]]},
				"Torso": {"pos": [[0.0, Vector3(0, 0.35, 0)], [1.0, Vector3(0, 0.37, 0)], [2.0, Vector3(0, 0.35, 0)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(0, 0, 0)], [1.0, Vector3(2, 0, -2)], [2.0, Vector3(0, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(0, 0, -12)], [1.0, Vector3(0, 0, -8)], [2.0, Vector3(0, 0, -12)]]},
				"Arm_R": {"rot": [[0.0, Vector3(0, 0, 12)], [1.0, Vector3(0, 0, 8)], [2.0, Vector3(0, 0, 12)]]},
				"Hip_L": {"rot": zeros2}, "Hip_R": {"rot": zeros2},
				"Shin_L": {"rot": zeros2}, "Shin_R": {"rot": zeros2},
				"Forearm_L": {"rot": zeros2}, "Forearm_R": {"rot": zeros2},
			},
		},
		"walk": {
			"len": 0.8, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.82, 0)], [0.2, Vector3(0, 0.88, 0)], [0.4, Vector3(0, 0.82, 0)], [0.6, Vector3(0, 0.88, 0)], [0.8, Vector3(0, 0.82, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(25, 0, 0)], [0.4, Vector3(-25, 0, 0)], [0.8, Vector3(25, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(-25, 0, 0)], [0.4, Vector3(25, 0, 0)], [0.8, Vector3(-25, 0, 0)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-20, 0, 0)], [0.4, Vector3(0, 0, 0)], [0.8, Vector3(-20, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(0, 0, 0)], [0.4, Vector3(-20, 0, 0)], [0.8, Vector3(0, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(20, 0, -15)], [0.4, Vector3(-20, 0, -15)], [0.8, Vector3(20, 0, -15)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-20, 0, 15)], [0.4, Vector3(20, 0, 15)], [0.8, Vector3(-20, 0, 15)]]},
			},
		},
		"sprint": {
			"len": 0.5, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.80, 0)], [0.125, Vector3(0, 0.92, 0)], [0.25, Vector3(0, 0.80, 0)], [0.375, Vector3(0, 0.92, 0)], [0.5, Vector3(0, 0.80, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(45, 0, 0)], [0.25, Vector3(-45, 0, 0)], [0.5, Vector3(45, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(-45, 0, 0)], [0.25, Vector3(45, 0, 0)], [0.5, Vector3(-45, 0, 0)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-35, 0, 0)], [0.25, Vector3(0, 0, 0)], [0.5, Vector3(-35, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(0, 0, 0)], [0.25, Vector3(-35, 0, 0)], [0.5, Vector3(0, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(40, 0, -20)], [0.25, Vector3(-40, 0, -20)], [0.5, Vector3(40, 0, -20)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-40, 0, 20)], [0.25, Vector3(40, 0, 20)], [0.5, Vector3(-40, 0, 20)]]},
			},
		},
		"crouch": {
			"len": 1.6, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.44, 0)], [0.8, Vector3(0, 0.46, 0)], [1.6, Vector3(0, 0.44, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(65, 0, -10)], [0.8, Vector3(68, 0, -10)], [1.6, Vector3(65, 0, -10)]]},
				"Hip_R": {"rot": [[0.0, Vector3(65, 0, 10)], [0.8, Vector3(68, 0, 10)], [1.6, Vector3(65, 0, 10)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-115, 0, 0)], [0.8, Vector3(-118, 0, 0)], [1.6, Vector3(-115, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(-115, 0, 0)], [0.8, Vector3(-118, 0, 0)], [1.6, Vector3(-115, 0, 0)]]},
				"Torso": {"rot": [[0.0, Vector3(12, 0, 0)], [0.8, Vector3(16, 0, 0)], [1.6, Vector3(12, 0, 0)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(-6, 0, 0)], [0.4, Vector3(-4, 6, 2)], [0.8, Vector3(-6, 0, 0)], [1.2, Vector3(-4, -6, -2)], [1.6, Vector3(-6, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(-30, 10, -25)], [0.8, Vector3(-25, 8, -20)], [1.6, Vector3(-30, 10, -25)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-30, -10, 25)], [0.8, Vector3(-25, -8, 20)], [1.6, Vector3(-30, -10, 25)]]},
				"Forearm_L": {"rot": [[0.0, Vector3(35, 0, 0)], [0.8, Vector3(30, 0, 0)], [1.6, Vector3(35, 0, 0)]]},
				"Forearm_R": {"rot": [[0.0, Vector3(35, 0, 0)], [0.8, Vector3(30, 0, 0)], [1.6, Vector3(35, 0, 0)]]},
			},
		},
		"crouch_walk": {
			"len": 0.8, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.44, 0)], [0.2, Vector3(0.04, 0.48, 0)], [0.4, Vector3(0, 0.44, 0)], [0.6, Vector3(-0.04, 0.48, 0)], [0.8, Vector3(0, 0.44, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(75, 0, -10)], [0.4, Vector3(45, 0, -10)], [0.8, Vector3(75, 0, -10)]]},
				"Hip_R": {"rot": [[0.0, Vector3(45, 0, 10)], [0.4, Vector3(75, 0, 10)], [0.8, Vector3(45, 0, 10)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-125, 0, 0)], [0.4, Vector3(-90, 0, 0)], [0.8, Vector3(-125, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(-90, 0, 0)], [0.4, Vector3(-125, 0, 0)], [0.8, Vector3(-90, 0, 0)]]},
				"Torso": {"rot": [[0.0, Vector3(14, 0, 0)], [0.2, Vector3(14, 4, -4)], [0.4, Vector3(14, 0, 0)], [0.6, Vector3(14, -4, 4)], [0.8, Vector3(14, 0, 0)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(-8, 3, 0)], [0.4, Vector3(-8, -3, 0)], [0.8, Vector3(-8, 3, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(10, 0, -25)], [0.4, Vector3(-45, 0, -25)], [0.8, Vector3(10, 0, -25)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-45, 0, 25)], [0.4, Vector3(10, 0, 25)], [0.8, Vector3(-45, 0, 25)]]},
				"Forearm_L": {"rot": [[0.0, Vector3(40, 0, 0)], [0.4, Vector3(25, 0, 0)], [0.8, Vector3(40, 0, 0)]]},
				"Forearm_R": {"rot": [[0.0, Vector3(25, 0, 0)], [0.4, Vector3(40, 0, 0)], [0.8, Vector3(25, 0, 0)]]},
			},
		},
		"jump": {
			"len": 0.6, "loop": false, "bones": {
				"Arm_L": {"rot": [[0.0, Vector3(0, 0, -20)], [0.3, Vector3(-60, 0, -35)], [0.6, Vector3(-20, 0, -20)]]},
				"Arm_R": {"rot": [[0.0, Vector3(0, 0, 20)], [0.3, Vector3(-60, 0, 35)], [0.6, Vector3(-20, 0, 20)]]},
				"Hip_L": {"rot": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-30, 0, 0)], [0.6, Vector3(-10, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-30, 0, 0)], [0.6, Vector3(-10, 0, 0)]]},
				"Shin_L": {"rot": zero}, "Shin_R": {"rot": zero},
				"Forearm_L": {"rot": zero}, "Forearm_R": {"rot": zero},
			},
		},
		"dance_kazachok": {
			"len": 0.8, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.45, 0)], [0.2, Vector3(0, 0.58, 0)], [0.4, Vector3(0, 0.45, 0)], [0.6, Vector3(0, 0.58, 0)], [0.8, Vector3(0, 0.45, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(65, 0, 0)], [0.2, Vector3(-65, -15, 0)], [0.4, Vector3(65, 0, 0)], [0.6, Vector3(60, 0, 0)], [0.8, Vector3(65, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(60, 0, 0)], [0.2, Vector3(65, 0, 0)], [0.4, Vector3(60, 0, 0)], [0.6, Vector3(-65, 15, 0)], [0.8, Vector3(60, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(-45, 30, -30)], [0.4, Vector3(-40, 25, -25)], [0.8, Vector3(-45, 30, -30)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-45, -30, 30)], [0.4, Vector3(-40, -25, 25)], [0.8, Vector3(-45, -30, 30)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(0, -10, -5)], [0.2, Vector3(0, 10, 5)], [0.4, Vector3(0, -10, -5)], [0.6, Vector3(0, 10, 5)], [0.8, Vector3(0, -10, -5)]]},
				"Shin_L": {"rot": [[0.0, Vector3.ZERO], [0.8, Vector3.ZERO]]},
				"Shin_R": {"rot": [[0.0, Vector3.ZERO], [0.8, Vector3.ZERO]]},
			},
		},
		"dance_disco": {
			"len": 1.2, "loop": true, "bones": {
				"Pelvis": {"rot": [[0.0, Vector3(0, 0, -12)], [0.3, Vector3(0, 0, 12)], [0.6, Vector3(0, 0, -12)], [0.9, Vector3(0, 0, 12)], [1.2, Vector3(0, 0, -12)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-140, 25, 45)], [0.3, Vector3(20, -15, 20)], [0.6, Vector3(-140, 25, 45)], [0.9, Vector3(20, -15, 20)], [1.2, Vector3(-140, 25, 45)]]},
				"Arm_L": {"rot": [[0.0, Vector3(15, 10, -25)], [0.3, Vector3(-60, 20, -35)], [0.6, Vector3(15, 10, -25)], [0.9, Vector3(-60, 20, -35)], [1.2, Vector3(15, 10, -25)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(-10, 20, 0)], [0.3, Vector3(10, -10, 0)], [0.6, Vector3(-10, 20, 0)], [0.9, Vector3(10, -10, 0)], [1.2, Vector3(-10, 20, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3.ZERO], [1.2, Vector3.ZERO]]},
				"Hip_R": {"rot": [[0.0, Vector3.ZERO], [1.2, Vector3.ZERO]]},
				"Shin_L": {"rot": [[0.0, Vector3.ZERO], [1.2, Vector3.ZERO]]},
				"Shin_R": {"rot": [[0.0, Vector3.ZERO], [1.2, Vector3.ZERO]]},
			},
		},
		"dance_wiggle": {
			"len": 1.0, "loop": true, "bones": {
				"Torso": {"rot": [[0.0, Vector3(0, 15, -15)], [0.25, Vector3(0, -15, 15)], [0.5, Vector3(0, 15, -15)], [0.75, Vector3(0, -15, 15)], [1.0, Vector3(0, 15, -15)]]},
				"Arm_L": {"rot": [[0.0, Vector3(-80, 40, -45)], [0.25, Vector3(-20, -10, -15)], [0.5, Vector3(-80, 40, -45)], [0.75, Vector3(-20, -10, -15)], [1.0, Vector3(-80, 40, -45)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-20, -10, 15)], [0.25, Vector3(-80, -40, 45)], [0.5, Vector3(-20, -10, 15)], [0.75, Vector3(-80, -40, 45)], [1.0, Vector3(-20, -10, 15)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(15, -20, 10)], [0.25, Vector3(-15, 20, -10)], [0.5, Vector3(15, -20, 10)], [0.75, Vector3(-15, 20, -10)], [1.0, Vector3(15, -20, 10)]]},
				"Hip_L": {"rot": [[0.0, Vector3.ZERO], [1.0, Vector3.ZERO]]},
				"Hip_R": {"rot": [[0.0, Vector3.ZERO], [1.0, Vector3.ZERO]]},
				"Shin_L": {"rot": [[0.0, Vector3.ZERO], [1.0, Vector3.ZERO]]},
				"Shin_R": {"rot": [[0.0, Vector3.ZERO], [1.0, Vector3.ZERO]]},
			},
		},
	}


# ------------------------------------------------------------ public API --

func get_head_socket() -> Node3D:
	return _head_socket


func set_first_person_view(is_first_person: bool) -> void:
	_head_mesh.visible = not is_first_person
	_torso_mesh.visible = not is_first_person
	_legs_mesh.visible = not is_first_person
	_arms_mesh.visible = true


func set_carrying_pose(is_carrying: bool) -> void:
	is_carrying_pose = is_carrying


func set_trampoline_pose(active: bool) -> void:
	is_trampoline_pose = active
	if is_trampoline_pose:
		if animation_player:
			animation_player.stop()
		_pelvis_drop_target = 0.40
		var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation_degrees:x", 85.0, 0.22)
	else:
		_pelvis_drop_target = 0.0
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation_degrees:x", 0.0, 0.2)
		current_anim = ""
		play_anim("idle")


func set_wind_reaction(wind_vec: Vector3) -> void:
	wind_force_vector = wind_vec


func set_stench_level(amount: float) -> void:
	stench_amount = amount


func play_anim(anim_name: String) -> void:
	if is_ragdoll or is_trampoline_pose:
		return
	var new_anim := anim_name.to_lower()
	if current_anim != new_anim:
		current_anim = new_anim
		if animation_player and animation_player.has_animation(new_anim):
			animation_player.play(new_anim, 0.15)


func start_ragdoll(velocity: Vector3 = Vector3.ZERO) -> void:
	is_ragdoll = true
	if animation_player:
		animation_player.stop()
	_pelvis_drop_target = 0.40
	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var tumble_z := deg_to_rad(randf_range(-70.0, 70.0))
	var tumble_x := deg_to_rad(randf_range(-45.0, 45.0))
	tw.tween_property(self, "rotation:z", tumble_z, 0.4)
	tw.parallel().tween_property(self, "rotation:x", tumble_x, 0.4)


func stop_ragdoll() -> void:
	is_ragdoll = false
	rotation = Vector3.ZERO
	_pelvis_drop = 0.0
	_pelvis_drop_target = 0.0
	skeleton.set_bone_pose_position(_b("Pelvis"), Vector3(0, PELVIS_REST_Y, 0))
	skeleton.set_bone_pose_scale(_b("TorsoS"), Vector3.ONE)
	skeleton.set_bone_pose_rotation(_b("HeadS"), Quaternion.IDENTITY)
	for spring_name in ["ArmS_L", "ArmS_R", "ForearmS_L", "ForearmS_R"]:
		skeleton.set_bone_pose_rotation(_b(spring_name), Quaternion.IDENTITY)
	current_anim = ""
	play_anim("idle")


# ------------------------------------------------------------ processing --

func _process(_delta: float) -> void:
	if _head_socket and skeleton:
		_head_socket.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(_b("HeadS"))


func _physics_process(delta: float) -> void:
	_time_passed += delta
	if is_ragdoll or is_trampoline_pose:
		_apply_pelvis_drop(delta)
		if is_trampoline_pose:
			_update_arm_springs(delta)
		return

	# 1. Parent linear velocity & clamped acceleration for active inertia
	var current_pos := global_position
	var current_vel := (current_pos - _last_parent_pos) / maxf(delta, 0.001)
	var raw_accel := (current_vel - _last_parent_vel) / maxf(delta, 0.001)
	var accel := raw_accel.clamp(Vector3(-15.0, -15.0, -15.0), Vector3(15.0, 15.0, 15.0))
	_last_parent_pos = current_pos
	_last_parent_vel = current_vel

	# 2. Wind & stench reactions
	var wind_tilt_x: float = 0.0
	if wind_force_vector.length_squared() > 0.01:
		wind_tilt_x = clampf(wind_force_vector.z * 0.015, -0.25, 0.25)

	var stench_tilt := Vector3.ZERO
	if stench_amount > 0.1:
		stench_tilt = Vector3(
			sin(_time_passed * 8.0) * 0.15 * stench_amount,
			0,
			cos(_time_passed * 10.0) * 0.12 * stench_amount
		)

	# 3. Active spring wobble on the bobblehead (dedicated bone)
	var target_tilt := Vector3(
		clampf(-accel.z * 0.010 + wind_tilt_x, -0.25, 0.25),
		clampf(current_vel.x * 0.012, -0.2, 0.2),
		clampf(-accel.x * 0.010, -0.25, 0.25)
	) + stench_tilt

	var spring_k := 140.0
	var damp := 14.0
	var force := (target_tilt - _head_spring_rot) * spring_k - (_head_velocity * damp)
	_head_velocity += force * delta
	_head_spring_rot += _head_velocity * delta
	skeleton.set_bone_pose_rotation(_b("HeadS"), Quaternion.from_euler(_rad(_head_spring_rot)))

	# 4. Active squash & stretch on the belly (dedicated torso spring bone)
	var target_scale_y := 1.0
	if accel.y > 6.0:
		target_scale_y = 0.90
	elif accel.y < -6.0:
		target_scale_y = 1.08
	if not is_carrying_pose:
		var belly_k := 160.0
		var belly_damp := 14.0
		var b_force := (target_scale_y - _belly_spring_scale_y) * belly_k - (_belly_velocity * belly_damp)
		_belly_velocity += b_force * delta
		_belly_spring_scale_y = clampf(_belly_spring_scale_y + _belly_velocity * delta, 0.85, 1.15)
		var squish_xz := 1.0 / sqrt(_belly_spring_scale_y)
		skeleton.set_bone_pose_scale(_b("TorsoS"), Vector3(squish_xz, _belly_spring_scale_y, squish_xz))
	else:
		skeleton.set_bone_pose_scale(_b("TorsoS"), Vector3.ONE)

	# 5. Carrying pose (boulder overhead) on arm spring bones
	_update_arm_springs(delta)


func _update_arm_springs(delta: float) -> void:
	var blend := clampf(delta * 10.0, 0.0, 1.0)
	var arm_l := Vector3.ZERO
	var arm_r := Vector3.ZERO
	var forearm := Vector3.ZERO
	if is_carrying_pose:
		arm_l = Vector3(-150.0, 18.0, -22.0)
		arm_r = Vector3(-150.0, -18.0, 22.0)
		forearm = Vector3(30.0, 0.0, 0.0)
	elif is_trampoline_pose:
		arm_l = Vector3(-30.0, 0.0, -45.0)
		arm_r = Vector3(-30.0, 0.0, 45.0)
	_spring_rot_lerp("ArmS_L", arm_l, blend)
	_spring_rot_lerp("ArmS_R", arm_r, blend)
	_spring_rot_lerp("ForearmS_L", forearm, blend)
	_spring_rot_lerp("ForearmS_R", forearm, blend)


func _spring_rot_lerp(bone_name: String, target_deg: Vector3, blend: float) -> void:
	var idx := _b(bone_name)
	var goal := Quaternion.from_euler(_rad(target_deg))
	var cur := skeleton.get_bone_pose_rotation(idx)
	skeleton.set_bone_pose_rotation(idx, cur.slerp(goal, blend))


func _apply_pelvis_drop(delta: float) -> void:
	_pelvis_drop = lerpf(_pelvis_drop, _pelvis_drop_target, clampf(delta * 8.0, 0.0, 1.0))
	skeleton.set_bone_pose_position(_b("Pelvis"), Vector3(0, PELVIS_REST_Y - _pelvis_drop, 0))


static func _rad(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))
