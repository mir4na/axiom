shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    if (glitch_intensity <= 0.0) {
        COLOR = texture(screen_texture, SCREEN_UV);
    } else {
        vec2 uv = SCREEN_UV;
        float time = TIME * 10.0;
        
        // Horizontal tearing
        float noise = rand(vec2(floor(uv.y * 30.0), floor(time)));
        if (noise > 1.0 - glitch_intensity * 0.5) {
            uv.x += (rand(vec2(time, uv.y)) - 0.5) * 0.1 * glitch_intensity;
        }
        
        // Chromatic Aberration / RGB Split
        float r_offset = 0.02 * glitch_intensity * rand(vec2(time, 1.0));
        float b_offset = -0.02 * glitch_intensity * rand(vec2(time, 2.0));
        
        float r = texture(screen_texture, vec2(uv.x + r_offset, uv.y)).r;
        float g = texture(screen_texture, uv).g;
        float b = texture(screen_texture, vec2(uv.x + b_offset, uv.y)).b;
        
        // Mix a bit of scanlines
        float scanline = sin(uv.y * 800.0) * 0.04 * glitch_intensity;
        
        COLOR = vec4(r - scanline, g - scanline, b - scanline, 1.0);
    }
}
