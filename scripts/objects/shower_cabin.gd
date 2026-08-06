class_name ShowerCabin
extends Area3D

## Continuous Automatic Shower Cabin that constantly runs water and automatically cleans/heals players on walk-in.

@export var heal_amount: float = 20.0
@export var auto_clean_interval: float = 2.0

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var water_particles: GPUParticles3D = $WaterParticles

var _wash_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if water_particles:
		water_particles.emitting = true # Continuous running water
	if prompt_label:
		prompt_label.text = "🚿 ДУШЕВАЯ (АВТО-МЫТЬЁ)"

func _process(delta: float) -> void:
	# Continuously wash any player standing inside the shower
	var overlapping := get_overlapping_bodies()
	var has_fat_player := false

	for body in overlapping:
		if body is Player:
			has_fat_player = true
			_wash_player_instant(body)

	if has_fat_player:
		_wash_timer += delta
		if _wash_timer >= auto_clean_interval:
			_wash_timer = 0.0
			for body in overlapping:
				if body is Player and body.is_multiplayer_authority():
					body.heal(heal_amount)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_wash_player_instant(body as Player)

func _wash_player_instant(player_node: Player) -> void:
	if player_node and player_node.active_mechanics and player_node.active_mechanics is FatMechanics:
		var fat_mech := player_node.active_mechanics as FatMechanics
		if fat_mech.stench_level > 0.0:
			fat_mech.wash_stench()
