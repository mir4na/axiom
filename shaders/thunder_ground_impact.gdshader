shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 burn_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform vec4 ring_color : source_color = vec4(0.14, 0.14, 0.18, 1.0);
uniform float glow_strength : hint_range(0.0, 12.0) = 3.6;
uniform float expansion : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float radial_noise = hash21(vec2(floor((angle + 3.14159) * 14.0), floor(r * 20.0 + expansion * 20.0)));
	float crack = smoothstep(0.75, 1.0, radial_noise) * smoothstep(0.85, 0.18, r);
	float burn = smoothstep(1.0, 0.0, r);
	float ring_center = mix(0.16, 0.94, expansion);
	float ring_width = mix(0.18, 0.06, expansion);
	float ring = 1.0 - smoothstep(ring_center - ring_width, ring_center + ring_width, r);
	ring *= smoothstep(1.02, 0.0, r);
	float pulse = 0.7 + 0.3 * sin(TIME * 30.0 + r * 48.0);
	float field = clamp(burn * 0.8 + ring * 1.25 + crack * 0.85, 0.0, 1.0) * pulse;
	vec3 col = mix(burn_color.rgb, ring_color.rgb, ring + crack * 0.6);
	ALBEDO = col;
	EMISSION = col * glow_strength * field * intensity;
	ALPHA = clamp(field * intensity, 0.0, 1.0);
}
