class_name SurfaceDetectorComponent
extends Node3D

## Player Component that detects ground, ceiling, and wall SurfaceMaterials.
## Triggers material-specific footsteps, landing SFX, and static electrification/grounding events.

signal surface_changed(new_material: SurfaceMaterial)
signal touched_static_charger(surface: SurfaceMaterial, delta: float)
signal touched_grounded_surface(surface: SurfaceMaterial)

@export var ray_length: float = 1.4
@export var overhead_ray_length: float = 6.0
@export var forward_ray_length: float = 1.4

var current_ground_material: SurfaceMaterial = null
var current_ceiling_material: SurfaceMaterial = null
var current_wall_material: SurfaceMaterial = null

var _ground_ray: RayCast3D
var _overhead_ray: RayCast3D
var _forward_ray: RayCast3D
var _player: CharacterBody3D

func setup(player: CharacterBody3D) -> void:
	_player = player
	_setup_rays()

func _setup_rays() -> void:
	if not _ground_ray:
		_ground_ray = RayCast3D.new()
		_ground_ray.name = "GroundMaterialRay"
		_ground_ray.target_position = Vector3(0, -ray_length, 0)
		_ground_ray.collision_mask = 1 | 4
		add_child(_ground_ray)

	if not _overhead_ray:
		_overhead_ray = RayCast3D.new()
		_overhead_ray.name = "OverheadMaterialRay"
		_overhead_ray.target_position = Vector3(0, overhead_ray_length, 0)
		_overhead_ray.collision_mask = 1 | 4
		add_child(_overhead_ray)

	if not _forward_ray:
		_forward_ray = RayCast3D.new()
		_forward_ray.name = "ForwardMaterialRay"
		_forward_ray.target_position = Vector3(0, 0, -forward_ray_length)
		_forward_ray.collision_mask = 1 | 4
		add_child(_forward_ray)

func check_surfaces(delta: float) -> void:
	var prev_mat := current_ground_material
	current_ground_material = _detect_material_from_ray(_ground_ray)
	current_ceiling_material = _detect_material_from_ray(_overhead_ray)
	current_wall_material = _detect_material_from_ray(_forward_ray)

	if current_ground_material != prev_mat:
		surface_changed.emit(current_ground_material)

	if current_ground_material:
		if current_ground_material.is_static_charger:
			touched_static_charger.emit(current_ground_material, delta)
		if current_ground_material.is_grounded:
			touched_grounded_surface.emit(current_ground_material)

func _detect_material_from_ray(ray: RayCast3D) -> SurfaceMaterial:
	if not ray or not ray.is_colliding():
		return null

	var collider := ray.get_collider()
	if not collider or not (collider is Node):
		return null

	var collider_node := collider as Node
	var surf_comp := collider_node.get_node_or_null("SurfaceMaterial3D") as SurfaceMaterial3D
	if surf_comp and surf_comp.surface_material:
		return surf_comp.surface_material

	for child in collider_node.get_children():
		if child is SurfaceMaterial3D and child.surface_material:
			return child.surface_material

	if collider_node.has_meta("surface_material"):
		var meta_val = collider_node.get_meta("surface_material")
		if meta_val is SurfaceMaterial:
			return meta_val

	return null

func play_footstep_sound(character_id: String, is_sprinting: bool = false) -> void:
	if not _player:
		return

	var sfx_name := "step_" + character_id.to_lower()
	if current_ground_material and current_ground_material.step_sound_event != "":
		sfx_name = current_ground_material.step_sound_event

	var vol_db := 2.0 if is_sprinting else -2.0
	if AudioManager:
		AudioManager.play_sfx_3d(sfx_name, _player.global_position, 35.0, vol_db)

func play_landing_sound(_character_id: String, fall_impact: float) -> void:
	if not _player:
		return

	var sfx_name := "land"
	if current_ground_material and current_ground_material.impact_sound_event != "":
		sfx_name = current_ground_material.impact_sound_event

	var vol_db := clampf((fall_impact - 2.0) * 0.7, -4.0, 6.0)
	if AudioManager:
		AudioManager.play_sfx_3d(sfx_name, _player.global_position, 40.0, vol_db)
