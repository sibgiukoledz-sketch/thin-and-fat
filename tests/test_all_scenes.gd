extends SceneTree

func _initialize() -> void:
	print("--- Running Full Scene & Character Validation ---")
	var scenes_to_test := [
		"res://scenes/characters/fat_character.tscn",
		"res://scenes/characters/thin_character.tscn",
		"res://scenes/player.tscn",
		"res://scenes/main_menu.tscn",
	]
	var errs := 0
	for path in scenes_to_test:
		var sc := load(path) as PackedScene
		if sc == null:
			print("❌ Failed to load scene: %s" % path)
			errs += 1
			continue
		var inst := sc.instantiate()
		if inst == null:
			print("❌ Failed to instantiate scene: %s" % path)
			errs += 1
			continue
		root.add_child(inst)
		await process_frame
		await process_frame
		print("✅ Successfully instantiated & ticked: %s" % path)
		inst.queue_free()
		await process_frame

	if errs == 0:
		print("🎉 ALL SCENES PASSED VALIDATION")
		quit(0)
	else:
		print("❌ SCENE VALIDATION FAILED WITH %d ERRORS" % errs)
		quit(1)
