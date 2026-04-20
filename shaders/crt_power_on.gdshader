shader_type canvas_item;

uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(0.95, 1.0, 0.82);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.4;
uniform float corner_roundness : hint_range(0.0, 0.8) = 0.22;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	float x_power = smoothstep(0.0, 0.24, power);
	float y_power = smoothstep(0.16, 1.0, power);
	vec2 p = UV * 2.0 - 1.0;
	vec2 half_size = vec2(0.02 + x_power * 0.98, 0.003 + y_power * 0.97);
	float radius = mix(0.0, corner_roundness, y_power);
	float sdf = rounded_box(p, half_size, radius);
	float reveal = 1.0 - smoothstep(0.0, 0.03, sdf);
	float line = exp(-abs(p.y) * mix(210.0, 14.0, y_power)) * (1.0 - y_power);
	float shimmer = (0.75 + 0.25 * sin(TIME * 46.0)) * (1.0 - y_power);
	float core = max(reveal, line * shimmer);
	float alpha = clamp(1.0 - core, 0.0, 1.0);
	vec3 color = glow_color * line * glow_strength;
	COLOR = vec4(color, alpha);
}
