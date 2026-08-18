class_name PlayerCameraComponent
extends Node

## Player Camera Component:
## - Full 1st-person & 3rd-person support (Scroll Wheel zoom & Middle-Click toggle)
## - Dynamic animated socket tracking (Follows head in 3D: standing, crouch, & trampoline pose)
## - Wall clipping protection: SpringArm3D with layer 1+4 mask & safety margin
## - Head & body culling in 1st-person (only hands & arms visible!)
## - Supports 180° ceiling crawling camera flip for Thin

const MOUSE_SENSITIVITY_DEFAULT := 0.0025
const ZOOM_STEP := 0.6
const DEFAULT_ZOOM := 3.2
const MIN_ZOOM := 0.0
const MAX_ZOOM := 6.5
const NORMAL_FOV := 75.0
const SPRINT_FOV := 85.0

var player: CharacterBody3D = null
var head: Node3D = null
var spring_arm: SpringArm3D = null
var camera_3d: Camera3D = null

var target_camera_zoom: float = DEFAULT_ZOOM
var current_camera_zoom: float = DEFAULT_ZOOM
var is_first_person: bool = false
var _last_cull_state: bool = false

func setup(p_player: CharacterBody3D, p_head: Node3D, p_spring_arm: SpringArm3D, p_camera: Camera3D) -> void:
	player = p_player
	head = p_head
	spring_arm = p_spring_arm
	camera_3d = p_camera

	if spring_arm:
		spring_arm.add_excluded_object(player.get_rid())
		spring_arm.spring_length = current_camera_zoom
		spring_arm.margin = 0.3
		spring_arm.collision_mask = 5 # Collide with world static (1) and rigid bodies/props (4)

	if camera_3d:
		camera_3d.position = Vector3.ZERO
		camera_3d.near = 0.05

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
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			# Middle Mouse Button toggle between 1st Person and 3rd Person
			if target_camera_zoom < 0.5:
				target_camera_zoom = DEFAULT_ZOOM
			else:
				target_camera_zoom = 0.0

func update_camera(delta: float, is_sprinting: bool, is_ceiling_crawling: bool = false) -> void:
	current_camera_zoom = lerpf(current_camera_zoom, target_camera_zoom, delta * 12.0)
	is_first_person = (current_camera_zoom < 0.35)

	if spring_arm:
		spring_arm.spring_length = current_camera_zoom

	# Dynamic 3D Head Tracking: Follow the animated head joint in X, Y, and Z!
	# This ensures the camera stays at the head even when Fat turns into a belly trampoline on his back!
	if head and player:
		var target_head_pos := Vector3(0.0, player.stand_head_y, 0.0)
		if is_ceiling_crawling:
			target_head_pos = Vector3(0.0, 0.6, 0.0)
		elif player.character_model and player.character_model.has_method("get_head_socket"):
			var socket: Node3D = player.character_model.call("get_head_socket")
			if socket:
				# Transform world position of head socket into player's local space
				var local_socket: Vector3 = player.global_transform.affine_inverse() * socket.global_position
				target_head_pos = local_socket
		elif player.is_crouching or player.synced_state_name.to_lower() == "crouch":
			target_head_pos = Vector3(0.0, player.crouch_head_y, 0.0)

		head.position = head.position.lerp(target_head_pos, delta * 16.0)
		var target_z_deg: float = 180.0 if is_ceiling_crawling else 0.0
		head.rotation_degrees.z = lerpf(head.rotation_degrees.z, target_z_deg, delta * 12.0)

	# In 1st Person: Cull local player's head/body so only arms/hands are visible
	if player and player.is_multiplayer_authority():
		if _last_cull_state != is_first_person:
			_last_cull_state = is_first_person
			if player.character_model and player.character_model.has_method("set_first_person_view"):
				player.character_model.call("set_first_person_view", is_first_person)

	if camera_3d:
		var target_fov := SPRINT_FOV if is_sprinting else NORMAL_FOV
		camera_3d.fov = lerpf(camera_3d.fov, target_fov, delta * 8.0)
		camera_3d.rotation_degrees.z = lerpf(camera_3d.rotation_degrees.z, 0.0, delta * 8.0)
