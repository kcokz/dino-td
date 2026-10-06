// res://assets/shaders/film_stars.gdshader
//
// THE OPENING'S SKY (scripts/fx/Opening.gd): space -- black, a scatter of stars of a few sizes and tints, and a faint
// band of the galaxy across it. A sky of its own for the shots above the world; the valley's sky comes back after.
shader_type sky;

uniform float density = 0.0028;      // the share of the sky's cells with a star in them
uniform float band = 0.22;           // how bright the galaxy's band is
uniform vec3 band_tint : source_color = vec3(0.45, 0.48, 0.62);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float stars(vec3 dir, float scale, float dens) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash3(cell);
	if (h < 1.0 - dens) {
		return 0.0;
	}
	vec3 centre = cell + 0.5 + (vec3(hash3(cell + 1.7), hash3(cell + 3.1), hash3(cell + 5.3)) - 0.5) * 0.6;
	float d = length(p - centre);
	return smoothstep(0.32, 0.0, d) * (0.4 + 0.6 * fract(h * 91.7));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float s = stars(d, 260.0, density) + stars(d, 520.0, density * 1.8) * 0.55 + stars(d, 120.0, density * 0.4) * 1.4;
	float tint = hash3(floor(d * 260.0) + 9.0);
	vec3 star_col = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), tint);
	// The galaxy: a soft band tilted across the sky, mottled smoothly.
	float across = abs(dot(d, normalize(vec3(0.3, 0.85, 0.42))));
	vec3 q = d * 9.0;
	vec3 qi = floor(q);
	vec3 qf = fract(q);
	vec3 qu = qf * qf * (3.0 - 2.0 * qf);
	float mottle = mix(mix(mix(hash3(qi), hash3(qi + vec3(1, 0, 0)), qu.x), mix(hash3(qi + vec3(0, 1, 0)), hash3(qi + vec3(1, 1, 0)), qu.x), qu.y),
		mix(mix(hash3(qi + vec3(0, 0, 1)), hash3(qi + vec3(1, 0, 1)), qu.x), mix(hash3(qi + vec3(0, 1, 1)), hash3(qi + vec3(1, 1, 1)), qu.x), qu.y), qu.z);
	float milky = smoothstep(0.32, 0.0, across) * (0.4 + 0.6 * mottle);
	COLOR = star_col * s * 1.6 + band_tint * milky * band;
}
