class_name CharacterVisualLoader
extends Node

## Character Visual Loader Component:
## - Instantiates 3D character scenes (fat_character.tscn / thin_character.tscn)
## - Manages ragdoll start & stop triggers
## - Handles fallback procedural skeleton generation if scene files are missing

var character_model: Node3D = null
var is_ragdoll_active: bool = false

func build_visuals(mesh_instance: MeshInstance3D, is_fat: bool) -> Node3D:
	if not mesh_instance:
		return null

	for child in mesh_instance.get_children():
		child.queue_free()

	mesh_instance.mesh = null
	var scene_path := "res://scenes/characters/%s_character.tscn" % ("fat" if is_fat else "thin")
	if ResourceLoader.exists(scene_path):
		var char_scene := load(scene_path) as PackedScene
		if char_scene:
			character_model = char_scene.instantiate() as Node3D
			character_model.rotation_degrees.y = 0.0
			mesh_instance.add_child(character_model)
			print("🎨 LOADED CHARACTER SCENE: %s" % scene_path)
			return character_model

	print("⚠️ Scene not found at %s" % scene_path)
	return null

func start_ragdoll(velocity: Vector3, mesh_instance: MeshInstance3D) -> void:
	is_ragdoll_active = true
	if character_model and character_model.has_method("start_ragdoll"):
		character_model.call("start_ragdoll", velocity)
	elif mesh_instance:
		mesh_instance.show()

func stop_ragdoll(mesh_instance: MeshInstance3D) -> void:
	is_ragdoll_active = false
	if character_model and character_model.has_method("stop_ragdoll"):
		character_model.call("stop_ragdoll")
	if mesh_instance:
		mesh_instance.rotation = Vector3.ZERO
