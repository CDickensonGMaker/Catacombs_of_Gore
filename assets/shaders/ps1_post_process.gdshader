// PS1-style post-processing shader
// Apply as a full-screen effect
shader_type canvas_item;

// Dithering
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.5;

// Color reduction
uniform float color_levels : hint_range(2.0, 32.0) = 16.0;

// Scanlines
uniform bool enable_scanlines = false;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_count : hint_range(100.0, 480.0) = 240.0;

// Chromatic aberration
uniform bool enable_aberration = false;
uniform float aberration_amount : hint_range(0.0, 0.01) = 0.002;

// Screen texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// 4x4 Bayer dithering matrix
const mat4 BAYER_MATRIX = mat4(
	vec4(0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0),
	vec4(12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0),
	vec4(3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0),
	vec4(15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0)
);

float get_dither_value(vec2 pixel_coord) {
	int x = int(mod(pixel_coord.x, 4.0));
	int y = int(mod(pixel_coord.y, 4.0));

	if (y == 0) return BAYER_MATRIX[0][x];
	if (y == 1) return BAYER_MATRIX[1][x];
	if (y == 2) return BAYER_MATRIX[2][x];
	return BAYER_MATRIX[3][x];
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color;

	// Chromatic aberration
	if (enable_aberration) {
		float r = texture(SCREEN_TEXTURE, uv + vec2(aberration_amount, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(aberration_amount, 0.0)).b;
		color = vec4(r, g, b, 1.0);
	} else {
		color = texture(SCREEN_TEXTURE, uv);
	}

	// Dithering
	if (enable_dithering) {
		vec2 pixel_coord = uv * vec2(textureSize(SCREEN_TEXTURE, 0));
		float dither = get_dither_value(pixel_coord) - 0.5;
		color.rgb += dither * dither_strength / color_levels;
	}

	// Color reduction (posterization)
	color.rgb = floor(color.rgb * color_levels + 0.5) / color_levels;

	// Scanlines
	if (enable_scanlines) {
		float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		scanline = pow(scanline, 1.5);
		color.rgb *= 1.0 - (scanline_strength * (1.0 - scanline));
	}

	COLOR = color;
}
