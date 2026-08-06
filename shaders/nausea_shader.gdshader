shader_type canvas_item;

// High quality 1st-Person Nausea, Double-Vision & Chromatic Aberration Shader
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_speed : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	if (intensity < 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		vec2 uv = SCREEN_UV;
		float time = TIME * distortion_speed;

		// 1. Organic Wobbly Wave UV Distortion
		vec2 wave_offset = vec2(
			sin(time * 2.5 + uv.y * 12.0) * 0.015 * intensity,
			cos(time * 2.0 + uv.x * 10.0) * 0.015 * intensity
		);
		vec2 distorted_uv = uv + wave_offset;

		// 2. Chromatic Aberration & Double Vision Offset
		float ab_offset = 0.018 * intensity;
		float r = texture(screen_texture, distorted_uv + vec2(ab_offset, 0.0)).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv - vec2(ab_offset, 0.0)).b;

		// 3. Dark Sickly Vignette Tint (Dark Bile Tone)
		vec2 dist_from_center = uv - vec2(0.5);
		float vignette = smoothstep(0.2, 0.75, length(dist_from_center)) * intensity * 0.75;
		vec3 bile_tint = vec3(0.12, 0.18, 0.04);

		vec3 final_color = mix(vec3(r, g, b), bile_tint, vignette * 0.65);
		COLOR = vec4(final_color, clamp(vignette + intensity * 0.2, 0.0, 0.85));
	}
}
