class_name VomitComponent
extends Node

## Component managing Vomit Particle Systems, Nausea Post-Processing, Retching Animations, and Vomit Puddle Spawning.

var player: Player

# Particle Emitters
var _vomit_particles: GPUParticles3D
var _vomit_splatter: GPUParticles3D
var _vomit_chunks: GPUParticles3D

# Nausea & Vomit Timers
var nausea_intensity: float = 0.0
var _vomit_cooldown_timer: float = 0.0
var _vomit_anim_timer: float = 0.0
var _severe_nausea_duration: float = 0.0

func _ready() -> void:
	if owner and owner is Player:
		player = owner as Player
	elif get_parent() is Player:
		player = get_parent() as Player

	_setup_vomit_particles()

func _setup_vomit_particles() -> void:
	if not player or not player.head or _vomit_particles:
		return

	# 1. Main Vomit Stream
	_vomit_particles = GPUParticles3D.new()
	_vomit_particles.name = "VomitStream"
	_vomit_particles.amount = 100
	_vomit_particles.lifetime = 1.4
	_vomit_particles.one_shot = true
	_vomit_particles.explosiveness = 0.7
	_vomit_particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -0.35, -1.0)
	mat.spread = 16.0
	mat.initial_velocity_min = 4.5
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -11.0, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.5
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.52, 0.62, 0.1, 0.95)

	var mesh: SphereMesh = SphereMesh.new()
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.48, 0.58, 0.08, 0.92)
	draw_mat.roughness = 0.06
	draw_mat.metallic = 0.1
	draw_mat.metallic_specular = 0.7
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	mesh.radius = 0.08
	mesh.height = 0.16

	_vomit_particles.process_material = mat
	_vomit_particles.draw_pass_1 = mesh
	_vomit_particles.transform.origin = Vector3(0, -0.15, -0.38)
	player.head.add_child(_vomit_particles)

	# 2. Splatter Spray
	var splatter: GPUParticles3D = GPUParticles3D.new()
	splatter.name = "VomitSplatter"
	splatter.amount = 50
	splatter.lifetime = 1.0
	splatter.one_shot = true
	splatter.explosiveness = 0.88
	splatter.emitting = false

	var smat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smat.direction = Vector3(0, -0.2, -1.0)
	smat.spread = 42.0
	smat.initial_velocity_min = 2.5
	smat.initial_velocity_max = 6.0
	smat.gravity = Vector3(0, -14.0, 0)
	smat.scale_min = 0.03
	smat.scale_max = 0.09
	smat.color = Color(0.68, 0.78, 0.18, 0.88)

	var smesh: SphereMesh = SphereMesh.new()
	var sdraw: StandardMaterial3D = StandardMaterial3D.new()
	sdraw.albedo_color = Color(0.65, 0.75, 0.18, 0.88)
	sdraw.roughness = 0.1
	sdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smesh.material = sdraw
	smesh.radius = 0.04
	smesh.height = 0.08

	splatter.process_material = smat
	splatter.draw_pass_1 = smesh
	splatter.transform.origin = Vector3(0, -0.15, -0.38)
	player.head.add_child(splatter)
	_vomit_splatter = splatter

	# 3. Heavy Food Chunks
	var chunks: GPUParticles3D = GPUParticles3D.new()
	chunks.name = "VomitChunks"
	chunks.amount = 25
	chunks.lifetime = 1.2
	chunks.one_shot = true
	chunks.explosiveness = 0.92
	chunks.emitting = false

	var cmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	cmat.direction = Vector3(0, -0.3, -1.0)
	cmat.spread = 22.0
	cmat.initial_velocity_min = 3.5
	cmat.initial_velocity_max = 7.0
	cmat.gravity = Vector3(0, -13.0, 0)
	cmat.scale_min = 0.08
	cmat.scale_max = 0.22
	cmat.color = Color(0.55, 0.42, 0.12, 1.0)

	var cmesh: SphereMesh = SphereMesh.new()
	var cdraw: StandardMaterial3D = StandardMaterial3D.new()
	cdraw.albedo_color = Color(0.55, 0.42, 0.12, 1.0)
	cdraw.roughness = 0.15
	cdraw.metallic = 0.1
	cmesh.material = cdraw
	cmesh.radius = 0.06
	cmesh.height = 0.12

	chunks.process_material = cmat
	chunks.draw_pass_1 = cmesh
	chunks.transform.origin = Vector3(0, -0.15, -0.38)
	player.head.add_child(chunks)
	_vomit_chunks = chunks

