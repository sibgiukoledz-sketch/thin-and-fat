class_name ThinMechanics
extends BaseCharacterMechanics

## Developer A File: Mechanics & Unique Abilities for "Thin / Высокий" character.

@export var dash_speed: float = 18.0
@export var dash_cooldown: float = 2.0

var _dash_timer: float = 0.0

func update_mechanics(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	# Ability 1: Air Dash (E or Right Click)
	if event.is_action_pressed("ability_1") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		trigger_dash()

func trigger_dash() -> void:
	if _dash_timer <= 0.0 and player:
		_dash_timer = dash_cooldown
		var dash_dir := -player.transform.basis.z
		player.velocity = dash_dir * dash_speed
		print("Thin Character used Dash!")
