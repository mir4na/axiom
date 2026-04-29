shader_type canvas_item;
render_mode unshaded;

uniform float crack_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 impact_uv = vec2(0.52, 0.46);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		value += noise2d(p * freq) * amp;
		freq *= 2.0;
		amp *= 0.5;
	}
	return value;
}

float angular_distance(float a, float b) {
	float d = abs(a - b);
	return min(d, 6.28318530718 - d);
}

void fragment() {
	vec2 p = UV - impact_uv;
	p.x *= 1.78;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float growth = smoothstep(0.0, 1.0, crack_intensity);

	float crack = 0.0;
	float active_spokes = mix(4.0, 24.0, growth);

	for (int i = 0; i < 24; i++) {
		float fi = float(i);
		float active = step(fi, active_spokes);
		if (active < 0.5) {
			continue;
		}

		float seed = fi * 19.731;
		float base_angle = hash12(vec2(seed, 1.17)) * 6.28318530718;
		float bend = (fbm(vec2(radius * 3.7 + fi * 0.26, fi * 1.91)) - 0.5) * (0.28 + growth * 0.32);
		float spoke_angle = base_angle + bend;
		float width = mix(0.036, 0.0065, growth) * (0.75 + hash12(vec2(seed, 3.9)) * 0.8);
		float spoke_line = 1.0 - smoothstep(width, width * 2.2, angular_distance(angle, spoke_angle));
		float reach = mix(0.26, 2.95, growth) * (0.42 + hash12(vec2(seed, 5.3)) * 0.86);
		float reach_mask = 1.0 - smoothstep(reach - 0.05, reach + 0.06, radius);
		float spoke = spoke_line * reach_mask;
		crack += spoke;

		for (int j = 0; j < 2; j++) {
			float fj = float(j);
			float bseed = seed + fj * 11.41;
			float branch_anchor = reach * (0.24 + hash12(vec2(bseed, 7.2)) * 0.56);
			float branch_side = sign(hash12(vec2(bseed, 9.6)) - 0.5);
			float branch_angle = spoke_angle + branch_side * (0.34 + hash12(vec2(bseed, 2.8)) * 0.74);
			float branch_width = width * (1.2 - fj * 0.22);
			float branch_line = 1.0 - smoothstep(branch_width, branch_width * 2.0, angular_distance(angle, branch_angle));
			float branch_reach = 1.0 - smoothstep(0.0, 0.22 + growth * 0.46, abs(radius - branch_anchor));
			crack += branch_line * branch_reach * (0.55 + growth * 0.45);
		}
	}

	float secondary = 0.0;
	for (int k = 0; k < 10; k++) {
		float fk = float(k) + 1.0;
		float sseed = fk * 23.11;
		float segment_angle = hash12(vec2(sseed, 4.7)) * 6.28318530718;
		float segment_radius = (0.22 + hash12(vec2(sseed, 8.3)) * 2.5) * growth;
		float segment_width = mix(0.028, 0.009, growth);
		float line = 1.0 - smoothstep(segment_width, segment_width * 2.0, angular_distance(angle, segment_angle));
		float radial_mask = 1.0 - smoothstep(0.0, 0.32 + growth * 0.68, abs(radius - segment_radius));
		secondary += line * radial_mask;
	}
	crack += secondary * 0.24;

	float center_shatter = (1.0 - smoothstep(0.0, 0.18 + growth * 0.08, radius)) * (0.38 + growth * 0.62);
	crack = max(crack, center_shatter);

	float edge_jitter = 0.72 + fbm(p * 22.0 + vec2(3.1, 7.4)) * 0.45;
	crack *= edge_jitter;
	crack = clamp(crack, 0.0, 1.0);

	float alpha = pow(crack, 1.24) * (0.06 + growth * 0.94);
	vec3 color = mix(vec3(0.63, 0.72, 0.8), vec3(0.95, 0.98, 1.0), crack);
	COLOR = vec4(color, alpha);
}
