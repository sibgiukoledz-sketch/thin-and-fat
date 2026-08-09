class_name SurfaceMaterial3D
extends Node

## World component node attached to 3D objects/meshes/bodies to define their SurfaceMaterial.

@export var surface_material: SurfaceMaterial

func get_material() -> SurfaceMaterial:
	return surface_material
