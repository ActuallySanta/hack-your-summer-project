shader_type canvas_item;

//Heart
uniform vec4 heart_color : source_color;
uniform vec4 heart_replace_color : source_color;
uniform float fill_amount : hint_range(0.0, 1.0, 0.001) = 1.0;

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 tex_color = texture(TEXTURE, UV);

	if (UV.x > fill_amount) {
	tex_color.rgb = vec3(0.2, 0.2, 0.2); // dark/empty color
	}

	COLOR = tex_color;
}