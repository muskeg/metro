shader_type canvas_item;
render_mode unshaded;

void fragment() {
	if (UV.x >= 0.0) {
		COLOR.a *= 1.0 - smoothstep(0.0, fwidth(UV.x), UV.x);
	}
}
