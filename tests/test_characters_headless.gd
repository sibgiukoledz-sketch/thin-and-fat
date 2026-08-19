extends SceneTree
## Headless validation for the procedurally-built HFF-style characters.
## Run: godot --headless --path . --script res://tests/test_characters_headless.gd

const ANIMS := ["idle", "walk", "sprint", "crouch", "crouch_walk", "jump", "dance_kazachok", "dance_disco", "dance_wiggle"]
const CASES := [
	{"scene": "res://scenes/characters/fat_character.tscn", "bones": 17, "head_y": 1.82},
	{"scene": "res://scenes/characters/thin_character.tscn", "bones": 18, "head_y": 2.47},
]

var _failures := 0


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_failures += 1
	push_error("TEST FAIL: " + msg)
	print("FAIL: " + msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		_fail(msg)


func _run() -> void:
	for case in CASES:
		await _test_character(case)
	if _failures == 0:
		print("ALL CHARACTER TESTS PASSED")
		quit(0)
	else:
		print("CHARACTER TESTS FAILED: %d" % _failures)
		quit(1)


func _test_character(case: Dictionary) -> void:
	print("== Testing %s ==" % case["scene"])
	var packed := load(case["scene"]) as PackedScene
	if packed == null:
		_fail("scene failed to load")
		return
	var chr := packed.instantiate()
	root.add_child(chr)
	await process_frame
	await process_frame

	var skel: Skeleton3D = chr.get_node_or_null("Skeleton3D")
	_check(skel != null, "Skeleton3D exists")
	if skel == null:
		return
	_check(skel.get_bone_count() == case["bones"], "bone count == %d (got %d)" % [case["bones"], skel.get_bone_count()])

	var total_verts := 0
	var mesh_names := ["TorsoMesh", "HeadMesh", "ArmsMesh", "LegsMesh"]
	if chr is ThinCharacter:
		mesh_names.append("HairTuftMesh")
	for mesh_name in mesh_names:
		var mi: MeshInstance3D = chr.get_node_or_null(mesh_name)
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
			_fail("missing/empty mesh " + mesh_name)
			continue
		var arrays := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones_a: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var wts_a: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		total_verts += verts.size()
		_check(verts.size() > 0, "%s: has %d verts" % [mesh_name, verts.size()])
		_check(bones_a.size() == verts.size() * 4 and wts_a.size() == verts.size() * 4, "%s: bones/weights arrays sized x4" % mesh_name)
		# spot-check weight normalization on every 10th vertex
		var ok_weights := true
		for vi in range(0, verts.size(), 10):
			var s := wts_a[vi * 4] + wts_a[vi * 4 + 1] + wts_a[vi * 4 + 2] + wts_a[vi * 4 + 3]
			if absf(s - 1.0) > 0.01:
				ok_weights = false
				break
		_check(ok_weights, "%s: skin weights normalized" % mesh_name)
		# bone indices in range
		var ok_bones := true
		for bi in bones_a:
			if bi < 0 or bi >= skel.get_bone_count():
				ok_bones = false
				break
		_check(ok_bones, "%s: bone indices valid" % mesh_name)

	print("  total skinned verts: %d" % total_verts)

	# AnimationPlayer + every clip
	var ap: AnimationPlayer = chr.get_node_or_null("AnimationPlayer")
	_check(ap != null, "AnimationPlayer exists")
	if ap:
		for anim_name in ANIMS:
			if not ap.has_animation(anim_name):
				_fail("missing animation: " + anim_name)
			else:
				chr.play_anim(anim_name)
				await process_frame
				if ap.current_animation != anim_name:
					_fail("play_anim did not switch to " + anim_name)
		print("  ok: all %d animations playable" % ANIMS.size())

	# Head socket follows the head bone
	await process_frame
	var socket: Node3D = chr.get_head_socket()
	_check(socket != null, "head socket exists")
	if socket:
		var expected: float = case["head_y"]
		_check(absf(socket.global_position.y - expected) < 0.15, "head socket y ~ %.2f (got %.2f)" % [expected, socket.global_position.y])

	# First-person culling toggles visibility without errors
	chr.set_first_person_view(true)
	await process_frame
	chr.set_first_person_view(false)
	await process_frame
	print("  ok: first person view toggled")

	# Ragdoll round-trip
	chr.start_ragdoll(Vector3.ONE)
	await create_timer(0.15).timeout
	chr.stop_ragdoll()
	await process_frame
	print("  ok: ragdoll round-trip")

	chr.queue_free()
