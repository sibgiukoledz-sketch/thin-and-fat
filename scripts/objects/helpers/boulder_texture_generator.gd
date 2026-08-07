class_name BoulderTextureGenerator
extends RefCounted

## Utility generator for 512x512 procedural multi-layer rock textures (Albedo, Normal, Roughness)

static func generate_rock_textures() -> Array[ImageTexture]:
	var width: int = 512
	var height: int = 512
	var albedo_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var normal_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rough_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	var noise_base: FastNoiseLite = FastNoiseLite.new()
	noise_base.seed = 12345
	noise_base.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_base.frequency = 0.02
	noise_base.fractal_octaves = 6

	var noise_cracks: FastNoiseLite = FastNoiseLite.new()
	noise_cracks.seed = 99999
	noise_cracks.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_cracks.frequency = 0.06

	var noise_lichen: FastNoiseLite = FastNoiseLite.new()
	noise_lichen.seed = 77777
	noise_lichen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_lichen.frequency = 0.09

	for y in range(height):
		for x in range(width):
			var fx: float = float(x)
			var fy: float = float(y)

			var n_base: float = (noise_base.get_noise_2d(fx, fy) + 1.0) * 0.5
			var n_crack: float = (noise_cracks.get_noise_2d(fx, fy) + 1.0) * 0.5
			var n_lichen: float = (noise_lichen.get_noise_2d(fx, fy) + 1.0) * 0.5

			var granite_col: Color = Color(0.20, 0.18, 0.16, 1.0).lerp(Color(0.55, 0.50, 0.42, 1.0), n_base)
			if n_crack < 0.35:
				var crack_factor: float = smoothstep(0.35, 0.1, n_crack)
				granite_col = granite_col.lerp(Color(0.12, 0.09, 0.07, 1.0), crack_factor * 0.85)
			if n_lichen > 0.62:
				var moss_factor: float = smoothstep(0.62, 0.85, n_lichen)
				granite_col = granite_col.lerp(Color(0.32, 0.38, 0.22, 1.0), moss_factor * 0.7)

			albedo_img.set_pixel(x, y, granite_col)

			var nx: float = (noise_base.get_noise_2d(fx + 1.0, fy) - noise_base.get_noise_2d(fx - 1.0, fy)) * 6.0
			var ny: float = (noise_base.get_noise_2d(fx, fy + 1.0) - noise_base.get_noise_2d(fx, fy - 1.0)) * 6.0
			var normal_vec: Vector3 = Vector3(-nx, -ny, 1.0).normalized()
			var norm_col: Color = Color(normal_vec.x * 0.5 + 0.5, normal_vec.y * 0.5 + 0.5, normal_vec.z * 0.5 + 0.5, 1.0)
			normal_img.set_pixel(x, y, norm_col)

			var rough_val: float = clampf(0.85 + (n_base - 0.5) * 0.3 - (n_lichen * 0.25), 0.35, 0.98)
			rough_img.set_pixel(x, y, Color(rough_val, rough_val, rough_val, 1.0))

	var albedo_tex: ImageTexture = ImageTexture.create_from_image(albedo_img)
	var normal_tex: ImageTexture = ImageTexture.create_from_image(normal_img)
	var rough_tex: ImageTexture = ImageTexture.create_from_image(rough_img)
	return [albedo_tex, normal_tex, rough_tex]
