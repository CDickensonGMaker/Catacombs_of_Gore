shader_type sky;

uniform sampler2D panorama : filter_nearest, repeat_enable;
uniform float horizon_height : hint_range(-0.5, 0.5) = 0.0;

void sky() {
	float yaw = atan(EYEDIR.x, EYEDIR.z);
	float u = (yaw / TAU) + 0.5;
	float v = clamp((-EYEDIR.y + horizon_height) * 0.5 + 0.5, 0.0, 1.0);
	COLOR = texture(panorama, vec2(u, v)).rgb;
}
