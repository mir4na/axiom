shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float screenshot_flash : hint_range(0.0, 1.0) = 0.0;
uniform float corner_roundness : hint_range(0.0, 0.8) = 0.22;
uniform float corner_softness : hint_range(0.001, 0.2) = 0.028;
uniform float content_fit : hint_range(0.7, 1.2) = 0.92;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
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
	float time = TIME * 10.0;
	float frame_mask = rounded_mask(frame_uv, corner_roundness, corner_softness);

	if (glitch_intensity > 0.0) {
		float noise = rand(vec2(floor(uv.y * 30.0), floor(time)));
		if (noise > 1.0 - glitch_intensity * 0.5) {
			uv.x += (rand(vec2(time, uv.y)) - 0.5) * 0.1 * glitch_intensity;
		}
	}

	float r_offset = 0.02 * glitch_intensity * rand(vec2(time, 1.0));
	float b_offset = -0.02 * glitch_intensity * rand(vec2(time, 2.0));

	float r = texture(screen_texture, vec2(uv.x + r_offset, uv.y)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, vec2(uv.x + b_offset, uv.y)).b;

	float scanline = sin(uv.y * 800.0) * 0.04 * glitch_intensity;
	vec3 col = vec3(r - scanline, g - scanline, b - scanline);

	vec3 inverted = vec3(1.0) - col;
	col = mix(col, inverted, invert_amount);

	vec2 center = uv - 0.5;
	float vignette = 1.0 - dot(center, center) * 2.5 * vignette_strength;
	col *= clamp(vignette, 0.0, 1.0);

	if (screenshot_flash > 0.0) {
		float flash = screenshot_flash;
		col = mix(col, vec3(1.0), flash * 0.85);

		float border_x = step(uv.x, 0.04 * flash) + step(1.0 - 0.04 * flash, uv.x);
		float border_y = step(uv.y, 0.06 * flash) + step(1.0 - 0.06 * flash, uv.y);
		float border = clamp(border_x + border_y, 0.0, 1.0);
		col = mix(col, vec3(0.9, 0.9, 0.85), border * flash);

		float desat = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(desat), (1.0 - flash) * 0.5);
	}

	COLOR = vec4(col * frame_mask, 1.0);
}
