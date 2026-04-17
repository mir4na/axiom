shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.0;
uniform float line_density : hint_range(10.0, 300.0) = 110.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
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
	COLOR = vec4(color, 1.0);
}
