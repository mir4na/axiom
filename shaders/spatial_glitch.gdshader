shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float glitch_speed : hint_range(0.0, 10.0) = 5.0;
uniform float glitch_intensity : hint_range(0.0, 5.0) = 0.5;
uniform vec3 base_color = vec3(0.0, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 2.0;
uniform float rim_strength : hint_range(0.0, 6.0) = 2.4;
uniform float pulse_strength : hint_range(0.0, 3.0) = 1.1;
uniform float stripe_density : hint_range(1.0, 120.0) = 54.0;
uniform float alpha_flicker : hint_range(0.0, 1.0) = 0.2;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec2 uv_time = VERTEX.xz + vec2(TIME * glitch_speed);
	float r = rand(floor(uv_time * 2.0));
	float wave = sin((VERTEX.y + TIME * glitch_speed * 1.7) * 5.0 + VERTEX.x * 1.8) * 0.5 + 0.5;

	if (r > 0.8) {
		float displacement = (rand(vec2(TIME, float(VERTEX_ID))) - 0.5) * glitch_intensity;
		VERTEX.x += displacement + (wave - 0.5) * glitch_intensity * 0.18;
		VERTEX.y += displacement * 0.7;
		VERTEX.z -= displacement * 1.15;
	}
}

void fragment() {
	float scanline = sin(UV.y * stripe_density - TIME * (8.0 + glitch_speed * 1.2)) * 0.5 + 0.5;
	float crossline = sin(UV.x * (stripe_density * 0.55) + TIME * (6.0 + glitch_speed)) * 0.5 + 0.5;
	float noise = rand(UV * 3.5 + vec2(TIME * 0.7, -TIME * 1.1));
	float pulse = sin(TIME * (4.0 + glitch_speed * 0.85) + UV.y * 14.0) * 0.5 + 0.5;
	float flicker = step(0.72, rand(vec2(floor(TIME * 14.0), floor(UV.y * 20.0)))) * alpha_flicker;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.7) * rim_strength;
	vec3 final_color = base_color;

	if (noise > 0.8) {
		final_color = mix(base_color, vec3(1.0, 0.0, 1.0), 0.85);
	} else if (noise < 0.2) {
		final_color = mix(base_color, vec3(0.0, 1.0, 0.5), 0.8);
	}

	float band_mix = mix(scanline, crossline, 0.35);
	float brightness = mix(0.45, 1.25, band_mix) + pulse * pulse_strength + rim;

	ALBEDO = final_color * brightness;
	EMISSION = final_color * emission_energy * (brightness + rim * 0.6);
	ALPHA = clamp(0.72 + pulse * 0.18 + rim * 0.08 - flicker, 0.38, 0.96);
}
