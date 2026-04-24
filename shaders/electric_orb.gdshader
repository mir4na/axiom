shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint_a : source_color = vec4(0.18, 0.92, 1.0, 0.92);
uniform vec4 tint_b : source_color = vec4(0.66, 0.28, 1.0, 0.9);
uniform float glow_strength = 7.2;
uniform float flicker_speed = 9.0;
uniform float ripple_speed = 3.4;

void fragment() {
	float swirl = UV.x * 11.0 + TIME * ripple_speed;
	float side_warp = sin((UV.y + TIME * 0.35) * 34.0) * 0.24;
	float filaments = abs(sin((swirl + side_warp) * TAU));
	filaments = pow(filaments, 8.0);
	float sparks = abs(sin((UV.x * 29.0 - TIME * flicker_speed) * TAU + UV.y * 57.0));
	sparks = pow(sparks, 14.0);
	float envelope = smoothstep(0.02, 0.3, UV.y) * (1.0 - smoothstep(0.7, 0.98, UV.y));
	float flicker = 0.62 + 0.38 * sin(TIME * flicker_speed + UV.x * 31.0 + UV.y * 19.0);
	float alpha = clamp((filaments * envelope + sparks * 0.5) * tint_a.a * flicker, 0.0, 1.0);
	vec3 blend = mix(tint_a.rgb, tint_b.rgb, 0.5 + 0.5 * sin(TIME * 2.6 + UV.x * TAU * 5.0));
	ALBEDO = blend;
	EMISSION = blend * glow_strength * (0.32 + filaments * 1.35 + sparks * 1.1) * flicker;
	ALPHA = alpha;
}
