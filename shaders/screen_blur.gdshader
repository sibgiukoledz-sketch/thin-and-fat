shader_type canvas_item;

// High performance mipmap screen blur shader for Pause Menu and Dialog Backdrops
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform vec4 tint_color : source_color = vec4(0.04, 0.06, 0.10, 0.72);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = mix(blurred, vec4(tint_color.rgb, 1.0), tint_color.a);
}
