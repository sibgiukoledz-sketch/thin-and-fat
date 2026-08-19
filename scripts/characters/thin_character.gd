class_name ThinCharacter
extends Node3D

## Thin Character ("Худой") — Human Fall Flat style.
## High quality continuous skinned geometry bound to an 18-bone Skeleton3D rig.
## 100% solid matte clay aesthetic, tall lanky silhouette with striped turquoise sweater,
## dark pants, hipster round spectacles, lively expressive eyes,
## dynamic reactive hair tufts, and yellow retro runner sneakers.

const PELVIS_REST_Y: float = 1.25

# Matte cartoon clay palette (vertex colors)
const COL_SKIN := Color(0.92, 0.65, 0.52)
const COL_CHEEK := Color(0.94, 0.52, 0.48)
const COL_SWEATER := Color(0.12, 0.58, 0.55)
const COL_STRIPE := Color(0.92, 0.70, 0.12)
const COL_PANTS := Color(0.20, 0.22, 0.26)
const COL_SNEAKER := Color(0.92, 0.70, 0.12)
const COL_HAIR := Color(0.30, 0.18, 0.12)
const COL_WHITE := Color(0.95, 0.95, 0.95)
const COL_DARK := Color(0.10, 0.10, 0.14)

var skeleton: Skeleton3D
var animation_player: AnimationPlayer

var is_ragdoll: bool = false
var is_static_charged: bool = false
var current_anim: String = ""

# Environmental reaction states
var wind_force_vector: Vector3 = Vector3.ZERO

var _bones := {}
var _head_socket: Node3D
var _torso_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _hair_tuft_mesh: MeshInstance3D
var _arms_mesh: MeshInstance3D
var _legs_mesh: MeshInstance3D
var _material: StandardMaterial3D

# Procedural spring physics state
var _head_velocity := Vector3.ZERO
var _head_spring_rot := Vector3.ZERO
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
		["Pelvis", "", Vector3(0, 1.25, 0)],
		["Torso", "Pelvis", Vector3(0, 0.35, 0)],
		["TorsoS", "Torso", Vector3.ZERO],
		["Neck", "TorsoS", Vector3(0, 0.65, 0)],
		["HeadPivot", "Neck", Vector3(0, 0.22, 0)],
		["HeadS", "HeadPivot", Vector3.ZERO],
		["Arm_L", "TorsoS", Vector3(-0.28, 0.58, 0)],
		["ArmS_L", "Arm_L", Vector3.ZERO],
		["Forearm_L", "ArmS_L", Vector3(-0.04, -0.45, 0)],
		["ForearmS_L", "Forearm_L", Vector3.ZERO],
		["Arm_R", "TorsoS", Vector3(0.28, 0.58, 0)],
		["ArmS_R", "Arm_R", Vector3.ZERO],
		["Forearm_R", "ArmS_R", Vector3(0.04, -0.45, 0)],
		["ForearmS_R", "Forearm_R", Vector3.ZERO],
		["Hip_L", "Pelvis", Vector3(-0.14, -0.05, 0)],
		["Shin_L", "Hip_L", Vector3(0, -0.55, 0)],
		["Hip_R", "Pelvis", Vector3(0.14, -0.05, 0)],
		["Shin_R", "Hip_R", Vector3(0, -0.55, 0)],
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
	# Torso spans from waist (y = 1.15) up to shoulders and neck (y = 2.45).
	# Knitted turquoise sweater with alternating yellow stripes.
	var profile := [
		{"y": 1.15, "offset": Vector3.ZERO, "r": Vector2(0.17, 0.15), "w": _w1("Pelvis"), "c": COL_PANTS},
		{"y": 1.25, "offset": Vector3.ZERO, "r": Vector2(0.18, 0.16), "w": _mix_w("Pelvis", "TorsoS", 0.25), "c": COL_STRIPE},
		{"y": 1.40, "offset": Vector3.ZERO, "r": Vector2(0.20, 0.17), "w": _w1("TorsoS"), "c": COL_SWEATER},
		{"y": 1.55, "offset": Vector3.ZERO, "r": Vector2(0.21, 0.18), "w": _w1("TorsoS"), "c": COL_STRIPE},
		{"y": 1.70, "offset": Vector3.ZERO, "r": Vector2(0.22, 0.18), "w": _w1("TorsoS"), "c": COL_SWEATER},
		{"y": 1.85, "offset": Vector3.ZERO, "r": Vector2(0.23, 0.19), "w": _w1("TorsoS"), "c": COL_STRIPE},
		{"y": 2.00, "offset": Vector3.ZERO, "r": Vector2(0.24, 0.20), "w": _w1("TorsoS"), "c": COL_SWEATER},
		{"y": 2.15, "offset": Vector3.ZERO, "r": Vector2(0.25, 0.20), "w": _w1("TorsoS"), "c": COL_STRIPE},
		{"y": 2.28, "offset": Vector3.ZERO, "r": Vector2(0.23, 0.18), "w": _mix_w("TorsoS", "Neck", 0.3), "c": COL_SWEATER},
		{"y": 2.40, "offset": Vector3.ZERO, "r": Vector2(0.13, 0.12), "w": _w1("Neck"), "c": COL_STRIPE},
		{"y": 2.48, "offset": Vector3.ZERO, "r": Vector2(0.10, 0.10), "w": _mix_w("Neck", "HeadS", 0.4), "c": COL_SKIN},
	]
	part.add_offset_lathe(profile, 32, 20)
	_torso_mesh = _mesh_instance(part, "TorsoMesh")


