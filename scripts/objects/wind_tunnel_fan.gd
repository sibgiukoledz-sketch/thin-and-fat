@tool
class_name WindTunnelFan
extends Node3D

## Hurricane Wind Turbine Mechanic ("Ураган / Сильный вентилятор"):
## - Blows a powerful hurricane wind stream down a corridor/zone.
## - Light characters ("Худой") and DummyNPCs are blown backward by the wind.
## - Heavy character ("Жирдяй") acts as a solid Wind Shield / Wind Shadow:
##   - Experiences heavy resistance when walking against the wind.
##   - Experiences subtle minor drift backward when standing completely still.
##   - Protects Thin character walking directly BEHIND him from the wind!

@export var is_active: bool = true
@export var wind_force: float = 32.0 # Push force magnitude
@export var fan_reach_length: float = 16.0 # Wind zone length in meters

@onready var outer_shroud: MeshInstance3D = $TurbineHousing/OuterShroud
@onready var cyan_glowing_ring: MeshInstance3D = $TurbineHousing/CyanGlowingRing
@onready var center_hub: MeshInstance3D = $TurbineHousing/CenterHub
@onready var nose_cone: MeshInstance3D = $TurbineHousing/NoseCone
@onready var blades_mesh: MeshInstance3D = $TurbineHousing/BladesMesh
@onready var wind_area: Area3D = $WindArea
@onready var wind_particles: GPUParticles3D = $WindParticles
@onready var raycast_sensor: RayCast3D = $RayCastSensor

var current_blade_speed: float = 18.0

func _ready() -> void:
	_apply_visual_rotations()
	if raycast_sensor:
		var fan_static: StaticBody3D = get_node_or_null("FanStatic")
		if fan_static:
			raycast_sensor.add_exception(fan_static)
		raycast_sensor.position = Vector3(0, 2.2, 1.8)

	if wind_particles:
		wind_particles.emitting = is_active and not Engine.is_editor_hint()

func toggle_active() -> void:
	set_active(not is_active)

func set_active(active: bool) -> void:
	is_active = active
	print("🌀 WIND TUNNEL FAN %s!" % ["ACTIVATED" if is_active else "DEACTIVATED"])

func deactivate() -> void:
	set_active(false)

func activate() -> void:
	set_active(true)

func _apply_visual_rotations() -> void:
	# Enforce vertical 90 degree X rotation on all circular turbine shroud meshes
	if outer_shroud:
		outer_shroud.rotation_degrees = Vector3(90, 0, 0)
	if cyan_glowing_ring:
		cyan_glowing_ring.rotation_degrees = Vector3(90, 0, 0)
	if center_hub:
		center_hub.rotation_degrees = Vector3(90, 0, 0)
	if nose_cone:
		nose_cone.rotation_degrees = Vector3(90, 0, 0)

func _physics_process(delta: float) -> void:
	# Ensure shroud meshes stay upright
	_apply_visual_rotations()

	var wind_dir: Vector3 = global_transform.basis.z.normalized()
	var fan_origin: Vector3 = global_position + Vector3(0, 1.8, 0)

	var block_info: Dictionary = _get_closest_obstacle_distance(fan_origin, wind_dir)
	var is_blocked: bool = block_info.get("is_nozzle_blocked", false)
	var hit_dist: float = block_info.get("distance", fan_reach_length)

	# 1. Smooth Blade Rotation Spin-down / Spin-up
	var target_blade_speed: float = 18.0 if (is_active and not is_blocked) else 0.0
	current_blade_speed = lerpf(current_blade_speed, target_blade_speed, 3.5 * delta)

	if blades_mesh and absf(current_blade_speed) > 0.01:
		blades_mesh.rotate_z(current_blade_speed * delta)

	# 2. Smooth Cyan Ring Emission & Particle Control
	if cyan_glowing_ring and cyan_glowing_ring.material_override:
		var mat: StandardMaterial3D = cyan_glowing_ring.material_override as StandardMaterial3D
		var target_energy: float = 2.5 if (is_active and not is_blocked) else 0.2
		mat.emission_energy_multiplier = lerpf(mat.emission_energy_multiplier, target_energy, 4.0 * delta)

	if Engine.is_editor_hint():
		return

	if wind_particles:
		if not is_active or is_blocked:
			wind_particles.emitting = false
		else:
			wind_particles.emitting = true
			# Dynamically adjust particle lifetime so particles DIE right upon touching the boulder!
			var target_lifetime: float = clampf(hit_dist / 18.0, 0.08, 0.90)
			wind_particles.lifetime = target_lifetime

	if is_active and not is_blocked:
		_apply_wind_physics(delta, hit_dist)

