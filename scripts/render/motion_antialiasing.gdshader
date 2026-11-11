shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec3 center = texture(screen_texture, SCREEN_UV).rgb;
	float middle = luminance(center);
	vec3 northwest = texture(screen_texture, SCREEN_UV + pixel * vec2(-1.0, -1.0)).rgb;
	vec3 northeast = texture(screen_texture, SCREEN_UV + pixel * vec2(1.0, -1.0)).rgb;
	vec3 southwest = texture(screen_texture, SCREEN_UV + pixel * vec2(-1.0, 1.0)).rgb;
	vec3 southeast = texture(screen_texture, SCREEN_UV + pixel * vec2(1.0, 1.0)).rgb;
	float nw = luminance(northwest);
	float ne = luminance(northeast);
	float sw = luminance(southwest);
	float se = luminance(southeast);
	float low = min(middle, min(min(nw, ne), min(sw, se)));
	float high = max(middle, max(max(nw, ne), max(sw, se)));
	vec3 result = center;
	if (high - low > max(0.03125, high * 0.125)) {
		vec2 direction = vec2(sw + se - nw - ne, nw + sw - ne - se);
		float damping = max((nw + ne + sw + se) * 0.03125, 0.0078125);
		direction = clamp(direction / (min(abs(direction.x), abs(direction.y)) + damping), vec2(-8.0), vec2(8.0)) * pixel;
		vec3 narrow = 0.5 * (
			texture(screen_texture, SCREEN_UV - direction / 6.0).rgb +
			texture(screen_texture, SCREEN_UV + direction / 6.0).rgb);
		vec3 wide = narrow * 0.5 + 0.25 * (
			texture(screen_texture, SCREEN_UV - direction * 0.5).rgb +
			texture(screen_texture, SCREEN_UV + direction * 0.5).rgb);
		float wide_luminance = luminance(wide);
		result = wide_luminance < low || wide_luminance > high ? narrow : wide;
		vec3 neighborhood = (northwest + northeast + southwest + southeast) * 0.25;
		float subpixel = clamp(abs(luminance(neighborhood) - middle) / (high - low), 0.0, 1.0);
		result = mix(result, neighborhood, subpixel * 0.5);
	}
	COLOR = vec4(result, 1.0);
}
