class_name InflationPumpStation
extends StaticBody3D

## Scene-friendly Physical 3D Inflation Hose Object (Standalone Hose on Floor).
## Can be edited directly in Godot Scene Editor (scenes/objects/inflation_pump_station.tscn)!
## Flow:
## 1. Fat walks up to the hose on floor and presses [F] to GRAB IT.
## 2. Hose attaches: End 1 -> Fat's mouth, End 2 -> Fat's hand!
## 3. Fat walks to Thin and presses [F] -> End 2 connects to Thin to inflate!

signal hose_grabbed(by_player: Player)
signal hose_connected(fat: Player, thin: Player)

@export var interaction_radius: float = 3.0

var is_hose_taken: bool = false
var hose_carrier: Player = null

@onready var hose_ground_node: Node3D = $StandaloneHose3D
@onready var hose_pickup_area: Area3D = $HosePickupArea
@onready var prompt_label: Label3D = $PromptLabel
@onready var title_label: Label3D = $TitleLabel

# Stretched hose lines (Origin -> Mouth, Mouth -> Hand / Thin)
var _stretched_mesh_mouth: ImmediateMesh
var _stretched_rope_mouth: MeshInstance3D
var _stretched_mesh_hand: ImmediateMesh
var _stretched_rope_hand: MeshInstance3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_setup_stretched_hoses()

func _setup_stretched_hoses() -> void:
	var rope_mat := StandardMaterial3D.new()
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_mat.albedo_color = Color(0.12, 0.78, 0.92, 1.0)

	# 1. Line from floor origin -> Fat's Mouth
	_stretched_mesh_mouth = ImmediateMesh.new()
	_stretched_rope_mouth = MeshInstance3D.new()
	_stretched_rope_mouth.name = "StretchedHoseToMouth"
	_stretched_rope_mouth.top_level = true
	_stretched_rope_mouth.mesh = _stretched_mesh_mouth
	_stretched_rope_mouth.material_override = rope_mat
	_stretched_rope_mouth.hide()
	add_child(_stretched_rope_mouth)

	# 2. Line from Fat's Mouth -> Fat's Hand (or Thin)
	_stretched_mesh_hand = ImmediateMesh.new()
	_stretched_rope_hand = MeshInstance3D.new()
	_stretched_rope_hand.name = "StretchedHoseToHand"
	_stretched_rope_hand.top_level = true
	_stretched_rope_hand.mesh = _stretched_mesh_hand
	_stretched_rope_hand.material_override = rope_mat
	_stretched_rope_hand.hide()
	add_child(_stretched_rope_hand)

func _process(_delta: float) -> void:
	_update_prompt_visibility()
	_update_stretched_hoses()

func _update_prompt_visibility() -> void:
	if not hose_pickup_area or not prompt_label:
		return

	if is_hose_taken:
		prompt_label.hide()
		return

	var show := false
	var bodies := hose_pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat" and p.is_multiplayer_authority():
				show = true
				break

	prompt_label.visible = show

func _update_stretched_hoses() -> void:
	if not _stretched_mesh_mouth or not _stretched_mesh_hand:
		return

	_stretched_mesh_mouth.clear_surfaces()
	_stretched_mesh_hand.clear_surfaces()

	if not is_hose_taken or not hose_carrier or not is_instance_valid(hose_carrier):
		_stretched_rope_mouth.hide()
		_stretched_rope_hand.hide()
		return

	# Anchors:
	var hose_origin: Vector3 = global_position + Vector3(0, 0.12, 0)
	var fat_mouth: Vector3 = hose_carrier.global_position + Vector3(0, 1.45, 0.25)
	var fat_hand: Vector3 = hose_carrier.global_position + Vector3(0.4, 0.85, 0.3)

	var infl_sys := hose_carrier.get_node_or_null("InflationSystem") as InflationSystem
	var target_end: Vector3 = fat_hand

	# If connected to Thin for pumping, End 2 goes from Fat's mouth -> Thin!
	if infl_sys and infl_sys.is_inflating and infl_sys.tether_partner and is_instance_valid(infl_sys.tether_partner):
		target_end = infl_sys.tether_partner.global_position + Vector3(0, 1.0, 0)

	# 1. Draw Line 1: Hose Floor Origin -> Fat's Mouth
	_stretched_rope_mouth.show()
	_stretched_mesh_mouth.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segs1: int = 14
	var sag1: float = 0.65
	for i in range(segs1 + 1):
		var t: float = float(i) / float(segs1)
		var pos: Vector3 = hose_origin.lerp(fat_mouth, t)
		pos.y -= sin(t * PI) * sag1 * (1.0 - t * 0.4)
		_stretched_mesh_mouth.surface_add_vertex(pos)
	_stretched_mesh_mouth.surface_end()

	# 2. Draw Line 2: Fat's Mouth -> Fat's Hand (or Thin)
	_stretched_rope_hand.show()
	_stretched_mesh_hand.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segs2: int = 10
	var sag2: float = 0.25
	for i in range(segs2 + 1):
		var t: float = float(i) / float(segs2)
		var pos: Vector3 = fat_mouth.lerp(target_end, t)
		pos.y -= sin(t * PI) * sag2
		_stretched_mesh_hand.surface_add_vertex(pos)
	_stretched_mesh_hand.surface_end()

# =================== RPC: GRAB / RETURN HOSE ===================

@rpc("any_peer", "call_local", "reliable")
func rpc_grab_hose(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p or is_hose_taken:
		return

	is_hose_taken = true
	hose_carrier = p

	if hose_ground_node:
		hose_ground_node.hide()

	print("🎈 HOSE GRABBED by %s (Attached to Mouth & Hand)!" % p.name)
	hose_grabbed.emit(p)

@rpc("any_peer", "call_local", "reliable")
func rpc_return_hose() -> void:
	is_hose_taken = false
	hose_carrier = null

	if hose_ground_node:
		hose_ground_node.show()

	_stretched_rope_mouth.hide()
	_stretched_rope_hand.hide()
	print("🎈 HOSE RETURNED to floor.")

func get_hose_nozzle_world_pos() -> Vector3:
	return global_position + Vector3(2.38, 0.08, 0.25)
