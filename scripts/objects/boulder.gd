class_name HeavyBoulder
extends RigidBody3D

## Giant Rugged Boulder with native Godot 3D Rigid Body physics.
## Rolls, bounces, and collides realistically with terrain and objects.
## Only Fat character can lift and throw it. Crushes Thin player into a pancake if attempted!

signal boulder_picked_up(by_player: Node3D)
signal boulder_thrown(by_player: Node3D)
signal boulder_impact(position: Vector3)

@export var damage_on_impact: float = 75.0
@export var impact_radius: float = 5.5
@export var throw_force: float = 11.5

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea

var _is_carried: bool = false
var _carrier_player: Player = null
var _is_crushing: bool = false

# Lifting Interpolation
var _lift_progress: float = 1.0
var _lift_start_pos: Vector3 = Vector3.ZERO

# VFX nodes
var _dust_particles: GPUParticles3D
var _debris_particles: GPUParticles3D
var _warning_timer: float = 0.0
var _warning_text: String = ""
var _last_impact_time: float = 0.0

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
	body_entered.connect(_on_physics_body_entered)

	_setup_boulder_visuals()
	_setup_impact_vfx()
	_update_prompt()

func _setup_boulder_visuals() -> void:
	if mesh_instance:
		# Create large rugged sphere for boulder (Radius 1.8m)
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.8
		sphere.height = 3.4
		sphere.radial_segments = 24
		sphere.rings = 18

		# Generate rugged rock textures with normal map
		var textures: Array[ImageTexture] = _generate_rugged_rock_textures()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = textures[0]
		mat.normal_enabled = true
		mat.normal_texture = textures[1]
		mat.normal_scale = 2.5
		mat.roughness = 0.95
		mat.metallic = 0.05
		mat.uv1_scale = Vector3(3, 3, 3)
		sphere.material = mat

		mesh_instance.mesh = sphere

	if collision_shape and not collision_shape.shape:
		var caps: SphereShape3D = SphereShape3D.new()
		caps.radius = 1.8
		collision_shape.shape = caps

