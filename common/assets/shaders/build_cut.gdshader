// res://assets/shaders/build_cut.gdshader
// THE WORK SEEN (Building._show_the_work; Config.CONSTRUCTION): a building going up, drawn from the ground to `cut`
// metres up (the world's height) and nothing above it -- in its own vertex colours, as the props are dressed
// (GroundCover.cover_material: sRGB colours, matte, both faces, so the cut's open inside is seen through the cut).
shader_type spatial;
render_mode cull_disabled;

uniform float cut = 0.0;
uniform vec4 albedo : source_color = vec4(1.0);

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void fragment() {
	if (height > cut) {
		discard;
	}
	ALBEDO = albedo.rgb * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
