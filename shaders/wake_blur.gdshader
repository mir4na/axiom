shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 4.0) = 2.2;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.24;
uniform float desaturate_strength : hint_range(0.0, 1.0) = 0.18;
uniform float bloom_lift : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = SCREEN_PIXEL_SIZE * blur_strength * 3.2;
	vec3 col = texture(screen_tex, uv).rgb * 0.227027;
	col += texture(screen_tex, uv + vec2(pixel.x, 0.0)).rgb * 0.1945946;
	col += texture(screen_tex, uv - vec2(pixel.x, 0.0)).rgb * 0.1945946;
	col += texture(screen_tex, uv + vec2(0.0, pixel.y)).rgb * 0.1216216;
	col += texture(screen_tex, uv - vec2(0.0, pixel.y)).rgb * 0.1216216;
	col += texture(screen_tex, uv + pixel * 0.75).rgb * 0.0702703;
	col += texture(screen_tex, uv - pixel * 0.75).rgb * 0.0702703;
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturate_strength);
	col += vec3(bloom_lift);
	col = mix(col, vec3(0.92, 0.93, 0.9), haze_strength);
	COLOR = vec4(col, 1.0);
}