func _generate_rugged_rock_textures() -> Array[ImageTexture]:
	var width: int = 256
	var height: int = 256
	var albedo_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var normal_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 12345
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.04
	noise.fractal_octaves = 5

	var detail_noise: FastNoiseLite = FastNoiseLite.new()
	detail_noise.seed = 67890
	detail_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	detail_noise.frequency = 0.12

	for y in range(height):
		for x in range(width):
			var n: float = (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var dn: float = (detail_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var rock_val: float = clampf(n * 0.65 + dn * 0.35, 0.0, 1.0)

			# Dark granite stone color with natural variation
			var base_col: Color = Color(0.25, 0.22, 0.20, 1.0).lerp(Color(0.52, 0.47, 0.40, 1.0), rock_val)
			albedo_img.set_pixel(x, y, base_col)

			# Normal map displacement vector
			var nx: float = (noise.get_noise_2d(float(x + 1), float(y)) - noise.get_noise_2d(float(x - 1), float(y))) * 5.0
			var ny: float = (noise.get_noise_2d(float(x), float(y + 1)) - noise.get_noise_2d(float(x), float(y - 1))) * 5.0
			var normal_vec: Vector3 = Vector3(-nx, -ny, 1.0).normalized()
			var norm_col: Color = Color(normal_vec.x * 0.5 + 0.5, normal_vec.y * 0.5 + 0.5, normal_vec.z * 0.5 + 0.5, 1.0)
			normal_img.set_pixel(x, y, norm_col)

	var albedo_tex: ImageTexture = ImageTexture.create_from_image(albedo_img)
	var normal_tex: ImageTexture = ImageTexture.create_from_image(normal_img)
	return [albedo_tex, normal_tex]

func _setup_impact_vfx() -> void:
	# Dust cloud explosion
	_dust_particles = GPUParticles3D.new()
	_dust_particles.name = "ImpactDust"
	_dust_particles.amount = 60
	_dust_particles.lifetime = 1.6
	_dust_particles.one_shot = true
	_dust_particles.explosiveness = 0.96
	_dust_particles.emitting = false

	var mat_proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat_proc.direction = Vector3(0, 1, 0)
	mat_proc.spread = 85.0
	mat_proc.initial_velocity_min = 5.0
	mat_proc.initial_velocity_max = 12.0
	mat_proc.gravity = Vector3(0, -4.0, 0)
	mat_proc.scale_min = 0.5
	mat_proc.scale_max = 1.4
	mat_proc.color = Color(0.52, 0.46, 0.38, 0.75)

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.52, 0.46, 0.38, 0.65)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sphere: SphereMesh = SphereMesh.new()
	sphere.material = draw_mat
	sphere.radius = 0.35
	sphere.height = 0.7

	_dust_particles.process_material = mat_proc
	_dust_particles.draw_pass_1 = sphere
	add_child(_dust_particles)

	# Rock Debris Shards
	_debris_particles = GPUParticles3D.new()
	_debris_particles.name = "ImpactDebris"
	_debris_particles.amount = 40
	_debris_particles.lifetime = 1.2
	_debris_particles.one_shot = true
	_debris_particles.explosiveness = 0.98
	_debris_particles.emitting = false

	var dmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	dmat.direction = Vector3(0, 1, 0)
	dmat.spread = 70.0
	dmat.initial_velocity_min = 8.0
	dmat.initial_velocity_max = 15.0
	dmat.gravity = Vector3(0, -22.0, 0)
	dmat.scale_min = 0.12
	dmat.scale_max = 0.38
	dmat.color = Color(0.35, 0.32, 0.28, 1.0)

	var dmesh: BoxMesh = BoxMesh.new()
	var ddraw: StandardMaterial3D = StandardMaterial3D.new()
	ddraw.albedo_color = Color(0.35, 0.32, 0.28, 1.0)
	ddraw.roughness = 0.95
	dmesh.material = ddraw
	dmesh.size = Vector3(0.2, 0.2, 0.2)

	_debris_particles.process_material = dmat
	_debris_particles.draw_pass_1 = dmesh
	add_child(_debris_particles)

func _update_prompt() -> void:
	if not prompt_label:
		return

	if _warning_timer > 0.0:
		prompt_label.text = _warning_text
		prompt_label.modulate = Color(1.0, 0.2, 0.2)
	elif _is_carried:
		prompt_label.text = "🪨 ГИГАНТСКИЙ ВАЛУН В РУКАХ ЖИРДЯЯ!\n[E] / [ЛКМ] — БРОСИТЬ ВАЛУН!"
		prompt_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		prompt_label.text = "🪨 ГИГАНТСКИЙ ТЯЖЁЛЫЙ ВАЛУН\n[E] — Поднять (Только для Жирдяя)"
		prompt_label.modulate = Color(1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0:
			_update_prompt()

	# Handling smooth physical carrying position above Fat player's head
	if _is_carried and is_instance_valid(_carrier_player):
		var target_pos: Vector3 = _carrier_player.global_position + Vector3(0, 3.2, 0)

		if _lift_progress < 1.0:
			_lift_progress = minf(_lift_progress + delta * 1.8, 1.0)
			var ease_p: float = 1.0 - pow(1.0 - _lift_progress, 3.0) # Smooth heavy cubic lift
			global_position = _lift_start_pos.lerp(target_pos, ease_p)
		else:
			global_position = global_position.lerp(target_pos, 18.0 * delta)

		rotation = _carrier_player.rotation

func _unhandled_input(event: InputEvent) -> void:
	var is_interact_pressed: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E)
	var is_lmb_pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)

	# Case 1: Fat player is carrying boulder -> THROW IT!
	if _is_carried and _carrier_player and _carrier_player.is_multiplayer_authority():
		if is_interact_pressed or is_lmb_pressed:
			get_viewport().set_input_as_handled()
			var throw_dir: Vector3 = -_carrier_player.global_transform.basis.z
			if _carrier_player.camera_3d:
				throw_dir = -_carrier_player.camera_3d.global_transform.basis.z
			
			# Arc upwards for massive heavy throw trajectory
			throw_dir = (throw_dir + Vector3(0, 0.30, 0)).normalized()
			rpc_throw_boulder.rpc(_carrier_player.global_position + Vector3(0, 2.5, 0), throw_dir * throw_force)
			return

	# Case 2: Player is standing near boulder and tries to pick it up
	if not _is_carried and not _is_crushing and is_interact_pressed and interaction_area:
		var bodies: Array[Node3D] = interaction_area.get_overlapping_bodies()
		for body in bodies:
			if body is Player and (body as Player).is_multiplayer_authority():
				var player_node: Player = body as Player
				_attempt_pick_up(player_node)
				get_viewport().set_input_as_handled()
				break

func _attempt_pick_up(player_node: Player) -> void:
	if player_node.selected_character_id.to_lower() != "fat":
		# THIN PLAYER TRIED TO LIFT -> CRUSH THIN PLAYER INTO A PANCAKE!
		rpc_crush_player.rpc(player_node.get_path())
		print("💥 THIN PLAYER SQUASHED BY BOULDER!")
		return

	# FAT PLAYER LIFTS BOULDER REALISTICALLY
	rpc_pick_up_boulder.rpc(player_node.get_path())

func _show_warning(msg: String) -> void:
	_warning_text = msg
	_warning_timer = 3.0
	_update_prompt()

