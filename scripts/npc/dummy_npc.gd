class_name DummyNPC
extends CharacterBody3D

## Interactive Training Dummy NPC with networked HP bar, hit reaction shake, particle burst,
## and full compatibility for testing Thin character mechanics (Slingshot launching, Boulder crushing, Seismic pops).

signal health_changed(current: float, max_hp: float)
signal dummy_hit(damage: float, hit_position: Vector3)

@export var selected_character_id: String = "thin"
@export var max_health: float = 200.0
@export var current_health: float = 200.0
@export var auto_respawn_delay: float = 3.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hp_viewport: SubViewport = $SubViewport
@onready var hp_sprite_3d: Sprite3D = $HPSprite3D
@onready var hp_bar: ProgressBar = $SubViewport/Panel/VBox/HPBar
@onready var hp_label: Label = $SubViewport/Panel/VBox/HPLabel
@onready var particles: GPUParticles3D = $HitParticles

var is_dead: bool = false
var _original_mesh_scale: Vector3 = Vector3.ONE
var _original_mesh_pos: Vector3 = Vector3.ZERO
var _auto_heal_timer: float = 0.0
var _shake_tween: Tween

func _ready() -> void:
	current_health = max_health
	if mesh_instance:
		_original_mesh_scale = mesh_instance.scale
		_original_mesh_pos = mesh_instance.position

	update_hp_display()

func _physics_process(delta: float) -> void:
	# Flight and gravity physics when launched by Slingshot or Seismic pop
	if velocity.length_squared() > 0.01:
		if not is_on_floor():
			velocity.y -= 18.0 * delta
		velocity.x = lerpf(velocity.x, 0.0, 2.5 * delta)
		velocity.z = lerpf(velocity.z, 0.0, 2.5 * delta)
		move_and_slide()

func _process(delta: float) -> void:
	if current_health < max_health:
		_auto_heal_timer += delta
		if _auto_heal_timer >= auto_respawn_delay:
			current_health = lerpf(current_health, max_health, 2.0 * delta)
			if absf(current_health - max_health) < 0.5:
				current_health = max_health
				is_dead = false
			update_hp_display()

func take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO) -> void:
	rpc_take_damage.rpc(amount, hit_pos)

@rpc("any_peer", "call_local", "reliable")
func rpc_take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO) -> void:
	current_health = maxf(current_health - amount, 0.0)
	_auto_heal_timer = 0.0
	if current_health <= 0.0:
		is_dead = true

	health_changed.emit(current_health, max_health)
	dummy_hit.emit(amount, hit_pos)

	_play_hit_shake()
	_spawn_hit_particles(hit_pos)
	_spawn_floating_damage_text(amount, hit_pos)
	update_hp_display()

func update_hp_display() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	if hp_label:
		hp_label.text = "TEST DUMMY (THIN): %d / %d HP" % [int(current_health), int(max_health)]

func _play_hit_shake() -> void:
	if not mesh_instance:
		return

	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()

	mesh_instance.scale = _original_mesh_scale
	mesh_instance.position = _original_mesh_pos

	_shake_tween = create_tween()
	var shake_offset := Vector3(randf_range(-0.15, 0.15), randf_range(-0.08, 0.08), randf_range(-0.15, 0.15))
	var squish_scale := Vector3(_original_mesh_scale.x * 1.15, _original_mesh_scale.y * 0.85, _original_mesh_scale.z * 1.15)

	_shake_tween.tween_property(mesh_instance, "scale", squish_scale, 0.06)
	_shake_tween.parallel().tween_property(mesh_instance, "position", _original_mesh_pos + shake_offset, 0.06)

	_shake_tween.tween_property(mesh_instance, "scale", _original_mesh_scale, 0.12).set_trans(Tween.TRANS_SPRING)
	_shake_tween.parallel().tween_property(mesh_instance, "position", _original_mesh_pos, 0.12)

func _spawn_hit_particles(_hit_pos: Vector3) -> void:
	if particles:
		particles.position = Vector3(0, 1.0, 0)
		particles.restart()
		particles.emitting = true

func _spawn_floating_damage_text(amount: float, _hit_pos: Vector3) -> void:
	var text_pos := global_position + Vector3(randf_range(-0.3, 0.3), 2.2, randf_range(-0.3, 0.3))

	var label_3d := Label3D.new()
	label_3d.text = "-%d" % int(amount)
	label_3d.font_size = 36
	label_3d.outline_size = 8
	label_3d.modulate = Color(1.0, 0.2, 0.2, 1.0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Add to scene tree FIRST before setting global_position to prevent !is_inside_tree error
	get_tree().root.add_child(label_3d)
	label_3d.global_position = text_pos

	var tween := get_tree().create_tween()

	tween.tween_property(label_3d, "global_position:y", text_pos.y + 1.0, 0.75)
	tween.parallel().tween_property(label_3d, "modulate:a", 0.0, 0.75)
	tween.tween_callback(label_3d.queue_free)
