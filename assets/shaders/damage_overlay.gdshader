// res://assets/shaders/damage_overlay.gdshader
// A building hurt, drawn over its own body (Building._show_damage; the player, 2026-10-05: "掉血的建筑应该有损坏的样子"):
// soot in patches that spread as `damage` grows, and cracks that open across it once it is badly hurt -- multiplied
// over whatever it is made of, so wood, stone and the cabin's hull darken alike. Placed in the building's own space,
// so the patches stay where they are as it is turned, and `seed` makes each building's its own.
shader_type spatial;
render_mode blend_mul, unshaded, depth_draw_never, cull_back, shadows_disabled;

// 0 whole .. 1 nearly gone.
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
// How the soot and the cracks darken what is under them.
uniform vec3 soot_colour : source_color = vec3(0.32, 0.27, 0.23);
uniform vec3 crack_colour : source_color = vec3(0.08, 0.07, 0.06);
// The damage at which cracks begin, and how wide they open by the end.
uniform float cracks_from = 0.35;
uniform float crack_width = 0.06;

varying vec3 body_pos;

void vertex() {
	body_pos = VERTEX;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 4; k++) {
		sum += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

// How near `p` is to the edge between two cells of a broken grid: the lines a crack runs along.
float crack_lines(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 cell = vec3(float(x), float(y), float(z));
				vec3 at = cell + vec3(hash3(i + cell), hash3(i + cell + 17.0), hash3(i + cell + 31.0)) - f;
				float d = dot(at, at);
				if (d < first) {
					second = first;
					first = d;
				} else if (d < second) {
					second = d;
				}
			}
		}
	}
	return sqrt(second) - sqrt(first);
}

void fragment() {
	vec3 p = body_pos + vec3(seed * 7.13, seed * 3.71, seed * 5.19);
	// Soot: the patches where the noise is highest, spreading as it is hurt.
	float n = fbm(p * 1.7);
	float soot = smoothstep(1.0 - damage * 0.45, 1.0 - damage * 0.45 + 0.12, n + 0.18);
	vec3 shade = mix(vec3(1.0), soot_colour, soot * clamp(damage * 1.1, 0.0, 0.75));
	// Cracks: thin dark lines across it, from `cracks_from` on, opening wider and running further as it is hurt more.
	float open = clamp((damage - cracks_from) / max(0.01, 1.0 - cracks_from), 0.0, 1.0);
	float edge = crack_lines(p * 2.4);
	float crack = (1.0 - smoothstep(0.0, crack_width * open + 0.001, edge)) * step(0.001, open);
	crack *= smoothstep(0.45, 0.7, fbm(p * 0.9 + 11.0) + open * 0.25);
	shade = mix(shade, crack_colour, crack * 0.85);
	ALBEDO = shade;
}
