class_name Icons
## The small pictures (GAME-DESIGN 23): what a homeland has and spends -- a gold coin, a drop of biomass, a flask of
## research points, a heart for the homeland's health -- and what the HUD's buttons and marks show -- the army (a
## raptor's head), the deck, a turn of fresh cards, two claws crossed for battle, the menu, the faster speed, the
## stash's chest -- and each place's own (a leaf, a volcano, reeds, a snowflake, a sun over a dune, a wave). Drawn as
## vectors, made into pictures once for each size they are shown at (twice as fine, so they stay sharp), the same
## everywhere.

const GOLD := "gold"
const BIOMASS := "biomass"
const RESEARCH := "research"
const HEALTH := "health"
const ARMY := "army"
const DECK := "deck"
const REFRESH := "refresh"
const BATTLE := "battle"
const MENU := "menu"
const SPEED := "speed"
const STASH := "stash"
## Each place's picture, by its place (Content.LEVELS).
const PLACES := ["place_rain", "place_lava", "place_bog", "place_ice", "place_sand", "place_sea"]

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
	"army": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="a" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffb08a"/>
<stop offset="0.55" stop-color="#d9502f"/><stop offset="1" stop-color="#8a2312"/></linearGradient></defs>
<path d="M4.5 20 C4.5 14.2 8.8 10.6 14.6 10.6 L23.8 11.4 C27.2 11.7 28.6 13.7 27.7 15.7 C27.1 17.1 25.4 17.3 24 17.6 L20 18.3 L24.4 20.1 C25.9 20.7 25.7 22.6 24.2 23 L15.6 24.4 C10.4 25.7 4.5 24.6 4.5 20 Z" fill="#000000" fill-opacity="0.3"/>
<path d="M4.5 18.8 C4.5 13 8.8 9.4 14.6 9.4 L23.8 10.2 C27.2 10.5 28.6 12.5 27.7 14.5 C27.1 15.9 25.4 16.1 24 16.4 L20 17.1 L24.4 18.9 C25.9 19.5 25.7 21.4 24.2 21.8 L15.6 23.2 C10.4 24.5 4.5 23.4 4.5 18.8 Z" fill="#3c0d07"/>
<path d="M6 18.6 C6 13.8 9.6 10.9 14.6 10.9 L23.6 11.6 C26 11.8 26.8 13.1 26.2 14.3 C25.8 15 24.8 15.1 23.7 15.3 L17.4 16.4 L23.6 19.4 C24.4 19.8 24.2 20.4 23.6 20.5 L15.4 21.8 C10.6 23 6 22.4 6 18.6 Z" fill="url(#a)"/>
<path d="M18 16.2 L19.1 17.6 L20.3 16 L21.4 17.3 L22.5 15.8" fill="none" stroke="#fff6e0" stroke-width="0.9" stroke-linejoin="round"/>
<circle cx="15.4" cy="13.9" r="1.9" fill="#2a0904"/>
<circle cx="15.9" cy="13.4" r="0.7" fill="#ffe9a0"/>
<path d="M8.6 14.6 C9.6 12.6 11.4 11.6 13.4 11.4" fill="none" stroke="#fff3e0" stroke-width="1.2" stroke-linecap="round" stroke-opacity="0.75"/>
</svg>""",
	"deck": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<rect x="7" y="7.5" width="14" height="19" rx="2" fill="#000000" fill-opacity="0.3" transform="rotate(-15 14 17)"/>
<rect x="7" y="6.5" width="14" height="19" rx="2" fill="#6b5631" stroke="#241a0c" stroke-width="1.2" transform="rotate(-15 14 16)"/>
<rect x="9.5" y="6.2" width="14" height="19" rx="2" fill="#7e6a3e" stroke="#241a0c" stroke-width="1.2" transform="rotate(-4 16.5 15.7)"/>
<rect x="12" y="6.8" width="14" height="19" rx="2" fill="#16211f" stroke="#241a0c" stroke-width="1.4" transform="rotate(8 19 16.3)"/>
<rect x="13.4" y="8.4" width="11.2" height="15.8" rx="1.2" fill="none" stroke="#e2c27a" stroke-width="1.1" transform="rotate(8 19 16.3)"/>
<path d="M19 12.4 L21.6 16.3 L19 20.2 L16.4 16.3 Z" fill="#f2d48a" transform="rotate(8 19 16.3)"/>
</svg>""",
	"refresh": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<g fill="none" stroke-linecap="round">
