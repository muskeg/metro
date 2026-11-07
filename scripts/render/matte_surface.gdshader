shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float warmth = 0.0;
uniform vec2 sun_position = vec2(0.5, 0.2);
varying vec2 world_position;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), fraction.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), fraction.x), fraction.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 surface = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, SCREEN_UV.y));
	float sunlight = exp(-3.0 * length((SCREEN_UV - sun_position) * vec2(1.0, 1.4)));
	surface = mix(surface, vec3(1.0, 0.77, 0.56), sunlight * warmth * 0.15);
	float brightness = dot(surface, vec3(0.2126, 0.7152, 0.0722));
	float grain = (noise(world_position * 1.3) - 0.5) / (1.0 + length(fwidth(world_position)));
	float fibers = noise(world_position / 120.0) - 0.5;
	surface += (grain * 0.012 + fibers * 0.008) * mix(0.12, 1.0, brightness);
	COLOR = vec4(surface, 1.0);
}
