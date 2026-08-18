# Cartoon Visual Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the entire visual aesthetic of `thin-and-fat` (characters, world environment, lighting, skybox, interactive props, test rooms, and UI) into a vibrant, juicy cartoon arcade style (inspired by Fall Guys, Super Mario 3D World, and Overcooked).

**Architecture:** Replace flat drab grey Roblox-like placeholder models and lighting with high-quality stylized StandardMaterial3D materials, rim lighting, cartoon facial features, multi-part stylized mesh assemblies, warm golden sunlight, sky-blue ambient fill, lush grass terrains, and candy-colored interactive mechanical props.

**Tech Stack:** Godot 4.x, GDScript, StandardMaterial3D (PBR + Rim + Emissive + Cartoon parameters), CSG3D & MeshInstance3D geometry.

## Global Constraints

- Preserve all existing node names, unique IDs, exported script properties, and collision shapes so that multiplayer replication, FSM states, physics calculations, and interaction scripts continue to work without breaking.
- Use bright, harmonious HSL/RGB colors (warm skin peach, candy reds, vibrant turquoise/yellows, emerald/lime grass, warm golden sunlight).
- Ensure all materials have proper cartoon roughness (`0.25..0.45`) and subtle rim lighting (`rim = 0.25..0.4`) for crisp silhouette separation.

---

### Task 1: Cartoon Character Revamp — Fat Character (`scenes/characters/fat_character.tscn`)

**Files:**
- Modify: `scenes/characters/fat_character.tscn`
- Modify: `scripts/characters/fat_character.gd` (if needed for visual hooks)

**Interfaces:**
- Consumes: `fat_character.gd` (manages animations: `idle`, `walk`, `sprint`, `crouch`, `jump`)
- Produces: Visual 3D scene instance with stylized chubby peach body, coral-red hoodie with front pocket and hood strings, denim shorts with belt and buckle, chunky white-and-red sneakers, expressive anime/cartoon eyes with highlights, blushing cheeks, smile, and backward cap.

- [ ] **Step 1: Inspect and update fat character mesh hierarchy and materials**
  Update `scenes/characters/fat_character.tscn` with:
  - `StandardMaterial3D_skin`: Peach tone `Color(1.0, 0.82, 0.70, 1.0)`, roughness `0.4`, rim enabled `0.35`, rim tint `0.5`.
  - `StandardMaterial3D_hoodie`: Coral red `Color(0.96, 0.26, 0.24, 1.0)`, roughness `0.45`.
  - `StandardMaterial3D_hoodie_white`: Pure white `Color(0.96, 0.96, 0.96, 1.0)`.
  - `StandardMaterial3D_denim`: Deep vibrant blue `Color(0.18, 0.42, 0.82, 1.0)`, roughness `0.5`.
  - `StandardMaterial3D_belt`: Saddle brown `Color(0.42, 0.24, 0.12, 1.0)` with gold buckle `Color(1.0, 0.82, 0.15, 1.0)`.
  - `StandardMaterial3D_sneaker_white`: Clean white `Color(0.95, 0.95, 0.95, 1.0)`.
  - `StandardMaterial3D_eye_white`: Glossy white `Color(0.98, 0.98, 0.98, 1.0)`.
  - `StandardMaterial3D_pupil`: Glossy deep black `Color(0.08, 0.08, 0.09, 1.0)`.
  - `StandardMaterial3D_highlight`: Pure emissive white `Color(1.0, 1.0, 1.0, 1.0)`.
  - `StandardMaterial3D_blush`: Soft pink blush `Color(1.0, 0.45, 0.55, 0.6)`.
  - `StandardMaterial3D_cap`: Bright yellow or cyan cap `Color(0.12, 0.72, 0.88, 1.0)`.

- [ ] **Step 2: Add stylized mesh details to FatCharacter**
  - Add pocket mesh (`KangarooPocket`), hoodie drawstring cords, backward cap on head with visor, and cute highlight beads on eyes.
  - Re-adjust animations (`idle`, `walk`, `sprint`, `crouch`, `jump`) for bouncy squash-and-stretch.

- [ ] **Step 3: Verify scene loads without errors**
  Verify `fat_character.tscn` syntax and node structure.

- [ ] **Step 4: Commit**
  ```bash
  git add scenes/characters/fat_character.tscn
  git commit -m "feat(graphics): revamp fat character into vibrant cartoon style"
  ```

---

### Task 2: Cartoon Character Revamp — Thin Character (`scenes/characters/thin_character.tscn`)

**Files:**
- Modify: `scenes/characters/thin_character.tscn`
- Modify: `scripts/characters/thin_character.gd` (if needed for visual hooks)