<path d="M24.5 13.6 A9 9 0 0 0 7.5 13.6" stroke="#1a1208" stroke-width="5.4"/>
<path d="M7.5 19.4 A9 9 0 0 0 24.5 19.4" stroke="#1a1208" stroke-width="5.4"/>
<path d="M24.5 13.6 A9 9 0 0 0 7.5 13.6" stroke="#f2deaa" stroke-width="3"/>
<path d="M7.5 19.4 A9 9 0 0 0 24.5 19.4" stroke="#f2deaa" stroke-width="3"/>
</g>
<path d="M4.2 11.4 L11.2 11.8 L6.4 17.6 Z" fill="#f2deaa" stroke="#1a1208" stroke-width="1.2" stroke-linejoin="round"/>
<path d="M27.8 21.6 L20.8 21.2 L25.6 15.4 Z" fill="#f2deaa" stroke="#1a1208" stroke-width="1.2" stroke-linejoin="round"/>
</svg>""",
	"battle": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="b" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fffaf0"/>
<stop offset="1" stop-color="#cdb98e"/></linearGradient></defs>
<path d="M5 27.4 C8.4 18.4 14.4 10.4 26.6 4.6 C19.6 11.4 14.6 19 9.6 28.6 Z" fill="#000000" fill-opacity="0.35" transform="translate(0 1)"/>
<path d="M27 27.4 C23.6 18.4 17.6 10.4 5.4 4.6 C12.4 11.4 17.4 19 22.4 28.6 Z" fill="#000000" fill-opacity="0.35" transform="translate(0 1)"/>
<path d="M5 27.4 C8.4 18.4 14.4 10.4 26.6 4.6 C19.6 11.4 14.6 19 9.6 28.6 Z" fill="url(#b)" stroke="#2b1a0c" stroke-width="1.3" stroke-linejoin="round"/>
<path d="M27 27.4 C23.6 18.4 17.6 10.4 5.4 4.6 C12.4 11.4 17.4 19 22.4 28.6 Z" fill="url(#b)" stroke="#2b1a0c" stroke-width="1.3" stroke-linejoin="round"/>
<circle cx="16" cy="16.6" r="3.1" fill="#2b1a0c"/>
<circle cx="16" cy="16.6" r="2.1" fill="#ffb347"/>
<circle cx="15.4" cy="16" r="0.8" fill="#fff4d0"/>
</svg>""",
	"menu": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<g fill="#000000" fill-opacity="0.35"><rect x="7" y="9.6" width="18" height="3.4" rx="1.7"/><rect x="7" y="15.4" width="18" height="3.4" rx="1.7"/><rect x="7" y="21.2" width="18" height="3.4" rx="1.7"/></g>
<g fill="#f2e2ba" stroke="#2a1d0c" stroke-width="0.8"><rect x="7" y="8.6" width="18" height="3.4" rx="1.7"/><rect x="7" y="14.4" width="18" height="3.4" rx="1.7"/><rect x="7" y="20.2" width="18" height="3.4" rx="1.7"/></g>
</svg>""",
	"speed": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<g fill="#000000" fill-opacity="0.35" transform="translate(0 1)"><path d="M6 8.5 L15.5 16 L6 23.5 Z"/><path d="M16 8.5 L25.5 16 L16 23.5 Z"/></g>
<g fill="#f2e2ba" stroke="#2a1d0c" stroke-width="1.2" stroke-linejoin="round"><path d="M6 8.5 L15.5 16 L6 23.5 Z"/><path d="M16 8.5 L25.5 16 L16 23.5 Z"/></g>
</svg>""",
	"stash": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a0703c"/>
