# R.E.P.O. & Human Fall Flat Characters, Lighting & Outline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely overhaul characters from scratch into high-quality, fully editable R.E.P.O. / Human Fall Flat style models with real connected bone hierarchies and active physics wobble; fix lighting overexposure and create crisp 4-split PSSM shadows; and implement a cartoon Inverted-Hull outline shader across characters and interactive objects.

**Architecture:** Godot 4 StandardMaterial3D + custom ShaderMaterial (Inverted Hull `toon_outline.gdshader`), connected `Skeleton3D` joint hierarchies (Pelvis -> Torso -> Neck -> Head, Shoulders -> Arms -> Forearms -> Hands, Hips -> Thighs -> Shins -> Feet), procedural spring-damper secondary physics in GDScript, and balanced DirectionalLight3D + ACES WorldEnvironment.

**Tech Stack:** Godot 4.x, GDScript, GLSL Spatial Shaders, StandardMaterial3D (PBR + Next Pass), Skeleton3D & AnimationPlayer.

## Global Constraints

- Keep all scene scenes fully open and natively editable in Godot Editor Inspector without breaking procedural fallbacks.
- Preserve all existing method signatures on character scripts: `play_anim(anim_name: String)`, `set_carrying_pose(is_carrying: bool)`, `start_ragdoll(velocity: Vector3)`, `stop_ragdoll()`.
- Ensure all `ext_resource` UIDs match their `.uid` files exactly to prevent silent script detaching.
- Keep performance high (60+ FPS) by using lightweight primitives and optimized vertex-normal extrusion for outlines.

---

### Task 1: Balanced Lighting & Crisp Cartoon Shadows (`scenes/world.tscn`)

**Files:**
- Modify: `scenes/world.tscn`

**Interfaces:**
- Consumes: Godot 4 `DirectionalLight3D`, `WorldEnvironment`, and `SkyMaterial`.
- Produces: Clean, balanced sunny environment with zero overexposure, rich shadow contrast, and crisp 4-cascade PSSM shadows.

- [ ] **Step 1: Update DirectionalLight3D parameters in `scenes/world.tscn`**
  - Set `light_color = Color(1.0, 0.98, 0.92, 1.0)`
  - Set `light_energy = 0.9` (reduced from 1.35)
  - Set `light_indirect_energy = 0.45`
  - Set `directional_shadow_mode = 2` (PSSM 4 Splits)
  - Set `directional_shadow_split_1 = 0.08`
  - Set `directional_shadow_split_2 = 0.22`
  - Set `directional_shadow_split_3 = 0.50`
  - Set `directional_shadow_blend_splits = true`
  - Set `directional_shadow_max_distance = 75.0`
  - Set `directional_shadow_bias = 0.02`
  - Set `directional_shadow_normal_bias = 1.6`
  - Set `shadow_blur = 0.8`

- [ ] **Step 2: Update WorldEnvironment tonemapping and ambient light in `scenes/world.tscn`**
  - Set `tonemap_mode = 3` (ACES)
  - Set `tonemap_exposure = 1.0`
  - Set `tonemap_white = 1.0`
  - Set `ambient_light_source = 3` (Sky)
  - Set `ambient_light_color = Color(0.72, 0.84, 0.96, 1.0)`
  - Set `ambient_light_sky_contribution = 0.65`
  - Set `ambient_light_energy = 0.45`
  - Set `glow_enabled = true`, `glow_intensity = 0.2`, `glow_bloom = 0.05`

- [ ] **Step 3: Commit**
  ```bash
  git add scenes/world.tscn
  git commit -m "feat(graphics): balance world lighting and configure crisp 4-split PSSM cartoon shadows"
  ```

---

### Task 2: Inverted-Hull Toon Outline Shader (`shaders/toon_outline.gdshader`)

**Files:**
- Create: `shaders/toon_outline.gdshader`

**Interfaces:**
- Consumes: Vertex normals in local space.
- Produces: `ShaderMaterial` suitable as `next_pass` for drawing crisp cartoon black/navy silhouettes.

- [ ] **Step 1: Create `shaders/toon_outline.gdshader`**
  Write an optimized spatial outline shader with vertex normal extrusion in `cull_front` render mode and unshaded output.

- [ ] **Step 2: Commit**
  ```bash
  git add shaders/toon_outline.gdshader
  git commit -m "feat(shader): create reusable inverted-hull toon outline shader"
  ```

---

### Task 3: Rebuild Fat Character from Scratch with Real Connected Bones & Active Physics (`scenes/characters/fat_character.tscn`, `scripts/characters/fat_character.gd`)

**Files:**
- Rewrite: `scenes/characters/fat_character.tscn`
- Rewrite: `scripts/characters/fat_character.gd`

**Interfaces:**
- Consumes: `CharacterVisualLoader` (`build_visuals`), `Player` (`play_anim`, `set_carrying_pose`, `start_ragdoll`, `stop_ragdoll`).
- Produces: High-quality, goofy R.E.P.O./Human Fall Flat fat character with connected parent-child joint chains, cartoon materials with outline `next_pass`, procedural spring physics wobble, and full animation set.

