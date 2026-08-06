class_name WindTunnelFan
extends Node3D

## Hurricane Wind Turbine Mechanic ("Ураган / Сильный вентилятор"):
## - Blows a powerful hurricane wind stream down a corridor/zone.
## - Light characters ("Худой") and DummyNPCs are blown backward by the wind.
## - Heavy character ("Жирдяй") acts as a solid Wind Shield / Wind Shadow.
##   When Thin walks directly BEHIND Fat, Fat blocks the raycast wind stream,
##   allowing Thin to safely advance forward through the hurricane!

@export var is_active: bool = true
@export var wind_force: float = 28.0 # Push force magnitude
@export var fan_reach_length: float = 15.0 # Wind zone length in meters

@onready var blades_mesh: MeshInstance3D = $TurbineHousing/BladesMesh
@onready var wind_area: Area3D = $WindArea
@onready var wind_particles: GPUParticles3D = $WindParticles
@onready var raycast_sensor: RayCast3D = $RayCastSensor

func _ready() -> void:
	if wind_particles:
		wind_particles.emitting = is_active

func _physics_process(delta: float) -> void:
	if not is_active:
		if wind_particles and wind_particles.emitting:
			wind_particles.emitting = false
		return

	# Spin turbine blades
	if blades_mesh:
		blades_mesh.rotate_z(18.0 * delta)

	if not wind_particles.emitting:
		wind_particles.emitting = true

	_apply_wind_physics(delta)

func _apply_wind_physics(delta: float) -> void:
	if not wind_area:
		return

	# Direction the wind is blowing (local +Z or global transform)
	var wind_dir: Vector3 = global_transform.basis.z.normalized()
	var fan_origin: Vector3 = global_position + Vector3(0, 1.8, 0)

	var bodies: Array[Node3D] = wind_area.get_overlapping_bodies()
	for body in bodies:
		if body == self or body is StaticBody3D:
			continue

		# Check if body is Fat (Fat is heavy anchor, unaffected by wind)
		var is_fat: bool = false
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat":
				is_fat = true

		if is_fat:
			# Fat is heavy & unyielding, acts as the wind shield for teammates!
			continue

		# Check if body is shielded by Fat standing between the Fan and this body!
		var is_shielded: bool = _check_is_shielded_by_fat(fan_origin, body.global_position)

		if is_shielded:
			# Protected in Fat's wind shadow zone!
			continue

		# Apply hurricane wind push force
		if body is Player:
			var p: Player = body as Player
			p.velocity += wind_dir * (wind_force * 1.6) * delta
			# Push back against forward movement against the wind
			var dot: float = p.velocity.dot(wind_dir)
			if dot < 0.0:
				p.velocity -= wind_dir * (dot * 0.85)

		elif body is DummyNPC:
			var npc: DummyNPC = body as DummyNPC
			npc.velocity += wind_dir * (wind_force * 2.2) * delta
			npc.move_and_slide()

		elif body is RigidBody3D:
			var rb: RigidBody3D = body as RigidBody3D
			if rb.mass < 120.0:
				rb.apply_central_force(wind_dir * wind_force * rb.mass * 14.0)

func _check_is_shielded_by_fat(fan_origin: Vector3, victim_pos: Vector3) -> bool:
	# Search for Fat player standing between fan_origin and victim_pos
	var root: Node = get_tree().root
	var players: Array[Node] = root.find_children("*", "CharacterBody3D", true, false)

	var victim_dist: float = fan_origin.distance_to(victim_pos)

	for p in players:
		if p is Player:
			var player: Player = p as Player
			if player.selected_character_id.to_lower() == "fat":
				var fat_pos: Vector3 = player.global_position + Vector3(0, 1.0, 0)
				var fat_dist: float = fan_origin.distance_to(fat_pos)

				# Fat must be CLOSER to the fan than the victim
				if fat_dist < victim_dist:
					# Check lateral alignment (distance from line between fan and victim)
					var line_vec: Vector3 = (victim_pos - fan_origin).normalized()
					var fat_vec: Vector3 = fat_pos - fan_origin
					var proj_len: float = fat_vec.dot(line_vec)
					var perp_dist: float = (fat_vec - line_vec * proj_len).length()

					# If Fat is within 2.0m width of the wind line, Fat shields the victim!
					if perp_dist <= 2.0:
						return true

	return false
