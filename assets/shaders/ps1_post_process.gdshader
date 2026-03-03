// PS1-style post-processing shader with GRIM DARK aesthetic
// Apply as a full-screen effect
shader_type canvas_item;

// ============================================================================
// GRIM DARK SETTINGS
// ============================================================================

// Vignette - dark edges for horror atmosphere
uniform bool enable_vignette = true;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.5;

// Film grain - subtle noise for retro feel
uniform bool enable_grain = true;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.06;

// Color grading - grim dark look
uniform bool enable_color_grading = true;
uniform float saturation : hint_range(0.0, 2.0) = 0.65;  // Desaturate for grim look
uniform float contrast : hint_range(0.5, 2.0) = 1.15;
uniform float brightness : hint_range(0.0, 2.0) = 0.88;  // Slightly darker

// Tint color for atmosphere (slight sepia/cold tint)
uniform vec3 tint_color : source_color = vec3(0.95, 0.92, 0.88);  // Slight warm tint
uniform float tint_strength : hint_range(0.0, 1.0) = 0.15;

// ============================================================================
// PS1 RETRO SETTINGS
// ============================================================================

// Dithering
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;

// Color reduction
uniform float color_levels : hint_range(2.0, 32.0) = 24.0;

// Scanlines
uniform bool enable_scanlines = false;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count : hint_range(100.0, 480.0) = 240.0;

// Chromatic aberration
uniform bool enable_aberration = true;
uniform float aberration_amount : hint_range(0.0, 0.01) = 0.001;

// Screen texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// Time for animated grain
uniform float time : hint_range(0.0, 1000.0) = 0.0;

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

// Hash function for film grain
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Film grain noise
float grain_noise(vec2 uv, float t) {
	vec2 grain_uv = uv * vec2(textureSize(SCREEN_TEXTURE, 0));
	return hash(grain_uv + vec2(t * 100.0, t * 57.0));
}

// Vignette function
float vignette(vec2 uv) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float vig = 1.0 - smoothstep(0.3, 0.3 + vignette_smoothness, dist);
	return mix(1.0, vig, vignette_intensity);
}

// Apply saturation
vec3 apply_saturation(vec3 color, float sat) {
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luminance), color, sat);
}

// Apply contrast around midpoint
vec3 apply_contrast(vec3 color, float con) {
	return (color - 0.5) * con + 0.5;
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

	// ========================================================================
	// COLOR GRADING (GRIM DARK)
	// ========================================================================
	if (enable_color_grading) {
		// Apply brightness
		color.rgb *= brightness;

		// Apply saturation (desaturate for grim look)
		color.rgb = apply_saturation(color.rgb, saturation);

		// Apply contrast
		color.rgb = apply_contrast(color.rgb, contrast);

		// Apply tint
		color.rgb = mix(color.rgb, color.rgb * tint_color, tint_strength);
	}

	// ========================================================================
	// PS1 DITHERING
	// ========================================================================
	if (enable_dithering) {
		vec2 pixel_coord = uv * vec2(textureSize(SCREEN_TEXTURE, 0));
		float dither = get_dither_value(pixel_coord) - 0.5;
		color.rgb += dither * dither_strength / color_levels;
	}

	// Color reduction (posterization)
	color.rgb = floor(color.rgb * color_levels + 0.5) / color_levels;

	// ========================================================================
	// FILM GRAIN
	// ========================================================================
	if (enable_grain) {
		float noise = grain_noise(uv, TIME) * 2.0 - 1.0;
		color.rgb += noise * grain_strength;
	}

	// ========================================================================
	// SCANLINES
	// ========================================================================
	if (enable_scanlines) {
		float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		scanline = pow(scanline, 1.5);
		color.rgb *= 1.0 - (scanline_strength * (1.0 - scanline));
	}

	// ========================================================================
	// VIGNETTE (apply last for dark edges)
	// ========================================================================
	if (enable_vignette) {
		color.rgb *= vignette(uv);
	}

	// Clamp to valid range
	color.rgb = clamp(color.rgb, 0.0, 1.0);

	COLOR = color;
}
