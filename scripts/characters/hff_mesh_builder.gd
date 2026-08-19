class_name HFFMeshBuilder
extends RefCounted

## Procedural seamless skinned-mesh builder (Human Fall Flat style).
## Every part is generated as high-quality continuous skinned geometry with smooth
## per-vertex bone weights, correct outward-facing normals, CCW front-facing triangles,
## and vibrant vertex colors.
##
## All geometry is authored in Skeleton3D rest space (character root space),
## which doubles as the bind pose.

const BONES_PER_VERTEX := 4


class Part:
	extends RefCounted

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	var idx := PackedInt32Array()

	## Degenerate "ring" of coincident vertices closing a cap.
	func pole(center: Vector3, normal: Vector3, seg: int, wb: Array, ww: Array, color: Color) -> int:
		var base := verts.size()
		for i in seg:
			verts.append(center)
			norms.append(normal.normalized())
			cols.append(color)
			for j in BONES_PER_VERTEX:
				bones.append(int(wb[j]) if j < wb.size() else 0)
				wts.append(float(ww[j]) if j < ww.size() else 0.0)
		return base

	## One ring of vertices around `center` in the plane spanned by the frame.
	func ring(center: Vector3, frame: Array, rx: float, rz: float, seg: int, wb: Array, ww: Array, color: Color) -> int:
		var base := verts.size()
		var right: Vector3 = frame[0]
		var up: Vector3 = frame[1]
		for i in seg:
			var a := TAU * float(i) / float(seg)
			var ca := cos(a)
			var sa := sin(a)
			verts.append(center + right * (ca * rx) + up * (sa * rz))
			var local_norm: Vector3 = (right * (ca / maxf(rx, 0.0001)) + up * (sa / maxf(rz, 0.0001))).normalized()
			norms.append(local_norm)
			cols.append(color)
			for j in BONES_PER_VERTEX:
				bones.append(int(wb[j]) if j < wb.size() else 0)
				wts.append(float(ww[j]) if j < ww.size() else 0.0)
		return base

	## Stitches two consecutive rings with Counter-Clockwise (CCW) front-facing triangles.
	func link(a: int, b: int, seg: int) -> void:
		for i in seg:
			var i2 := (i + 1) % seg
			# Triangle 1 (CCW)
			idx.append(a + i)
			idx.append(b + i2)
			idx.append(a + i2)
			# Triangle 2 (CCW)
			idx.append(a + i)
			idx.append(b + i)
			idx.append(b + i2)

	func vert_count() -> int:
		return verts.size()

	func commit() -> ArrayMesh:
		if verts.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = wts
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

	## Rounded limb tube along a polyline, with a buried dome cap at root and end.
	func add_tube(points: Array, radii: Array, seg: int, sub: int, wf: Callable, cf: Callable) -> void:
		var n := points.size()
		if n < 2 or radii.size() != n:
			push_error("HFFMeshBuilder.add_tube: bad points/radii (%d/%d)" % [n, radii.size()])
			return

		var cum: Array[float] = [0.0]
		for i in range(1, n):
			cum.append(cum[i - 1] + (points[i] - points[i - 1]).length())
		var total: float = cum[n - 1]

		var tans: Array = []
		for i in n:
			if i == 0:
				tans.append((points[1] - points[0]).normalized())
			elif i == n - 1:
				tans.append((points[n - 1] - points[n - 2]).normalized())
			else:
				tans.append(((points[i + 1] - points[i]) + (points[i] - points[i - 1])).normalized())

		var chain: Array[int] = []

		# --- Root dome cap (buried inside the torso) ---
		var f0: Array = HFFMeshBuilder._frame(tans[0])
		var r0: Vector2 = radii[0]
		var r0max := maxf(r0.x, r0.y)
		var w0: Array = HFFMeshBuilder.norm_weights(wf.call(0.0))
		var c0: Color = cf.call(0.0)
		chain.append(pole(points[0] - tans[0] * r0max, -tans[0], seg, w0[0], w0[1], c0))
		const CAP_RINGS := 3
		for k in range(CAP_RINGS, 0, -1):
			var phi := PI * 0.5 * float(k) / float(CAP_RINGS)
			var cap_c: Vector3 = points[0] - tans[0] * (r0max * sin(phi))
			var sc := cos(phi)
			chain.append(ring(cap_c, f0, r0.x * sc, r0.y * sc, seg, w0[0], w0[1], c0))

		# --- Main rings ---
		var ring_count := (n - 1) * sub + 1
		for r in ring_count:
			var t := float(r) / float(ring_count - 1)
			var seg_i := 0
			while seg_i < n - 2 and t * total > cum[seg_i + 1]:
				seg_i += 1
			var seg_len: float = cum[seg_i + 1] - cum[seg_i]
			var s: float = 0.5 if seg_len <= 0.0001 else clampf((t * total - cum[seg_i]) / seg_len, 0.0, 1.0)
			var center: Vector3 = points[seg_i].lerp(points[seg_i + 1], s)
			var dir: Vector3 = tans[seg_i].lerp(tans[seg_i + 1], s).normalized()
			var rad := _radius_at(radii, t)
			var w: Array = HFFMeshBuilder.norm_weights(wf.call(t))
			chain.append(ring(center, HFFMeshBuilder._frame(dir), rad.x, rad.y, seg, w[0], w[1], cf.call(t)))

		# --- End dome cap ---
		var fN: Array = HFFMeshBuilder._frame(tans[n - 1])
		var rN: Vector2 = radii[n - 1]
		var rNmax := maxf(rN.x, rN.y)
		var wN: Array = HFFMeshBuilder.norm_weights(wf.call(1.0))
		var cN: Color = cf.call(1.0)
		for k in range(1, CAP_RINGS):
			var phi := PI * 0.5 * float(k) / float(CAP_RINGS)
			var cap_c: Vector3 = points[n - 1] + tans[n - 1] * (rNmax * sin(phi))
			var sc := cos(phi)
			chain.append(ring(cap_c, fN, rN.x * sc, rN.y * sc, seg, wN[0], wN[1], cN))
		chain.append(pole(points[n - 1] + tans[n - 1] * rNmax, tans[n - 1], seg, wN[0], wN[1], cN))

		for i in chain.size() - 1:
			link(chain[i], chain[i + 1], seg)

	## Advanced vertical lathe supporting offset centers per ring for organic bodies.
	func add_offset_lathe(profile: Array, rings: int, seg: int) -> void:
		var n := profile.size()
		if n < 2:
			push_error("HFFMeshBuilder.add_offset_lathe: profile too short")
			return
		var fr := HFFMeshBuilder._frame(Vector3.UP)
		var chain: Array[int] = []

		var p0: Dictionary = profile[0]
		var off0: Vector3 = p0.get("offset", Vector3.ZERO)
		var w_b: Array = HFFMeshBuilder.norm_weights(p0["w"])
		chain.append(pole(Vector3(off0.x, p0["y"], off0.z), Vector3.DOWN, seg, w_b[0], w_b[1], p0["c"]))

		for k in rings:
			var u := float(k) / float(rings - 1)
			var cu := u * float(n - 1)
			var i := clampi(int(cu), 0, n - 2)
			var s := cu - float(i)
			var p1: Dictionary = profile[i]
			var p2: Dictionary = profile[i + 1]

			var y: float = lerpf(p1["y"], p2["y"], s)
			var off1: Vector3 = p1.get("offset", Vector3.ZERO)
			var off2: Vector3 = p2.get("offset", Vector3.ZERO)
			var off := off1.lerp(off2, s)

			var r1: Vector2 = p1["r"]
			var r2: Vector2 = p2["r"]
			var rp0: Vector2 = profile[maxi(i - 1, 0)]["r"]
			var rp3: Vector2 = profile[mini(i + 2, n - 1)]["r"]
			var rad := Vector2(
				HFFMeshBuilder.cr_interp(rp0.x, r1.x, r2.x, rp3.x, s),
				HFFMeshBuilder.cr_interp(rp0.y, r1.y, r2.y, rp3.y, s)
			)

			var w: Array = HFFMeshBuilder.norm_weights(HFFMeshBuilder.mix(p1["w"], p2["w"], s))
			var col: Color = (p1["c"] as Color).lerp(p2["c"], s)
			chain.append(ring(Vector3(off.x, y, off.z), fr, rad.x, rad.y, seg, w[0], w[1], col))

		var pn: Dictionary = profile[n - 1]
		var offN: Vector3 = pn.get("offset", Vector3.ZERO)
		var w_t: Array = HFFMeshBuilder.norm_weights(pn["w"])
		chain.append(pole(Vector3(offN.x, pn["y"], offN.z), Vector3.UP, seg, w_t[0], w_t[1], pn["c"]))

		for i in chain.size() - 1:
			link(chain[i], chain[i + 1], seg)

	## Standard vertical lathe without offsets.
	func add_lathe(profile: Array, rings: int, seg: int) -> void:
		add_offset_lathe(profile, rings, seg)

	## Ellipsoid blob with clean outward normals and CCW front-facing winding.
	func add_ball(center: Vector3, radii: Vector3, wb: Array, color: Color, seg := 16, rings := 10, rot_euler := Vector3.ZERO) -> void:
		var w: Array = HFFMeshBuilder.norm_weights(wb)
		var orient := Basis.from_euler(Vector3(deg_to_rad(rot_euler.x), deg_to_rad(rot_euler.y), deg_to_rad(rot_euler.z)))
		var chain: Array[int] = []

		var p_bot: Vector3 = center + orient * Vector3(0, -radii.y, 0)
		var n_bot: Vector3 = (orient * Vector3.DOWN).normalized()
		chain.append(pole(p_bot, n_bot, seg, w[0], w[1], color))

		for m in range(1, rings):
			var phi := -PI * 0.5 + PI * float(m) / float(rings)
			var y_local := radii.y * sin(phi)
			var sc := cos(phi)
			var rx := radii.x * sc
			var rz := radii.z * sc
			var ring_base := verts.size()

			for i in seg:
				var a := TAU * float(i) / float(seg)
				var ca := cos(a)
				var sa := sin(a)
				var local_pos := Vector3(ca * rx, y_local, sa * rz)
				var world_pos: Vector3 = center + orient * local_pos
				var local_norm := Vector3(
					ca / maxf(radii.x, 0.0001),
					sin(phi) / maxf(radii.y, 0.0001),
					sa / maxf(radii.z, 0.0001)
				).normalized()
				var world_norm: Vector3 = (orient * local_norm).normalized()

				verts.append(world_pos)
				norms.append(world_norm)
				cols.append(color)
				for j in BONES_PER_VERTEX:
					bones.append(int(w[0][j]) if j < w[0].size() else 0)
					wts.append(float(w[1][j]) if j < w[1].size() else 0.0)

			chain.append(ring_base)

		var p_top: Vector3 = center + orient * Vector3(0, radii.y, 0)
		var n_top: Vector3 = (orient * Vector3.UP).normalized()
		chain.append(pole(p_top, n_top, seg, w[0], w[1], color))

		for i in chain.size() - 1:
			link(chain[i], chain[i + 1], seg)

	## Rounded box / slab for shoe soles, visor, belts.
	func add_rounded_slab(center: Vector3, size: Vector3, wb: Array, color: Color, seg := 12) -> void:
		var half := size * 0.5
		var w: Array = HFFMeshBuilder.norm_weights(wb)
		var fr := HFFMeshBuilder._frame(Vector3.UP)
		var chain: Array[int] = []

		var y_bot := center.y - half.y
		var y_top := center.y + half.y

		chain.append(pole(Vector3(center.x, y_bot, center.z), Vector3.DOWN, seg, w[0], w[1], color))
		chain.append(ring(Vector3(center.x, y_bot, center.z), fr, half.x, half.z, seg, w[0], w[1], color))
		chain.append(ring(Vector3(center.x, y_top, center.z), fr, half.x, half.z, seg, w[0], w[1], color))
		chain.append(pole(Vector3(center.x, y_top, center.z), Vector3.UP, seg, w[0], w[1], color))

		for i in chain.size() - 1:
			link(chain[i], chain[i + 1], seg)

	## Stylized Human Fall Flat cartoon hand (palm + articulated thumb + curved mitten fingers).
	func add_stylized_hand(wrist_pos: Vector3, dir: Vector3, is_left: bool, wb: Array, skin_col: Color, cuff_col: Color, scale := 1.0) -> void:
		var sx := -1.0 if is_left else 1.0
		var palm_pos := wrist_pos + dir * (0.07 * scale)

		# Wrist cuff
		add_ball(wrist_pos, Vector3(0.065, 0.035, 0.065) * scale, wb, cuff_col, 12, 6)

		# Palm
		add_ball(palm_pos, Vector3(0.075, 0.085, 0.060) * scale, wb, skin_col, 14, 8)

		# Thumb (pointing inward/forward)
		var thumb_root := palm_pos + Vector3(0.05 * sx, -0.015, -0.035) * scale
		var thumb_tip := thumb_root + Vector3(0.035 * sx, -0.035, -0.035) * scale
		var thumb_points := [thumb_root, thumb_tip]
		var thumb_radii := [Vector2(0.028, 0.028) * scale, Vector2(0.022, 0.022) * scale]
		var wf_hand := func(_t: float) -> Array: return wb
		var cf_hand := func(_t: float) -> Color: return skin_col
		add_tube(thumb_points, thumb_radii, 10, 3, wf_hand, cf_hand)

		# 3-finger mitten bundle with soft curved tips
		var finger_base := palm_pos + dir * (0.055 * scale)
		var finger_tip := finger_base + dir * (0.055 * scale)
		var finger_points := [palm_pos, finger_base, finger_tip]
		var finger_radii := [
			Vector2(0.065, 0.050) * scale,
			Vector2(0.058, 0.042) * scale,
			Vector2(0.040, 0.030) * scale
		]
		add_tube(finger_points, finger_radii, 12, 4, wf_hand, cf_hand)

	## Stylized Human Fall Flat sneaker (rubber sole, colored canvas body, rubber toe cap, laces).
	func add_stylized_sneaker(ankle_pos: Vector3, is_left: bool, wb: Array, upper_col: Color, sole_col: Color, toe_col: Color, lace_col: Color, scale := 1.0) -> void:
		var shoe_center := ankle_pos + Vector3(0, -0.04, -0.05) * scale

		# 1. Thick rubber outsole (resting flat at bottom)
		add_rounded_slab(shoe_center + Vector3(0, -0.075 * scale, 0), Vector3(0.18, 0.045, 0.34) * scale, wb, sole_col, 16)

		# 2. Main canvas body
		add_ball(shoe_center + Vector3(0, 0.01 * scale, 0.01 * scale), Vector3(0.090, 0.080, 0.160) * scale, wb, upper_col, 16, 8)

		# 3. Curved rubber toe bumper
		add_ball(shoe_center + Vector3(0, -0.015 * scale, -0.11 * scale), Vector3(0.085, 0.058, 0.080) * scale, wb, toe_col, 14, 7)

		# 4. White laces and tongue
		add_ball(shoe_center + Vector3(0, 0.060 * scale, -0.04 * scale), Vector3(0.046, 0.020, 0.080) * scale, wb, lace_col, 10, 5)

		# 5. Ankle collar
		add_ball(ankle_pos + Vector3(0, 0.04 * scale, 0), Vector3(0.095, 0.045, 0.095) * scale, wb, upper_col, 14, 6)

	## Expressive cartoon face: large lively eyes with dark pupils, specular highlight, and eyebrows.
	func add_cartoon_eyes(head_center: Vector3, eye_spacing: float, eye_y: float, eye_z: float, eye_rad: Vector3, wb: Array, dark_col: Color, white_col: Color) -> void:
		for sx in [-1.0, 1.0]:
			var eye_pos := head_center + Vector3(eye_spacing * sx, eye_y, eye_z)
			# Sclera (White eye)
			add_ball(eye_pos, eye_rad, wb, white_col, 14, 8)
			# Pupil (Glossy dark)
			var pupil_pos := eye_pos + Vector3(0, 0, -eye_rad.z * 0.72)
			add_ball(pupil_pos, eye_rad * 0.58, wb, dark_col, 12, 6)
			# Specular highlight (Crisp white gleam at upper-outer corner)
			var gleam_pos := eye_pos + Vector3(eye_rad.x * 0.32 * sx, eye_rad.y * 0.32, -eye_rad.z * 0.95)
			add_ball(gleam_pos, eye_rad * 0.22, wb, white_col, 8, 4)
			# Curved cartoon eyebrow
			var brow_pos := eye_pos + Vector3(0, eye_rad.y * 1.35, -eye_rad.z * 0.15)
			add_ball(brow_pos, Vector3(eye_rad.x * 1.05, eye_rad.y * 0.25, eye_rad.z * 0.35), wb, dark_col, 10, 5)

	## Round hipster spectacles for Thin character.
	func add_spectacles(head_center: Vector3, eye_spacing: float, eye_y: float, eye_z: float, radius: float, wb: Array, frame_col: Color) -> void:
		for sx in [-1.0, 1.0]:
			var frame_pos := head_center + Vector3(eye_spacing * sx, eye_y, eye_z - 0.02)
			add_ball(frame_pos, Vector3(radius, radius, 0.022), wb, frame_col, 14, 7)

		# Nose bridge
		var bridge_pos := head_center + Vector3(0, eye_y, eye_z - 0.03)
		add_ball(bridge_pos, Vector3(eye_spacing * 0.45, 0.018, 0.022), wb, frame_col, 8, 4)

	## Snapback / baseball cap for Fat character fitting snugly over the head.
	func add_baseball_cap(head_center: Vector3, head_rad: Vector3, wb: Array, cap_col: Color, visor_col: Color, button_col: Color) -> void:
		# Crown covering upper half of head
		var crown_pos := head_center + Vector3(0, head_rad.y * 0.32, -0.02)
		add_ball(crown_pos, Vector3(head_rad.x * 1.06, head_rad.y * 0.76, head_rad.z * 1.06), wb, cap_col, 20, 10)

		# Forward visor
		var visor_pos := head_center + Vector3(0, head_rad.y * 0.22, -head_rad.z * 1.14)
		add_ball(visor_pos, Vector3(head_rad.x * 0.88, 0.036, head_rad.z * 0.52), wb, visor_col, 16, 7, Vector3(14, 0, 0))

		# Top button
		var button_pos := crown_pos + Vector3(0, head_rad.y * 0.74, 0)
		add_ball(button_pos, Vector3(0.048, 0.032, 0.048), wb, button_col, 10, 5)

	## Cartoon hair volume covering top & back of head.
	func add_cartoon_hair(head_center: Vector3, head_rad: Vector3, wb: Array, hair_col: Color) -> void:
		# Hair cap covering top & back
		var hair_pos := head_center + Vector3(0, head_rad.y * 0.30, 0.04)
		add_ball(hair_pos, Vector3(head_rad.x * 1.06, head_rad.y * 0.78, head_rad.z * 1.06), wb, hair_col, 18, 9)

		# Front fringe bangs
		var fringe_pos := head_center + Vector3(0, head_rad.y * 0.82, -head_rad.z * 0.65)
		add_ball(fringe_pos, Vector3(head_rad.x * 0.65, 0.09, 0.12), wb, hair_col, 12, 6)

	func _radius_at(radii: Array, t: float) -> Vector2:
		var n := radii.size()
		var cu := clampf(t, 0.0, 1.0) * float(n - 1)
		var i := clampi(int(cu), 0, n - 2)
		var s := cu - float(i)
		var r0: Vector2 = radii[maxi(i - 1, 0)]
		var r1: Vector2 = radii[i]
		var r2: Vector2 = radii[i + 1]
		var r3: Vector2 = radii[mini(i + 2, n - 1)]
		return Vector2(
			HFFMeshBuilder.cr_interp(r0.x, r1.x, r2.x, r3.x, s),
			HFFMeshBuilder.cr_interp(r0.y, r1.y, r2.y, r3.y, s)
		)


