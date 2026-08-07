class_name InflationPumpStation
extends StaticBody3D

## Interactive Inflation Pump Station — a compressor unit with a visible hose.
## Fat stands near the station and presses [E] to start inflating a nearby Thin player.

@export var interaction_radius: float = 4.0

var _compressor_mesh: MeshInstance3D
var _hose_base_mesh: MeshInstance3D
var _platform_mesh: MeshInstance3D
var _prompt_label: Label3D
var _title_label: Label3D
var _interaction_area: Area3D
var _compressor_material: StandardMaterial3D
var _hose_material: StandardMaterial3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_build_compressor_visuals()
	_build_interaction_area()
	_build_labels()

func _build_compressor_visuals() -> void:
	# --- Platform base (dark metal plate) ---
	_platform_mesh = MeshInstance3D.new()
	_platform_mesh.name = "PlatformMesh"
	var plat_box := BoxMesh.new()
	plat_box.size = Vector3(3.0, 0.12, 3.0)
	var plat_mat := StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.25, 0.28, 0.32, 1.0)
	plat_mat.metallic = 0.6
	plat_mat.roughness = 0.35
	plat_box.material = plat_mat
	_platform_mesh.mesh = plat_box
	_platform_mesh.position = Vector3(0, 0.06, 0)
	add_child(_platform_mesh)

	# Platform collision
	var plat_col := CollisionShape3D.new()
	var plat_shape := BoxShape3D.new()
	plat_shape.size = Vector3(3.0, 0.12, 3.0)
	plat_col.shape = plat_shape
	plat_col.position = Vector3(0, 0.06, 0)
	add_child(plat_col)

	# --- Compressor body (cylindrical tank) ---
	var tank := MeshInstance3D.new()
	tank.name = "CompressorTank"
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.45
	cyl_mesh.bottom_radius = 0.5
	cyl_mesh.height = 1.2
	_compressor_material = StandardMaterial3D.new()
	_compressor_material.albedo_color = Color(0.85, 0.25, 0.15, 1.0) # Red compressor tank
	_compressor_material.metallic = 0.7
	_compressor_material.roughness = 0.25
	cyl_mesh.material = _compressor_material
	tank.mesh = cyl_mesh
	tank.position = Vector3(-0.8, 0.72, 0)
	add_child(tank)

	# --- Pressure gauge (small sphere on top of tank) ---
	var gauge := MeshInstance3D.new()
	gauge.name = "PressureGauge"
	var gauge_mesh := SphereMesh.new()
	gauge_mesh.radius = 0.12
	gauge_mesh.height = 0.24
	var gauge_mat := StandardMaterial3D.new()
	gauge_mat.albedo_color = Color(0.9, 0.9, 0.85, 1.0)
	gauge_mat.metallic = 0.8
	gauge_mesh.material = gauge_mat
	gauge.mesh = gauge_mesh
	gauge.position = Vector3(-0.8, 1.45, 0.25)
	add_child(gauge)

	# --- Hose nozzle (cylinder sticking out from compressor toward mannequin area) ---
	_hose_base_mesh = MeshInstance3D.new()
	_hose_base_mesh.name = "HoseNozzle"
	var hose_cyl := CylinderMesh.new()
	hose_cyl.top_radius = 0.06
	hose_cyl.bottom_radius = 0.08
	hose_cyl.height = 1.8
	_hose_material = StandardMaterial3D.new()
	_hose_material.albedo_color = Color(0.15, 0.75, 0.9, 1.0) # Cyan rubber hose
	_hose_material.roughness = 0.65
	hose_cyl.material = _hose_material
	_hose_base_mesh.mesh = hose_cyl
	_hose_base_mesh.position = Vector3(0.2, 0.85, 0)
	_hose_base_mesh.rotation_degrees = Vector3(0, 0, 75) # Angled from tank toward target
	add_child(_hose_base_mesh)

	# --- Hose coil on the ground (torus-like ring made from a torus mesh) ---
	var coil := MeshInstance3D.new()
	coil.name = "HoseCoil"
	var coil_mesh := TorusMesh.new()
	coil_mesh.inner_radius = 0.25
	coil_mesh.outer_radius = 0.45
	var coil_mat := StandardMaterial3D.new()
	coil_mat.albedo_color = Color(0.15, 0.75, 0.9, 1.0)
	coil_mat.roughness = 0.65
	coil_mesh.material = coil_mat
	coil.mesh = coil_mesh
	coil.position = Vector3(0.6, 0.2, 0)
	coil.rotation_degrees = Vector3(90, 0, 0)
	add_child(coil)

	# --- Valve handle on the tank ---
	var valve := MeshInstance3D.new()
	valve.name = "ValveHandle"
	var valve_mesh := TorusMesh.new()
	valve_mesh.inner_radius = 0.06
	valve_mesh.outer_radius = 0.15
	var valve_mat := StandardMaterial3D.new()
	valve_mat.albedo_color = Color(0.3, 0.3, 0.35, 1.0)
	valve_mat.metallic = 0.85
	valve_mesh.material = valve_mat
	valve.mesh = valve_mesh
	valve.position = Vector3(-0.8, 1.4, -0.3)
	valve.rotation_degrees = Vector3(0, 0, 90)
	add_child(valve)

func _build_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 2 # Players layer

	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = interaction_radius
	area_col.shape = area_shape
	area_col.position = Vector3(0, 1.0, 0)
	_interaction_area.add_child(area_col)
	add_child(_interaction_area)

func _build_labels() -> void:
	# Title label (always visible, above the station)
	_title_label = Label3D.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "🎈 СТАНЦИЯ НАКАЧКИ"
	_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title_label.position = Vector3(0, 2.6, 0)
	_title_label.font_size = 32
	_title_label.outline_size = 10
	_title_label.modulate = Color(0.2, 0.9, 1.0, 1.0)
	add_child(_title_label)

	# Prompt label (shows only when Fat is nearby)
	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = "💨 [E] ПОДКЛЮЧИТЬ ШЛАНГ И НАКАЧАТЬ!"
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.position = Vector3(0, 2.1, 0)
	_prompt_label.font_size = 22
	_prompt_label.outline_size = 8
	_prompt_label.modulate = Color(1.0, 0.95, 0.4, 1.0)
	_prompt_label.hide()
	add_child(_prompt_label)

func _process(_delta: float) -> void:
	if not _interaction_area or not _prompt_label:
		return

	# Show prompt when Fat player is nearby
	var show_prompt := false
	var bodies := _interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			var p: Player = body as Player
			if p.selected_character_id.to_lower() == "fat" and p.is_multiplayer_authority():
				show_prompt = true
				break

	_prompt_label.visible = show_prompt
