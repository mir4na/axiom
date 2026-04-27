shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

uniform vec4 base_color : source_color = vec4(0.72, 0.9, 1.0, 0.8);
uniform vec4 accent_color : source_color = vec4(1.0, 0.78, 0.86, 1.0);
uniform float emission_energy = 2.8;
uniform float pulse_speed = 1.7;
uniform float flow_strength = 0.24;
uniform float edge_softness = 1.25;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.y * 9.0 + UV.x * 13.0);
	float flow = sin((UV.y + TIME * 0.38) * 22.0) * 0.5 + 0.5;
	float blend = clamp(pulse * 0.7 + flow * flow_strength, 0.0, 1.0);
	vec3 color = mix(base_color.rgb, accent_color.rgb, blend);
	float fresnel = pow(1.0 - abs(dot(normalize(VIEW), NORMAL)), edge_softness);
	ALBEDO = color;
	EMISSION = color * emission_energy * (0.65 + pulse * 0.7 + fresnel * 1.15);
	ALPHA = clamp(base_color.a * (0.72 + pulse * 0.28 + fresnel * 0.25), 0.0, 1.0);
}