## Stable ring frame with right x up == dir.
static func _frame(dir: Vector3) -> Array:
	var d := dir.normalized()
	var right: Vector3
	if absf(d.y) > 0.85:
		right = Vector3.BACK
	else:
		right = Vector3.UP.cross(d).normalized()
	var up := d.cross(right).normalized()
	return [right, up]


## Uniform Catmull-Rom interpolation.
static func cr_interp(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Linear blend of two weight-pair lists.
static func mix(a: Array, b: Array, k: float) -> Array:
	var merged := {}
	for pair in a:
		merged[int(pair[0])] = (pair[1] as float) * (1.0 - k)
	for pair in b:
		var bone := int(pair[0])
		merged[bone] = (merged.get(bone, 0.0) as float) + (pair[1] as float) * k
	return _pairs_from_map(merged)


static func _pairs_from_map(map: Dictionary) -> Array:
	var pairs := []
	for bone in map:
		var w: float = map[bone]
		if w > 0.001:
			pairs.append([int(bone), w])
	return pairs


## Normalizes weight pairs, keeps the 4 strongest. Returns [bones, weights].
static func norm_weights(input: Array) -> Array:
	if input.is_empty():
		return [[0], [1.0]]

	var map := {}
	if input[0] is Array and input[0].size() == 2 and (input[0][1] is float or input[0][1] is int):
		for item in input:
			if item is Array and item.size() >= 2:
				var bone := int(item[0])
				var w := float(item[1])
				map[bone] = (map.get(bone, 0.0) as float) + w
	elif input.size() == 2 and input[0] is Array and input[1] is Array:
		return input
	else:
		for item in input:
			if item is Array and item.size() >= 2:
				var bone := int(item[0])
				var w := float(item[1])
				map[bone] = (map.get(bone, 0.0) as float) + w
			elif item is int or item is float:
				map[int(item)] = 1.0

	var bones := []
	var weights := []
	var total := 0.0
	for bone in map:
		var w: float = map[bone]
		if w > 0.001:
			bones.append(int(bone))
			weights.append(w)
			total += w
	if bones.is_empty() or total <= 0.0001:
		return [[0], [1.0]]
	var order := range(bones.size())
	order.sort_custom(func(a: int, b: int) -> bool: return weights[a] > weights[b])
	var out_b := []
	var out_w := []
	var sum := 0.0
	for idx in order.slice(0, BONES_PER_VERTEX):
		out_b.append(bones[idx])
		out_w.append(weights[idx])
		sum += weights[idx]
	for i in out_w.size():
		out_w[i] /= sum
	return [out_b, out_w]
