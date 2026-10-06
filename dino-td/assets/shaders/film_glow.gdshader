// res://assets/shaders/film_glow.gdshader
//
// A part of the ship lit by itself (tools/generate_ship.py, its "_glow" parts: the time drive's ring, the engines'
// throats): its own vertex colours, brighter than white so the shot's glow blooms round them. `energy` to fade it --
// the drive guttering and dying in the failure -- and `fault` to turn it red.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float energy = 3.0;
uniform float fault = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.25, 0.08);

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	ALBEDO = mix(c, hot * dot(c, vec3(0.33)) * 1.6, fault) * energy;
}
