shader_type spatial;
render_mode cull_front, unshaded;

// Cartoon Inverted-Hull Outline Shader (100% Opaque)
uniform float outline_width : hint_range(0.0, 0.1, 0.001) = 0.018;
uniform vec4 outline_color : source_color = vec4(0.08, 0.08, 0.12, 1.0);

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
