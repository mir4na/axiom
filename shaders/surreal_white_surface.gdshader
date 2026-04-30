shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.82, 0.9, 1.0, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.28;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.08;
uniform float emission_strength : hint_range(0.0, 6.0) = 1.25;
uniform float pulse_speed : hint_range(0.0, 8.0) = 1.6;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.24;
uniform float fresnel_strength : hint_range(0.0, 3.0) = 1.2;

void fragment() {
	float wave = sin((UV.x * 7.0 + UV.y * 5.0) + TIME * pulse_speed) * 0.5 + 0.5;
	float pulse = mix(1.0 - pulse_amount, 1.0 + pulse_amount, wave);
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fresnel = pow(1.0 - max(dot(n, v), 0.0), 2.2) * fresnel_strength;
	vec3 tint = mix(base_color.rgb, edge_color.rgb, clamp(fresnel, 0.0, 1.0));
	ALBEDO = tint;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
	EMISSION = tint * emission_strength * pulse;
}
