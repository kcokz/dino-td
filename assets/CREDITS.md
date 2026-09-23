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
- **Animations Included**: `idle`, `run` (walk), `attack`, `death`, `alert`, `jump`
- **Usage**: Primary model for `dino/big_theropod` (1.6m size).

### Velociraptor (`assets/models/raptor.glb`)
- **Asset Name**: Low-Poly Rigged Velociraptor with Sickle Claws & Tiger Stripes
- **Source**: `tools/generate_dinos.py` (Scripted Blender Procedural Low-Poly Mesh & Armature)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5 & Antigravity)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-18
- **Files**: `assets/models/raptor.glb`
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

### Jurassic Flora (`assets/models/flora/*.glb`)
- **Asset Name**: Low-Poly Mesozoic Plants -- tree ferns, cycads, horsetails, ground ferns, monkey-puzzle araucaria, a felled tree-fern stump
- **Source**: `tools/generate_flora.py` (Scripted Blender procedural low-poly meshes, one vertex-coloured surface each)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-22
- **Files**: `tree_fern_a/b/c.glb`, `tree_fern_stump_a.glb`, `cycad_a/b/c.glb`, `horsetail_a/b.glb`, `ground_fern_a/b/c.glb`, `araucaria_a/b.glb`
- **Usage**: The choppable tree (`node/wood`) and its stump; the ground cover, the forest at the field's edge and the monkey-puzzles on the skyline (`Config.GROUND_COVER`).

### Props, Landforms & Landmarks (`assets/models/props/*.glb`)
- **Asset Name**: Low-Poly Props -- sharpened stake, stone outcrops (whole and quarried), fallen logs, volcanic crag formations, columnar basalt cliffs, the dinosaur nest, the sentry turret, resource piles
- **Source**: `tools/generate_props.py` (Scripted Blender procedural low-poly meshes, vertex-coloured; the sentry exports a Stand / Head / Muzzle hierarchy so its head can turn)
- **Author**: Defend Dinosaur Project Contributors (Co-authored with Claude Opus 5.5)
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Date Added**: 2026-09-22 (stake, outcrops, logs, crags); 2026-09-23 (basalt cliffs, nest, sentry, piles)
- **Files**: `stake_a.glb`, `outcrop_a/b.glb`, `outcrop_quarried_a.glb`, `fallen_log_a/b.glb`, `rock_formation_a/b/c.glb`, `basalt_cliff_a/b/c.glb`, `nest_a.glb`, `sentry_a.glb`, `drop_wood_a.glb`, `drop_stone_a.glb`, `drop_bone_a.glb`, `drop_food_a.glb`, `drop_water_a.glb`
- **Usage**: `building/wall`, `node/stone`, `nest`, `building/tower`, `drop/*` (`Config.VISUALS`); the hills (`Config.MAP.hill_rocks`); the cliffs and fallen logs (`Config.GROUND_COVER`).

### Volcanoes, Valley Floor & Hills (built at runtime, no asset files)
- **Source**: `scripts/fx/Volcano.gd` and `scripts/fx/TerrainBuilder.gd` -- meshes and particles built in code from `Config.VOLCANOES` and `Config.TERRAIN`; the smoke puff texture is generated from noise at load.
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
