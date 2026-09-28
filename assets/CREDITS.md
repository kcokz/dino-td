# Third-Party & Generated Assets Credits & Licensing Ledger

This ledger tracks all 3D models, textures, animations, audio, and environmental assets used in Defend Dinosaur.

Every asset in this project MUST be documented here on the day it is introduced.
Unrecorded assets are considered unpublishable and will fail automated CI tests.

All external assets adhere strictly to **CC0 (Public Domain)** or compatible commercial licenses.

---

## 1. 3D Models & Rigs

### Big Theropod / T-Rex (`assets/models/t_rex.glb`)
- **Asset Name**: Low-Poly Rigged Tyrannosaurus Rex
- **Source**: `tools/generate_dinos.py` (Scripted Blender Procedural Low-Poly Mesh & Armature)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5 & Antigravity)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-15 (Updated 2026-09-18 with Death clip)
- **Files**: `assets/models/t_rex.glb`, `assets/models/t_rex.blend`
- **Superseded**: 2026-09-23 by the Quaternius model (below) for `dino/big_theropod`. The file and its generator stay; nothing loads it.
- **Animations Included**: `idle`, `run` (walk), `attack`, `death`, `alert`, `jump`
- **Usage**: Primary model for `dino/big_theropod` (1.6m size).

### Velociraptor (`assets/models/raptor.glb`)
- **Asset Name**: Low-Poly Rigged Velociraptor with Sickle Claws & Tiger Stripes
- **Source**: `tools/generate_dinos.py` (Scripted Blender Procedural Low-Poly Mesh & Armature)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5 & Antigravity)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-18
- **Files**: `assets/models/raptor.glb`
- **Superseded**: 2026-09-23 by the Quaternius model (below) for `dino/raptor`. The file and its generator stay; nothing loads it.
- **Animations Included**: `idle`, `run` (walk), `attack` (sickle claw leap & bite), `death`, `alert`
- **Usage**: Primary model for `dino/raptor` (0.8m size).

### Pterosaur / Pterodactyl (`assets/models/pterosaur.glb`)
- **Asset Name**: Low-Poly Rigged Pterodactyl with Cranial Crest & Wing Membranes
- **Source**: `tools/generate_dinos.py` (Scripted Blender Procedural Low-Poly Mesh & Armature)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5 & Antigravity)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-18
- **Files**: `assets/models/pterosaur.glb`
- **Animations Included**: `idle`, `run` (wing-assisted lope), `attack` (beak spear peck), `death`, `alert`
- **Usage**: Primary model for `dino/pterosaur` (1.0m size).

### Hero / Explorer (`assets/models/hero.glb`)
- **Asset Name**: Low-Poly Rigged Humanoid Hero / Explorer with Survival Pack & Multitool
- **Source**: `tools/generate_hero.py` (Scripted Blender Procedural Low-Poly Biped Mesh & Armature Rig)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5 & Antigravity)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-18
- **Files**: `assets/models/hero.glb`, `assets/models/hero.blend`
- **Superseded**: 2026-09-23 by the Quaternius model (below) for `hero`. The file and its generator stay; nothing loads it.
- **Animations Included**: `idle`, `walk`, `run`, `build` (overhead rhythmic hammer strike), `harvest` (two-handed downward cleave/chop), `attack` (defensive thrust), `death` (stumble and collapse)
- **Usage**: Primary model for `hero` (0.8m width, 1.6m height). Full 1:1 coverage of all 6 `Hero.State` enum states.

### Spaceship Wreck / Core Base (`assets/models/wreck.glb`)
- **Asset Name**: Low-Poly Crashed Spaceship Command Pod Wreck with Scorched Hull & Debris
- **Source**: `tools/generate_wreck.py` (Scripted Blender Procedural Low-Poly Mesh & Materials)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5 & Antigravity)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-18
- **Files**: `assets/models/wreck.glb`, `assets/models/wreck.blend`
- **Materials Included**: Composite hull plating, dark carbon thermal tiles, polarized canopy visor, hazard orange markings, charred re-entry burn, sheared titanium frame spars
- **Usage**: Primary model for `building/core` (default 1.0m footprint, 1.9m height).

