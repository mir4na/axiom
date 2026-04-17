shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front;

uniform vec4 glow_color : source_color = vec4(0.82, 0.98, 0.62, 1.0);
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.8);
	float aura = highlight_strength * (0.4 + fresnel * 1.8);
	ALBEDO = vec3(0.0);
	EMISSION = glow_color.rgb * aura * 2.2;
	ALPHA = clamp(aura * 0.38, 0.0, 1.0);
}
