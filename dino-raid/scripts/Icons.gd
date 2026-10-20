class_name Icons
## The small pictures for what a homeland has and spends (GAME-DESIGN 23): a gold coin, a drop of biomass, a flask of
## research points, a heart for the homeland's health -- drawn as vectors, made into pictures once for each size they
## are shown at (twice as fine, so they stay sharp), the same everywhere: the panel, the cards, the hints.

const GOLD := "gold"
const BIOMASS := "biomass"
const RESEARCH := "research"
const HEALTH := "health"

const SVG := {
	"gold": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><radialGradient id="f" cx="0.36" cy="0.3" r="0.85"><stop offset="0" stop-color="#fff0b8"/>
<stop offset="0.5" stop-color="#e8b44a"/><stop offset="1" stop-color="#9c6a1c"/></radialGradient></defs>
<circle cx="16" cy="17.2" r="13.5" fill="#000000" fill-opacity="0.35"/>
<circle cx="16" cy="16" r="13.5" fill="#5e3d0e"/>
<circle cx="16" cy="16" r="12.2" fill="url(#f)"/>
<circle cx="16" cy="16" r="9" fill="none" stroke="#9a6a1e" stroke-width="1.3"/>
<path d="M16 10.6 L20 16 L16 21.4 L12 16 Z" fill="#a8741f"/>
<path d="M16 12.4 L18.5 16 L16 19.6 L13.5 16 Z" fill="#ffe7a0"/>
<path d="M7.6 12 A9.5 9.5 0 0 1 12.5 6.9" fill="none" stroke="#fffbe8" stroke-width="1.8" stroke-linecap="round" stroke-opacity="0.85"/>
</svg>""",
	"biomass": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><radialGradient id="g" cx="0.38" cy="0.45" r="0.75"><stop offset="0" stop-color="#c8f58a"/>
<stop offset="0.55" stop-color="#5fbf3a"/><stop offset="1" stop-color="#23661c"/></radialGradient></defs>
<path d="M16 4.4 C13 9.2 6.5 15.4 6.5 21.4 A9.5 9.5 0 0 0 25.5 21.4 C25.5 15.4 19 9.2 16 4.4 Z" fill="#000000" fill-opacity="0.3"/>
<path d="M16 3.2 C13 8 6.5 14.2 6.5 20.2 A9.5 9.5 0 0 0 25.5 20.2 C25.5 14.2 19 8 16 3.2 Z" fill="#163d10"/>
<path d="M16 5.2 C13.4 9.4 8 14.8 8 20.2 A8 8 0 0 0 24 20.2 C24 14.8 18.6 9.4 16 5.2 Z" fill="url(#g)"/>
<ellipse cx="12.6" cy="17.5" rx="2" ry="3.6" fill="#f2ffd8" fill-opacity="0.75" transform="rotate(20 12.6 17.5)"/>
<circle cx="19" cy="22" r="1.6" fill="#2d7a22" fill-opacity="0.7"/>
<circle cx="15.5" cy="24.5" r="1.1" fill="#2d7a22" fill-opacity="0.6"/>
</svg>""",
	"research": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9ff5e4"/>
<stop offset="1" stop-color="#1f9c88"/></linearGradient></defs>
<path d="M12 4.7 H20 V6.8 H18.8 V13.2 L26 25.7 A3 3 0 0 1 23.4 30.2 H8.6 A3 3 0 0 1 6 25.7 L13.2 13.2 V6.8 H12 Z" fill="#000000" fill-opacity="0.3"/>
<path d="M12 3.5 H20 V5.6 H18.8 V12 L26 24.5 A3 3 0 0 1 23.4 29 H8.6 A3 3 0 0 1 6 24.5 L13.2 12 V5.6 H12 Z" fill="#0c2d29"/>
<path d="M14.6 6.6 H17.4 V12.6 L24.2 24.6 A1.6 1.6 0 0 1 22.8 27 H9.2 A1.6 1.6 0 0 1 7.8 24.6 L14.6 12.6 Z" fill="#cfe9e4" fill-opacity="0.28"/>
<path d="M11 18.5 H21 L24.2 24.6 A1.6 1.6 0 0 1 22.8 27 H9.2 A1.6 1.6 0 0 1 7.8 24.6 Z" fill="url(#l)"/>
<circle cx="14" cy="23" r="1.3" fill="#e9fffb" fill-opacity="0.85"/>
<circle cx="18" cy="21" r="0.9" fill="#e9fffb" fill-opacity="0.75"/>
<path d="M15.3 8 V12.8" stroke="#ffffff" stroke-opacity="0.6" stroke-width="1" stroke-linecap="round"/>
</svg>""",
	"health": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><radialGradient id="h" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#ffb0a0"/>
<stop offset="0.5" stop-color="#e2463a"/><stop offset="1" stop-color="#8e1d18"/></radialGradient></defs>
<path d="M16 29.2 C8 22.7 3.5 18.2 3.5 12.7 A6.5 6.5 0 0 1 16 9.8 A6.5 6.5 0 0 1 28.5 12.7 C28.5 18.2 24 22.7 16 29.2 Z" fill="#000000" fill-opacity="0.3"/>
<path d="M16 28 C8 21.5 3.5 17 3.5 11.5 A6.5 6.5 0 0 1 16 8.6 A6.5 6.5 0 0 1 28.5 11.5 C28.5 17 24 21.5 16 28 Z" fill="#4a0f0c"/>
<path d="M16 26 C9 20.4 5 16.4 5 11.6 A5.2 5.2 0 0 1 16 10.4 A5.2 5.2 0 0 1 27 11.6 C27 16.4 23 20.4 16 26 Z" fill="url(#h)"/>
<ellipse cx="10.5" cy="11.5" rx="2.2" ry="1.4" fill="#ffffff" fill-opacity="0.6" transform="rotate(-30 10.5 11.5)"/>
</svg>""",
}

static var _made := {}             # "name@pixels" -> Texture2D


## The picture `name` (GOLD, BIOMASS, RESEARCH, HEALTH) made for showing `px` pixels across.
static func of(name: String, px := 20) -> Texture2D:
	var key := "%s@%d" % [name, px]
	if not _made.has(key):
		var img := Image.new()
		img.load_svg_from_string(SVG[name], float(px * 2) / 32.0)
		img.generate_mipmaps()
		_made[key] = ImageTexture.create_from_image(img)
	return _made[key]


## A small picture as a control (for a row of them): `px` across, sharp.
static func rect(name: String, px := 20) -> TextureRect:
	var t := TextureRect.new()
	t.texture = of(name, px)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Draws the picture `name` on `item`, `px` across, its middle at `at` (dimmed to grey when `lit` is false).
static func draw(item: CanvasItem, name: String, at: Vector2, px: float, lit := true) -> void:
	var tex := of(name, int(ceil(px)))
	item.draw_texture_rect(tex, Rect2(at - Vector2(px, px) * 0.5, Vector2(px, px)), false,
		Color.WHITE if lit else Color(0.55, 0.55, 0.55, 0.85))
