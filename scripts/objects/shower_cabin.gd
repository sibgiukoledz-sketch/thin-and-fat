class_name ShowerCabin
extends Area3D

## Continuous Automatic Shower Cabin that gradually washes away stench and heals HP while standing inside.

@export var wash_rate_per_sec: float = 25.0
@export var heal_rate_per_sec: float = 5.0

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var water_particles: GPUParticles3D = $WaterParticles

func _ready() -> void:
	if water_particles:
		water_particles.emitting = true # Continuous running water
	if prompt_label:
		prompt_label.text = "🚿 ДУШЕВАЯ (ПОСТЕПЕННОЕ МЫТЬЁ)"

func _process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("is_multiplayer_authority"):
			_wash_player_gradual(body as CharacterBody3D, delta)

func _wash_player_gradual(player_node: CharacterBody3D, delta: float) -> void:
	if not player_node:
		return

	if player_node.active_mechanics and player_node.active_mechanics is FatMechanics:
		var fat_mech := player_node.active_mechanics as FatMechanics
		if fat_mech.stench_level > 0.0:
			fat_mech.wash_stench_gradual(wash_rate_per_sec * delta)

	if player_node.is_multiplayer_authority() and player_node.current_health < player_node.max_health:
		player_node.heal(heal_rate_per_sec * delta)
