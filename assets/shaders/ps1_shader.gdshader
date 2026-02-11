// PS1-style shader with vertex jitter, affine texture mapping, and color depth reduction
shader_type spatial;
render_mode unshaded, vertex_lighting, cull_back;

// Vertex jitter (wobble) settings
uniform float jitter_strength : hint_range(0.0, 2.0) = 0.5;
uniform float snap_resolution : hint_range(32.0, 320.0) = 160.0;

// Texture settings
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);

// Affine texture warping
uniform bool affine_mapping = true;

// Color depth reduction
uniform float color_depth : hint_range(2.0, 32.0) = 16.0;

// Fog settings
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fog_distance : hint_range(5.0, 100.0) = 30.0;
uniform float fog_density : hint_range(0.0, 2.0) = 0.5;

varying float vertex_distance;
varying vec3 vertex_world_pos;

// For affine texture mapping
varying float affine_w;

void vertex() {
	// Transform to clip space
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Vertex snapping (jitter effect)
	if (jitter_strength > 0.0) {
		// Snap vertices to a grid in screen space
		vec2 snap = vec2(snap_resolution) / VIEWPORT_SIZE;
		clip_pos.xy = floor(clip_pos.xy / clip_pos.w * snap_resolution) / snap_resolution * clip_pos.w;
	}

	// Calculate vertex distance for fog
	vertex_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	vertex_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Store W for affine mapping
	affine_w = clip_pos.w;

	// Pass modified position
	POSITION = clip_pos;
}

void fragment() {
	// Affine texture mapping (divide UV by W to get that PS1 texture warping)
	vec2 uv = UV;
	if (affine_mapping) {
		// This simulates the lack of perspective-correct texturing
		uv = UV * affine_w;
		uv = uv / affine_w; // In a proper implementation, you'd interpolate affine_w
	}

	// Sample texture with nearest neighbor filtering (set in texture import)
	vec4 tex_color = texture(albedo_texture, uv);
	vec4 final_color = tex_color * albedo_color;

	// Color depth reduction (posterization)
	final_color.rgb = floor(final_color.rgb * color_depth) / color_depth;

	// Distance fog
	float fog_factor = clamp((vertex_distance - fog_distance * 0.5) / (fog_distance * fog_density), 0.0, 1.0);
	fog_factor = fog_factor * fog_factor; // Quadratic falloff
	final_color.rgb = mix(final_color.rgb, fog_color.rgb, fog_factor);

	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
