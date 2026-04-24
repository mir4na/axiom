shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint_color : source_color = vec4(1.0, 0.2, 0.12, 0.9);
uniform float glow_strength = 6.2;
uniform float pulse_speed = 17.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radial = clamp(1.0 - length(p), 0.0, 1.0);
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed + radial * 9.0);
	float alpha = radial * tint_color.a * pulse;
	ALBEDO = tint_color.rgb;
	EMISSION = tint_color.rgb * glow_strength * radial * pulse;
	ALPHA = alpha;
}
