class_name VomitPuddle
extends Area3D

## Vomit Puddle hazard created on floor when a nauseous player retches.

@export var lifetime: float = 20.0
@export var extra_nausea: float = 0.35

var _life_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_life_timer += delta
	if _life_timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if p.has_method("trigger_nausea"):
			p.trigger_nausea(extra_nausea)
			print("🤢 STEPPED IN VOMIT: Increased nausea for %s" % p.name)
