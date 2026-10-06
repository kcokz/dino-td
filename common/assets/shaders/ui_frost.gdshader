// res://assets/shaders/ui_frost.gdshader
//
// Frosted glass behind a full-screen menu: whatever is on screen underneath, blurred and
// tinted towards the interface's own dark. The menu then sits on the world rather than on a
// flat grey wash, and nothing behind it -- the valley, the cabin's room -- competes with it.
//
// The blur is the screen texture's own mip chain (read at a coarser level), which the engine
// builds for a shader that asks for mipmaps: no passes, no kernel.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// How soft: the mip level read. Each step halves the detail.
uniform float blur_lod = 3.0;
// What the blur is tinted towards, and how far (alpha).
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.035, 0.6);
// A darker edge, so the middle -- where the menu is -- reads first.
uniform float vignette = 0.35;

void fragment() {
	vec3 behind = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	vec3 frosted = mix(behind, tint.rgb, tint.a);
	float edge = smoothstep(0.35, 0.95, length(SCREEN_UV - vec2(0.5)) * 1.4);
	COLOR = vec4(frosted * (1.0 - vignette * edge), 1.0);
}
