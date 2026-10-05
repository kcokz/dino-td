// res://assets/shaders/film_planet.gdshader
//
// THE OPENING'S WORLD BELOW (scripts/fx/Opening.gd): the Earth of the Late Triassic seen from above -- one great
// continent (Pangaea) of dry browns and greens on a deep ocean, white cloud drifting over it, the air's blue haze at
// its rim. A sphere, lit by the sun of the shot.
shader_type spatial;
render_mode cull_back;

uniform vec3 ocean : source_color = vec3(0.03, 0.12, 0.26);
uniform vec3 land : source_color = vec3(0.40, 0.33, 0.20);
uniform vec3 green : source_color = vec3(0.17, 0.27, 0.12);
uniform vec3 cloud : source_color = vec3(0.92, 0.94, 0.96);
uniform vec3 air : source_color = vec3(0.35, 0.6, 1.0);

varying vec3 local;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		s += a * noise3(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	local = normalize(VERTEX);
}

void fragment() {
	// One supercontinent: land where the noise, pulled towards one side of the globe, is high.
	float mass = fbm(local * 2.2) + dot(local, normalize(vec3(0.3, 0.5, -0.8))) * 0.35;
	float is_land = smoothstep(0.52, 0.56, mass);
	float wet = fbm(local * 5.0 + 4.0);
	vec3 ground = mix(land, green, smoothstep(0.45, 0.65, wet));
	vec3 col = mix(ocean, ground, is_land);
	float c = smoothstep(0.55, 0.72, fbm(local * 4.0 + vec3(TIME * 0.004, 0.0, 0.0)));
	col = mix(col, cloud, c * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.35, 0.95, is_land);
	// The air at its rim.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = air * rim * 0.9;
}
