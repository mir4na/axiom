shader_type canvas_item;

uniform float chromatic_aberration : hint_range(0.0, 10.0) = 2.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count : hint_range(100.0, 1000.0) = 540.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_smoothness : hint_range(0.01, 1.0) = 0.3;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	vec2 offset = vec2(chromatic_aberration / 1000.0, 0.0);
	float r = texture(TEXTURE, uv + offset).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - offset).b;
	vec4 color = vec4(r, g, b, 1.0);

	float scanline = sin(uv.y * scanline_count * PI) * 0.5 + 0.5;
	color.rgb -= scanline * scanline_intensity;

	vec2 vignette_uv = uv * (1.0 - uv.yx);
	float vignette = vignette_uv.x * vignette_uv.y * 15.0;
	vignette = pow(vignette, vignette_intensity);
	vignette = smoothstep(0.0, vignette_smoothness, vignette);
	color.rgb *= vignette;

	float grain = random(uv + fract(TIME + time_offset)) * grain_intensity;
	color.rgb += grain - grain_intensity * 0.5;

	COLOR = color;
}
