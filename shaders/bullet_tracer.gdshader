shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint_color : source_color = vec4(1.0, 0.9, 0.55, 0.92);
uniform float glow_strength = 4.8;
uniform float pulse_speed = 11.0;

void fragment() {
	float line = smoothstep(0.58, 0.0, abs(UV.y - 0.5));
	float pulse = 0.62 + 0.38 * sin(TIME * pulse_speed + UV.x * 20.0);
	float alpha = line * tint_color.a * pulse;
	ALBEDO = tint_color.rgb;
	EMISSION = tint_color.rgb * glow_strength * (0.3 + line * 0.7) * pulse;
	ALPHA = alpha;
}