- [ ] **Step 1: Write `scripts/characters/fat_character.gd`**
  - Implement real bone references (`Pelvis`, `Torso`, `HeadPivot`, `Arm_L`, `Arm_R`, `Forearm_L`, `Forearm_R`, `Hand_L`, `Hand_R`, `Hip_L`, `Hip_R`, `Shin_L`, `Shin_R`, `Foot_L`, `Foot_R`).
  - Implement active secondary spring physics (`_physics_process` spring-damping on head bobble, torso squash/bounce, and arm swing).
  - Implement `set_carrying_pose(is_carrying: bool)`, `play_anim(anim_name: String)`, `start_ragdoll(velocity: Vector3)`, and `stop_ragdoll()`.

- [ ] **Step 2: Build `scenes/characters/fat_character.tscn` from scratch**
  - Construct clean articulated humanoid hierarchy under `Skeleton3D/Pelvis`.
  - Add chunky pear torso, hoodie pocket, collar, cap with visor, expressive faceplate with large cartoon eyes, eyebrows, blush, smile, and sneaker soles.
  - Assign `next_pass` toon outline to materials.
  - Create complete `AnimationPlayer` library (`idle`, `walk`, `sprint`, `crouch`, `jump`).

- [ ] **Step 3: Commit**
  ```bash
  git add scenes/characters/fat_character.tscn scripts/characters/fat_character.gd
  git commit -m "feat(character): rebuild fat character from scratch with real connected bones and active physics wobble"
  ```

---

### Task 4: Rebuild Thin Character from Scratch with Real Connected Bones & Active Physics (`scenes/characters/thin_character.tscn`, `scripts/characters/thin_character.gd`)

**Files:**
- Rewrite: `scenes/characters/thin_character.tscn`
- Rewrite: `scripts/characters/thin_character.gd`

**Interfaces:**
- Consumes: `CharacterVisualLoader` (`build_visuals`), `Player` (`play_anim`, `start_ragdoll`, `stop_ragdoll`).
- Produces: High-quality, goofy R.E.P.O./Human Fall Flat thin character with tall noodle-jointed skeleton, striped windbreaker sweater, bobblehead with round glasses, high-top Converse sneakers, active spring physics wobble, and full animation set.

- [ ] **Step 1: Write `scripts/characters/thin_character.gd`**
  - Implement bone references (`Pelvis`, `Torso`, `Neck`, `HeadPivot`, `Arm_L`, `Arm_R`, `Forearm_L`, `Forearm_R`, `Hand_L`, `Hand_R`, `Hip_L`, `Hip_R`, `Shin_L`, `Shin_R`, `Foot_L`, `Foot_R`).
  - Implement active secondary spring physics (`_physics_process` spring-damping on noodle limb swaying and head bobble).
  - Implement `play_anim(anim_name: String)`, `start_ragdoll(velocity: Vector3)`, and `stop_ragdoll()`.

- [ ] **Step 2: Build `scenes/characters/thin_character.tscn` from scratch**
  - Construct tall articulated skeleton under `Skeleton3D/Pelvis`.
  - Add striped sweater, dark slate pants, high-top yellow sneakers, round glasses with bridge, expressive eyes with pupils, and hair tuft.
  - Assign `next_pass` toon outline to materials.
  - Create complete `AnimationPlayer` library (`idle`, `walk`, `sprint`, `crouch`, `jump`).

- [ ] **Step 3: Commit**
  ```bash
  git add scenes/characters/thin_character.tscn scripts/characters/thin_character.gd
  git commit -m "feat(character): rebuild thin character from scratch with real connected bones and active physics wobble"
  ```

---

### Task 5: Apply Toon Outline to Interactive Puzzle Objects & Props

**Files:**
- Modify: `scenes/boulder.tscn`
- Modify: `scenes/dummy_npc.tscn`
- Modify: `scenes/objects/heavy_lever.tscn`
- Modify: `scenes/objects/heavy_pressure_button.tscn`
- Modify: `scenes/objects/seesaw_catapult.tscn`
- Modify: `scenes/objects/wind_tunnel_fan.tscn`
- Modify: `scenes/shower_cabin.tscn`
- Modify: `scenes/trash_bin.tscn`

**Interfaces:**
- Consumes: `shaders/toon_outline.gdshader`.
- Produces: Pop-out comic outline styling across interactive objects.

- [ ] **Step 1: Add outline material next_pass to puzzle props**
- [ ] **Step 2: Verify all UIDs match `.uid` files**
- [ ] **Step 3: Commit**
  ```bash
  git add scenes/
  git commit -m "feat(graphics): apply toon outline next_pass to interactive puzzle objects"
  ```

---

### Task 6: Final Verification & Polish

**Files:**
- Run full diagnostic UID and syntax verification.

- [ ] **Step 1: Check all 33 scene files for format and UID validity**
- [ ] **Step 2: Check git status and clean working tree**
- [ ] **Step 3: Commit final polish**
