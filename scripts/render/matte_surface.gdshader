shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform sampler2D grain_texture : repeat_enable, filter_linear;
uniform float warmth = 0.0;
uniform vec2 sun_position = vec2(0.5, 0.2);
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 surface = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, SCREEN_UV.y));
	float sunlight = exp(-3.0 * length((SCREEN_UV - sun_position) * vec2(1.0, 1.4)));
	surface = mix(surface, vec3(1.0, 0.77, 0.56), sunlight * warmth * 0.15);
	float brightness = dot(surface, vec3(0.2126, 0.7152, 0.0722));
	float grain = (texture(grain_texture, world_position * (1.3 / 256.0)).r - 0.5) / (1.0 + length(fwidth(world_position)));
	float fibers = texture(grain_texture, world_position / 30720.0).r - 0.5;
	surface += (grain * 0.012 + fibers * 0.008) * mix(0.12, 1.0, brightness);
	COLOR = vec4(surface, 1.0);
}
