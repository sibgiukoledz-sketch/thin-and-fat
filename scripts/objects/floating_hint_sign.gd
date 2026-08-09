@tool
class_name FloatingHintSign
extends Node3D

## AAA 3D Floating / Wall Hint Sign Controller.
## All visual geometry, materials, shaders, and text styles are configured directly in floating_hint_sign.tscn.
## This script handles runtime mechanics:
## - Billboard camera tracking vs static rotation.
## - Sine-wave hovering animation.
## - Distance-based alpha fade.

enum ViewMode {
	BILLBOARD_CAMERA, # Dynamically faces player camera
	STATIC_WORLD # Fixed orientation for walls, pillars, signs
}

@export_group("Content Settings")
@export_multiline var hint_text: String = "💡 ПОДСКАЗКА:\n[E] - ВЗАИМОДЕЙСТВИЕ":
	set(val):
		hint_text = val
		_update_content()

@export_range(12, 96, 1) var font_size: int = 36:
	set(val):
		font_size = val
		_update_content()

@export var text_color: Color = Color(1.0, 0.96, 0.88):
	set(val):
		text_color = val
		_update_content()

@export var hint_icon: Texture2D = null:
	set(val):
		hint_icon = val
		_update_content()

@export var icon_size: Vector2 = Vector2(0.65, 0.65):
	set(val):
		icon_size = val
		_update_content()

@export var show_icon: bool = true:
	set(val):
		show_icon = val
		_update_content()

@export_group("Display & Orientation Mechanics")
@export var mode: ViewMode = ViewMode.BILLBOARD_CAMERA:
	set(val):
		mode = val
		if Engine.is_editor_hint():
			rotation = Vector3.ZERO

@export var enable_floating_bob: bool = true
@export var bob_amplitude: float = 0.10
@export var bob_frequency: float = 1.8

@export_group("Distance Fade Mechanics")
@export var distance_fade: bool = true
@export var fade_start_distance: float = 14.0
@export var fade_end_distance: float = 20.0

@export_group("Frame Toggle")
@export var show_border: bool = false:
	set(val):
		show_border = val
		_update_border_visibility()

@onready var label_3d: Label3D = $Label3D
@onready var icon_sprite_3d: Sprite3D = $IconSprite3D
@onready var bg_mesh: MeshInstance3D = $BGMesh
@onready var frame_mesh: MeshInstance3D = $FrameMesh

var _initial_pos_y: float = 0.0
var _anim_time: float = 0.0
var _default_icon_tex: Texture2D = null

func _ready() -> void:
	_initial_pos_y = position.y
	_default_icon_tex = _generate_default_info_icon()
	_update_content()
	_update_border_visibility()

func _update_content() -> void:
	if label_3d:
		label_3d.text = hint_text
		label_3d.font_size = font_size
		label_3d.modulate = text_color

	if icon_sprite_3d:
		if show_icon:
			icon_sprite_3d.texture = hint_icon if hint_icon else _default_icon_tex
			icon_sprite_3d.scale = Vector3(icon_size.x, icon_size.y, 1.0)
			icon_sprite_3d.show()
			if label_3d:
				label_3d.position.x = 0.35
		else:
			icon_sprite_3d.hide()
			if label_3d:
				label_3d.position.x = 0.0

func _update_border_visibility() -> void:
	if frame_mesh:
		frame_mesh.visible = show_border

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_anim_time += delta

	# 1. Hovering Bobbing Motion
	if enable_floating_bob:
		position.y = _initial_pos_y + sin(_anim_time * bob_frequency) * bob_amplitude

	# 2. Billboard Camera Rotation Mechanics
	var cam := get_viewport().get_camera_3d()
	if cam:
		if mode == ViewMode.BILLBOARD_CAMERA:
			look_at(cam.global_position, Vector3.UP)
			rotate_y(PI) # Face front to camera

		# 3. Distance Alpha Fading
		if distance_fade:
			var dist := global_position.distance_to(cam.global_position)
			var alpha := 1.0
			if dist > fade_start_distance:
				alpha = clampf(1.0 - (dist - fade_start_distance) / maxf(fade_end_distance - fade_start_distance, 0.001), 0.0, 1.0)

			_modulate_alpha(alpha)

func _modulate_alpha(alpha: float) -> void:
	if label_3d:
		label_3d.modulate.a = text_color.a * alpha
	if icon_sprite_3d:
		icon_sprite_3d.modulate.a = alpha
	if bg_mesh and bg_mesh.material_override:
		bg_mesh.material_override.albedo_color.a = 0.82 * alpha
	if frame_mesh and frame_mesh.material_override:
		frame_mesh.material_override.albedo_color.a = 0.18 * alpha

func _generate_default_info_icon() -> Texture2D:
	var w := 128
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w * 0.5, h * 0.5)
	var radius := w * 0.45

	for y in range(h):
		for x in range(w):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			if dist <= radius:
				var edge := smoothstep(radius, radius - 2.0, dist)
				var col := Color(0.2, 0.85, 1.0, edge * 0.95)
				var rel_x := absf(x - center.x)
				var rel_y := y - center.y
				if (rel_x < 7.0 and rel_y > -30.0 and rel_y < -16.0) or (rel_x < 7.0 and rel_y > -6.0 and rel_y < 30.0):
					col = Color(1.0, 1.0, 1.0, edge)
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)
