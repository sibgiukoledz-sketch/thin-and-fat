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

- [x] **Step 1: Inspect and update fat character mesh hierarchy and materials**
- [x] **Step 2: Add stylized mesh details to FatCharacter**
- [x] **Step 3: Verify scene loads without errors**
- [x] **Step 4: Commit**

---

### Task 2: Cartoon Character Revamp — Thin Character (`scenes/characters/thin_character.tscn`)

**Files:**
- Modify: `scenes/characters/thin_character.tscn`
- Modify: `scripts/characters/thin_character.gd` (if needed for visual hooks)

**Interfaces:**
- Consumes: `thin_character.gd` (manages animations: `idle`, `walk`, `sprint`, `crouch`, `jump`)
- Produces: Visual 3D scene instance with stylized lanky beanpole body, bright turquoise/yellow striped windbreaker sweater, dark cyan trousers, yellow high-top Converse sneakers, round glasses/expressive eyes, and hair tuft.

- [x] **Step 1: Inspect and update thin character mesh hierarchy and materials**
- [x] **Step 2: Add stylized mesh details to ThinCharacter**
- [x] **Step 3: Verify scene loads without errors**
- [x] **Step 4: Commit**

---

### Task 3: Cartoon NPC Revamp — Dummy Bot (`scenes/dummy_npc.tscn`)

**Files:**
- Modify: `scenes/dummy_npc.tscn`

**Interfaces:**
- Consumes: Target dummy damage signals and hit effects.
- Produces: Goofy cartoon crash-test robot with bright yellow/orange paint, spiral bullseye target belly, metallic spring neck, and cartoon expression.

- [x] **Step 1: Redesign dummy mesh and materials**
- [x] **Step 2: Commit**

---

### Task 4: World Environment, Lighting & Sky Revamp (`scenes/world.tscn`)

**Files:**
- Modify: `scenes/world.tscn`
- Modify: `addons/lowpolytrees/` or tree materials in `tree_4.tscn`

**Interfaces:**
- Consumes: Godot 4 WorldEnvironment and DirectionalLight3D.
- Produces: Sunny, vibrant cartoon playground with emerald green lawn, crisp golden sunlight, soft sky-blue fill shadows, clean sky with fluffy clouds, and colorful foliage.

- [x] **Step 1: Update WorldEnvironment in `scenes/world.tscn`**
- [x] **Step 2: Update Ground and Terrain Materials**
- [x] **Step 3: Update Low-Poly Trees Foliage**
- [x] **Step 4: Commit**

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

- [x] **Step 1: Revamp Seesaw Catapult & Boulder**
- [x] **Step 2: Revamp Heavy Pressure Button & Heavy Lever**
- [x] **Step 3: Revamp Wind Fan, Shower, and Trash Bin**
- [x] **Step 4: Revamp Test Rooms, Glass Floor, and Roads**
- [x] **Step 5: Commit**

---

### Task 6: Cartoon UI & HUD Revamp (`scenes/player.tscn`, `scenes/ui/`)

**Files:**
- Modify: `scenes/player.tscn`
- Modify: `scripts/ui/player_hud.gd`

**Interfaces:**
- Consumes: Player health/stamina/character switch signals.
- Produces: Colorful rounded pill HUD with smooth health/stamina bars, pop-up damage indicators, and clean cartoon fonts.

- [x] **Step 1: Update Player HUD styles in `player.tscn`**
- [x] **Step 2: Commit**

---

### Task 7: Full Scene Verification & Polish

**Files:**
- Test all scenes and run project verification.

**Interfaces:**
- Consumes: All updated scenes and resources.
- Produces: Verified working project with no missing resource errors or broken references.

- [x] **Step 1: Check all modified scene files for format and resource integrity**
- [x] **Step 2: Verify git status and clean working tree**
- [x] **Step 3: Commit any final polish adjustments**
