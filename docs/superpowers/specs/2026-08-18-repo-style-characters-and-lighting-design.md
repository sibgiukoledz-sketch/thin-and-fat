# R.E.P.O. & Human Fall Flat Style Characters, Balanced Lighting & Toon Outline Design Spec

## 1. Overview & Goals

This specification defines the complete overhaul of:
1. **Lighting & Shadows**: Eliminate severe overexposure/whiteout, re-balance sunlight and sky ambient energy, and configure crisp, artifact-free 4-split PSSM directional shadows.
2. **Character Models from Scratch with Real Connected Bones (`FatCharacter` & `ThinCharacter`)**:
   - Rebuilt completely from scratch inspired by **Human: Fall Flat** (active ragdoll, physics joint inertia, spring-damped wobble) and **R.E.P.O.** (goofy semibot/humanoid proportions, expressive puppet-like head, articulated limbs).
   - Full anatomical joint hierarchy: Pelvis $\rightarrow$ Spine/Torso $\rightarrow$ Neck $\rightarrow$ Bobblehead, Shoulders $\rightarrow$ Arms $\rightarrow$ Forearms $\rightarrow$ Hands, Hips $\rightarrow$ Thighs $\rightarrow$ Shins $\rightarrow$ Feet.
   - Procedural physics secondary motion (spring-damping head bobble, belly bounce, arm swing based on velocity/acceleration) blended with clean `AnimationPlayer` cycles.
3. **Toon Outline Shader**: Implement a lightweight, crisp Inverted-Hull cartoon outline shader (`res://shaders/toon_outline.gdshader`) applied via `next_pass` on characters and key interactive props.

---

## 2. Human Fall Flat & R.E.P.O. Character Bone Hierarchy

### 2.1 Anatomical Joint Structure
Both characters are built with real connected parent-child joint chains inside `Skeleton3D`:
```
CharacterRoot (Node3D, scripts/characters/*_character.gd)
└── Skeleton3D
    └── Pelvis (Root Bone / Hips)
        ├── Torso (Spine / Chest Mesh)
        │   ├── Collar / Pocket / Details
        │   ├── NeckJoint (CylinderMesh)
        │   │   └── HeadPivot (Node3D with Spring Inertia)
        │   │       └── HeadMesh (FacePlate, Eyes, Glasses/Cap, Hair)
        │   ├── Shoulder_L (Node3D Socket)
        │   │   └── Arm_L (Upper Arm)
        │   │       └── Forearm_L (Elbow)
        │   │           └── Hand_L (Wrist / Palm)
        │   └── Shoulder_R (Node3D Socket)
        │       └── Arm_R (Upper Arm)
        │           └── Forearm_R (Elbow)
        │               └── Hand_R (Wrist / Palm)
        ├── Hip_L (Node3D Socket)
        │   └── Thigh_L
        │       └── Shin_L (Knee)
        │           └── Foot_L (Sneaker / Boot)
        └── Hip_R (Node3D Socket)
            └── Thigh_R
                └── Shin_R (Knee)
                    └── Foot_R (Sneaker / Boot)
    └── AnimationPlayer (idle, walk, sprint, crouch, jump)
```

### 2.2 Dynamic Secondary Physics ("Human Fall Flat Active Wobble")
In `scripts/characters/fat_character.gd` and `scripts/characters/thin_character.gd`:
- **Head Bobble Spring**: Head tilts and bobs in response to movement acceleration, turns, and vertical jumping/landing with spring-damping.
- **Belly Jiggle (Fat)**: Pear-shaped torso squashes on landing and wobbles when running.
- **Arm Pendulum Inertia**: Arms naturally react to momentum, holding forward when carrying (`set_carrying_pose`).
- **Floppy Ragdoll**: When `start_ragdoll(velocity)` is triggered, joints go floppy and tumble with bounce.

---

## 3. Lighting & Environment Specification (`scenes/world.tscn`)

### 3.1 Sun & Shadow Parameters (`DirectionalLight3D`)
- **Light Color**: Warm natural sunlight `Color(1.0, 0.98, 0.92, 1.0)`
- **Light Energy**: `0.9` (down from overexposed 1.35)
- **Light Indirect Energy**: `0.45`
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

### 3.2 Environment & Tonemapping (`WorldEnvironment`)
- **Tonemap Mode**: `3` (ACES Filmic)
- **Exposure**: `1.0`
- **Whitepoint**: `1.0`
- **Ambient Light**:
  - `ambient_light_source = 3` (Sky)
  - `ambient_light_color = Color(0.72, 0.84, 0.96, 1.0)`
  - `ambient_light_sky_contribution = 0.65`
  - `ambient_light_energy = 0.45`
- **Glow / Bloom**:
  - `glow_enabled = true`
  - `glow_intensity = 0.2`
  - `glow_bloom = 0.05`

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