func trigger_nausea(amount: float) -> void:
	if player and not player.is_dead:
		nausea_intensity = clampf(nausea_intensity + amount, 0.0, 1.0)
		player.nausea_intensity = nausea_intensity

@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_vomit() -> void:
	_severe_nausea_duration = 0.0
	_vomit_cooldown_timer = 8.0
	_vomit_anim_timer = 1.8

	nausea_intensity = maxf(nausea_intensity - 0.35, 0.15)
	if player:
		player.nausea_intensity = nausea_intensity

	# Emit all 3 particle passes & SFX on ALL clients!
	if AudioManager:
		var pos: Vector3 = player.global_position if player else Vector3.ZERO
		AudioManager.play_sfx_3d("vomit_burst", pos)

	if _vomit_particles:
		_vomit_particles.restart()
		_vomit_particles.emitting = true
	if _vomit_splatter:
		_vomit_splatter.restart()
		_vomit_splatter.emitting = true
	if _vomit_chunks:
		_vomit_chunks.restart()
		_vomit_chunks.emitting = true

	if player and player.is_multiplayer_authority():
		if player.head:
			player.head.rotation.x = clampf(player.head.rotation.x + deg_to_rad(42.0), deg_to_rad(-89.0), deg_to_rad(89.0))
		if player.camera_3d:
			player.camera_3d.fov = 68.0

		if player.hud and player.hud.has_method("set_nausea_intensity"):
			player.hud.set_nausea_intensity(1.0)

func trigger_vomit() -> void:
	rpc_trigger_vomit.rpc()

	if player and player.is_multiplayer_authority():
		var mouth_pos: Vector3 = player.head.global_position if player.head else player.global_position + Vector3(0, 1.5, 0)
		var forward: Vector3 = -player.global_transform.basis.z
		var ray_end: Vector3 = mouth_pos + forward * 3.5 + Vector3(0, -2.5, 0)

		var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(mouth_pos, ray_end)
		query.exclude = [player]

		var hit: Dictionary = space_state.intersect_ray(query)
		var hit_pos: Vector3 = player.global_position + forward * 1.5
		var hit_normal: Vector3 = Vector3.UP
		var hit_node_path: NodePath = NodePath()

		if not hit.is_empty():
			hit_pos = hit.get("position", hit_pos)
			hit_normal = hit.get("normal", Vector3.UP)
			if hit.get("collider") is Node:
				hit_node_path = (hit["collider"] as Node).get_path()

		player.rpc_spawn_vomit_puddle.rpc(hit_pos, hit_normal, hit_node_path)

	print("🤮 AAA VOMIT BURST: Player vomited!")

func update_nausea_effects(delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	if player.is_dead:
		return

	# Handle prolonged severe nausea -> Vomiting burst!
	if nausea_intensity >= 0.75:
		_severe_nausea_duration += delta
		if _severe_nausea_duration >= 3.0 and _vomit_cooldown_timer <= 0.0:
			trigger_vomit()
	else:
		_severe_nausea_duration = maxf(_severe_nausea_duration - delta, 0.0)

	if _vomit_cooldown_timer > 0.0:
		_vomit_cooldown_timer -= delta

	# Slowly decay nausea when away from stench
	nausea_intensity = maxf(nausea_intensity - 0.08 * delta, 0.0)
	player.nausea_intensity = nausea_intensity

	# Update Shader Parameter for Nausea post-processing
	if player.hud and player.hud.has_method("set_nausea_intensity"):
		player.hud.set_nausea_intensity(nausea_intensity)

	# 1st Person Camera Vertigo Sway & Periodic Gag / Retch Heaves
	if player.camera_3d and player.head:
		if nausea_intensity > 0.01:
			var t: float = Time.get_ticks_msec() * 0.001
			var roll_z: float = sin(t * 2.4) * deg_to_rad(15.0) * nausea_intensity
			var pitch_sway: float = cos(t * 3.6) * deg_to_rad(6.0) * nausea_intensity
			var gag_heave: float = -pow(maxf(sin(t * 3.2), 0.0), 6.0) * deg_to_rad(10.0) * nausea_intensity

			player.camera_3d.rotation.z = roll_z
			player.head.rotation.x = clampf(player.head.rotation.x + gag_heave * delta * 4.0 + pitch_sway * delta * 2.0, deg_to_rad(-89.0), deg_to_rad(89.0))
		else:
			player.camera_3d.rotation.z = lerpf(player.camera_3d.rotation.z, 0.0, 8.0 * delta)
