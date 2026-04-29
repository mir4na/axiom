shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 ring_color : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform vec4 core_color : source_color = vec4(0.12, 0.12, 0.16, 1.0);
uniform float glow_strength : hint_range(0.0, 20.0) = 3.2;
uniform float expansion : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = smoothstep(0.38, 0.0, r);
	float ring_center = mix(0.16, 0.94, expansion);
	float ring_width = mix(0.18, 0.06, expansion);
	float ring = 1.0 - smoothstep(ring_center - ring_width, ring_center + ring_width, r);
	ring *= smoothstep(1.02, 0.0, r);
	float ripple = 0.7 + 0.3 * sin(TIME * 30.0 + r * 44.0);
	float field = clamp(core * 0.85 + ring * 1.3, 0.0, 1.0) * ripple;
	vec3 col = mix(ring_color.rgb, core_color.rgb, core);
	ALBEDO = col;
	EMISSION = col * glow_strength * field * intensity;
	ALPHA = clamp(field * intensity, 0.0, 1.0);
}
