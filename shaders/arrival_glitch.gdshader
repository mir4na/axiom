shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.0;
uniform float line_density : hint_range(10.0, 300.0) = 110.0;
uniform float corner_roundness : hint_range(0.0, 0.8) = 0.22;
uniform float corner_softness : hint_range(0.001, 0.2) = 0.028;
uniform float content_fit : hint_range(0.7, 1.2) = 0.92;
uniform bool apply_crt_mask = false;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
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
	vec2 uv = frame_uv;
	float frame_mask = 1.0;
	if (apply_crt_mask) {
		frame_mask = rounded_mask(frame_uv, corner_roundness, corner_softness);
	}
	float block = floor(uv.y * line_density + TIME * 9.0);
	float noise = rand(vec2(block, floor(TIME * 18.0)));
	float x_shift = (noise - 0.5) * 0.08 * glitch_strength;
	float y_jitter = (rand(vec2(block * 0.71, floor(TIME * 23.0))) - 0.5) * 0.01 * glitch_strength;
	vec2 shifted_uv = vec2(clamp(uv.x + x_shift, 0.0, 1.0), clamp(uv.y + y_jitter, 0.0, 1.0));
	float split = glitch_strength * 0.012;
	vec3 color;
	color.r = texture(screen_texture, clamp(shifted_uv + vec2(split, 0.0), vec2(0.0), vec2(1.0))).r;
	color.g = texture(screen_texture, shifted_uv).g;
	color.b = texture(screen_texture, clamp(shifted_uv - vec2(split, 0.0), vec2(0.0), vec2(1.0))).b;
	float scan = sin((uv.y + TIME * 0.8) * line_density * 1.8) * 0.5 + 0.5;
	float flash = step(0.86, rand(vec2(block * 1.23, floor(TIME * 31.0)))) * glitch_strength;
	color += vec3(0.12, 0.18, 0.28) * scan * glitch_strength * 0.7;
	color += vec3(flash) * 0.65;
	COLOR = vec4(color * frame_mask, 1.0);
}
