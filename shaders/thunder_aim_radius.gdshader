shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 fill_color : source_color = vec4(0.02, 0.02, 0.025, 0.34);
uniform vec4 edge_color : source_color = vec4(0.08, 0.08, 0.1, 0.96);
uniform vec4 core_color : source_color = vec4(0.12, 0.12, 0.16, 0.88);
uniform float ring_radius : hint_range(0.0, 1.0) = 0.86;
uniform float ring_width : hint_range(0.005, 0.4) = 0.08;
uniform float glow_strength : hint_range(0.0, 10.0) = 2.8;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fill_mask = smoothstep(1.0, 0.0, r);
	float outer = smoothstep(ring_radius + ring_width, ring_radius, r);
	float inner = smoothstep(ring_radius, ring_radius - ring_width, r);
	float ring = clamp(outer * (1.0 - inner), 0.0, 1.0);
	float core = smoothstep(0.11, 0.0, r);
	float pulse = 0.82 + 0.18 * sin(TIME * 9.2);
	vec3 col = fill_color.rgb * fill_mask;
	col = mix(col, edge_color.rgb, ring);
	col = mix(col, core_color.rgb, core * 0.7);
	float alpha = clamp(fill_color.a * fill_mask + edge_color.a * ring + core_color.a * core * 0.42, 0.0, 1.0) * intensity;
	ALBEDO = col;
	EMISSION = col * glow_strength * (ring * 0.95 + core * 0.5) * pulse * intensity;
	ALPHA = alpha;
}
