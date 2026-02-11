## repair_station.gd - Repair station world object (anvil)
## Allows player to repair equipment durability and restore quality
class_name RepairStation
extends StaticBody3D

## Visual representation
var mesh_root: Node3D
var anvil_base: MeshInstance3D
var anvil_top: MeshInstance3D
var interaction_area: Area3D

## UI instances
var repair_ui: Control = null
var crafting_ui: Control = null
var choice_ui: Control = null
var repair_ui_script = preload("res://scripts/ui/repair_station_ui.gd")
var crafting_ui_script = preload("res://scripts/ui/crafting_ui.gd")

## PS1-style material
var anvil_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("repair_stations")

	# Setup collision for player interaction detection
	collision_layer = 1  # World layer for physics
	collision_mask = 0   # Don't collide with anything

	_create_anvil_mesh()
	_create_interaction_area()

func _create_anvil_mesh() -> void:
	## Create the anvil programmatically
	## Simple low-poly representation: box base + smaller box top

	# Material for the anvil (dark iron look)
	anvil_material = StandardMaterial3D.new()
	anvil_material.albedo_color = Color(0.25, 0.25, 0.28)
	anvil_material.metallic = 0.8
	anvil_material.roughness = 0.6

	# Root for the mesh
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# Base of the anvil (larger box)
	anvil_base = MeshInstance3D.new()
	anvil_base.name = "AnvilBase"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.8, 0.5, 0.5)
	anvil_base.mesh = base_mesh
	anvil_base.material_override = anvil_material
	anvil_base.position = Vector3(0, 0.25, 0)
	mesh_root.add_child(anvil_base)

	# Top of the anvil (work surface - slightly narrower)
	anvil_top = MeshInstance3D.new()
	anvil_top.name = "AnvilTop"
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(1.0, 0.15, 0.4)
	anvil_top.mesh = top_mesh
	anvil_top.material_override = anvil_material
	anvil_top.position = Vector3(0, 0.575, 0)
	mesh_root.add_child(anvil_top)

	# Horn of the anvil (pointed end)
	var horn := MeshInstance3D.new()
	horn.name = "AnvilHorn"
	var horn_mesh := BoxMesh.new()
	horn_mesh.size = Vector3(0.3, 0.12, 0.2)
	horn.mesh = horn_mesh
	horn.material_override = anvil_material
	horn.position = Vector3(0.55, 0.56, 0)
	mesh_root.add_child(horn)

func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.0, 1.0)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0.5, 0)
	interaction_area.add_child(area_shape)

## Called by player interaction system
func interact(_interactor: Node) -> void:
	_open_choice_ui()

## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Use Anvil"

## Show choice between Repair and Craft
func _open_choice_ui() -> void:
	if choice_ui and is_instance_valid(choice_ui):
		choice_ui.queue_free()

	# Create choice dialog
	var canvas := CanvasLayer.new()
	canvas.name = "AnvilChoiceCanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)

	choice_ui = _create_choice_dialog(canvas)
	canvas.add_child(choice_ui)

	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _create_choice_dialog(canvas: CanvasLayer) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	root.add_child(overlay)

	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(200, 150)
	panel.position = Vector2(-100, -75)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.12)
	panel_style.border_color = Color(0.4, 0.35, 0.25)
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_top = 15
	vbox.offset_right = -15
	vbox.offset_bottom = -15
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "ANVIL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Repair button
	var repair_btn := Button.new()
	repair_btn.text = "Repair Equipment"
	repair_btn.pressed.connect(_on_choice_repair.bind(canvas))
	_style_choice_button(repair_btn)
	vbox.add_child(repair_btn)

	# Craft button
	var craft_btn := Button.new()
	craft_btn.text = "Craft Items"
	craft_btn.pressed.connect(_on_choice_craft.bind(canvas))
	_style_choice_button(craft_btn)
	vbox.add_child(craft_btn)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_choice_cancel.bind(canvas))
	_style_choice_button(cancel_btn)
	vbox.add_child(cancel_btn)

	return root


func _style_choice_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.18)
	normal.border_color = Color(0.3, 0.25, 0.2)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.18, 0.15)
	hover.border_color = Color(0.5, 0.4, 0.3)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))


func _on_choice_repair(canvas: CanvasLayer) -> void:
	canvas.queue_free()
	choice_ui = null
	_open_repair_ui()


func _on_choice_craft(canvas: CanvasLayer) -> void:
	canvas.queue_free()
	choice_ui = null
	_open_crafting_ui()


func _on_choice_cancel(canvas: CanvasLayer) -> void:
	canvas.queue_free()
	choice_ui = null
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _open_repair_ui() -> void:
	## Create and show the repair UI
	if repair_ui and is_instance_valid(repair_ui):
		repair_ui.queue_free()

	# Create the UI
	repair_ui = Control.new()
	repair_ui.set_script(repair_ui_script)
	repair_ui.name = "RepairStationUI"

	# Add to scene tree (as child of canvas layer or root)
	var canvas := CanvasLayer.new()
	canvas.name = "RepairUICanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(repair_ui)

	# Connect close signal
	if repair_ui.has_signal("ui_closed"):
		repair_ui.ui_closed.connect(_on_repair_ui_closed.bind(canvas))

	# Open the UI (already in menu mode from choice dialog)
	if repair_ui.has_method("open"):
		repair_ui.open()


func _open_crafting_ui() -> void:
	## Create and show the crafting UI
	if crafting_ui and is_instance_valid(crafting_ui):
		crafting_ui.queue_free()

	# Create the UI
	crafting_ui = Control.new()
	crafting_ui.set_script(crafting_ui_script)
	crafting_ui.name = "CraftingUI"

	# Set station type to blacksmith (only show Weapon, Armor, Tool, Material - no potions)
	crafting_ui.set("station_type", "blacksmith")

	# Add to scene tree
	var canvas := CanvasLayer.new()
	canvas.name = "CraftingUICanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(crafting_ui)

	# Connect close signal
	if crafting_ui.has_signal("ui_closed"):
		crafting_ui.ui_closed.connect(_on_crafting_ui_closed.bind(canvas))

	# Open the UI
	if crafting_ui.has_method("open"):
		crafting_ui.open()


func _on_repair_ui_closed(canvas: CanvasLayer) -> void:
	## Handle repair UI close
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	repair_ui = null


func _on_crafting_ui_closed(canvas: CanvasLayer) -> void:
	## Handle crafting UI close
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	crafting_ui = null

## Static factory method for spawning repair stations
static func spawn_station(parent: Node, pos: Vector3) -> RepairStation:
	var instance := RepairStation.new()
	instance.position = pos

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.7, 0.6)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.35, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
