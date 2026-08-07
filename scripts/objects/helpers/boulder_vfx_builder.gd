class_name BoulderVFXBuilder
extends RefCounted

## Utility builder for Heavy Boulder 4-tier AAA impact VFX (Dust, Shards, Shockwave, Friction Sparks)

static func build_impact_vfx(parent_node: Node3D) -> Dictionary:
	# 1. Fine dust plume
	var dust := GPUParticles3D.new()
	dust.name = "VFX_DustPlume"
	dust.top_level = true
	dust.amount = 140
	dust.lifetime = 1.4
	dust.one_shot = true
	dust.explosiveness = 0.94
	dust.emitting = false

	var mat_dust := ParticleProcessMaterial.new()
	mat_dust.direction = Vector3(0, 1, 0)
	mat_dust.spread = 85.0
	mat_dust.initial_velocity_min = 4.0
	mat_dust.initial_velocity_max = 14.0
	mat_dust.gravity = Vector3(0, -1.8, 0)
	mat_dust.scale_min = 0.6
	mat_dust.scale_max = 2.2
	dust.process_material = mat_dust

	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.45
	dust_mesh.height = 0.9
	dust_mesh.radial_segments = 8
	dust_mesh.rings = 6
	dust.draw_pass_1 = dust_mesh
	parent_node.add_child(dust)

	# 2. Debris shards
	var debris := GPUParticles3D.new()
	debris.name = "VFX_DebrisShards"
	debris.top_level = true
	debris.amount = 45
	debris.lifetime = 1.2
	debris.one_shot = true
	debris.explosiveness = 0.98
	debris.emitting = false

	var mat_debris := ParticleProcessMaterial.new()
	mat_debris.direction = Vector3(0, 1, 0)
	mat_debris.spread = 75.0
	mat_debris.initial_velocity_min = 8.0
	mat_debris.initial_velocity_max = 22.0
	mat_debris.gravity = Vector3(0, -16.0, 0)
	debris.process_material = mat_debris

	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.18, 0.18, 0.18)
	debris.draw_pass_1 = shard_mesh
	parent_node.add_child(debris)

	# 3. Shockwave ring
	var shockwave := GPUParticles3D.new()
	shockwave.name = "VFX_ShockwaveRing"
	shockwave.top_level = true
	shockwave.amount = 1
	shockwave.lifetime = 0.45
	shockwave.one_shot = true
	shockwave.emitting = false

	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 0.6
	torus_mesh.outer_radius = 1.8
	shockwave.draw_pass_1 = torus_mesh
	parent_node.add_child(shockwave)

	# 4. Friction sparks
	var sparks := GPUParticles3D.new()
	sparks.name = "VFX_FrictionSparks"
	sparks.top_level = true
	sparks.amount = 30
	sparks.lifetime = 0.6
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.emitting = false
	parent_node.add_child(sparks)

	return {
		"dust": dust,
		"debris": debris,
		"shockwave": shockwave,
		"sparks": sparks
	}

static func trigger_impact_vfx(vfx_dict: Dictionary, impact_pos: Vector3) -> void:
	for key in vfx_dict:
		var p: GPUParticles3D = vfx_dict[key] as GPUParticles3D
		if p:
			p.global_position = impact_pos
			p.restart()
			p.emitting = true