func _build_head_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	var head := _w1("HeadS")

	# Continuous head lathe: face on lower half, brown hair volume on upper half.
	# ZERO duplicate spheres, ZERO Z-fighting, 100% solid opaque!
	var head_profile := [
		{"y": 2.40, "offset": Vector3.ZERO, "r": Vector2(0.11, 0.11), "w": head, "c": COL_SKIN},
		{"y": 2.48, "offset": Vector3(0, 0, -0.01), "r": Vector2(0.16, 0.16), "w": head, "c": COL_SKIN},
		{"y": 2.58, "offset": Vector3(0, 0, -0.02), "r": Vector2(0.20, 0.20), "w": head, "c": COL_SKIN},
		{"y": 2.68, "offset": Vector3(0, 0, -0.01), "r": Vector2(0.21, 0.20), "w": head, "c": COL_SKIN.lerp(COL_HAIR, 0.6)},
		{"y": 2.76, "offset": Vector3(0, 0, 0.0), "r": Vector2(0.18, 0.18), "w": head, "c": COL_HAIR},
		{"y": 2.82, "offset": Vector3(0, 0, 0.0), "r": Vector2(0.11, 0.11), "w": head, "c": COL_HAIR},
	]
	part.add_offset_lathe(head_profile, 24, 20)

	# Blush cheeks
	for sx in [-1.0, 1.0]:
		part.add_ball(Vector3(0.12 * sx, 2.56, -0.16), Vector3(0.045, 0.035, 0.035), head, COL_CHEEK, 10, 5)

	# Round hipster spectacles (circular frames & nose bridge)
	part.add_spectacles(Vector3(0, 2.60, 0), 0.068, 0.02, -0.19, 0.052, head, COL_DARK)

	# Lively cartoon eyes behind glasses
	part.add_cartoon_eyes(Vector3(0, 2.60, 0), 0.068, 0.02, -0.18, Vector3(0.038, 0.042, 0.032), head, COL_DARK, COL_WHITE)

	# Cheerful cartoon smile
	part.add_ball(Vector3(0, 2.49, -0.19), Vector3(0.048, 0.014, 0.016), head, COL_DARK, 8, 4)

	_head_mesh = _mesh_instance(part, "HeadMesh")

	# Dynamic reactive hair tufts (scales up and frizzes under static charge)
	var tuft := HFFMeshBuilder.Part.new()
	tuft.add_ball(Vector3(0, 2.86, 0.02), Vector3(0.075, 0.11, 0.09), head, COL_HAIR, 14, 8)
	tuft.add_ball(Vector3(0.04, 2.96, 0.01), Vector3(0.050, 0.08, 0.06), head, COL_HAIR, 12, 6)
	tuft.add_ball(Vector3(-0.03, 2.94, 0.03), Vector3(0.045, 0.07, 0.055), head, COL_HAIR, 12, 6)
	_hair_tuft_mesh = _mesh_instance(tuft, "HairTuftMesh")


