class_name PlayerCameraComponent
extends Node

## Player Camera Component:
## - Handles Roblox-style 1st person / 3rd person smooth camera zoom (Scroll Wheel)
## - Mouse look rotation (Yaw on Player, Pitch clamped -89..89 on Head)
## - Sprint FOV transitions & nausea camera tilt
## - Dynamic crouch eye-height transition
## - Unobstructed 1st-person eye positioning (in front of character skull)
## - Supports 180° ceiling crawling camera flip on Head node for Thin

const MOUSE_SENSITIVITY_DEFAULT := 0.0025
const ZOOM_STEP := 0.5
const MIN_ZOOM := 0.0
const MAX_ZOOM := 8.0
const NORMAL_FOV := 75.0
const SPRINT_FOV := 85.0

var player: CharacterBody3D = null
var head: Node3D = null
var spring_arm: SpringArm3D = null
var camera_3d: Camera3D = null

var target_camera_zoom: float = 0.0
var current_camera_zoom: float = 0.0
var is_first_person: bool = true

func setup(p_player: CharacterBody3D, p_head: Node3D, p_spring_arm: SpringArm3D, p_camera: Camera3D) -> void:
	player = p_player
	head = p_head
	spring_arm = p_spring_arm
	camera_3d = p_camera

func handle_input(event: InputEvent, mouse_sensitivity: float, nausea_intensity: float, is_ceiling_crawling: bool = false) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := mouse_sensitivity * (1.0 - nausea_intensity * 0.60)
		var rel_x: float = motion.relative.x
		var rel_y: float = motion.relative.y

		# When ceiling crawling with 180° inverted camera, invert mouse look deltas
		if is_ceiling_crawling:
			rel_x = -rel_x
			rel_y = -rel_y

		player.rotate_y(-rel_x * sens)
		if head:
			head.rotate_x(-rel_y * sens)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_camera_zoom = clampf(target_camera_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_camera_zoom = clampf(target_camera_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func update_camera(delta: float, is_sprinting: bool, is_ceiling_crawling: bool = false) -> void:
	current_camera_zoom = lerpf(current_camera_zoom, target_camera_zoom, delta * 14.0)
	is_first_person = (current_camera_zoom < 0.25)

	if spring_arm:
		spring_arm.spring_length = current_camera_zoom

	if head and player:
		var target_head_y: float
		if is_ceiling_crawling:
			target_head_y = 0.6
		elif player.is_crouching or player.synced_state_name.to_lower() == "crouch":
			target_head_y = player.crouch_head_y
		else:
			target_head_y = player.stand_head_y

		head.position.y = lerpf(head.position.y, target_head_y, delta * 12.0)
		var target_z_deg: float = 180.0 if is_ceiling_crawling else 0.0
		head.rotation_degrees.z = lerpf(head.rotation_degrees.z, target_z_deg, delta * 12.0)

	if camera_3d:
		# In First Person: place camera slightly forward to avoid clipping into own head/face
		var target_cam_z: float = -0.22 if is_first_person else 0.0
		camera_3d.position.z = lerpf(camera_3d.position.z, target_cam_z, delta * 12.0)

		var target_fov := SPRINT_FOV if is_sprinting else NORMAL_FOV
		camera_3d.fov = lerpf(camera_3d.fov, target_fov, delta * 8.0)
		camera_3d.rotation_degrees.z = lerpf(camera_3d.rotation_degrees.z, 0.0, delta * 8.0)
