shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 core_color : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform vec4 edge_color : source_color = vec4(0.12, 0.12, 0.16, 1.0);
uniform float glow_strength : hint_range(0.0, 20.0) = 3.8;
uniform float flicker_speed : hint_range(1.0, 160.0) = 72.0;
uniform float branch_density : hint_range(1.0, 80.0) = 32.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

float seg_shift(float y, float seed) {
	float base = floor(y * branch_density + seed);
	float n0 = hash11(base + 0.31);
	float n1 = hash11(base + 3.79);
	return (n0 - 0.5) * 0.26 + (n1 - 0.5) * 0.14;
}

void fragment() {
	float y = clamp(UV.y, 0.0, 1.0);
	float x = UV.x - 0.5;
	float shift_a = seg_shift(y + TIME * 0.8, 0.0);
	float shift_b = seg_shift(y * 1.3 + TIME * 1.1, 21.7) * 0.65;
	float path = shift_a + shift_b;
	float dist = abs(x - path);
	float core = smoothstep(0.06, 0.0, dist);
	float edge = smoothstep(0.22, 0.04, dist);
	float flicker = 0.58 + 0.42 * sin(TIME * flicker_speed + y * 80.0 + sin(TIME * 8.0 + y * 30.0));
	float branch = smoothstep(0.72, 1.0, hash11(floor(y * branch_density * 0.7) + floor(TIME * 30.0)));
	branch *= smoothstep(0.2, 0.0, abs(x - (path + (hash11(y * 91.0) - 0.5) * 0.28)));
	float body = clamp(core * 1.35 + edge * 0.55 + branch * 0.95, 0.0, 1.0);
	float alpha = body * flicker * intensity;
	vec3 col = mix(edge_color.rgb, core_color.rgb, clamp(core * 1.2, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * glow_strength * (0.5 + body * 1.1) * intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
