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

### Humanoid Characters Pack (Selected Candidate for S4)
- **Asset Name**: Quaternius Modular Men / Characters & Kenney Animated Characters
- **Source URL**: https://quaternius.com / https://kenney.nl/assets/animated-characters-1
- **Author**: Quaternius / Kenney
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: glTF / .glb (Rigged, bipedal humanoid)
- **Intended Usage**: Hero and survivor base models with walking, building, harvesting, and death animations.

### Nature & Foliage Pack (Selected Candidate for S6)
- **Asset Name**: Quaternius Nature Pack
- **Source URL**: https://quaternius.com/packs/naturepack.html
- **Author**: Quaternius
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: glTF / .glb
- **Intended Usage**: Low-poly stylized prehistoric trees, ferns, cycads, and fallen logs.

### Rocks & Cliffs Pack (Selected Candidate for S9)
- **Asset Name**: Quaternius Rocks Pack & ambientCG Stylized Stones
- **Source URL**: https://quaternius.com / https://ambientcg.com
- **Author**: Quaternius / ambientCG
- **License**: CC0 1.0 Universal (Public Domain)
- **Format**: glTF / .glb
- **Intended Usage**: Stone resource nodes, scatter boulders, and dinosaur nest mounds.

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
