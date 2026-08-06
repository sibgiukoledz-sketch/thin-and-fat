class_name SeesawCatapult
extends Node3D

## Catapult Seesaw Mechanic ("Качели-катапульта"):
## - Heavy slam by Fat ("Жирдяй") or Heavy Boulder ("HeavyBoulder") on one end of the plank
##   instantly launches any Thin player ("Худой"), DummyNPC, or light object on the opposite end
##   high into the sky / upper tier ("в открытый космос")!

signal catapult_launched(launched_body: Node, launch_velocity: float)

@export var max_tilt_angle: float = 20.0 # Max tilt in degrees (deg_to_rad(20.0) ~ 0.35 rad)
@export var base_launch_force: float = 30.0 # Base skyward velocity (m/s)
@export var max_launch_force: float = 46.0 # Max skyward launch velocity for heavy falls

@onready var plank_pivot: Node3D = $PlankPivot
@onready var area_left: Area3D = $PlankPivot/AreaLeft
@onready var area_right: Area3D = $PlankPivot/AreaRight
@onready var particles_left: GPUParticles3D = $PlankPivot/ParticlesLeft
@onready var particles_right: GPUParticles3D = $PlankPivot/ParticlesRight

var _is_animating: bool = false
var _current_side: int = 0 # -1 = Left down, +1 = Right down, 0 = Level
var _last_slam_time: float = 0.0

func _ready() -> void:
	if area_left:
		area_left.body_entered.connect(func(body: Node) -> void: _on_side_impact(body, -1))
	if area_right:
		area_right.body_entered.connect(func(body: Node) -> void: _on_side_impact(body, 1))

func _on_side_impact(body: Node, side: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_slam_time < 0.35:
		return

	var is_heavy_slam: bool = false
	var downward_speed: float = 0.0

	if body is Player:
		var p: Player = body as Player
		if p.selected_character_id.to_lower() == "fat":
			# Fat jumping, falling, or carrying heavy object onto the pad
			if p.velocity.y < -0.4 or not p.is_on_floor() or p.is_carrying_heavy_object or p.velocity.length_squared() > 4.0:
				is_heavy_slam = true
				downward_speed = maxf(absf(p.velocity.y), 4.0)
	elif body is HeavyBoulder or (body is RigidBody3D and (body as RigidBody3D).mass >= 30.0):
		var rb: RigidBody3D = body as RigidBody3D
		# Heavy Boulder rolling or landing onto pad ALWAYS triggers catapult!
		is_heavy_slam = true
		downward_speed = maxf(rb.linear_velocity.length(), 6.0)

	if not is_heavy_slam:
		return

	_last_slam_time = now
	var impact_power: float = clampf(24.0 + downward_speed * 1.8, base_launch_force, max_launch_force)
	rpc_trigger_catapult_slam.rpc(side, impact_power)

@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_catapult_slam(slam_side: int, launch_force: float) -> void:
	_current_side = slam_side
	var target_angle_rad: float = deg_to_rad(-max_tilt_angle if slam_side == -1 else max_tilt_angle)

	# 1. Animate Plank Tilt
	if plank_pivot:
		var tween: Tween = create_tween()
		tween.tween_property(plank_pivot, "rotation:z", target_angle_rad, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Spawn Launch FX on Slammed Side
	var target_particles: GPUParticles3D = particles_left if slam_side == -1 else particles_right
	if target_particles:
		target_particles.restart()
		target_particles.emitting = true

	# 3. Find All Entities on OPPOSITE Side (both Area3D overlap + 4.2m radius search around target pad)
	var opposite_area: Area3D = area_right if slam_side == -1 else area_left
	var opposite_pad: GPUParticles3D = particles_right if slam_side == -1 else particles_left
	var opp_pad_pos: Vector3 = opposite_pad.global_position if opposite_pad else global_position
	var launch_dir_x: float = 1.0 if slam_side == -1 else -1.0

	var launch_targets: Array[Node3D] = []

	# Check Area3D overlaps
	if opposite_area:
		for b in opposite_area.get_overlapping_bodies():
			if b is Node3D and not b in launch_targets:
				launch_targets.append(b as Node3D)

	# Check 4.2m distance radius around opposite landing pad for players & NPCs
	var root: Node = get_tree().root
	for child in root.find_children("*", "CharacterBody3D", true, false):
		if child is Node3D:
			var n3d: Node3D = child as Node3D
			if n3d.global_position.distance_to(opp_pad_pos) < 4.2 and not n3d in launch_targets:
				launch_targets.append(n3d)

	for child in root.find_children("*", "RigidBody3D", true, false):
		if child is RigidBody3D and child.mass < 100.0:
			var rb: RigidBody3D = child as RigidBody3D
			if rb.global_position.distance_to(opp_pad_pos) < 4.2 and not rb in launch_targets:
				launch_targets.append(rb)

	# 4. Launch Target Entities Skyward ("в открытый космос")!
	for victim in launch_targets:
		if victim is Player:
			var p: Player = victim as Player
			p.velocity.y = launch_force
			p.velocity.x += launch_dir_x * 6.0
			p.velocity.z += randf_range(-1.5, 1.5)
			if p.has_method("set_target_fov"):
				p.set_target_fov(105.0)
			catapult_launched.emit(p, launch_force)
			print("🚀 CATAPULT SEESAW: Player %s launched skyward at %.1f m/s!" % [p.name, launch_force])

		elif victim is DummyNPC:
			var npc: DummyNPC = victim as DummyNPC
			npc.velocity = Vector3(launch_dir_x * 6.0, launch_force * 1.25, randf_range(-1.5, 1.5))
			npc.move_and_slide()
			catapult_launched.emit(npc, launch_force)
			print("🚀 CATAPULT SEESAW: DummyNPC %s launched skyward at %.1f m/s!" % [npc.name, launch_force])

		elif victim is RigidBody3D:
			var rb: RigidBody3D = victim as RigidBody3D
			var impulse: Vector3 = Vector3(launch_dir_x * 4.0, launch_force * rb.mass * 1.3, randf_range(-1.5, 1.5))
			rb.apply_central_impulse(impulse)
			rb.apply_torque_impulse(Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)))
			catapult_launched.emit(rb, launch_force)
			print("🚀 CATAPULT SEESAW: RigidBody %s launched skyward!" % rb.name)
