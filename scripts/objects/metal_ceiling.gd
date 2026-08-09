class_name MetalCeiling
extends Node3D

## Metal Ceiling Platform / Electromagnet:
## - Electrified Thin character clings to this ceiling when active (`is_magnetic = true`).
## - Can be toggled ON/OFF by HeavyLever to cut electromagnetic power!

signal magnetism_toggled(is_active: bool)

@export var is_magnetic: bool = true:
	set(val):
		is_magnetic = val
		_update_magnetism_visuals()
		magnetism_toggled.emit(is_magnetic)

@onready var surface_material_3d: SurfaceMaterial3D = get_node_or_null("SurfaceMaterial3D") as SurfaceMaterial3D
@onready var magnetic_light: OmniLight3D = get_node_or_null("MagneticLight") as OmniLight3D
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

func _ready() -> void:
	_update_magnetism_visuals()

@rpc("any_peer", "call_local", "reliable")
func rpc_set_magnetism(active: bool) -> void:
	set_magnetism(active)

func set_magnetism(active: bool) -> void:
	is_magnetic = active

func set_active(active: bool) -> void:
	rpc_set_magnetism.rpc(active)

func toggle_active() -> void:
	rpc_set_magnetism.rpc(not is_magnetic)

func disable_magnetism() -> void:
	rpc_set_magnetism.rpc(false)

func enable_magnetism() -> void:
	rpc_set_magnetism.rpc(true)

func _update_magnetism_visuals() -> void:
	if surface_material_3d and surface_material_3d.surface_material:
		surface_material_3d.surface_material.is_magnetic = is_magnetic

	if magnetic_light:
		magnetic_light.light_energy = 3.5 if is_magnetic else 0.2
		magnetic_light.light_color = Color(0.2, 0.85, 1.0) if is_magnetic else Color(0.3, 0.3, 0.3)