### Quaternius Animated Dinosaur Pack (`assets/models/quaternius/{trex,velociraptor,apatosaurus,parasaurolophus,stegosaurus,triceratops}.glb`)
- **Asset Name**: Animated Dinosaur Pack (December 2018) -- six rigged, animated dinosaurs
- **Source URL**: https://quaternius.com/packs/animateddinosaurs.html (the Google Drive folder that page links to, FBX folder)
- **Author**: Quaternius
- **License**: CC0 1.0 Universal (Public Domain Dedication); the pack's own `License.txt` is kept at `assets/source/quaternius/License.txt`
- **Date Added**: 2026-09-23, downloaded with the user's permission
- **Source Files (unchanged)**: `assets/source/quaternius/{Trex,Velociraptor,Apatosaurus,Parasaurolophus,Stegosaurus,Triceratops}.fbx`
- **Converted By**: `tools/convert_quaternius.py` -- turned to face the game's -Z; the rig object's own keyed transform taken out of every clip; each mesh's transform baked into its vertices; clips renamed to the names `Config.ANIMATIONS` uses; matte; and made OPAQUE (the FBX materials import with an alpha of 0, which drew every dinosaur invisible)
- **Usage**: `dino/big_theropod` (trex), `dino/raptor` (velociraptor). The four plant-eaters are converted for background herds (the first map's herds are Placerias since v0.6 round three; these wait for later maps).

### The First Map's Cast, reshaped from the Quaternius pack (`assets/models/triassic/{coelophysis,postosuchus,placerias}.glb`)
- **Asset Name**: Coelophysis (from the velociraptor), Postosuchus (from the trex), Placerias (from the triceratops) -- the Late Triassic's raiders, boss and grazers (GAME-DESIGN 7.2, station 1)
- **Source**: the converted Quaternius models above (CC0), reshaped by `tools/generate_triassic.py`: bones stretched and slimmed in pose, the pose baked into the mesh and made the rest pose, so every clip still plays; recoloured; Postosuchus given rows of scutes, Placerias its frill and horns cut away
- **Author**: Quaternius (the rigs, meshes and animations); reshaped by Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-28
- **Usage**: `dino/coelophysis`, `dino/coelophysis_alpha`, `dino/postosuchus` (`Config.VISUALS`); the herds (`Config.HERDS`).

### Quaternius Ultimate Animated Character Pack -- Worker (`assets/models/quaternius/worker.glb`)
- **Asset Name**: Ultimate Animated Character Pack (November 2019), `Worker_Male`
- **Source URL**: https://quaternius.com/packs/ultimatedanimatedcharacter.html (the Google Drive folder that page links to, glTF folder)
- **Author**: Quaternius
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-23, downloaded with the user's permission
- **Source File (unchanged)**: `assets/source/quaternius/Worker_Male.gltf`
- **Converted By**: `tools/convert_quaternius.py` -- as above, plus: a stray unparented icosphere removed; clips mapped onto the Hero's work (Punch -> attack, SwordSlash -> harvest, PickUp -> build); and the skin recoloured from the authored near-black (0.013 linear), which read in the game as a featureless black head with white eyes, to a warm mid tone
- **Usage**: `hero`, fitted by height (he is rigged in a T-pose)
- **Superseded**: 2026-09-25 by the Hero below: the pack is built to cartoon proportions (a big head on a short body) and he wore a hard hat -- reported as too cartoonish. The file and its conversion stay; nothing loads it.

### Quaternius Universal Base Characters, Modular Character Outfits -- Fantasy, Universal Animation Library -- the Hero (`assets/models/quaternius/hero.glb`)
- **Asset Names**: Universal Base Characters (Standard), Modular Character Outfits -- Fantasy (Standard, v2.0), Universal Animation Library (Standard) -- characters, outfits and animations built to real human proportions on one humanoid rig
- **Source URLs**: https://quaternius.itch.io/universal-base-characters , https://quaternius.itch.io/modular-character-outfits-fantasy , https://quaternius.itch.io/universal-animation-library (the free Standard downloads)
- **Author**: Quaternius
- **License**: CC0 1.0 Universal (Public Domain Dedication); each kit's own licence file is kept in `assets/source/quaternius/ubc/`
- **Date Added**: 2026-09-25, downloaded with the user's permission (`Universal Base Characters[Standard].zip` 122 MB, `Modular Character Outfits - Fantasy[Standard].zip` 280 MB, `Universal Animation Library[Standard].zip` 15 MB)
- **Source Files**: `assets/source/quaternius/ubc/` -- `Male_Peasant.gltf` (the Regular male body in a plain shirt, trousers and shoes), `Superhero_Male_FullBody.gltf` (for its head, eyes and brows: the only head in the free kit), `Hair_SimpleParted.gltf`, `UAL1_Standard.glb`; the models unchanged, their textures reduced from 4096 to 1024 pixels
- **Built By**: `tools/build_hero.py` -- the head cut from the Superhero body at the neck and put on the Regular body (the kits' spine, neck and head bones stand in exactly the same places), hair added, eight clips taken from the animation library under the names the game plays (Idle_Loop, Walk_Loop, Jog_Fwd_Loop, Punch_Jab -> attack, Interact -> harvest, Fixing_Kneeling -> build, Death01, Hit_Chest), the grey hair dyed dark brown; and since 2026-09-27 dressed as the ship's crew: the clothes and bare forearms re-dyed as a white suit (their shading kept), boots and gloves darkened, and the suit's hard parts modelled on the rig by the same script (a neck ring, a life-support pack, a chest unit with a lit screen, arm bands, wrist and ankle cuffs), each weighted wholly to one bone
- **Usage**: `hero`, fitted by height (he is rigged in a T-pose)

### Jurassic Flora (`assets/models/flora/*.glb`)
- **Asset Name**: Low-Poly Mesozoic Plants -- tree ferns, cycads, horsetails, ground ferns, monkey-puzzle araucaria, a felled tree-fern stump
- **Source**: `tools/generate_flora.py` (Scripted Blender procedural low-poly meshes, one vertex-coloured surface each)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-22
- **Files**: `tree_fern_a/b/c.glb`, `tree_fern_stump_a.glb`, `cycad_a/b/c.glb`, `horsetail_a/b.glb`, `ground_fern_a/b/c.glb`, `araucaria_a/b.glb`
- **Usage**: The choppable tree (`node/wood`) and its stump; the ground cover, the forest at the field's edge and the monkey-puzzles on the skyline (`Config.GROUND_COVER`).

### Props, Landforms & Landmarks (`assets/models/props/*.glb`)
- **Asset Name**: Low-Poly Props -- the palisade (a post and four runs of sharpened logs, one plain and one bone-tipped), the gate (two posts and a hinged door of planks), the drystone wall, stone outcrops (whole and quarried), fallen logs, volcanic crag formations, columnar basalt cliffs, the dinosaur nest, the traps (the trip bow on its forked stakes; the set crossbow on a stone plinth, and its twin-staved improvement -- each with a String and an Arrow or Bolt the game moves), resource piles, the water spot on the river bank (the cabin moved to `tools/generate_cabin.py` in v0.6 round three)
- **Source**: `tools/generate_props.py` (Scripted Blender procedural low-poly meshes, vertex-coloured; the palisade, the gate and the traps export their named parts -- Post, Run_E/W/N/S; Frame, Door; String, Arrow, Bolt -- so the game can show, hide, swing and draw them)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-22 (stake, outcrops, logs, crags); 2026-09-23 (basalt cliffs, nest, sentry, piles); 2026-09-25 (water spot, cabin); 2026-09-27 (bow tower, the cabin's turret; the palisade, bone palisade and gate, replacing the single stakes; the traps, replacing the sentry and the bow tower)
- **Files**: `palisade_a.glb`, `bone_palisade_a.glb`, `gate_a.glb`, `stone_wall_a.glb`, `outcrop_a/b.glb`, `outcrop_quarried_a.glb`, `fallen_log_a/b.glb`, `rock_formation_a/b/c.glb`, `basalt_cliff_a/b/c.glb`, `nest_a.glb`, `trip_bow_a.glb`, `set_crossbow_a.glb`, `set_crossbow_2_a.glb`, `drop_wood_a.glb`, `drop_stone_a.glb`, `drop_bone_a.glb`, `drop_food_a.glb`, `drop_water_a.glb`, `water_landing_a.glb`
- **Usage**: `building/wall`, `building/bone_stake`, `building/stone_wall`, `building/gate`, `building/trip_bow`, `building/set_crossbow`, `building/set_crossbow_2`, `node/stone`, `node/water`, `nest`, `drop/*` (`Config.VISUALS`); the hills (`Config.MAP.hill_rocks`); the cliffs and fallen logs (`Config.GROUND_COVER`); the boulders in the river's white water (`Config.TERRAIN.river`).

### Volcanoes, Valley Floor, River & Hills (built at runtime, no asset files)
- **Source**: `scripts/fx/Volcano.gd`, `scripts/fx/TerrainBuilder.gd` and `scripts/fx/River.gd` -- meshes and particles built in code from `Config.VOLCANOES` and `Config.TERRAIN`; the smoke puff texture and the water's ripple normal map are generated from noise at load.
- **License**: Project code; nothing external.

### Nature & Foliage Pack (Selected Candidate for S6 -- not used)
- **Asset Name**: Quaternius Nature Pack
- **Source URL**: https://quaternius.com/packs/naturepack.html
- **Author**: Quaternius
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: glTF / .glb
- **Intended Usage**: Low-poly stylized prehistoric trees, ferns, cycads, and fallen logs.
- **Outcome**: Superseded by `tools/generate_flora.py`. The free packs' trees are temperate -- oaks and pines -- and read as a modern forest with dinosaurs in it (see VERSION.md, v0.5).

### Rocks & Cliffs Pack (Selected Candidate for S9 -- not used)
- **Asset Name**: Quaternius Rocks Pack & ambientCG Stylized Stones
- **Source URL**: https://quaternius.com / https://ambientcg.com
- **Author**: Quaternius / ambientCG
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: glTF / .glb
- **Intended Usage**: Stone resource nodes, scatter boulders, and dinosaur nest mounds.
- **Outcome**: Superseded by `tools/generate_props.py`, so every rock on the map shares one palette and one faceted style.

---

## 2. Textures & Materials (PBR)

### Terrain PBR Ground Materials (Selected Candidate for S7)
- **Asset Name**: Ground / Dirt / Grass / Rock Face PBR Textures
- **Source URL**: https://ambientcg.com
- **Author**: Lennart Demes (ambientCG)
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: 1K/2K PNG (Albedo, Normal, Roughness, Ambient Occlusion)
- **Intended Usage**: Tri-planar slope blend shader for level terrain.

---

## 3. Environment & Skies

### Prehistoric Dawn / Low Sun HDRI (Selected Candidate for S8)
- **Asset Name**: Poly Haven Sky Series (e.g., prehistoric / savannah dawn)
- **Source URL**: https://polyhaven.com/hdris
- **Author**: Poly Haven contributors (polyhaven.com)
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: .exr / .hdr (Equirectangular panorama)
- **Intended Usage**: Realistic environment lighting, ambient sky contribution, and background panorama.

---

## 4. Interface: Type, Icons & Shaders

### Cinzel (`assets/fonts/Cinzel.ttf`)
- **Asset Name**: Cinzel, variable (weights 400-900) -- Roman inscriptional capitals, its lowercase small capitals
- **Source**: https://github.com/google/fonts/tree/main/ofl/cinzel (`Cinzel[wght].ttf`, 125,468 bytes), downloaded with the user's approval
- **Author**: The Cinzel Project Authors (Natanael Gama); https://github.com/NDISCOVER/Cinzel
- **License**: SIL Open Font License 1.1 -- full text in `assets/fonts/Cinzel-OFL.txt`, beside the font. No Reserved Font Name is declared. OFL fonts may be bundled with commercial software; the font may not be sold on its own.
- **Date Added**: 2026-09-27
- **Usage**: Titles, names, headings and every button (`Config.THEME.display_font`, `UiTheme.display_font`).

### Alegreya Sans (`assets/fonts/AlegreyaSans-{Regular,Medium,Bold,ExtraBold}.ttf`)
- **Asset Name**: Alegreya Sans, four weights -- a humanist sans with lining and tabular figures
- **Source**: https://github.com/google/fonts/tree/main/ofl/alegreyasans, downloaded with the user's approval
- **Author**: The Alegreya Sans Project Authors (Huerta Tipográfica); https://github.com/huertatipografica/Alegreya-Sans
- **License**: SIL Open Font License 1.1 -- full text in `assets/fonts/AlegreyaSans-OFL.txt`, beside the fonts.
- **Date Added**: 2026-09-27
- **Usage**: Running text, counts and card names (`Config.THEME.text_fonts`, `UiTheme.font`). Chinese running text falls back to the player's installed system UI face (`Config.THEME.fallback_fonts`).

### Noto Serif SC, cut down (`assets/fonts/NotoSerifSC-Title.ttf`)
- **Asset Name**: Noto Serif SC (思源宋体), its weight axis narrowed to 600-900 and its characters cut down to those the game's strings use (about four hundred), 339 KB
- **Source**: https://github.com/google/fonts/tree/main/ofl/notoserifsc (`NotoSerifSC[wght].ttf`, 25 MB), downloaded with the user's approval; cut by `tools/subset_fonts.py` (fontTools). The whole face stays out of the repository (`tools/font_sources/`, git-ignored).
- **Author**: Google Inc. (the Noto CJK / Source Han project, with Adobe)
- **License**: SIL Open Font License 1.1 -- full text in `assets/fonts/NotoSerifSC-OFL.txt`, beside the font. A cut of an OFL font is a Modified Version under the licence; it keeps the licence and makes no use of a Reserved Font Name.
- **Date Added**: 2026-09-27
- **Usage**: Chinese in titles, names and buttons, behind Cinzel (`Config.THEME.display_cjk_font`).

### Interface Icons (`assets/icons/*.svg`)
- **Asset Name**: Resource, building, unit, bench and command icons
- **Source**: `tools/build_icons.py` (hand-written SVG geometry, generated)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-26
- **Usage**: Every icon the HUD, command card, cabin screen and menus draw, imported as DPITexture so they stay sharp at any scale.

### The Cabin (`assets/models/cabin/{module,workbench,kitchen,beacon}_a.glb`)
- **Asset Name**: The crew module the Hero lives in, outside and in (v0.6 round three) -- its hull with a sliding door and glass windows in its south side, its roof and front wall in parts that fade while he is inside, a heat shield ploughed into the earth at one end and the engine with the ship's turret at the other, docking ports at both ends -- and its three benches: a workbench on log legs under a tool board, a stone hearth under a hood, the module's radio and its antenna mast, each with the parts that appear as the run goes on (the tools, the stone pot, the mast's three repaired stages)
- **Source**: `tools/generate_cabin.py` (Scripted Blender low-poly geometry, coloured by its vertices, in the props' palette)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-26
- **Usage**: `building/core` and `station/<id>` in `Config.VISUALS`; parts shown and faded by `scripts/fx/CabinArt.gd` and `scripts/entities/CoreCampfire.gd`.

### Interface Materials (`assets/ui/*.png`)
- **Asset Name**: The interface's surfaces -- leather framed in bone with knuckles at its corners, the ship's slate framed in steel, a plate, a studded button and a painted one, sunk sockets (square and round), round buttons, the status bar's strip, a medallion and the ring of pigment in it, brush strokes in ink and red ochre, a trough capped with bone, pigment and hatched pigment, a groove, a rule and its ornament, a stitched hide
- **Source**: `tools/build_ui_textures.gd` (drawn by rule: tiling gradient noise, a crack field measured round a torus, and light worked out from each pixel's distance to the outline; every surface drawn to tile)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-27
- **Usage**: `Config.THEME.surfaces`, imported as Images; `UiTheme.surface` cuts each into nine, tiles it and tints it (`Config.THEME.tints`).

### Rendered Material Icons (`assets/icons/rendered/*.png`)
- **Asset Name**: Each material's icon -- logs, rocks, bones, meat, a boss's cut, a pot of water -- rendered from the pile the game drops of it, ringed with a dark edge
- **Source**: `tools/render_portraits.gd` (`Config.RENDERED_ICONS`), from this project's own drop models (`assets/models/props/drop_*_a.glb`)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-27
- **Usage**: `UiTheme.icon` takes one over the drawn icon of the same name: the status bar, prices, toasts.

### Portraits (`assets/portraits/*.png`)
- **Asset Name**: A portrait of each thing the command card and a bench can show -- the Hero's head and shoulders, each building, bench, tree and rock in three-quarter view -- on a clear ground
- **Source**: `tools/render_portraits.gd`: rendered in the engine from the game's own models (the entries above: the Hero from Quaternius' kits, CC0; the buildings, benches and rocks from this project's generators), fitted and posed as the game shows them, under a studio light
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication); the models rendered keep their own licences above
- **Date Added**: 2026-09-27
- **Usage**: `UiTheme.portrait` (`Config.PORTRAITS`), in the command card and on each bench's card in the cabin.

### Frosted Backdrop Shader (`assets/shaders/ui_frost.gdshader`)
- **Asset Name**: Frosted-glass backdrop for full-screen menus
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-26
- **Usage**: Behind the pause menu, the results card and the cabin screen.