**Interfaces:**
- Consumes: `thin_character.gd` (manages animations: `idle`, `walk`, `sprint`, `crouch`, `jump`)
- Produces: Visual 3D scene instance with stylized lanky beanpole body, bright turquoise/yellow striped windbreaker sweater, dark cyan trousers, yellow high-top Converse sneakers, round glasses/expressive eyes, and hair tuft.

- [ ] **Step 1: Inspect and update thin character mesh hierarchy and materials**
  Update `scenes/characters/thin_character.tscn` with:
  - `StandardMaterial3D_skin`: Warm peach `Color(1.0, 0.82, 0.70, 1.0)`, roughness `0.4`, rim enabled `0.35`.
  - `StandardMaterial3D_sweater`: Bright turquoise `Color(0.08, 0.78, 0.74, 1.0)` with yellow accent stripes `Color(1.0, 0.84, 0.12, 1.0)`.
  - `StandardMaterial3D_pants`: Dark slate turquoise `Color(0.12, 0.22, 0.30, 1.0)`.
  - `StandardMaterial3D_shoes`: Vivid yellow canvas `Color(1.0, 0.82, 0.10, 1.0)` with white rubber toe caps.
  - `StandardMaterial3D_glasses`: Dark circular cartoon glasses frames `Color(0.12, 0.12, 0.14, 1.0)`.
  - `StandardMaterial3D_hair`: Fun cartoon hair tuft `Color(0.35, 0.20, 0.10, 1.0)`.

- [ ] **Step 2: Add stylized mesh details to ThinCharacter**
  - Add sweater collar, cuffs, stylish glasses, hair tuft, and high-top shoe soles.
  - Update walk/run animation curves for comical long-legged stride.

- [ ] **Step 3: Verify scene loads without errors**
  Verify `thin_character.tscn` syntax and node structure.

- [ ] **Step 4: Commit**
  ```bash
  git add scenes/characters/thin_character.tscn
  git commit -m "feat(graphics): revamp thin character into vibrant cartoon style"
  ```

---

### Task 3: Cartoon NPC Revamp — Dummy Bot (`scenes/dummy_npc.tscn`)

**Files:**
- Modify: `scenes/dummy_npc.tscn`

**Interfaces:**
- Consumes: Target dummy damage signals and hit effects.
- Produces: Goofy cartoon crash-test robot with bright yellow/orange paint, spiral bullseye target belly, metallic spring neck, and cartoon expression.

- [ ] **Step 1: Redesign dummy mesh and materials**
  - Update `dummy_npc.tscn`:
    - Body: Bright golden-yellow crash-test dummy color `Color(1.0, 0.75, 0.1, 1.0)`.
    - Chest Target: Black & red concentric target rings / spiral decal mesh.
    - Neck: Shiny metallic coil spring `Color(0.7, 0.75, 0.8, 1.0)`, metallic `0.85`.
    - Head & Face: Cute robot head with funny glowing cartoon eyes `Color(0.1, 0.9, 1.0, 1.0)` (emissive).
    - Base Stand: Heavy rounded dark steel plate with yellow hazard stripes.

- [ ] **Step 2: Commit**
  ```bash
  git add scenes/dummy_npc.tscn
  git commit -m "feat(graphics): redesign dummy NPC into goofy crash-test cartoon bot"
  ```

---

### Task 4: World Environment, Lighting & Sky Revamp (`scenes/world.tscn`)

**Files:**
- Modify: `scenes/world.tscn`
- Modify: `addons/lowpolytrees/` or tree materials in `tree_4.tscn`

**Interfaces:**
- Consumes: Godot 4 WorldEnvironment and DirectionalLight3D.
- Produces: Sunny, vibrant cartoon playground with emerald green lawn, crisp golden sunlight, soft sky-blue fill shadows, clean sky with fluffy clouds, and colorful foliage.

- [ ] **Step 1: Update WorldEnvironment in `scenes/world.tscn`**
  - Remove dark grey fog and dreary atmospheric tints.
  - Set ambient light source to sky/custom with soft cheerful sky blue tint `Color(0.70, 0.85, 1.0, 1.0)`, energy `0.85`.
  - Set tonemap mode to ACES/Filmic with exposure `1.15`, white `1.0`.
  - Enable Glow/Bloom with strength `0.45`, bloom `0.15` for vibrant cartoon highlights.
  - Configure Sun light (`DirectionalLight3D`): Warm sunshine `Color(1.0, 0.97, 0.90, 1.0)`, energy `1.3`, soft shadow blur `1.8`.

- [ ] **Step 2: Update Ground and Terrain Materials**
  - Replace dark grey box floor material with bright lush grass material `Color(0.32, 0.78, 0.25, 1.0)`, roughness `0.55`.
  - Add cartoon spawn pads with colorful concentric borders and cheerful floating 3D labels.
  - Update checkpoint arches with glowing yellow/gold energy rings.