<stop offset="1" stop-color="#5a3816"/></linearGradient></defs>
<path d="M5 14.4 H27 V26 A1.6 1.6 0 0 1 25.4 27.6 H6.6 A1.6 1.6 0 0 1 5 26 Z" fill="#000000" fill-opacity="0.3" transform="translate(0 1)"/>
<path d="M5 14.4 H27 V26 A1.6 1.6 0 0 1 25.4 27.6 H6.6 A1.6 1.6 0 0 1 5 26 Z" fill="url(#s)" stroke="#2a1708" stroke-width="1.2"/>
<path d="M5 14.4 C5 8.6 9 6 16 6 C23 6 27 8.6 27 14.4 Z" fill="#b5844a" stroke="#2a1708" stroke-width="1.2"/>
<path d="M5 14.4 H27" stroke="#e8c473" stroke-width="2"/>
<path d="M11 6.6 V27.6 M21 6.6 V27.6" stroke="#e8c473" stroke-width="1.6"/>
<rect x="13.8" y="12.6" width="4.4" height="5" rx="0.8" fill="#f2d48a" stroke="#2a1708" stroke-width="0.9"/>
</svg>""",
	"place_rain": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="r" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b8ef7a"/>
<stop offset="0.6" stop-color="#4fa83a"/><stop offset="1" stop-color="#1f5e1a"/></linearGradient></defs>
<path d="M16 3.6 C24.6 7.6 27 18.6 16 28.8 C5 18.6 7.4 7.6 16 3.6 Z" fill="#000000" fill-opacity="0.3" transform="translate(0 1)"/>
<path d="M16 3.6 C24.6 7.6 27 18.6 16 28.8 C5 18.6 7.4 7.6 16 3.6 Z" fill="url(#r)" stroke="#143d10" stroke-width="1.3"/>
<path d="M16 6.4 V27.4 M16 11.6 L11.4 9.2 M16 15.6 L10 12.8 M16 19.8 L10.4 17.4 M16 13.4 L20.8 10.8 M16 17.4 L21.8 14.6 M16 21.6 L21.2 19.2" stroke="#e8ffc8" stroke-width="1" stroke-linecap="round" stroke-opacity="0.8" fill="none"/>
</svg>""",
	"place_lava": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="v" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6a5a54"/>
<stop offset="1" stop-color="#2a201c"/></linearGradient>
<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff2a0"/>
<stop offset="0.5" stop-color="#ffa12e"/><stop offset="1" stop-color="#e2401a"/></linearGradient></defs>
<path d="M3 28 L12 15.2 H20 L29 28 Z" fill="url(#v)" stroke="#140c08" stroke-width="1.3" stroke-linejoin="round"/>
<path d="M12.6 15.2 L14.4 19 L16.2 16.4 L18 19.6 L19.4 15.2 Z" fill="#ff7a2a"/>
<path d="M16 2.8 C19.6 6.8 21.8 9.4 19.8 13.2 C18.8 15.2 13.4 15.2 12.4 13.2 C10.4 9.4 13.4 7.2 16 2.8 Z" fill="url(#f)" stroke="#7a1e08" stroke-width="1"/>
<path d="M16 7.6 C17.6 9.6 18.2 11 17.2 12.6 C16.6 13.4 15.2 13.4 14.8 12.6 C14 11 14.8 9.8 16 7.6 Z" fill="#fff8d0" fill-opacity="0.85"/>
</svg>""",
	"place_bog": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<ellipse cx="16" cy="25.4" rx="12.6" ry="3.4" fill="#2f5a4a" stroke="#132820" stroke-width="1.2"/>
<ellipse cx="13" cy="24.6" rx="5" ry="1" fill="#a8e0c8" fill-opacity="0.45"/>
<g stroke="#183214" stroke-width="3.2" stroke-linecap="round" fill="none"><path d="M10.6 25 C10.4 18 9.4 13 8 8.6"/><path d="M16 25 V6"/><path d="M21.4 25 C21.8 19 23 14.4 24.6 10.4"/></g>
<g stroke="#7fb04a" stroke-width="1.6" stroke-linecap="round" fill="none"><path d="M10.6 25 C10.4 18 9.4 13 8 8.6"/><path d="M16 25 V6"/><path d="M21.4 25 C21.8 19 23 14.4 24.6 10.4"/></g>
<g fill="#7a4a24" stroke="#2a1608" stroke-width="1"><rect x="14.2" y="6.4" width="3.6" height="8.6" rx="1.8"/><rect x="6.8" y="9" width="3.2" height="7" rx="1.6" transform="rotate(-16 8.4 12.5)"/><rect x="22.4" y="10.6" width="3.2" height="7" rx="1.6" transform="rotate(18 24 14)"/></g>
</svg>""",
	"place_ice": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<g stroke="#163248" stroke-width="4" stroke-linecap="round" fill="none">
