shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint_a : source_color = vec4(0.18, 0.92, 1.0, 0.92);
uniform vec4 tint_b : source_color = vec4(0.66, 0.28, 1.0, 0.9);
uniform float glow_strength = 7.2;
uniform float flicker_speed = 9.0;
uniform float ripple_speed = 3.4;

void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float radial = length(centered_uv);
	float orb_mask = 1.0 - smoothstep(0.28, 1.0, radial);
	float swirl = atan(centered_uv.y, centered_uv.x) * 2.2 + TIME * ripple_speed;
	float branch_a = abs(sin(swirl * 3.0 + radial * 19.0 - TIME * flicker_speed));
	float branch_b = abs(sin(swirl * 4.7 - radial * 23.0 + TIME * (flicker_speed * 0.7)));
	float lightning = pow(max(branch_a, branch_b), 8.5);
	float sparks = abs(sin((UV.x * 31.0 - TIME * flicker_speed) * TAU + UV.y * 61.0));
	sparks = pow(sparks, 15.0) * orb_mask;
	float halo = 1.0 - smoothstep(0.12, 0.86, radial);
	float flicker = 0.68 + 0.32 * sin(TIME * flicker_speed + UV.x * 27.0 + UV.y * 19.0);
	float alpha = clamp((orb_mask * 0.46 + lightning * halo + sparks * 0.52) * tint_a.a * flicker, 0.0, 1.0);
	vec3 blend = mix(tint_a.rgb, tint_b.rgb, 0.5 + 0.5 * sin(TIME * 2.6 + radial * 12.0 + swirl * 0.4));
	ALBEDO = blend;
	EMISSION = blend * glow_strength * (0.28 + orb_mask * 0.55 + lightning * 1.45 + sparks * 1.1) * flicker;
	ALPHA = alpha;
}