- [ ] **Step 3: Update Low-Poly Trees Foliage**
  - Ensure tree leaf materials have rich emerald/lime gradient tones and warm chocolate tree trunks.

- [ ] **Step 4: Commit**
  ```bash
  git add scenes/world.tscn tree_4.tscn
  git commit -m "feat(graphics): overhaul world environment, lighting, sky and grass to sunny cartoon aesthetic"
  ```

---

### Task 5: Interactive Puzzle Objects & Props Revamp

**Files:**
- Modify: `scenes/objects/seesaw_catapult.tscn`
- Modify: `scenes/objects/heavy_pressure_button.tscn`
- Modify: `scenes/objects/heavy_lever.tscn`
- Modify: `scenes/objects/wind_tunnel_fan.tscn`
- Modify: `scenes/objects/fragile_glass_floor.tscn`
- Modify: `scenes/objects/test_room.tscn`
- Modify: `scenes/objects/magnetism_test_room.tscn`
- Modify: `scenes/objects/road_segment.tscn`
- Modify: `scenes/objects/floating_hint_sign.tscn`
- Modify: `scenes/shower_cabin.tscn`
- Modify: `scenes/trash_bin.tscn`
- Modify: `scenes/boulder.tscn`

**Interfaces:**
- Consumes: Existing gameplay scripts (`heavy_pressure_button.gd`, `heavy_lever.gd`, `seesaw_catapult.gd`, etc.).
- Produces: Vibrant arcade-style 3D props matching the Mario/Fall Guys aesthetic.

- [ ] **Step 1: Revamp Seesaw Catapult & Boulder**
  - Seesaw: Red and yellow striped plank (`StandardMaterial3D`), glossy red jump pad, chrome pivot.
  - Boulder: Stylized cartoon rock / giant bowling ball with smooth beveled facets.

- [ ] **Step 2: Revamp Heavy Pressure Button & Heavy Lever**
  - Button: Large glowing red dome button with hazard yellow/black base, smooth push spring.
  - Lever: Sturdy cartoon console with red sphere handle and glowing green/red LED lamps.

- [ ] **Step 3: Revamp Wind Fan, Shower, and Trash Bin**
  - Wind Fan: Bright cyan turbo nozzle, orange spinner hub, white swirl particle trails.
  - Shower Cabin: Glossy pastel-blue ceramic tiles, shiny chrome showerhead, water spray particles.
  - Trash Bin: Vibrant green cartoon recycling can with curved lid and recycle logo.

- [ ] **Step 4: Revamp Test Rooms, Glass Floor, and Roads**
  - Test Rooms: Clean bright glossy white walls with neon color-coded portal arches (cyan/lime/coral).
  - Fragile Glass: Translucent candy cyan crystal glass with sparkling highlights.
  - Road Segments: Stylized cobblestone pavers with grass edges.

- [ ] **Step 5: Commit**
  ```bash
  git add scenes/objects/ scenes/shower_cabin.tscn scenes/trash_bin.tscn scenes/boulder.tscn
  git commit -m "feat(graphics): upgrade interactive puzzle props and test rooms to cartoon style"
  ```

---

### Task 6: Cartoon UI & HUD Revamp (`scenes/player.tscn`, `scenes/ui/`)

**Files:**
- Modify: `scenes/player.tscn`
- Modify: `scripts/ui/player_hud.gd`

**Interfaces:**
- Consumes: Player health/stamina/character switch signals.
- Produces: Colorful rounded pill HUD with smooth health/stamina bars, pop-up damage indicators, and clean cartoon fonts.

- [ ] **Step 1: Update Player HUD styles in `player.tscn`**
  - StyleBoxFlat: Rounded pill containers (corner radius `12px`), dark translucent background with subtle glow border.
  - HP Bar: Bright juicy green gradient (`Color(0.2, 0.9, 0.4)` -> `Color(0.35, 0.95, 0.5)`).
  - Stamina Bar: Bright sky-blue/cyan gradient (`Color(0.15, 0.75, 1.0)`).
  - Crosshair & Indicators: Clean, crisp cartoon crosshair and friendly typography.

- [ ] **Step 2: Commit**
  ```bash
  git add scenes/player.tscn scripts/ui/player_hud.gd
  git commit -m "feat(ui): style HUD with rounded cartoon bars and clean typography"
  ```

---

### Task 7: Full Scene Verification & Polish

**Files:**
- Test all scenes and run project verification.

**Interfaces:**
- Consumes: All updated scenes and resources.
- Produces: Verified working project with no missing resource errors or broken references.

- [ ] **Step 1: Check all modified scene files for format and resource integrity**
- [ ] **Step 2: Verify git status and clean working tree**
- [ ] **Step 3: Commit any final polish adjustments**
  ```bash
  git add -A
  git commit -m "chore: finalize cartoon visual revamp integration"
  ```
