shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 core_color : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform vec4 edge_color : source_color = vec4(0.16, 0.16, 0.22, 1.0);
uniform float glow_strength : hint_range(0.0, 20.0) = 5.0;
uniform float flicker_speed : hint_range(1.0, 160.0) = 92.0;
uniform float noise_scale : hint_range(1.0, 120.0) = 34.0;
uniform float thickness : hint_range(0.02, 0.9) = 0.22;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float segment_seed : hint_range(0.0, 1024.0) = 0.0;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

void fragment() {
	float y = UV.y;
	float x = UV.x - 0.5;
	float seg = floor(y * noise_scale + segment_seed);
	float shift = (hash11(seg + 0.23) - 0.5) * 0.42;
	shift += (hash11(seg * 0.71 + 13.7) - 0.5) * 0.24;
	float branch = smoothstep(0.72, 1.0, hash11(seg * 1.21 + 4.3));
	float branch_shift = shift + (hash11(seg + 8.17) - 0.5) * 0.35;
	float d_main = abs(x - shift);
	float d_branch = abs(x - branch_shift);
	float main_line = smoothstep(thickness, 0.0, d_main);
	float branch_line = smoothstep(thickness * 0.68, 0.0, d_branch) * branch * 0.8;
	float body = clamp(main_line + branch_line, 0.0, 1.0);
	float flicker = 0.55 + 0.45 * sin(TIME * flicker_speed + y * 80.0 + segment_seed * 0.11);
	flicker *= 0.88 + 0.12 * sin(TIME * 41.0 + y * 17.0);
	vec3 col = mix(edge_color.rgb, core_color.rgb, main_line);
	float alpha = clamp(body * flicker * intensity, 0.0, 1.0);
	ALBEDO = col;
	EMISSION = col * glow_strength * (0.45 + body * 1.5) * intensity;
	ALPHA = alpha;
}
