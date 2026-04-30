shader_type canvas_item;

uniform float scribble_strength : hint_range(0.0, 1.0) = 0.75;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform vec4 ink_color : source_color = vec4(0.99, 0.9, 0.58, 0.28);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.0);
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

void fragment() {
	vec2 uv = UV;
	float t = TIME * animation_speed;
	float a = noise21(vec2(uv.x * 21.0 + t * 0.35, uv.y * 3.0));
	float b = noise21(vec2(uv.x * 12.0 - t * 0.25, uv.y * 7.0));
	float line = smoothstep(0.45, 0.78, max(a, b));
	float edge_fade = smoothstep(0.02, 0.14, uv.y) * smoothstep(0.02, 0.14, 1.0 - uv.y);
	float alpha = line * edge_fade * scribble_strength;
	COLOR = vec4(ink_color.rgb, ink_color.a * alpha);
}
