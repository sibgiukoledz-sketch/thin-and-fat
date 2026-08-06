class_name CharacterData
extends Resource

## Resource defining extensible stats and properties for playable characters.

@export var character_id: String = "thin"
@export var character_name: String = "Thin Character"
@export_multiline var description: String = "Fast and agile FPS character."

@export_group("Health & Combat")
@export var max_health: float = 100.0

@export_group("Stamina Stats")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_regen_rate: float = 20.0

@export_group("Movement Stats")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var crouch_speed: float = 3.0
@export var jump_velocity: float = 5.2
@export var air_accel_factor: float = 0.5

@export_group("Physical Dimensions")
@export var capsule_radius: float = 0.35
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var stand_head_y: float = 1.5
@export var crouch_head_y: float = 0.85

@export_group("Visual Style")
@export var body_color: Color = Color(0.2, 0.6, 0.95)
@export var mesh_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
