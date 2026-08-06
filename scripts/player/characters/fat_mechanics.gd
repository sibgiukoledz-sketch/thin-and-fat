class_name FatMechanics
extends BaseCharacterMechanics

## Dedicated Controller for "Fat / Жирдяй" character mechanics & unique abilities.

signal slam_performed(position: Vector3)
signal charge_performed

@export_group("Ground Slam Stats")
@export var slam_impulse: float = -26.0
@export var slam_cooldown: float = 3.0
@export var slam_shockwave_radius: float = 6.0

@export_group("Heavy Charge Stats")
@export var charge_speed: float = 16.0
@export var charge_duration: float = 0.6
@export var charge_cooldown: float = 5.0

var _slam_cooldown_timer: float = 0.0
var _charge_cooldown_timer: float = 0.0
var _is_charging: bool = false
var _charge_timer: float = 0.0
var _is_slamming: bool = false

func update_mechanics(delta: float) -> void:
	if _slam_cooldown_timer > 0.0:
		_slam_cooldown_timer -= delta
	if _charge_cooldown_timer > 0.0:
		_charge_cooldown_timer -= delta

	if _is_charging:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_is_charging = false

	# Detect impact when slamming into ground
	if _is_slamming and player and player.is_on_floor():
		_is_slamming = false
		_on_slam_impact()

func physics_update_mechanics(delta: float) -> void:
	if _is_charging and player and player.is_multiplayer_authority():
		var forward_dir := -player.transform.basis.z
		player.velocity.x = forward_dir.x * charge_speed
		player.velocity.z = forward_dir.z * charge_speed

func handle_ability_input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	# Ability 1: Ground Slam (E key or Right Click)
	var is_slam_pressed := false
	if InputMap.has_action("ability_1") and event.is_action_pressed("ability_1"):
		is_slam_pressed = true
	elif event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		is_slam_pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		is_ability_pressed_right_click(event)
		is_slam_pressed = true

	if is_slam_pressed:
		trigger_slam()

	# Ability 2: Heavy Body Charge (F key or Middle Mouse Button)
	var is_charge_pressed := false
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		is_charge_pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		is_charge_pressed = true

	if is_charge_pressed:
		trigger_charge()

func is_ability_pressed_right_click(event: InputEventMouseButton) -> bool:
	return event.button_index == MOUSE_BUTTON_RIGHT and event.pressed

func trigger_slam() -> void:
	if _slam_cooldown_timer <= 0.0 and player and not player.is_on_floor():
		_slam_cooldown_timer = slam_cooldown
		_is_slamming = true
		player.velocity.y = slam_impulse
		print("🦛 FAT: Executing Heavy Ground Slam!")

func trigger_charge() -> void:
	if _charge_cooldown_timer <= 0.0 and player and player.is_on_floor():
		_charge_cooldown_timer = charge_cooldown
		_is_charging = true
		_charge_timer = charge_duration
		charge_performed.emit()
		print("🦛 FAT: Executing Heavy Body Charge!")

func _on_slam_impact() -> void:
	if player:
		slam_performed.emit(player.global_position)
		rpc_create_shockwave_effect.rpc(player.global_position)
		print("🦛 FAT: Slam Impact Created Shockwave at ", player.global_position)

@rpc("any_peer", "call_local", "reliable")
func rpc_create_shockwave_effect(impact_pos: Vector3) -> void:
	if not player:
		return
	# Visual ring pulse on impact
	var mesh_inst := MeshInstance3D.new()
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 0.2
	torus_mesh.outer_radius = 1.0

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.8) # Orange shockwave ring
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus_mesh.material = mat

	mesh_inst.mesh = torus_mesh
	mesh_inst.global_position = impact_pos + Vector3(0, 0.1, 0)
	player.get_tree().root.add_child(mesh_inst)

	var tween := player.get_tree().create_tween()
	tween.tween_property(mesh_inst, "scale", Vector3(5.0, 1.0, 5.0), 0.3)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(mesh_inst.queue_free)
