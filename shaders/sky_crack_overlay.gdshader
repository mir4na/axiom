shader_type canvas_item;
render_mode unshaded;

uniform float crack_intensity : hint_range(0.0, 1.0) = 0.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float ang_dist(float a, float b) {
	float d = abs(a - b);
	return min(d, 6.28318530718 - d);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.78;
	float r = length(p);
	float a = atan(p.y, p.x);
	float crack = 0.0;
	float growth = smoothstep(0.02, 1.0, crack_intensity);
	float width_base = mix(0.03, 0.007, growth);
	for (int i = 0; i < 22; i++) {
		float fi = float(i);
		float seed = fi + 1.0;
		float h1 = hash11(seed * 2.37);
		float h2 = hash11(seed * 5.71);
		float base_angle = fi * 0.286 + h1 * 0.55;
		float bend = (h2 - 0.5) * 0.34;
		float target_angle = base_angle + bend * r * (0.65 + growth * 0.45);
		float line_width = width_base * (0.78 + hash11(seed * 8.13) * 0.75);
		float line = 1.0 - smoothstep(0.0, line_width, ang_dist(a, target_angle));
		float length_limit = mix(0.2, 1.58, growth) * (0.58 + hash11(seed * 11.19) * 0.68);
		float reach = 1.0 - smoothstep(length_limit - 0.06, length_limit + 0.03, r);
		crack += line * reach;
		float branch_anchor = 0.26 + hash11(seed * 3.01) * 0.95 * growth;
		float branch_angle = target_angle + (hash11(seed * 9.31) - 0.5) * 0.9;
		float branch_line = 1.0 - smoothstep(0.0, line_width * 1.5, ang_dist(a, branch_angle));
		float branch_reach = 1.0 - smoothstep(0.0, 0.52 * growth + 0.07, abs(r - branch_anchor));
		crack += branch_line * branch_reach * 0.68;
	}
	float center_shatter = (1.0 - smoothstep(0.0, 0.26, r)) * growth;
	crack = max(crack, center_shatter * 0.7);
	crack = clamp(crack, 0.0, 1.0);
	float alpha = pow(crack, 1.35) * growth * 0.95;
	vec3 color = mix(vec3(0.68, 0.79, 0.92), vec3(0.97, 0.99, 1.0), crack);
	COLOR = vec4(color, alpha);
}
