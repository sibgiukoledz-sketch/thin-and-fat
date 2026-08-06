class_name SeesawCatapult
extends Node3D

## Catapult Seesaw Mechanic ("Качели-катапульта"):
## - Heavy slam by Fat ("Жирдяй") or Heavy Boulder ("HeavyBoulder") on one end of the plank
##   instantly launches any Thin player ("Худой"), DummyNPC, or light object on the opposite end
##   high into the sky / upper tier ("в открытый космос")!

signal catapult_launched(launched_body: Node, launch_velocity: float)

@export var max_tilt_angle: float = 20.0 # Max tilt in degrees (deg_to_rad(20.0) ~ 0.35 rad)
@export var base_launch_force: float = 26.0 # Base skyward velocity (m/s)
@export var max_launch_force: float = 40.0 # Max skyward launch velocity for heavy falls

@onready var plank_pivot: Node3D = $PlankPivot
@onready var area_left: Area3D = $PlankPivot/AreaLeft
@onready var area_right: Area3D = $PlankPivot/AreaRight
@onready var particles_left: GPUParticles3D = $PlankPivot/ParticlesLeft
@onready var particles_right: GPUParticles3D = $PlankPivot/ParticlesRight

var _is_animating: bool = false
var _current_side: int = 0 # -1 = Left down, +1 = Right down, 0 = Level

func _ready() -> void:
	if area_left:
		area_left.body_entered.connect(func(body: Node) -> void: _on_side_impact(body, -1))
	if area_right:
		area_right.body_entered.connect(func(body: Node) -> void: _on_side_impact(body, 1))

func _on_side_impact(body: Node, side: int) -> void:
	# Check if body is a Heavy Slammer (Fat character landing or Heavy Boulder)
	var is_fat: bool = false
	var downward_speed: float = 0.0

	if body is Player:
		var p: Player = body as Player
		if p.selected_character_id.to_lower() == "fat":
			is_fat = true
			downward_speed = absf(minf(p.velocity.y, -1.0))
	elif body is HeavyBoulder:
		is_fat = true
		downward_speed = absf(minf(body.linear_velocity.y, -2.0))
	elif body is RigidBody3D and body.mass >= 150.0:
		is_fat = true
		downward_speed = absf(minf(body.linear_velocity.y, -2.0))

	if not is_fat:
		return

	# Execute Catapult Slam RPC
	var impact_power: float = clampf(18.0 + downward_speed * 1.6, base_launch_force, max_launch_force)
	rpc_trigger_catapult_slam.rpc(side, impact_power)

@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_catapult_slam(slam_side: int, launch_force: float) -> void:
	_current_side = slam_side
	var target_angle_rad: float = deg_to_rad(-max_tilt_angle if slam_side == -1 else max_tilt_angle)

	# 1. Animate Plank Tilt
	if plank_pivot:
		var tween: Tween = create_tween()
		tween.tween_property(plank_pivot, "rotation:z", target_angle_rad, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Spawn Launch FX on Slammed Side
	var target_particles: GPUParticles3D = particles_left if slam_side == -1 else particles_right
	if target_particles:
		target_particles.restart()
		target_particles.emitting = true

	# 3. Launch Entities on OPPOSITE Side!
	var opposite_area: Area3D = area_right if slam_side == -1 else area_left
	if not opposite_area:
		return

	var launch_dir_x: float = 1.0 if slam_side == -1 else -1.0
	var bodies: Array[Node3D] = opposite_area.get_overlapping_bodies()

	for victim in bodies:
		if victim is Player:
			var p: Player = victim as Player
			# Launch Thin player or any teammate high into the sky!
			p.velocity.y = launch_force
			p.velocity.x += launch_dir_x * 5.0
			p.velocity.z += randf_range(-1.5, 1.5)
			if p.has_method("set_target_fov"):
				p.set_target_fov(100.0)
			catapult_launched.emit(p, launch_force)
			print("🚀 CATAPULT SEESAW: Player %s launched at %.1f m/s!" % [p.name, launch_force])

		elif victim is DummyNPC:
			var npc: DummyNPC = victim as DummyNPC
			npc.velocity.y = launch_force
			npc.velocity.x += launch_dir_x * 5.0
			catapult_launched.emit(npc, launch_force)
			print("🚀 CATAPULT SEESAW: DummyNPC launched at %.1f m/s!" % launch_force)

		elif victim is RigidBody3D:
			var rb: RigidBody3D = victim as RigidBody3D
			var impulse: Vector3 = Vector3(launch_dir_x * 3.0, launch_force * rb.mass * 1.1, randf_range(-1.0, 1.0))
			rb.apply_central_impulse(impulse)
			rb.apply_torque_impulse(Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)))
			catapult_launched.emit(rb, launch_force)
			print("🚀 CATAPULT SEESAW: RigidBody %s launched skyward!" % rb.name)
