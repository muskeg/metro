shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.55, 0.82, 0.92, 0.42);
uniform float flow_time = 0.0;
uniform float flow_speed = 0.18;

void fragment() {
	float across = smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y));
	float pulse = pow(max(0.0, cos((UV.x - flow_time * flow_speed) * 6.28318)), 10.0);
	COLOR = vec4(glow_color.rgb, glow_color.a * across * (0.18 + pulse * 0.72));
}
