shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.02, 0.02, 0.02, 0.82);
uniform vec4 edge_color : source_color = vec4(0.18, 0.18, 0.2, 0.92);
uniform float pulse_speed : hint_range(0.0, 12.0) = 5.2;
uniform float pulse_strength : hint_range(0.0, 2.0) = 0.75;
uniform float alpha_boost : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float radial = abs(UV.x * 2.0 - 1.0);
	float edge = pow(1.0 - clamp(radial, 0.0, 1.0), 2.4);
	float pulse = 0.65 + sin((UV.y * 18.0) - (TIME * pulse_speed)) * 0.35;
	float intensity = clamp(edge * (0.7 + pulse * pulse_strength), 0.0, 1.0);
	vec3 col = mix(core_color.rgb, edge_color.rgb, edge);
	ALBEDO = col;
	EMISSION = col * (1.2 + intensity * 3.2);
	ALPHA = clamp((core_color.a + intensity * 0.6) * alpha_boost, 0.0, 1.0);
}
