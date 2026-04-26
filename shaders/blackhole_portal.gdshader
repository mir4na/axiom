shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform float open_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outer_color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform vec4 inner_color : source_color = vec4(0.05, 0.02, 0.08, 1.0);
uniform vec4 glitch_color : source_color = vec4(1.0, 0.2, 0.9, 1.0);
uniform float swirl_speed : hint_range(0.0, 12.0) = 3.6;
uniform float ring_width : hint_range(0.02, 0.8) = 0.2;
uniform float glow_strength : hint_range(0.0, 16.0) = 6.0;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float radius = length(uv);
	float angle = atan(uv.y, uv.x);
	float swirl = sin(angle * 8.0 + TIME * swirl_speed + radius * 18.0) * 0.5 + 0.5;
	float ripple = sin(radius * 28.0 - TIME * (swirl_speed * 2.2)) * 0.5 + 0.5;
	float noise = rand(floor((uv + 1.0) * 12.0) + vec2(floor(TIME * 10.0), floor(TIME * 7.0)));
	float ring_outer = smoothstep(1.02, 0.76, radius);
	float ring_inner = smoothstep(0.76 - ring_width, 0.14 + ring_width * 0.2, radius);
	float ring = clamp(ring_outer - ring_inner, 0.0, 1.0);
	float core = smoothstep(0.7, 0.08, radius);
	float void_hole = 1.0 - smoothstep(0.0, 0.22, radius);
	vec3 ring_color = mix(outer_color.rgb, glitch_color.rgb, swirl * 0.35 + noise * 0.2);
	vec3 core_color = mix(inner_color.rgb, ring_color, ripple * 0.16);
	vec3 color = mix(core_color, ring_color, ring);
	float emission_mask = ring * (0.7 + swirl * 0.7 + ripple * 0.45) + core * 0.28;
	float alpha = (ring * 0.95 + core * 0.42) * open_amount;
	alpha *= smoothstep(1.06, 0.92, radius);
	alpha *= 1.0 - void_hole * 0.92;
	ALBEDO = color;
	EMISSION = color * emission_mask * glow_strength * open_amount;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
