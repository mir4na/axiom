shader_type canvas_item;

uniform float blend_strength : hint_range(0.0, 1.0) = 0.5;
uniform float drift_speed : hint_range(0.0, 2.0) = 0.45;
uniform vec4 glow_tint : source_color = vec4(1.0, 1.0, 1.0, 0.22);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 753.22));
	p += dot(p, p + 34.12);
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
	float t = TIME * drift_speed;
	float wobble = (noise21(uv * vec2(8.0, 3.0) + vec2(t, -t * 0.6)) - 0.5) * 0.01;
	vec2 warped_uv = vec2(uv.x + wobble, uv.y);
	vec4 tex = texture(TEXTURE, warped_uv);
	float edge = smoothstep(0.0, 0.12, uv.x) * smoothstep(0.0, 0.12, 1.0 - uv.x);
	float grain = (noise21(uv * 140.0 + vec2(t * 3.0, -t * 2.0)) - 0.5) * 0.08;
	vec3 rgb = tex.rgb;
	rgb = mix(rgb, rgb + glow_tint.rgb * glow_tint.a, blend_strength * 0.65);
	rgb += grain * blend_strength;
	float a = tex.a * edge;
	COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), a);
}
