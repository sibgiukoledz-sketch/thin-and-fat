class_name FatMechanics
extends BaseCharacterMechanics

## Developer B File: Mechanics & Unique Abilities for "Fat / Жирдяй" character.

@export var slam_impulse: float = -20.0
@export var slam_cooldown: float = 3.0

var _slam_timer: float = 0.0

func update_mechanics(delta: float) -> void:
	if _slam_timer > 0.0:
		_slam_timer -= delta

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	# Ability 1: Heavy Slam down (E key, Right Click, or ability_1 action)
	var is_ability_pressed := false
	if InputMap.has_action("ability_1") and event.is_action_pressed("ability_1"):
		is_ability_pressed = true
	elif event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		is_ability_pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		is_ability_pressed = true

	if is_ability_pressed:
		trigger_slam()

func trigger_slam() -> void:
	if _slam_timer <= 0.0 and player and not player.is_on_floor():
		_slam_timer = slam_cooldown
		player.velocity.y = slam_impulse
		print("Fat Character triggered Ground Slam!")
