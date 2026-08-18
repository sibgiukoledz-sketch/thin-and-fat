# R.E.P.O.-Style Characters, Balanced Lighting & Toon Outline Design Spec

## 1. Overview & Goals

This specification defines the complete overhaul of:
1. **Lighting & Shadows**: Eliminate severe overexposure/whiteout, re-balance sunlight and sky ambient energy, and configure crisp, artifact-free 4-split PSSM directional shadows.
2. **Character Models from Scratch (`FatCharacter` & `ThinCharacter`)**: Rebuild both character scenes from scratch using the goofy, expressive, physics-articulated semi-robot/humanoid aesthetic inspired by **R.E.P.O.** (Semiwork), **Human Fall Flat**, and **Gang Beasts**.
3. **Toon Outline Shader**: Implement a lightweight, crisp Inverted-Hull cartoon outline shader (`res://shaders/toon_outline.gdshader`) applied via `next_pass` on characters and key interactive props.

---

## 2. Lighting & Environment Specification (`scenes/world.tscn`)

### 2.1 Sun & Shadow Parameters (`DirectionalLight3D`)
- **Light Color**: Warm natural sunlight `Color(1.0, 0.98, 0.92, 1.0)`
- **Light Energy**: `0.9` (down from overexposed 1.35)
- **Light Indirect Energy**: `0.45` (prevents washed-out shadows)
- **Shadow Quality & Splits**:
  - `shadow_enabled = true`
  - `directional_shadow_mode = 2` (PSSM 4 Splits)
  - `directional_shadow_split_1 = 0.08`
  - `directional_shadow_split_2 = 0.22`
  - `directional_shadow_split_3 = 0.50`
  - `directional_shadow_blend_splits = true`
  - `directional_shadow_max_distance = 75.0` (delivers high-density shadow resolution in player zone)
  - `directional_shadow_bias = 0.02`
  - `directional_shadow_normal_bias = 1.6`
  - `shadow_blur = 0.8` (sharp, defined cartoon shadow edges)

### 2.2 Environment & Tonemapping (`WorldEnvironment`)
- **Tonemap Mode**: `3` (ACES Filmic)
- **Exposure**: `1.0` (eliminates clipping of light surfaces)
- **Whitepoint**: `1.0`
- **Ambient Light**:
  - `ambient_light_source = 3` (Sky)
  - `ambient_light_color = Color(0.72, 0.84, 0.96, 1.0)`
  - `ambient_light_sky_contribution = 0.65`
  - `ambient_light_energy = 0.45` (rich dark contrast in shadows without pure black crush)
- **Glow / Bloom**:
  - `glow_enabled = true`
  - `glow_intensity = 0.2`
  - `glow_bloom = 0.05` (subtle emissive sheen without blinding glare)

---

## 3. Character Design from Scratch (R.E.P.O. / Semibot Style)

### 3.1 Fat Character (`scenes/characters/fat_character.tscn`)
- **Aesthetic**: Chunky, squishy, pear-capsule torso with articulated ball-and-socket joints, short sturdy legs, funny cartoon eyes, and backward cap.
- **Node & Joint Hierarchy**:
  ```
  FatCharacter (Node3D, scripts/characters/fat_character.gd)
  └── Skeleton3D
      ├── TorsoPear (CapsuleMesh / SphereMesh pear union)
      │   ├── KangarooPocket (BoxMesh)
      │   └── HoodieCollar (TorusMesh)
      ├── HeadPivot (Node3D)
      │   └── HeadMesh (SphereMesh)
      │       ├── FacePlate / Eyes (Sclera + Pupil + Highlight)
      │       ├── Eyebrows (BoxMesh)
      │       └── Cap (SphereMesh + Visor)
      ├── Arm_L (Node3D - Joint Socket)
      │   └── UpperArm -> Forearm -> ChubbyHand (Node3D + Meshes)
      ├── Arm_R (Node3D - Joint Socket)
      │   └── UpperArm -> Forearm -> ChubbyHand (Node3D + Meshes)
      ├── Leg_L (Node3D - Hip Socket)
      │   └── Thigh -> Shin -> SneakerShoe (Node3D + Meshes)
      └── Leg_R (Node3D - Hip Socket)
          └── Thigh -> Shin -> SneakerShoe (Node3D + Meshes)
  └── AnimationPlayer (animations: idle, walk, sprint, crouch, jump)
  ```
- **Animation System**: Bouncy squash-and-stretch walking, comically heavy run, bouncy jump landing, carrying boulder pose (`set_carrying_pose`).

### 3.2 Thin Character (`scenes/characters/thin_character.tscn`)
- **Aesthetic**: Tall, noodle-limbed, flexible beanpole with articulated cylindrical segments, bobblehead with round glasses, and high-top sneakers.
- **Node & Joint Hierarchy**:
  ```
  ThinCharacter (Node3D, scripts/characters/thin_character.gd)
  └── Skeleton3D
      ├── TorsoNoodle (CylinderMesh / CapsuleMesh)
      │   └── SweaterStripes (MeshInstance3D)
      ├── NeckJoint (CylinderMesh)
      │   └── HeadPivot (Node3D)
      │       └── HeadMesh (SphereMesh)
      │           ├── Glasses (TorusMesh + Bridge)
      │           ├── Eyes (Sclera + Pupil + Highlight)
      │           └── HairTuft (SphereMesh)
      ├── Arm_L (Node3D - Shoulder Socket)
      │   └── UpperArm -> Elbow -> Forearm -> Hand
      ├── Arm_R (Node3D - Shoulder Socket)
      │   └── UpperArm -> Elbow -> Forearm -> Hand
      ├── Leg_L (Node3D - Hip Socket)
      │   └── Thigh -> Knee -> Shin -> ConverseSneaker
      └── Leg_R (Node3D - Hip Socket)
          └── Thigh -> Knee -> Shin -> ConverseSneaker
  └── AnimationPlayer (animations: idle, walk, sprint, crouch, jump)
  ```

---

## 4. Inverted-Hull Toon Outline Shader (`res://shaders/toon_outline.gdshader`)

- **Technique**: Vertex normal extrusion in `cull_front` render mode with unshaded fragment pass.
- **Parameters**:
  - `outline_width`: `0.03` (subtle crisp edge)
  - `outline_color`: `Color(0.08, 0.08, 0.12, 1.0)` (deep comic ink)
- **Usage**: Applied as `next_pass` on character skin/clothes materials and key interactive puzzle objects.

---

## 5. Verification & Safety

- Ensure all `ext_resource` UIDs and paths match `.uid` files exactly.
- Keep all existing method hooks (`play_anim`, `set_carrying_pose`, `start_ragdoll`, `stop_ragdoll`).
- Verify multiplayer authority and camera pitch/yaw remain unaffected.
