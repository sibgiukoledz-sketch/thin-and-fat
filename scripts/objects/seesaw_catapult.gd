class_name SeesawCatapult
extends Node3D

## Catapult Seesaw Mechanic ("Качели-катапульта"):
## - Normal walking/stepping simply tilts the seesaw plank smoothly without launching.
## - Heavy impact slam by Fat ("Жирдяй") jumping/falling from height or Heavy Boulder ("HeavyBoulder")
##   triggers the Catapult Launch, blasting any Thin player ("Худой"), DummyNPC, or light object
##   on the opposite end high into orbit ("в открытый космос")!

signal catapult_launched(launched_body: Node, launch_velocity: float)

@export var max_tilt_angle: float = 11.5 # Max tilt in degrees (stops right on ground bumpers without floor clipping!)
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

	var is_heavy_slam: bool = false
	var downward_speed: float = 0.0

	if body is Player:
		var p: Player = body as Player
		if p.selected_character_id.to_lower() == "fat":
			# Only launch if Fat JUMPED / FELL from a height (velocity.y < -1.8 m/s) or carried heavy item
			if p.velocity.y < -1.8 or p.is_carrying_heavy_object:
				is_heavy_slam = true
				downward_speed = absf(p.velocity.y)
			else:
				# Normal stepping/walking: tilt seesaw gently WITHOUT launching!
				_gently_tilt_seesaw(side)
				return
	elif body is HeavyBoulder or (body is RigidBody3D and (body as RigidBody3D).mass >= 30.0):
		var rb: RigidBody3D = body as RigidBody3D
		if rb.linear_velocity.y < -0.8 or rb.linear_velocity.length_squared() > 10.0:
			is_heavy_slam = true
			downward_speed = maxf(rb.linear_velocity.length(), 6.0)
		else:
			_gently_tilt_seesaw(side)
			return

	if not is_heavy_slam:
		return

	if now - _last_slam_time < 0.35:
		return
	_last_slam_time = now

	var impact_power: float = clampf(24.0 + downward_speed * 1.8, base_launch_force, max_launch_force)
	rpc_trigger_catapult_slam.rpc(side, impact_power)

func _gently_tilt_seesaw(side: int) -> void:
	var target_angle_rad: float = deg_to_rad(max_tilt_angle if side == -1 else -max_tilt_angle)
	if plank_pivot:
		var tween: Tween = create_tween()
		tween.tween_property(plank_pivot, "rotation:z", target_angle_rad, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_catapult_slam(slam_side: int, launch_force: float) -> void:
	_current_side = slam_side
	var target_angle_rad: float = deg_to_rad(max_tilt_angle if slam_side == -1 else -max_tilt_angle)

	# 1. Smooth Mechanical Tilt Animation
	if plank_pivot:
		var tween: Tween = create_tween()
		tween.tween_property(plank_pivot, "rotation:z", target_angle_rad, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(plank_pivot, "rotation:z", target_angle_rad * 0.88, 0.12).set_trans(Tween.TRANS_SINE)
		tween.tween_property(plank_pivot, "rotation:z", target_angle_rad, 0.10)

		# Slowly level back to horizontal balance after 2.2 seconds
		tween.tween_interval(2.2)
		tween.tween_property(plank_pivot, "rotation:z", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Spawn Launch FX on Slammed Side
	var target_particles: GPUParticles3D = particles_left if slam_side == -1 else particles_right
	if target_particles:
		target_particles.restart()
		target_particles.emitting = true

	# 3. Find All Entities on OPPOSITE Side (Area3D overlap + 4.2m radius search around target pad)
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