func _get_closest_obstacle_distance(fan_origin: Vector3, wind_dir: Vector3) -> Dictionary:
	var closest_dist: float = fan_reach_length
	var is_nozzle_blocked: bool = false
	var root: Node = get_tree().root

	# 1. Native RayCastSensor check
	if raycast_sensor:
		raycast_sensor.force_raycast_update()
		if raycast_sensor.is_colliding():
			var collider: Object = raycast_sensor.get_collider()
			if collider is RigidBody3D:
				var rb: RigidBody3D = collider as RigidBody3D
				if rb is HeavyBoulder or rb.mass >= 150.0:
					var hit_pt: Vector3 = raycast_sensor.get_collision_point()
					var dist: float = fan_origin.distance_to(hit_pt)
					closest_dist = minf(closest_dist, dist)
					if dist <= 3.8:
						is_nozzle_blocked = true

	# 2. Spatial search for Heavy Boulder anywhere in the corridor
	var rigid_bodies: Array[Node] = root.find_children("*", "RigidBody3D", true, false)
	for rb_node in rigid_bodies:
		if rb_node is RigidBody3D:
			var rb: RigidBody3D = rb_node as RigidBody3D
			if rb is HeavyBoulder or rb.mass >= 150.0:
				var boulder_pos_2d: Vector3 = rb.global_position
				boulder_pos_2d.y = 0.0
				var fan_pos_2d: Vector3 = global_position
				fan_pos_2d.y = 0.0

				var rel_pos: Vector3 = boulder_pos_2d - fan_pos_2d
				var forward_dist: float = rel_pos.dot(wind_dir)
				var lateral_dist: float = (rel_pos - wind_dir * forward_dist).length()

				# If boulder is within the wind corridor (lateral_dist <= 3.5m, forward_dist > 0)
				if forward_dist > 0.0 and forward_dist < fan_reach_length and lateral_dist <= 3.5:
					closest_dist = minf(closest_dist, forward_dist)
					if forward_dist <= 3.8 and lateral_dist <= 3.0:
						is_nozzle_blocked = true

	return {
		"distance": closest_dist,
		"is_nozzle_blocked": is_nozzle_blocked
	}

func _apply_wind_physics(delta: float, max_wind_distance: float) -> void:
	var wind_dir: Vector3 = global_transform.basis.z.normalized()
	var fan_origin: Vector3 = global_position + Vector3(0, 1.8, 0)
	var root: Node = get_tree().root

	# 1. Process all overlapping bodies in WindArea
	if wind_area:
		var bodies: Array[Node3D] = wind_area.get_overlapping_bodies()
		for body in bodies:
			if body == self or body is StaticBody3D:
				continue

			if body.has_method("is_multiplayer_authority"):
				var p: CharacterBody3D = body as CharacterBody3D
				var p_dist: float = fan_origin.distance_to(p.global_position)

				# IF PLAYER IS BEYOND THE BOULDER (p_dist > max_wind_distance), PLAYER IS 100% IN WIND SHADOW!
				if p_dist > max_wind_distance + 0.5:
					continue

				if _check_is_shielded(fan_origin, p.global_position):
					continue

				if p.selected_character_id.to_lower() == "fat":
					var dot_fat: float = p.velocity.dot(wind_dir)
					# 1. Subtle minor heavy drift backward when Fat stands still or moves slowly
					if dot_fat < 0.5:
						p.velocity += wind_dir * (wind_force * 0.12) * delta
					# 2. Heavy resistance when Fat pushes forward against the wind
					if dot_fat < 0.0:
						p.velocity -= wind_dir * (dot_fat * 0.25)
					continue

				# Thin Player: check if shielded by Fat or Heavy Boulder!
				if _check_is_shielded(fan_origin, p.global_position):
					continue

				# Blown backward violently by wind!
				var push_vel: Vector3 = wind_dir * (wind_force * 1.6)
				p.velocity.x = lerpf(p.velocity.x, push_vel.x, 14.0 * delta)
				p.velocity.z = lerpf(p.velocity.z, push_vel.z, 14.0 * delta)
				p.move_and_slide()

			elif body is RigidBody3D:
				var rb: RigidBody3D = body as RigidBody3D
				# Only blow light/medium objects; Heavy Boulder (mass >= 150) stays grounded as a shield!
				if rb.mass < 150.0:
					rb.apply_central_force(wind_dir * wind_force * rb.mass * 15.0)

	# 2. Spatial corridor search for Thin players & DummyNPCs inside wind reach zone
	for child in root.find_children("*", "CharacterBody3D", true, false):
		if child.has_method("is_multiplayer_authority"):
			var player_node: CharacterBody3D = child as CharacterBody3D
			if String(player_node.get("selected_character_id")).to_lower() == "thin" and not player_node.get("is_dead"):
				var rel_pos: Vector3 = player_node.global_position - fan_origin
				var forward_dist: float = rel_pos.dot(wind_dir)
				var side_dist: float = (rel_pos - wind_dir * forward_dist).length()

				if forward_dist > 0.0 and forward_dist <= max_wind_distance + 0.5 and side_dist < 2.5:
					if not _check_is_shielded(fan_origin, player_node.global_position):
						var push_vel: Vector3 = wind_dir * (wind_force * 1.6)
						player_node.velocity.x = lerpf(player_node.velocity.x, push_vel.x, 14.0 * delta)
						player_node.velocity.z = lerpf(player_node.velocity.z, push_vel.z, 14.0 * delta)
						player_node.move_and_slide()

		elif child is DummyNPC:
			var npc: DummyNPC = child as DummyNPC
			var npc_pos: Vector3 = npc.global_position
			var rel_pos: Vector3 = npc_pos - fan_origin
			var forward_dist: float = rel_pos.dot(wind_dir)
			var side_dist: float = (rel_pos - wind_dir * forward_dist).length()

			if forward_dist > 0.0 and forward_dist < fan_reach_length and side_dist < 2.5:
				if not _check_is_shielded(fan_origin, npc_pos):
					var push_vel: Vector3 = wind_dir * (wind_force * 1.6)
					npc.velocity.x = lerpf(npc.velocity.x, push_vel.x, 14.0 * delta)
					npc.velocity.z = lerpf(npc.velocity.z, push_vel.z, 14.0 * delta)
					npc.move_and_slide()

