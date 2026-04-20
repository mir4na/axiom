shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float distortion : hint_range(0.0, 0.2) = 0.04;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.035;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.72;
uniform float chroma_strength : hint_range(0.0, 3.0) = 0.95;
uniform float vhs_jitter_strength : hint_range(0.0, 0.03) = 0.0038;
uniform float vhs_band_strength : hint_range(0.0, 0.2) = 0.06;
uniform float vhs_bleed_strength : hint_range(0.0, 0.25) = 0.05;
uniform float vhs_ghost_strength : hint_range(0.0, 0.3) = 0.055;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.0, 289.0))) * 45758.5453);
}

vec2 warp(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	p *= 1.0 + dot(p, p) * distortion;
	return p * 0.5 + 0.5;
}

void fragment() {
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 vhs_uv = SCREEN_UV;
	float tape_wave = sin(vhs_uv.y * 34.0 + TIME * 2.6) * 0.5 + 0.5;
	float tape_wave_b = sin(vhs_uv.y * 16.0 - TIME * 1.7) * 0.5 + 0.5;
	float tape_band = smoothstep(0.48, 1.0, tape_wave) * vhs_band_strength;
	float tape_band_b = smoothstep(0.7, 1.0, tape_wave_b) * vhs_band_strength * 0.55;
	float tape_total = tape_band + tape_band_b;
	vhs_uv.x += sin(vhs_uv.y * 42.0 + TIME * 3.3) * vhs_jitter_strength * tape_total;
	vhs_uv.x += sin(vhs_uv.y * 8.0 - TIME * 1.15) * vhs_jitter_strength * 0.35;
	vec2 uv = warp(vhs_uv);
	vec3 base = texture(screen_texture, SCREEN_UV).rgb;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float chroma = chroma_strength / viewport_size.x;
	vec3 crt = vec3(
		texture(screen_texture, uv + vec2(chroma, 0.0)).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - vec2(chroma, 0.0)).b
	);
	vec3 bleed = texture(screen_texture, uv + vec2(1.5 * SCREEN_PIXEL_SIZE.x, 0.0)).rgb;
	vec3 ghost = texture(screen_texture, uv + vec2(3.0 * SCREEN_PIXEL_SIZE.x, 0.0)).rgb;
	float scanline = 0.94 + sin(uv.y * viewport_size.y * 1.08) * scanline_strength * 0.08;
	float noise = (hash(floor(uv * viewport_size) + floor(TIME * 60.0)) - 0.5) * noise_strength;
	vec2 centered = uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength * 0.28;
	crt = mix(crt, vec3(bleed.r, crt.g, crt.b), vhs_bleed_strength);
	crt = mix(crt, ghost * vec3(1.0, 0.94, 0.9), vhs_ghost_strength * (0.35 + tape_total));
	crt *= scanline * vignette;
	crt *= 1.0 - tape_total * 0.18;
	crt = mix(crt, crt * vec3(1.03, 0.985, 0.95), 0.14);
	crt += vec3(tape_total * 0.018, tape_total * 0.008, tape_total * 0.012);
	crt += noise;
	crt *= inside;
	COLOR = vec4(mix(base, crt, intensity), 1.0);
}