func _build_arms_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	for sx in [-1.0, 1.0]:
		var side := "_L" if sx < 0 else "_R"
		var is_left: bool = (sx < 0.0)

		# Long slender arm tube hanging along side
		var points := [
			Vector3(0.26 * sx, 2.24, 0),
			Vector3(0.28 * sx, 2.10, 0),
			Vector3(0.32 * sx, 1.70, 0),
			Vector3(0.32 * sx, 1.34, 0),
			Vector3(0.32 * sx, 1.22, 0),
		]
		var radii := [
			Vector2(0.080, 0.078), Vector2(0.082, 0.080), Vector2(0.068, 0.066),
			Vector2(0.058, 0.056), Vector2(0.052, 0.050),
		]
		var wf := func(t: float) -> Array:
			if t < 0.15:
				return _mix_w("TorsoS", "ArmS" + side, t / 0.15)
			if t < 0.45:
				return _w1("ArmS" + side)
			if t < 0.65:
				return _mix_w("ArmS" + side, "ForearmS" + side, (t - 0.45) / 0.20)
			return _w1("ForearmS" + side)
		var cf := func(t: float) -> Color:
			if t < 0.70:
				return COL_SWEATER
			if t < 0.85:
				return COL_STRIPE
			return COL_SKIN
		part.add_tube(points, radii, 14, 8, wf, cf)

		# Stylized cartoon hand (palm + articulated thumb + fingers)
		var forearm := _w1("ForearmS" + side)
		var wrist_pos := Vector3(0.32 * sx, 1.20, 0)
		part.add_stylized_hand(wrist_pos, Vector3.DOWN, is_left, forearm, COL_SKIN, COL_STRIPE, 0.95)

	_arms_mesh = _mesh_instance(part, "ArmsMesh")


func _build_legs_mesh() -> void:
	var part := HFFMeshBuilder.Part.new()
	for sx in [-1.0, 1.0]:
		var side := "_L" if sx < 0 else "_R"
		var is_left: bool = (sx < 0.0)

		# Long spindly leg tube (hips y = 1.20 down to ankles y = 0.14)
		var points := [
			Vector3(0.14 * sx, 1.20, 0),
			Vector3(0.14 * sx, 1.05, 0),
			Vector3(0.14 * sx, 0.60, 0),
			Vector3(0.14 * sx, 0.14, 0),
		]
		var radii := [
			Vector2(0.095, 0.095), Vector2(0.092, 0.092),
			Vector2(0.076, 0.074), Vector2(0.062, 0.060),
		]
		var wf := func(t: float) -> Array:
			if t < 0.20:
				return _mix_w("Pelvis", "Hip" + side, t / 0.20)
			if t < 0.50:
				return _w1("Hip" + side)
			if t < 0.72:
				return _mix_w("Hip" + side, "Shin" + side, (t - 0.50) / 0.22)
			return _w1("Shin" + side)
		var cf := func(_t: float) -> Color:
			return COL_PANTS
		part.add_tube(points, radii, 14, 8, wf, cf)

		# Stylized yellow retro runner sneaker (thick white sole, yellow canvas, white toe cap, white laces)
		var shin := _w1("Shin" + side)
		var ankle_pos := Vector3(0.14 * sx, 0.14, -0.02)
		part.add_stylized_sneaker(ankle_pos, is_left, shin, COL_SNEAKER, COL_WHITE, COL_WHITE, COL_WHITE, 0.90)

	_legs_mesh = _mesh_instance(part, "LegsMesh")


# ------------------------------------------------------------- animations --

func _build_animations() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.add_animation_library("", HFFAnimFactory.build_library(_anim_table()))


