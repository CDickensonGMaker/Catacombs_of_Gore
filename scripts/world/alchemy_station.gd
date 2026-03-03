## alchemy_station.gd - Alchemy station world object (table with bottles)
## Allows player to brew potions and consumables
class_name AlchemyStation
extends StaticBody3D

## Visual representation
var mesh_root: Node3D
var table_mesh: MeshInstance3D
var interaction_area: Area3D

## UI instances
var crafting_ui: Control = null
var crafting_ui_script = preload("res://scripts/ui/crafting_ui.gd")

## PS1-style materials
var wood_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var liquid_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("alchemy_stations")

	# Setup collision for player interaction detection
	collision_layer = 1  # World layer for physics
	collision_mask = 0   # Don't collide with anything

	_create_alchemy_mesh()
	_create_interaction_area()


func _create_alchemy_mesh() -> void:
	## Create the alchemy station programmatically
	## Table with bottles and vials

	# Wood material for table
	wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.4, 0.28, 0.18)
	wood_material.metallic = 0.0
	wood_material.roughness = 0.8

	# Glass material for bottles (translucent)
	glass_material = StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.7, 0.75, 0.8, 0.6)
	glass_material.metallic = 0.1
	glass_material.roughness = 0.2
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Liquid materials for different potion colors
	liquid_material = StandardMaterial3D.new()
	liquid_material.albedo_color = Color(0.8, 0.2, 0.2, 0.8)  # Red potion
	liquid_material.emission_enabled = true
	liquid_material.emission = Color(0.5, 0.1, 0.1)
	liquid_material.emission_energy_multiplier = 0.5
	liquid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Root for the mesh
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# Table top
	table_mesh = MeshInstance3D.new()
	table_mesh.name = "TableTop"
	var table_top := BoxMesh.new()
	table_top.size = Vector3(1.2, 0.08, 0.6)
	table_mesh.mesh = table_top
	table_mesh.material_override = wood_material
	table_mesh.position = Vector3(0, 0.75, 0)
	mesh_root.add_child(table_mesh)

	# Table legs (4 corners)
	var leg_positions: Array[Vector3] = [
		Vector3(-0.5, 0.35, -0.22),
		Vector3(0.5, 0.35, -0.22),
		Vector3(-0.5, 0.35, 0.22),
		Vector3(0.5, 0.35, 0.22),
	]

	for i in range(4):
		var leg := MeshInstance3D.new()
		leg.name = "TableLeg%d" % i
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.08, 0.7, 0.08)
		leg.mesh = leg_mesh
		leg.material_override = wood_material
		leg.position = leg_positions[i]
		mesh_root.add_child(leg)

	# Add bottles and vials on the table
	_add_bottle(Vector3(-0.35, 0.95, 0.1), 0.08, 0.25, Color(0.8, 0.2, 0.2, 0.8))  # Red potion
	_add_bottle(Vector3(-0.15, 0.9, -0.1), 0.06, 0.2, Color(0.2, 0.6, 0.8, 0.8))   # Blue potion
	_add_bottle(Vector3(0.1, 0.92, 0.05), 0.07, 0.22, Color(0.2, 0.8, 0.3, 0.8))   # Green potion
	_add_vial(Vector3(0.35, 0.85, -0.05), 0.03, 0.12, Color(0.9, 0.8, 0.2, 0.8))   # Yellow vial
	_add_vial(Vector3(0.45, 0.85, 0.1), 0.03, 0.1, Color(0.6, 0.3, 0.8, 0.8))      # Purple vial

	# Mortar and pestle (simple representation)
	var mortar := MeshInstance3D.new()
	mortar.name = "Mortar"
	var mortar_mesh := CylinderMesh.new()
	mortar_mesh.top_radius = 0.08
	mortar_mesh.bottom_radius = 0.06
	mortar_mesh.height = 0.08
	mortar.mesh = mortar_mesh
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.5, 0.48)
	mortar.material_override = stone_mat
	mortar.position = Vector3(-0.4, 0.83, -0.15)
	mesh_root.add_child(mortar)


