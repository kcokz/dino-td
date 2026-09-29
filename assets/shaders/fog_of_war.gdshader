// res://assets/shaders/fog_of_war.gdshader
//
// The fog of war (scripts/fx/FogOfWar.gd): one quad over the whole screen, drawn last, laying
// black over each pixel by how seen the ground under it is -- never seen, black; seen but out of
// sight, dimmed; in sight, clear. Where the ground is comes from the depth the scene left, so it
// covers what a decal laid on the ground could not: the river (drawn see-through, which no decal
// touches), the far walls of the valley and the haze over them (v0.6 round four: "迷雾没有遮挡远景
// 只遮挡了近景很奇怪，而且没去过的地方应该完全看不到"). Past the shroud's own square, and the sky, is
// never seen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// How dark each cell of the field is, 0 clear to 1 black (red channel), one texel a cell.
uniform sampler2D shroud : repeat_disable, filter_linear;
// The world's x and z at the shroud's middle, and metres from there to its edge.
uniform vec2 origin = vec2(0.0);
uniform float half_size = 32.0;

void vertex() {
	// Straight onto the screen, in front of everything (the engine's depth runs from 1 near to 0 far).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec2 at = world.xz / world.w;
	vec2 uv = (at - origin) / (2.0 * half_size) + 0.5;
	float dark = 1.0;
	if (depth > 0.0 && uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		dark = texture(shroud, uv).r;
	}
	ALBEDO = vec3(0.0);
	ALPHA = dark;
}