func _anim_table() -> Dictionary:
	var zero_idle := [[0.0, Vector3.ZERO], [2.4, Vector3.ZERO]]
	return {
		"idle": {
			"len": 2.4, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 1.25, 0)], [1.2, Vector3(0, 1.265, 0)], [2.4, Vector3(0, 1.25, 0)]]},
				"Torso": {"pos": [[0.0, Vector3(0, 0.35, 0)], [1.2, Vector3(0, 0.37, 0)], [2.4, Vector3(0, 0.35, 0)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(0, 0, 0)], [1.2, Vector3(2, 4, 1)], [2.4, Vector3(0, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(0, 0, -8)], [1.2, Vector3(0, 0, -5)], [2.4, Vector3(0, 0, -8)]]},
				"Arm_R": {"rot": [[0.0, Vector3(0, 0, 8)], [1.2, Vector3(0, 0, 5)], [2.4, Vector3(0, 0, 8)]]},
				"Hip_L": {"rot": zero_idle}, "Hip_R": {"rot": zero_idle},
				"Shin_L": {"rot": zero_idle}, "Shin_R": {"rot": zero_idle},
				"Forearm_L": {"rot": zero_idle}, "Forearm_R": {"rot": zero_idle},
			},
		},
		"walk": {
			"len": 0.8, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 1.25, 0)], [0.2, Vector3(0, 1.30, 0)], [0.4, Vector3(0, 1.25, 0)], [0.6, Vector3(0, 1.30, 0)], [0.8, Vector3(0, 1.25, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(30, 0, 0)], [0.4, Vector3(-30, 0, 0)], [0.8, Vector3(30, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(-30, 0, 0)], [0.4, Vector3(30, 0, 0)], [0.8, Vector3(-30, 0, 0)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-25, 0, 0)], [0.4, Vector3(0, 0, 0)], [0.8, Vector3(-25, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(0, 0, 0)], [0.4, Vector3(-25, 0, 0)], [0.8, Vector3(0, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(25, 0, -10)], [0.4, Vector3(-25, 0, -10)], [0.8, Vector3(25, 0, -10)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-25, 0, 10)], [0.4, Vector3(25, 0, 10)], [0.8, Vector3(-25, 0, 10)]]},
			},
		},
		"sprint": {
			"len": 0.45, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 1.22, 0)], [0.112, Vector3(0, 1.34, 0)], [0.225, Vector3(0, 1.22, 0)], [0.337, Vector3(0, 1.34, 0)], [0.45, Vector3(0, 1.22, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(55, 0, 0)], [0.225, Vector3(-55, 0, 0)], [0.45, Vector3(55, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(-55, 0, 0)], [0.225, Vector3(55, 0, 0)], [0.45, Vector3(-55, 0, 0)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-45, 0, 0)], [0.225, Vector3(0, 0, 0)], [0.45, Vector3(-45, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(0, 0, 0)], [0.225, Vector3(-45, 0, 0)], [0.45, Vector3(0, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(50, 0, -15)], [0.225, Vector3(-50, 0, -15)], [0.45, Vector3(50, 0, -15)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-50, 0, 15)], [0.225, Vector3(50, 0, 15)], [0.45, Vector3(-50, 0, 15)]]},
			},
		},
		"crouch": {
			"len": 1.6, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.65, 0)], [0.8, Vector3(0, 0.67, 0)], [1.6, Vector3(0, 0.65, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(70, 0, -8)], [0.8, Vector3(72, 0, -8)], [1.6, Vector3(70, 0, -8)]]},
				"Hip_R": {"rot": [[0.0, Vector3(70, 0, 8)], [0.8, Vector3(72, 0, 8)], [1.6, Vector3(70, 0, 8)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-125, 0, 0)], [0.8, Vector3(-128, 0, 0)], [1.6, Vector3(-125, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(-125, 0, 0)], [0.8, Vector3(-128, 0, 0)], [1.6, Vector3(-125, 0, 0)]]},
				"Torso": {"rot": [[0.0, Vector3(18, 0, 0)], [0.8, Vector3(22, 0, 0)], [1.6, Vector3(18, 0, 0)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(-10, 0, 0)], [0.8, Vector3(-10, 0, 0)], [1.6, Vector3(-10, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(-20, 0, -18)], [0.8, Vector3(-15, 0, -14)], [1.6, Vector3(-20, 0, -18)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-20, 0, 18)], [0.8, Vector3(-15, 0, 14)], [1.6, Vector3(-20, 0, 18)]]},
			},
		},
		"crouch_walk": {
			"len": 0.8, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.65, 0)], [0.2, Vector3(0.03, 0.70, 0)], [0.4, Vector3(0, 0.65, 0)], [0.6, Vector3(-0.03, 0.70, 0)], [0.8, Vector3(0, 0.65, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(80, 0, -8)], [0.4, Vector3(50, 0, -8)], [0.8, Vector3(80, 0, -8)]]},
				"Hip_R": {"rot": [[0.0, Vector3(50, 0, 8)], [0.4, Vector3(80, 0, 8)], [0.8, Vector3(50, 0, 8)]]},
				"Shin_L": {"rot": [[0.0, Vector3(-135, 0, 0)], [0.4, Vector3(-95, 0, 0)], [0.8, Vector3(-135, 0, 0)]]},
				"Shin_R": {"rot": [[0.0, Vector3(-95, 0, 0)], [0.4, Vector3(-135, 0, 0)], [0.8, Vector3(-95, 0, 0)]]},
				"Torso": {"rot": [[0.0, Vector3(20, 0, 0)], [0.2, Vector3(20, 5, -5)], [0.4, Vector3(20, 0, 0)], [0.6, Vector3(20, -5, 5)], [0.8, Vector3(20, 0, 0)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(-12, 4, 0)], [0.4, Vector3(-12, -4, 0)], [0.8, Vector3(-12, 4, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(15, 0, -18)], [0.4, Vector3(-35, 0, -18)], [0.8, Vector3(15, 0, -18)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-35, 0, 18)], [0.4, Vector3(15, 0, 18)], [0.8, Vector3(-35, 0, 18)]]},
			},
		},
		"jump": {
			"len": 0.6, "loop": false, "bones": {
				"Arm_L": {"rot": [[0.0, Vector3(0, 0, -15)], [0.3, Vector3(-70, 0, -25)], [0.6, Vector3(-20, 0, -15)]]},
				"Arm_R": {"rot": [[0.0, Vector3(0, 0, 15)], [0.3, Vector3(-70, 0, 25)], [0.6, Vector3(-20, 0, 15)]]},
				"Hip_L": {"rot": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-35, 0, 0)], [0.6, Vector3(-10, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-35, 0, 0)], [0.6, Vector3(-10, 0, 0)]]},
			},
		},
		"dance_kazachok": {
			"len": 0.8, "loop": true, "bones": {
				"Pelvis": {"pos": [[0.0, Vector3(0, 0.68, 0)], [0.2, Vector3(0, 0.82, 0)], [0.4, Vector3(0, 0.68, 0)], [0.6, Vector3(0, 0.82, 0)], [0.8, Vector3(0, 0.68, 0)]]},
				"Hip_L": {"rot": [[0.0, Vector3(70, 0, 0)], [0.2, Vector3(-70, -20, 0)], [0.4, Vector3(70, 0, 0)], [0.6, Vector3(65, 0, 0)], [0.8, Vector3(70, 0, 0)]]},
				"Hip_R": {"rot": [[0.0, Vector3(65, 0, 0)], [0.2, Vector3(70, 0, 0)], [0.4, Vector3(65, 0, 0)], [0.6, Vector3(-70, 20, 0)], [0.8, Vector3(65, 0, 0)]]},
				"Arm_L": {"rot": [[0.0, Vector3(-45, 25, -20)], [0.4, Vector3(-40, 20, -15)], [0.8, Vector3(-45, 25, -20)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-45, -25, 20)], [0.4, Vector3(-40, -20, 15)], [0.8, Vector3(-45, -25, 20)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(0, -12, -6)], [0.2, Vector3(0, 12, 6)], [0.4, Vector3(0, -12, -6)], [0.6, Vector3(0, 12, 6)], [0.8, Vector3(0, -12, -6)]]},
			},
		},
		"dance_disco": {
			"len": 1.2, "loop": true, "bones": {
				"Pelvis": {"rot": [[0.0, Vector3(0, 0, -14)], [0.3, Vector3(0, 0, 14)], [0.6, Vector3(0, 0, -14)], [0.9, Vector3(0, 0, 14)], [1.2, Vector3(0, 0, -14)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-150, 30, 40)], [0.3, Vector3(20, -15, 15)], [0.6, Vector3(-150, 30, 40)], [0.9, Vector3(20, -15, 15)], [1.2, Vector3(-150, 30, 40)]]},
				"Arm_L": {"rot": [[0.0, Vector3(15, 10, -20)], [0.3, Vector3(-70, 25, -30)], [0.6, Vector3(15, 10, -20)], [0.9, Vector3(-70, 25, -30)], [1.2, Vector3(15, 10, -20)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(-12, 22, 0)], [0.3, Vector3(12, -12, 0)], [0.6, Vector3(-12, 22, 0)], [0.9, Vector3(12, -12, 0)], [1.2, Vector3(-12, 22, 0)]]},
			},
		},
		"dance_wiggle": {
			"len": 1.0, "loop": true, "bones": {
				"Torso": {"rot": [[0.0, Vector3(0, 20, -18)], [0.25, Vector3(0, -20, 18)], [0.5, Vector3(0, 20, -18)], [0.75, Vector3(0, -20, 18)], [1.0, Vector3(0, 20, -18)]]},
				"Arm_L": {"rot": [[0.0, Vector3(-90, 45, -40)], [0.25, Vector3(-20, -10, -12)], [0.5, Vector3(-90, 45, -40)], [0.75, Vector3(-20, -10, -12)], [1.0, Vector3(-90, 45, -40)]]},
				"Arm_R": {"rot": [[0.0, Vector3(-20, -10, 12)], [0.25, Vector3(-90, -45, 40)], [0.5, Vector3(-20, -10, 12)], [0.75, Vector3(-90, -45, 40)], [1.0, Vector3(-20, -10, 12)]]},
				"HeadPivot": {"rot": [[0.0, Vector3(18, -22, 12)], [0.25, Vector3(-18, 22, -12)], [0.5, Vector3(18, -22, 12)], [0.75, Vector3(-18, 22, -12)], [1.0, Vector3(18, -22, 12)]]},
			},
		},
	}


