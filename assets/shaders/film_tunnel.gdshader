// res://assets/shaders/film_tunnel.gdshader
//
// THE OPENING'S TIME TUNNEL (scripts/fx/Opening.gd): the inside of a long tube round the ship's way, streaks of light
// rushing back past it -- the jump. Drawn from inside, added onto what is behind it, fading out at its two ends.
// `fault` takes it from the drive's cold blue to the red of the failure, shaking and breaking up.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float speed = 2.2;          // how fast the streaks rush back, in the tube's lengths a minute or so
uniform float fault = 0.0;          // 0 the jump going well, 1 the drive failing
uniform float strength = 1.0;       // its brightness, to fade it in and out
uniform vec3 cold : source_color = vec3(0.30, 0.78, 1.0);
uniform vec3 white : source_color = vec3(0.92, 0.97, 1.0);
uniform vec3 hot : source_color = vec3(1.0, 0.32, 0.12);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// UV.x round the tube, UV.y along it (Godot's cylinder).
	float around = UV.x * 64.0;
	float along = UV.y * 6.0 + TIME * speed * (1.0 + fault * 0.6);
	// The failure shakes the streaks sideways and tears them.
	around += fault * sin(TIME * 23.0 + UV.y * 40.0) * 1.5;
	float lanes = noise(vec2(around, 0.5));
	float streak = noise(vec2(around * 1.0 + 13.0, along * 0.35));
	streak = smoothstep(0.55, 0.95, streak) * smoothstep(0.25, 0.75, lanes);
	float fine = smoothstep(0.7, 1.0, noise(vec2(around * 3.0, along * 1.4 + 7.0)));
	float tear = 1.0 - fault * 0.6 * step(0.7, noise(vec2(TIME * 9.0, UV.y * 10.0)));
	// Out at the ends, and dim across the middle of its length where the ship is, so the ship reads against it.
	float ends = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	vec3 col = mix(cold, white, fine) * (streak * 1.6 + fine * 0.8);
	col = mix(col, hot * (streak * 1.8 + fine), fault);
	ALBEDO = col * ends * tear * strength;
}
