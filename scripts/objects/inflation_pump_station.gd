class_name InflationPumpStation
extends StaticBody3D

## Interactive Air Pump Hose Station for Fat & Thin balloon puzzles.

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt_label: Label3D = $PromptLabel3D

func _ready() -> void:
	if prompt_label:
		prompt_label.text = "🎈 [E] НАКАЧАТЬ ХУДОЩАВОГО!"

func _unhandled_input(event: InputEvent) -> void:
	var is_e_pressed: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E)
	if not is_e_pressed or not interaction_area:
		return

	var bodies: Array[Node3D] = interaction_area.get_overlapping_bodies()
	var fat_player: Player = null
	var thin_player: Player = null

	for body in bodies:
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat":
				fat_player = p
			elif p.selected_character_id.to_lower() == "thin":
				thin_player = p

	if fat_player and thin_player and fat_player.is_multiplayer_authority():
		get_viewport().set_input_as_handled()
		var infl_sys := fat_player.get_node_or_null("InflationSystem") as InflationSystem
		if infl_sys and not infl_sys.is_inflating and not infl_sys.is_balloon_mode:
			infl_sys.rpc_start_inflation.rpc(thin_player.get_path())
			print("🎈 PUMP STATION: Fat connected hose to Thin!")
