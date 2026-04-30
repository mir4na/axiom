shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(0.95, 1.0, 0.82);
uniform float glow_strength : hint_range(0.0, 6.0) = 2.8;
uniform float corner_roundness : hint_range(0.0, 0.8) = 0.22;
uniform float corner_softness : hint_range(0.001, 0.2) = 0.028;
uniform float content_fit : hint_range(0.7, 1.2) = 0.92;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float rounded_mask(vec2 uv, float radius, float feather) {
	vec2 p = uv * 2.0 - 1.0;
	vec2 half_size = vec2(1.0 - radius);
	vec2 q = abs(p) - half_size;
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	return 1.0 - smoothstep(0.0, feather, dist);
}

void fragment() {
	vec2 frame_uv = (SCREEN_UV - vec2(0.5)) / content_fit + vec2(0.5);
	float frame_mask = rounded_mask(frame_uv, corner_roundness, corner_softness);

	float x_power = smoothstep(0.0, 0.30, power);
	float y_power = smoothstep(0.22, 1.0, power);
	vec2 p = frame_uv * 2.0 - 1.0;
	vec2 half_size = vec2(0.01 + x_power * 0.99, 0.001 + y_power * 0.999);
	float radius = mix(0.0, corner_roundness, y_power);
	float sdf = rounded_box(p, half_size, radius);
	float grow_reveal = 1.0 - smoothstep(0.0, 0.02, sdf);
	float reveal = min(frame_mask, grow_reveal);
	float line = exp(-abs(p.y) * mix(440.0, 18.0, y_power)) * (1.0 - y_power);
	float pulse = 0.84 + 0.16 * sin(TIME * 52.0);
	float center_burst = exp(-dot(p, p) * 36.0) * (1.0 - y_power) * 1.2;
	float glow = max(line * pulse, center_burst) * frame_mask;
	vec3 scene_col = texture(screen_texture, frame_uv).rgb;
	vec3 lit_scene = scene_col * reveal;
	vec3 beam = glow_color * glow * glow_strength;
	float visibility = clamp(reveal + glow * 0.9, 0.0, 1.0) * frame_mask;
	vec3 col = mix(vec3(0.0), lit_scene + beam, visibility);
	COLOR = vec4(col, 1.0);
}
