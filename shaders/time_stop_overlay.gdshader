shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 2.0) = 0.0;
uniform float edge_softness : hint_range(0.001, 0.5) = 0.12;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint = vec3(0.94, 0.98, 1.0);

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	float dist = distance(SCREEN_UV, center_uv);
	float mask = 1.0 - smoothstep(radius, radius + edge_softness, dist);
	float blend = clamp(mask * intensity, 0.0, 1.0);
	vec3 inverted = (vec3(1.0) - base.rgb) * tint;
	vec3 color = mix(base.rgb, inverted, blend);
	COLOR = vec4(color, 1.0);
}
