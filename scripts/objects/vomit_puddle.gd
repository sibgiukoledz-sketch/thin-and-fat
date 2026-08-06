class_name VomitPuddle
extends Area3D

## Slimy vomit puddle hazard on the floor. Emits rising steam and attracts flies.
## Stepping in it triggers extra nausea. Fades out after lifetime.

@export var lifetime: float = 25.0
@export var extra_nausea: float = 0.35

var _life_timer: float = 0.0
var _steam_particles: GPUParticles3D
var _fly_particles: GPUParticles3D
var _puddle_mesh: MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_create_steam_particles()
	_create_fly_particles()

	# Randomize puddle scale to look organic
	var rand_scale := randf_range(0.7, 1.3)
	scale = Vector3(rand_scale, 1.0, rand_scale * randf_range(0.8, 1.2))
	rotation.y = randf() * TAU

func _create_steam_particles() -> void:
	_steam_particles = GPUParticles3D.new()
	_steam_particles.name = "VomitSteam"
	_steam_particles.amount = 12
	_steam_particles.lifetime = 2.0
	_steam_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0, 0.3, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.35
	mat.color = Color(0.5, 0.6, 0.15, 0.35)

	var mesh := SphereMesh.new()
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.5, 0.6, 0.2, 0.3)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	mesh.radius = 0.12
	mesh.height = 0.24

	_steam_particles.process_material = mat
	_steam_particles.draw_pass_1 = mesh
	_steam_particles.transform.origin = Vector3(0, 0.08, 0)
	add_child(_steam_particles)

func _create_fly_particles() -> void:
	_fly_particles = GPUParticles3D.new()
	_fly_particles.name = "PuddleFlies"
	_fly_particles.amount = 8
	_fly_particles.lifetime = 1.5
	_fly_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.8
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -0.5, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	mat.color = Color(0.15, 0.15, 0.1, 0.95)

	var mesh := QuadMesh.new()
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.12, 0.12, 0.08, 0.95)
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	mesh.size = Vector2(0.04, 0.04)

	_fly_particles.process_material = mat
	_fly_particles.draw_pass_1 = mesh
	_fly_particles.transform.origin = Vector3(0, 0.3, 0)
	add_child(_fly_particles)

func _process(delta: float) -> void:
	_life_timer += delta

	# Fade out puddle mesh near end of lifetime
	var fade_start := lifetime - 5.0
	if _life_timer >= fade_start:
		var fade_alpha := clampf(1.0 - (_life_timer - fade_start) / 5.0, 0.0, 1.0)
		# Stop particles when fading
		if _steam_particles and fade_alpha < 0.3:
			_steam_particles.emitting = false
		if _fly_particles and fade_alpha < 0.5:
			_fly_particles.emitting = false

	if _life_timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if p.has_method("trigger_nausea"):
			p.trigger_nausea(extra_nausea)
			print("🤢 STEPPED IN VOMIT: Increased nausea for %s" % p.name)
