shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.06, 0.1, 0.09, 1.0);
uniform vec4 edge_color : source_color = vec4(0.34, 0.96, 0.54, 1.0);
uniform vec4 glow_color : source_color = vec4(0.18, 0.78, 0.4, 1.0);
uniform float emission_energy : hint_range(0.0, 12.0) = 3.4;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.88;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.14;
uniform float flow_speed : hint_range(0.0, 8.0) = 2.2;
uniform float flow_density : hint_range(1.0, 36.0) = 16.0;
uniform float edge_power : hint_range(0.2, 8.0) = 2.2;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * flow_speed;
	float core = 1.0 - abs(uv.x * 2.0 - 1.0);
	float edge_mask = pow(1.0 - core, edge_power);
	float flow = sin((uv.y * flow_density) - t) * 0.5 + 0.5;
	float grain = noise(uv * 24.0 + vec2(t * 0.23, -t * 0.17));
	float energy = clamp(flow * 0.72 + grain * 0.38, 0.0, 1.0);
	vec3 albedo = mix(base_color.rgb, edge_color.rgb, edge_mask * 0.9 + energy * 0.22);
	vec3 emission = glow_color.rgb * (0.35 + edge_mask * 0.95 + energy * 0.8) * emission_energy;
	ALBEDO = albedo;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.86;
	EMISSION = emission;
}