@rpc("any_peer", "call_local", "reliable")
func rpc_crush_player(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p:
		return

	_is_crushing = true
	freeze = true
	_show_warning("💥 СЛИШКОМ ТЯЖЁЛЫЙ ВАЛУН!\nТонкого раздавило в лепёшку!")

	# Dust and debris crushing explosion at Thin's feet
	if _dust_particles:
		_dust_particles.global_position = p.global_position
		_dust_particles.restart()
		_dust_particles.emitting = true
	if _debris_particles:
		_debris_particles.global_position = p.global_position
		_debris_particles.restart()
		_debris_particles.emitting = true

	# Tilt physical boulder over onto Thin player
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", p.global_position + Vector3(0, 0.8, 0), 0.4)

	# Deal lethal crushing physical HP damage ONLY (NO NAUSEA!)
	p.take_damage(150.0, p.global_position)

	get_tree().create_timer(1.2).timeout.connect(func():
		freeze = false
		_is_crushing = false
	)

@rpc("any_peer", "call_local", "reliable")
func rpc_pick_up_boulder(player_path: NodePath) -> void:
	var p: Player = get_node_or_null(player_path) as Player
	if not p:
		return

	_is_carried = true
	_carrier_player = p
	p.is_carrying_heavy_object = true
	freeze = true # Disable rigid physics body while carried by Fat
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	_lift_progress = 0.0
	_lift_start_pos = global_position
	_update_prompt()

	# Heavy lifting camera shudder for local player
	if p.is_multiplayer_authority() and p.camera_3d:
		p.camera_3d.rotation.z = deg_to_rad(8.0)

	# Particle dust puff at feet on lift
	if _dust_particles:
		_dust_particles.global_position = p.global_position
		_dust_particles.restart()
		_dust_particles.emitting = true

	boulder_picked_up.emit(p)
	print("🪨 REALISTIC HEAVY LIFT: Boulder lifted by %s!" % p.name)

@rpc("any_peer", "call_local", "reliable")
func rpc_throw_boulder(start_pos: Vector3, initial_velocity: Vector3) -> void:
	global_position = start_pos
	if _carrier_player:
		_carrier_player.is_carrying_heavy_object = false
		boulder_thrown.emit(_carrier_player)
		_carrier_player = null

	_is_carried = false
	freeze = false # Enable full RigidBody3D 3D physics!

	# Apply heavy linear velocity impulse & forward roll torque!
	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-4.0, -7.0), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))

	_update_prompt()
	print("🪨 REALISTIC HEAVY THROW! Velocity: %s" % str(initial_velocity))

func _on_physics_body_entered(body: Node) -> void:
	var cur_time: float = Time.get_ticks_msec() * 0.001
	if cur_time - _last_impact_time < 0.2:
		return

	var speed: float = linear_velocity.length()
	if speed > 3.5:
		_last_impact_time = cur_time
		var impact_pos: Vector3 = global_position

		# Emit visual particles
		if _dust_particles:
			_dust_particles.global_position = impact_pos
			_dust_particles.restart()
			_dust_particles.emitting = true
		if _debris_particles:
			_debris_particles.global_position = impact_pos
			_debris_particles.restart()
			_debris_particles.emitting = true

		# Deal physical crushing damage ONLY (NO NAUSEA!)
		if body is Node3D and body != self and body != _carrier_player:
			if body.has_method("take_damage"):
				var dmg: float = clampf(speed * 3.5, 25.0, damage_on_impact)
				body.take_damage(dmg, (body as Node3D).global_position)
				print("💥 PHYSICAL BOULDER CRUSH: Dealt %.1f damage to %s" % [dmg, body.name])

		_apply_impact_aoe_damage(impact_pos, speed)
		boulder_impact.emit(impact_pos)

func _apply_impact_aoe_damage(center: Vector3, speed: float) -> void:
	var root: Node = get_tree().root
	_damage_nodes_recursive(root, center, speed)

func _damage_nodes_recursive(node: Node, center: Vector3, speed: float) -> void:
	if not node:
		return

	if node is Node3D and node != self and node != _carrier_player:
		var n3d: Node3D = node as Node3D
		var dist: float = center.distance_to(n3d.global_position)
		if dist <= impact_radius:
			if node.has_method("take_damage"):
				var falloff: float = 1.0 - (dist / impact_radius)
				var final_dmg: float = maxf(damage_on_impact * (speed / 15.0) * falloff, 15.0)
				# PHYSICAL DAMAGE ONLY (NO NAUSEA!)
				node.take_damage(final_dmg, n3d.global_position)

	for child in node.get_children():
		_damage_nodes_recursive(child, center, speed)

func _on_interaction_body_entered(body: Node) -> void:
	if not _is_carried and body is Player:
		var p: Player = body as Player
		if p.is_multiplayer_authority() and p.selected_character_id.to_lower() == "fat":
			_update_prompt()
