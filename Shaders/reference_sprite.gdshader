// Palette-indexed sprites.
//
// The sheet fed to this shader is not a picture. Each of its pixels stores a
// *coordinate*: red is the column and green is the row of a cell in a second, tiny
// "reference" texture, and that cell holds the colour the pixel actually is. The
// sheet is the shape, the reference is the skin.
//
// The point is that a variant -- a different suit, a damage state, a palette swap --
// is then a 16x16 reference image rather than another full copy of every sheet, and
// a single pixel of one can be rewritten at runtime to recolour one part of the
// character everywhere at once.
//
// Requirements on the shape sheet, all of which the baker in
// Tools/bake_reference_sprite.gd already satisfies:
//   - imported lossless (PNG), Filter off, Mipmaps off, Fix Alpha Border off.
//     Any filtering blends two indices into a third, which reads as a wrong colour.
//   - fully transparent where the sprite is empty.
shader_type canvas_item;
render_mode unshaded;

// The palette. Sampled by index, so it must be nearest-filtered too.
uniform sampler2D reference_texture : filter_nearest, repeat_disable;

// Size of reference_texture in pixels. Set from code; the shader cannot ask for it.
uniform vec2 reference_size = vec2(16.0, 16.0);

// Multiplies the looked-up alpha by the shape pixel's own, so anti-aliased or
// feathered edges on the sheet survive. Turn off for a strictly indexed sheet where
// the shape's alpha is only ever 0 or 1.
uniform bool keep_shape_alpha = true;

// Shape alpha at or below this counts as empty and is discarded before the lookup,
// so the transparent border never resolves to palette entry (0, 0).
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.004;

// Tints the result, so modulate-style effects (invulnerability blink, boss flash)
// still work on top of the lookup.
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 shape = texture(TEXTURE, UV);
	if (shape.a <= alpha_cutoff) {
		discard;
	}

	// 0..1 channels back to whole indices. The round is what keeps an 8-bit PNG's
	// exact byte values from drifting a cell either way.
	vec2 index = floor(shape.rg * 255.0 + 0.5);
	vec2 reference_uv = (index + 0.5) / reference_size;

	vec4 looked_up = texture(reference_texture, reference_uv);
	float alpha = keep_shape_alpha ? looked_up.a * shape.a : looked_up.a;
	COLOR = vec4(looked_up.rgb, alpha) * tint * COLOR;
}
