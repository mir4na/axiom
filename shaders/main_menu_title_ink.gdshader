shader_type canvas_item;

uniform float wobble_strength : hint_range(0.0, 1.0) = 0.12;
uniform float wobble_speed : hint_range(0.0, 3.0) = 0.7;
uniform float ink_noise : hint_range(0.0, 0.3) = 0.06;

float hash21(vec2 p) {
	p = fract(p * vec2(213.12, 371.77));
	p += dot(p, p + 19.19);
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
	float t = TIME * wobble_speed;
	float wobble = (noise21(vec2(uv.y * 8.0, t)) - 0.5) * wobble_strength * 0.03;
	vec2 wuv = vec2(uv.x + wobble, uv.y);
	vec4 tex = texture(TEXTURE, wuv);
	float grain = (noise21(uv * 140.0 + vec2(t * 2.5, -t)) - 0.5) * ink_noise;
	vec3 rgb = tex.rgb + vec3(grain);
	COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), tex.a);
}
