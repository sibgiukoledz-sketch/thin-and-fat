shader_type spatial;
render_mode cull_front, unshaded;

// Reusable Cartoon Inverted-Hull Outline Shader
// Extrudes vertices along vertex normals to draw a crisp outline silhouette.

uniform float outline_width : hint_range(0.0, 0.2, 0.002) = 0.028;
uniform vec4 outline_color : source_color = vec4(0.08, 0.08, 0.12, 1.0);
uniform bool use_smooth_normals = false;

void vertex() {
	// Extrude along normal in view or local space
	vec3 norm = NORMAL;
	if (use_smooth_normals) {
		norm = normalize(VERTEX);
	}
	VERTEX += norm * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
