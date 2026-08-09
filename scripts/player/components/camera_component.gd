class_name PlayerCameraComponent
extends Node

## Player Camera Component:
## - Handles Roblox-style 1st person / 3rd person smooth camera zoom (Scroll Wheel)
## - Mouse look rotation (Yaw on Player, Pitch clamped -89..89 on Head)
## - Sprint FOV transitions & nausea camera tilt
## - Preserves camera shake/tilt effects for Fat character heavy landing impacts

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

func handle_input(event: InputEvent, mouse_sensitivity: float, nausea_intensity: float, _is_ceiling_crawling: bool = false) -> void:
	if not player or not player.is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := mouse_sensitivity * (1.0 - nausea_intensity * 0.60)
		player.rotate_y(-motion.relative.x * sens)
		if head:
			head.rotate_x(-motion.relative.y * sens)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_camera_zoom = clampf(target_camera_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_camera_zoom = clampf(target_camera_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func update_camera(delta: float, is_sprinting: bool, is_ceiling_crawling: bool = false) -> void:
	current_camera_zoom = lerpf(current_camera_zoom, target_camera_zoom, delta * 12.0)
	is_first_person = (current_camera_zoom < 0.25)

	if spring_arm:
		spring_arm.spring_length = current_camera_zoom

	if head:
		var target_head_y: float = 0.6 if is_ceiling_crawling else (player.stand_head_y if player else 1.8)
		head.position.y = lerpf(head.position.y, target_head_y, delta * 10.0)

	if camera_3d:
		var target_fov := (SPRINT_FOV if is_sprinting else NORMAL_FOV) + (6.0 if is_ceiling_crawling else 0.0)
		camera_3d.fov = lerpf(camera_3d.fov, target_fov, delta * 8.0)