<path d="M16 3.5 V28.5 M5.2 9.75 L26.8 22.25 M5.2 22.25 L26.8 9.75"/></g>
<g stroke="#dff4ff" stroke-width="2.2" stroke-linecap="round" fill="none">
<path d="M16 3.5 V28.5 M5.2 9.75 L26.8 22.25 M5.2 22.25 L26.8 9.75"/>
<path d="M12.6 6 L16 8.6 L19.4 6 M12.6 26 L16 23.4 L19.4 26 M6.4 14.2 L9 12.4 L8.4 9.2 M25.6 17.8 L23 19.6 L23.6 22.8 M6.4 17.8 L9 19.6 L8.4 22.8 M25.6 14.2 L23 12.4 L23.6 9.2"/></g>
<circle cx="16" cy="16" r="2.6" fill="#9fd6ff" stroke="#163248" stroke-width="1"/>
</svg>""",
	"place_sand": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><radialGradient id="u" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#fff4c0"/>
<stop offset="1" stop-color="#f2a22c"/></radialGradient>
<linearGradient id="d" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f2cf86"/>
<stop offset="1" stop-color="#b9823e"/></linearGradient></defs>
<g stroke="#f7c45a" stroke-width="1.6" stroke-linecap="round"><path d="M21 3 V5.4 M27.6 9.6 H25.4 M26 4.6 L24.4 6.2 M14.4 9.6 H16.6 M16 4.6 L17.6 6.2"/></g>
<circle cx="21" cy="11" r="5.2" fill="url(#u)" stroke="#8a4e10" stroke-width="1.1"/>
<path d="M2 28.4 C8 19 14.6 18.4 21.4 23.2 C24.4 21.2 27.4 20.8 30 21.6 V28.4 Z" fill="url(#d)" stroke="#6a4214" stroke-width="1.2" stroke-linejoin="round"/>
<path d="M6.4 24.6 C10 21.8 13.6 21.6 17 23.2" stroke="#fff0c8" stroke-width="1" stroke-linecap="round" fill="none" stroke-opacity="0.8"/>
</svg>""",
	"place_sea": """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fd0f0"/>
<stop offset="1" stop-color="#1c5f8e"/></linearGradient></defs>
<path d="M2.6 21.4 C6.6 12.2 13 7.6 19.6 9.6 C14.6 10.8 13.6 16.2 17.4 18.4 C21.4 20.6 26.2 18.2 29.4 13.8 V28 H2.6 Z" fill="#000000" fill-opacity="0.3" transform="translate(0 1)"/>
<path d="M2.6 21.4 C6.6 12.2 13 7.6 19.6 9.6 C14.6 10.8 13.6 16.2 17.4 18.4 C21.4 20.6 26.2 18.2 29.4 13.8 V28 H2.6 Z" fill="url(#w)" stroke="#0e2c44" stroke-width="1.3" stroke-linejoin="round"/>
<path d="M4.6 19.6 C8.4 12.6 13.2 9.6 18.2 10" stroke="#f2fbff" stroke-width="1.6" stroke-linecap="round" fill="none"/>
<path d="M7 24.6 C10 23 12.6 23 15.4 24.4 M18.6 24.2 C21.2 22.8 24 22.8 26.8 24" stroke="#d8f2ff" stroke-width="1.1" stroke-linecap="round" fill="none" stroke-opacity="0.75"/>
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