func _add_bottle(pos: Vector3, radius: float, height: float, liquid_color: Color) -> void:
	## Add a bottle with liquid inside

	# Bottle glass
	var bottle := MeshInstance3D.new()
	bottle.name = "Bottle"
	var bottle_mesh := CylinderMesh.new()
	bottle_mesh.top_radius = radius * 0.4  # Narrow neck
	bottle_mesh.bottom_radius = radius
	bottle_mesh.height = height
	bottle.mesh = bottle_mesh
	bottle.material_override = glass_material
	bottle.position = pos
	mesh_root.add_child(bottle)

	# Liquid inside (slightly smaller)
	var liquid := MeshInstance3D.new()
	liquid.name = "Liquid"
	var liquid_mesh := CylinderMesh.new()
	liquid_mesh.top_radius = radius * 0.85
	liquid_mesh.bottom_radius = radius * 0.85
	liquid_mesh.height = height * 0.6
	liquid.mesh = liquid_mesh

	var liq_mat := StandardMaterial3D.new()
	liq_mat.albedo_color = liquid_color
	liq_mat.emission_enabled = true
	liq_mat.emission = Color(liquid_color.r * 0.3, liquid_color.g * 0.3, liquid_color.b * 0.3)
	liq_mat.emission_energy_multiplier = 0.5
	liq_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.material_override = liq_mat
	liquid.position = pos + Vector3(0, -height * 0.15, 0)
	mesh_root.add_child(liquid)


func _add_vial(pos: Vector3, radius: float, height: float, liquid_color: Color) -> void:
	## Add a small vial

	# Vial glass (thin cylinder)
	var vial := MeshInstance3D.new()
	vial.name = "Vial"
	var vial_mesh := CylinderMesh.new()
	vial_mesh.top_radius = radius * 0.6
	vial_mesh.bottom_radius = radius
	vial_mesh.height = height
	vial.mesh = vial_mesh
	vial.material_override = glass_material
	vial.position = pos
	mesh_root.add_child(vial)

	# Liquid inside
	var liquid := MeshInstance3D.new()
	liquid.name = "VialLiquid"
	var liquid_mesh := CylinderMesh.new()
	liquid_mesh.top_radius = radius * 0.8
	liquid_mesh.bottom_radius = radius * 0.8
	liquid_mesh.height = height * 0.5
	liquid.mesh = liquid_mesh

	var liq_mat := StandardMaterial3D.new()
	liq_mat.albedo_color = liquid_color
	liq_mat.emission_enabled = true
	liq_mat.emission = Color(liquid_color.r * 0.4, liquid_color.g * 0.4, liquid_color.b * 0.4)
	liq_mat.emission_energy_multiplier = 0.3
	liq_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.material_override = liq_mat
	liquid.position = pos + Vector3(0, -height * 0.1, 0)
	mesh_root.add_child(liquid)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.2, 1.0)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0.6, 0)
	interaction_area.add_child(area_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Play alchemy clink sound when interacting with table
	if AudioManager:
		AudioManager.play_alchemy_sound(false)  # Clink sound (not success)
	_open_crafting_ui()


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Use Alchemy Table"


func _open_crafting_ui() -> void:
	## Create and show the crafting UI
	if crafting_ui and is_instance_valid(crafting_ui):
		crafting_ui.queue_free()

	# Create the UI
	crafting_ui = Control.new()
	crafting_ui.set_script(crafting_ui_script)
	crafting_ui.name = "CraftingUI"

	# Set station type to alchemy (only show Consumable category)
	crafting_ui.set("station_type", "alchemy")

	# Add to scene tree
	var canvas := CanvasLayer.new()
	canvas.name = "CraftingUICanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(crafting_ui)

	# Connect close signal
	if crafting_ui.has_signal("ui_closed"):
		crafting_ui.ui_closed.connect(_on_crafting_ui_closed.bind(canvas))

	# Enter menu mode
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Open the UI
	if crafting_ui.has_method("open"):
		crafting_ui.open()


func _on_crafting_ui_closed(canvas: CanvasLayer) -> void:
	## Handle crafting UI close
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	crafting_ui = null


## Static factory method for spawning alchemy stations
static func spawn_alchemy_station(parent: Node, pos: Vector3) -> AlchemyStation:
	var instance := AlchemyStation.new()
	instance.position = pos

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.8, 0.6)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.4, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
