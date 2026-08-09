class_name SurfaceMaterial
extends Resource

## Data Resource defining surface properties, sound events, static electrification,
## and physical characteristics for world materials.

@export var material_id: String = "stone" ## Unique identifier (carpet, metal, wood, stone, glass, wool)
@export var display_name: String = "Камень"
@export var step_sound_event: String = "step_stone"
@export var impact_sound_event: String = "land"
@export var is_metallic: bool = false ## Attracts magnetized Thin character (ceiling/wall stick)
@export var is_static_charger: bool = false ## Charges Thin with static electricity when walked/rubbed on
@export var static_charge_rate: float = 40.0 ## Static charge gain per second of movement
@export var is_grounded: bool = false ## Discharges static electricity immediately when stepped on
@export var friction: float = 1.0
@export var bounciness: float = 0.0
@export var color_tint: Color = Color.WHITE
