shader_type spatial;
render_mode cull_disabled, blend_mix, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform vec4 edge_color : source_color = vec4(0.22, 0.22, 0.3, 1.0);
uniform float metallic_value : hint_range(0.0, 1.0) = 0.88;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.18;
uniform float emission_energy : hint_range(0.0, 12.0) = 3.4;
uniform float pulse_speed : hint_range(0.0, 16.0) = 4.8;
uniform float streak_density : hint_range(1.0, 120.0) = 38.0;
uniform float edge_power : hint_range(0.1, 8.0) = 2.8;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(dot(view_dir, NORMAL), 0.0, 1.0), edge_power);
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed + UV.y * 8.0);
	float streak = sin(UV.y * streak_density - TIME * (pulse_speed * 3.2)) * 0.5 + 0.5;
	float cross = sin(UV.x * 48.0 + TIME * (pulse_speed * 2.0)) * 0.5 + 0.5;
	float mix_v = clamp(streak * 0.58 + pulse * 0.28 + cross * 0.14, 0.0, 1.0);
	vec3 col = mix(base_color.rgb, edge_color.rgb, mix_v);
	ALBEDO = col;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.95;
	EMISSION = col * emission_energy * (0.38 + pulse * 0.52 + fresnel * 1.4) * intensity;
	ALPHA = clamp(base_color.a * (0.7 + fresnel * 0.3) * intensity, 0.0, 1.0);
}