func _check_is_shielded(_fan_origin: Vector3, victim_pos: Vector3) -> bool:
	var wind_dir: Vector3 = global_transform.basis.z.normalized()
	var fan_pos_2d: Vector3 = global_position
	fan_pos_2d.y = 0.0

	var victim_pos_2d: Vector3 = victim_pos
	victim_pos_2d.y = 0.0

	var rel_victim: Vector3 = victim_pos_2d - fan_pos_2d
	var v_fwd: float = rel_victim.dot(wind_dir)

	# 1. Native RayCastSensor check down wind beam line!
	if raycast_sensor:
		raycast_sensor.force_raycast_update()
		if raycast_sensor.is_colliding():
			var collider: Object = raycast_sensor.get_collider()
			if collider is RigidBody3D:
				var rb: RigidBody3D = collider as RigidBody3D
				if rb is HeavyBoulder or rb.mass >= 150.0:
					var hit_pt: Vector3 = raycast_sensor.get_collision_point()
					var rel_hit: Vector3 = hit_pt - global_position
					rel_hit.y = 0.0
					var hit_fwd: float = rel_hit.dot(wind_dir)
					# If the boulder raycast hit is BEFORE the victim along wind line, victim is shielded!
					if hit_fwd > 0.0 and hit_fwd < v_fwd:
						return true

	var root: Node = get_tree().root

	# 2. Check Fat player shielding
	var players: Array[Node] = root.find_children("*", "CharacterBody3D", true, false)
	for p in players:
		if p.has_method("is_multiplayer_authority"):
			var player_node: CharacterBody3D = p as CharacterBody3D
			if String(player_node.get("selected_character_id")).to_lower() == "fat" and not player_node.get("is_dead"):
				var fat_pos_2d: Vector3 = player_node.global_position
				fat_pos_2d.y = 0.0
				var rel_fat: Vector3 = fat_pos_2d - fan_pos_2d
				var fat_fwd: float = rel_fat.dot(wind_dir)
				var fat_side: float = (rel_fat - wind_dir * fat_fwd).length()

				if fat_fwd > 0.0 and fat_fwd < v_fwd and fat_side <= 2.5:
					return true

	# 3. Check Heavy Boulder shielding (closing/blocking the wind corridor!)
	var rigid_bodies: Array[Node] = root.find_children("*", "RigidBody3D", true, false)
	for rb_node in rigid_bodies:
		if rb_node is RigidBody3D:
			var rb: RigidBody3D = rb_node as RigidBody3D
			if rb is HeavyBoulder or rb.mass >= 150.0:
				var boulder_pos_2d: Vector3 = rb.global_position
				boulder_pos_2d.y = 0.0

				var rel_boulder: Vector3 = boulder_pos_2d - fan_pos_2d
				var b_fwd: float = rel_boulder.dot(wind_dir)
				var b_side: float = (rel_boulder - wind_dir * b_fwd).length()

				# If boulder is in wind stream (b_fwd > 0), placed between fan and victim (b_fwd < v_fwd),
				# and within 3.8m corridor width (b_side <= 3.8): VICTIM IS 100% SHIELDED!
				if b_fwd > 0.0 and b_fwd < v_fwd and b_side <= 3.8:
					return true

	return false
