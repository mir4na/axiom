shader_type canvas_item;

uniform float time_scale : hint_range(0.0, 4.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.0;
uniform float grain_strength : hint_range(0.0, 0.4) = 0.08;
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.35;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.85;
uniform vec4 color_a : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform vec4 color_b : source_color = vec4(0.9, 0.9, 0.92, 1.0);
uniform vec4 color_c : source_color = vec4(0.84, 0.86, 0.9, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise21(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return value;
}

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float edge_crack(vec2 p, float t) {
	vec2 d = abs(p);
	float frame_edge = max(d.x, d.y);
	float edge_mask = smoothstep(0.78, 0.985, frame_edge);
	float r = length(p) + 0.0001;
	float a = atan(p.y, p.x);
	vec2 base = vec2(a * 3.6, r * 12.4);
	vec2 warp = vec2(
		fbm(rot2(p, 0.73) * 6.4 + vec2(t * 0.11, -t * 0.07)),
		fbm(rot2(p, -1.12) * 7.2 + vec2(-t * 0.09, t * 0.12))
	);
	base += (warp - 0.5) * vec2(2.2, 1.5);
	float n1 = fbm(base * vec2(1.2, 0.92) + vec2(2.1, -1.3));
	float n2 = fbm(base * vec2(2.4, 1.65) + vec2(-3.4, 4.8)) * 0.65;
	float ridge = 1.0 - abs(sin(base.x * 1.85 + base.y * 0.82 + warp.x * 5.2));
	ridge = pow(clamp(ridge, 0.0, 1.0), 6.0);
	float branches = 1.0 - abs(sin(base.x * 3.25 - base.y * 0.54 + warp.y * 3.9));
	branches = pow(clamp(branches, 0.0, 1.0), 11.0) * 0.6;
	float fracture = n1 * 0.92 + n2 + ridge * 0.86 + branches;
	float crack = smoothstep(0.98, 1.24, fracture);
	float breakup = fbm(p * 9.0 + vec2(-t * 0.04, t * 0.03));
	crack *= smoothstep(0.25, 0.9, breakup + edge_mask * 0.9);
	return crack * edge_mask;
}

void fragment() {
	vec2 uv = UV;
	vec2 original_uv = uv;
	vec2 centered = uv * 2.0 - 1.0;
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float t = TIME * time_scale;
	float band = floor(uv.y * 42.0 + t * 3.0);
	float jitter = (hash21(vec2(band, floor(t * 24.0))) - 0.5) * 0.035 * glitch_strength;
	float burst = smoothstep(0.82, 0.98, hash21(vec2(floor(t * 4.0), band)));
	uv.x += jitter * mix(0.35, 1.0, burst);
	float event_seed = floor(t * 2.4);
	float event_active = smoothstep(0.86, 0.98, hash21(vec2(event_seed, 19.7)));
	float block_band = floor(uv.y * 18.0 + hash21(vec2(event_seed, 31.1)) * 8.0);
	float block_gate = step(0.55, hash21(vec2(block_band, event_seed + 3.17)));
	float rand_shift = (hash21(vec2(block_band, event_seed + 8.91)) - 0.5) * 0.16;
	uv.x += rand_shift * event_active * block_gate * glitch_strength;
	centered = uv * 2.0 - 1.0;
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float swirl = fbm(centered * 1.95 + vec2(0.0, t * 0.12));
	float wave = sin((centered.y + swirl * 0.32) * 9.5 - t * 1.15) * 0.5 + 0.5;
	float energy = smoothstep(0.28, 0.9, fbm(centered * vec2(2.8, 1.6) + vec2(t * 0.18, -t * 0.12)));
	vec3 col = mix(color_a.rgb, color_b.rgb, wave);
	col = mix(col, color_c.rgb, energy * 0.72);
	float scan = sin((original_uv.y * 820.0) + t * 55.0) * 0.018;
	col *= 0.985 + scan;
	float grain = (hash21(original_uv * vec2(1660.0, 980.0) + t * 13.0) - 0.5) * grain_strength;
	col += grain;
	float dark_bands = smoothstep(0.72, 1.0, abs(sin(original_uv.y * 58.0 + t * 7.5))) * glitch_strength * 0.08;
	col -= vec3(dark_bands);
	float glitch_flash = event_active * block_gate * 0.12 * glitch_strength;
	col = mix(col, col * 0.72, glitch_flash);
	float crack = edge_crack(centered, t) * crack_strength;
	col = mix(col, vec3(0.0), crack);
	float border = smoothstep(1.34, 0.24, length(centered));
	col *= clamp(mix(1.0, border, 0.15) * vignette_strength, 0.0, 1.0);
	col = clamp(col, vec3(0.0), vec3(1.0));
	COLOR = vec4(col, 1.0);
}