# ------------------------------------------------------------ public API --

func get_head_socket() -> Node3D:
	return _head_socket


func set_first_person_view(is_first_person: bool) -> void:
	_head_mesh.visible = not is_first_person
	if _hair_tuft_mesh:
		_hair_tuft_mesh.visible = not is_first_person
	_torso_mesh.visible = not is_first_person
	_legs_mesh.visible = not is_first_person
	_arms_mesh.visible = true


func set_wind_reaction(wind_vec: Vector3) -> void:
	wind_force_vector = wind_vec


func set_static_charge(charged: bool) -> void:
	is_static_charged = charged
	if _hair_tuft_mesh:
		_hair_tuft_mesh.scale = Vector3(1.7, 2.3, 1.7) if is_static_charged else Vector3.ONE


func play_anim(anim_name: String) -> void:
	if is_ragdoll:
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
	_pelvis_drop_target = 0.65
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
	skeleton.set_bone_pose_position(_b("Pelvis"), Vector3(0, PELVIS_REST_Y - _pelvis_drop, 0))
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
	if is_ragdoll:
		_apply_pelvis_drop(delta)
		return

	# 1. Parent linear velocity & acceleration
	var current_pos := global_position
	var current_vel := (current_pos - _last_parent_pos) / maxf(delta, 0.001)
	var raw_accel := (current_vel - _last_parent_vel) / maxf(delta, 0.001)
	var accel := raw_accel.clamp(Vector3(-15.0, -15.0, -15.0), Vector3(15.0, 15.0, 15.0))
	_last_parent_pos = current_pos
	_last_parent_vel = current_vel

	# 2. Wind reaction
	var wind_tilt_x: float = 0.0
	var wind_flail := Vector3.ZERO
	if wind_force_vector.length_squared() > 0.01:
		wind_tilt_x = clampf(wind_force_vector.z * 0.02, -0.35, 0.35)
		wind_flail = Vector3(
			sin(_time_passed * 16.0) * 15.0,
			cos(_time_passed * 14.0) * 12.0,
			sin(_time_passed * 18.0) * 20.0
		) * clampf(wind_force_vector.length() * 0.08, 0.0, 1.0)

	# 3. Active bobblehead spring
	var target_tilt := Vector3(
		clampf(-accel.z * 0.012 + wind_tilt_x, -0.3, 0.3),
		clampf(current_vel.x * 0.015, -0.25, 0.25),
		clampf(-accel.x * 0.012, -0.3, 0.3)
	)
	var spring_k := 160.0
	var damp := 12.0
	var force := (target_tilt - _head_spring_rot) * spring_k - (_head_velocity * damp)
	_head_velocity += force * delta
	_head_spring_rot += _head_velocity * delta
	skeleton.set_bone_pose_rotation(_b("HeadS"), Quaternion.from_euler(_rad(_head_spring_rot)))

	# 4. Arm spring reactions (wind flutter & static electricity jitter)
	var blend := clampf(delta * 12.0, 0.0, 1.0)
	var static_jitter_l := Vector3.ZERO
	var static_jitter_r := Vector3.ZERO
	if is_static_charged:
		static_jitter_l = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0), randf_range(-15.0, 15.0))
		static_jitter_r = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0), randf_range(-15.0, 15.0))

	_spring_rot_lerp("ArmS_L", wind_flail + static_jitter_l, blend)
	_spring_rot_lerp("ArmS_R", -wind_flail + static_jitter_r, blend)
	_spring_rot_lerp("ForearmS_L", wind_flail * 0.6, blend)
	_spring_rot_lerp("ForearmS_R", -wind_flail * 0.6, blend)


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
