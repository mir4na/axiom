shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

uniform vec4 base_color : source_color = vec4(0.72, 0.9, 1.0, 0.75);
uniform vec4 accent_color : source_color = vec4(1.0, 0.86, 0.58, 1.0);
uniform float emission_energy = 3.2;
uniform float pulse_speed = 2.0;
uniform float streak_density = 18.0;
uniform float streak_speed = 1.4;
uniform float edge_power = 2.0;
uniform float alpha_strength = 1.0;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.y * 10.0);
	float streaks = sin(UV.y * streak_density - TIME * streak_speed) * 0.5 + 0.5;
	float cross = sin(UV.x * 28.0 + TIME * 2.0) * 0.5 + 0.5;
	float fresnel = pow(1.0 - abs(dot(normalize(VIEW), NORMAL)), edge_power);
	float mix_value = clamp(streaks * 0.6 + pulse * 0.35 + cross * 0.2, 0.0, 1.0);
	vec3 color = mix(base_color.rgb, accent_color.rgb, mix_value);
	float glow = 0.55 + pulse * 0.45 + streaks * 0.35 + fresnel * 1.25;
	ALBEDO = color;
	EMISSION = color * emission_energy * glow;
	ALPHA = clamp(base_color.a * alpha_strength * (0.65 + pulse * 0.15 + fresnel * 0.35), 0.0, 1.0);
}
