class_name StenchCloudZone
extends Area3D

## Test Stench Cloud Zone that constantly inflicts Nausea and toxic damage to any player standing inside its volume.

@export var damage_per_sec: float = 5.0
@export var nausea_per_sec: float = 0.45

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var gas_particles: GPUParticles3D = $GasParticles

var _damage_timer: float = 0.0

func _ready() -> void:
	if prompt_label:
		prompt_label.text = "🤢 ЗОНА ВОНИ (ТЕСТ ТОШНОТЫ)"
	if gas_particles:
		gas_particles.emitting = true

func _process(delta: float) -> void:
	var overlapping := get_overlapping_bodies()
	for body in overlapping:
		if body is Player:
			var player_node := body as Player
			# Trigger Nausea continuously while inside
			if player_node.has_method("trigger_nausea"):
				player_node.trigger_nausea(nausea_per_sec * delta)

	_damage_timer += delta
	if _damage_timer >= 1.0:
		_damage_timer = 0.0
		for body in overlapping:
			if body is Player and body.is_multiplayer_authority():
				body.take_damage(damage_per_sec)
