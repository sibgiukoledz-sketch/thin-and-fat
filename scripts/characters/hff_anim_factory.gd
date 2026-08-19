class_name HFFAnimFactory
extends RefCounted

## Builds Animation resources with Skeleton3D bone tracks from compact
## keyframe tables, so procedurally-rigged characters can be driven by a
## normal AnimationPlayer.
##
## Table format:
## {
##   "walk": { "len": 0.8, "loop": true, "bones": {
##       "Pelvis": { "pos": [[t, Vector3], ...] },
##       "Hip_L":  { "rot": [[t, Vector3DEG], ...] },
##   }},
## }

static func build_library(tables: Dictionary) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for anim_name in tables:
		lib.add_animation(anim_name, build_animation(tables[anim_name]))
	return lib


static func build_animation(def: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = def.get("len", 1.0)
	anim.loop_mode = Animation.LOOP_LINEAR if def.get("loop", true) else Animation.LOOP_NONE
	var bones: Dictionary = def.get("bones", {})
	for bone in bones:
		var spec: Dictionary = bones[bone]
		if spec.has("pos"):
			var ti := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(ti, "Skeleton3D:%s" % bone)
			for key in spec["pos"]:
				anim.position_track_insert_key(ti, key[0], key[1])
		if spec.has("rot"):
			var ri := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(ri, "Skeleton3D:%s" % bone)
			for key in spec["rot"]:
				anim.rotation_track_insert_key(ri, key[0], Quaternion.from_euler(_rad(key[1])))
	return anim


static func _rad(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))
