// res://assets/shaders/fog_of_war.gdshader
//
// The fog of war (scripts/fx/FogOfWar.gd): one quad over the whole screen, drawn last, laying the
// valley's own mist over each pixel by how seen the ground under it is. Never seen: thick mist,
// drifting, the lie of the land a shade through it and nothing on it (what stands there is not
// drawn -- FogOfWar._hide_the_unseen). Seen but out of sight: a thin veil. In sight: clear. Where
// the ground is comes from the depth the scene left, so it covers what a decal on the ground could
// not -- the river, drawn see-through, and the far walls and their haze; past the shroud's square,
// and the sky, is never seen.
//
// Mist, not black (v0.6 round four: "考虑到这是一个追求真实场景的游戏，全黑是不是有点不真实"), in the
// colour of the valley's haze at the hour -- pale by day, red at dusk, dark blue at night. What
// keeps it the fog of war rather than weather is its shape: it clears round everything that sees
// and nowhere else ("只要玩家能感觉出来这个雾是迷雾不是天气就行"). Weather never does (GAME-DESIGN 9.3).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// How unknown each cell of the field is (red channel), one texel a cell: 0 in sight, `seen_level`
// seen and out of sight, 1 never seen.
uniform sampler2D shroud : repeat_disable, filter_linear;
// The mist's own shapes: the engine's noise, laid on the world so it does not swim with the camera.
uniform sampler2D drift : repeat_enable, filter_linear_mipmap;
// The world's x and z at the shroud's middle, and metres from there to its edge.
uniform vec2 origin = vec2(0.0);
uniform float half_size = 32.0;
// The valley's haze at this hour (the environment's fog colour, toned): the mist's colour.
uniform vec3 mist_color : source_color = vec3(0.7, 0.74, 0.68);
// Config.FOG: the shroud's value for seen; how thick the mist is over seen ground and over never
// seen ground; how much the wisps thicken and thin it; their size and drift.
uniform float seen_level = 0.55;
uniform float veil = 0.4;
uniform float never = 0.9;
uniform float wisps = 0.14;
uniform float wisp_scale = 0.05;
uniform vec2 wisp_drift = vec2(0.010, 0.004);

void vertex() {
	// Straight onto the screen, in front of everything (the engine's depth runs from 1 near to 0 far).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 w4 = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world = w4.xyz / w4.w;
	vec2 uv = (world.xz - origin) / (2.0 * half_size) + 0.5;
	float unknown = 1.0;
	if (depth > 0.0 && uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		unknown = texture(shroud, uv).r;
	}
	// Two layers of wisps drifting different ways: the mist moves, as mist does.
	vec2 at = world.xz * wisp_scale;
	float w = mix(texture(drift, at + TIME * wisp_drift).r,
		texture(drift, at * 2.3 - TIME * wisp_drift * 1.7).r, 0.4) - 0.5;
	float seen = clamp(unknown / max(0.001, seen_level), 0.0, 1.0);
	float beyond = smoothstep(seen_level, 1.0, unknown);
	float thin = seen * veil * (1.0 + wisps * w);
	float thick = never * (1.0 + 2.0 * wisps * w);
	ALBEDO = mist_color * (1.0 + 0.4 * w);
	ALPHA = clamp(mix(thin, thick, beyond), 0.0, 0.98);
}
