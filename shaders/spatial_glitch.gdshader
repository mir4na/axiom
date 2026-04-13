shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float glitch_speed : hint_range(0.0, 10.0) = 5.0;
uniform float glitch_intensity : hint_range(0.0, 5.0) = 0.5;
uniform vec3 base_color = vec3(0.0, 1.0, 1.0); // Cyan/Magenta vibes
uniform float emission_energy : hint_range(0.0, 10.0) = 2.0;

// Pseudo-random noise function
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void vertex() {
	// Vertex Displacement (Jittering) for floating fragments
	vec2 uv_time = VERTEX.xz + vec2(TIME * glitch_speed);
	float r = rand(floor(uv_time * 2.0));
	
	if (r > 0.8) {
		float displacement = (rand(vec2(TIME, float(VERTEX_ID))) - 0.5) * glitch_intensity;
		VERTEX.x += displacement;
		VERTEX.y += displacement * 0.5;
		VERTEX.z -= displacement;
	}
}

void fragment() {
	// Holographic Scanlines
	float scanline = sin(UV.y * 50.0 - TIME * 10.0) * 0.5 + 0.5;
	float noise = rand(UV + vec2(TIME, -TIME));
	
	vec3 final_color = base_color;
	
	// Rapid color shifting based on noise
	if (noise > 0.8) {
		final_color = vec3(1.0, 0.0, 1.0); // Shift to magenta
	} else if (noise < 0.2) {
		final_color = vec3(0.0, 1.0, 0.5); // Shift to green
	}
	
	ALBEDO = final_color * mix(0.5, 1.0, scanline);
	EMISSION = final_color * emission_energy * scanline;
	ALPHA = 0.85; // Slightly transparent holographic hologram effect
}
