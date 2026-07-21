shader_type canvas_item;
uniform sampler2D palette : filter_nearest;

void fragment() {
    vec3 src = texture(TEXTURE, UV).rgb;
    vec3 best = vec3(0.0);
    float min_err = 10.0;
    
    // Iterate through the 1D palette texture to find the closest match
    int p_size = textureSize(palette, 0).x;
    for (int i = 0; i < p_size; i++) {
        vec3 p_col = texture(palette, vec2(float(i) / float(p_size), 0.5)).rgb;
        float err = distance(src, p_col);
        if (err < min_err) {
            min_err = err;
            best = p_col;
        }
    }
    COLOR.rgb = best;
    COLOR.a = texture(TEXTURE, UV).a;
}
