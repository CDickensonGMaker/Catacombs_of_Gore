## cooking_station.gd - Cooking station world object (campfire with pot)
## Allows player to cook food items
class_name CookingStation
extends StaticBody3D

## Visual representation
var mesh_root: Node3D
var fire_base: MeshInstance3D
var pot_mesh: MeshInstance3D
var interaction_area: Area3D

## UI instances
var crafting_ui: Control = null
var crafting_ui_script = preload("res://scripts/ui/crafting_ui.gd")

## PS1-style materials
var stone_material: StandardMaterial3D
var pot_material: StandardMaterial3D
var fire_material: StandardMaterial3D

## Fire light
var fire_light: OmniLight3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cooking_stations")

	# Setup collision for player interaction detection
	collision_layer = 1  # World layer for physics
	collision_mask = 0   # Don't collide with anything

	_create_cooking_mesh()
	_create_interaction_area()


func _create_cooking_mesh() -> void:
	## Create the cooking station programmatically
	## Simple campfire with cooking pot

	# Stone material for fire ring
	stone_material = StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.35, 0.35, 0.32)
	stone_material.metallic = 0.0
	stone_material.roughness = 0.9

	# Pot material (dark iron)
	pot_material = StandardMaterial3D.new()
	pot_material.albedo_color = Color(0.2, 0.2, 0.22)
	pot_material.metallic = 0.7
	pot_material.roughness = 0.5

	# Fire material (glowing emissive)
	fire_material = StandardMaterial3D.new()
	fire_material.albedo_color = Color(1.0, 0.4, 0.1)
	fire_material.emission_enabled = true
	fire_material.emission = Color(1.0, 0.5, 0.1)
	fire_material.emission_energy_multiplier = 2.0

	# Root for the mesh
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# Fire ring base (flat cylinder of stones)
	fire_base = MeshInstance3D.new()
	fire_base.name = "FireBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.6
	base_mesh.bottom_radius = 0.7
	base_mesh.height = 0.15
	fire_base.mesh = base_mesh
	fire_base.material_override = stone_material
	fire_base.position = Vector3(0, 0.075, 0)
	mesh_root.add_child(fire_base)

	# Fire embers (glowing center)
	var embers := MeshInstance3D.new()
	embers.name = "Embers"
	var ember_mesh := CylinderMesh.new()
	ember_mesh.top_radius = 0.4
	ember_mesh.bottom_radius = 0.4
	ember_mesh.height = 0.1
	embers.mesh = ember_mesh
	embers.material_override = fire_material
	embers.position = Vector3(0, 0.2, 0)
	mesh_root.add_child(embers)

	# Pot tripod legs (3 thin boxes)
	for i in range(3):
		var leg := MeshInstance3D.new()
		leg.name = "TripodLeg%d" % i
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.05, 0.8, 0.05)
		leg.mesh = leg_mesh
		leg.material_override = pot_material
		# Position legs in a triangle around the fire
		var angle: float = (PI * 2.0 / 3.0) * i
		var leg_x: float = cos(angle) * 0.35
		var leg_z: float = sin(angle) * 0.35
		leg.position = Vector3(leg_x, 0.4, leg_z)
		# Tilt legs inward
		leg.rotation = Vector3(sin(angle) * 0.3, 0, -cos(angle) * 0.3)
		mesh_root.add_child(leg)

	# Cooking pot
	pot_mesh = MeshInstance3D.new()
	pot_mesh.name = "CookingPot"
	var pot := CylinderMesh.new()
	pot.top_radius = 0.25
	pot.bottom_radius = 0.2
	pot.height = 0.3
	pot_mesh.mesh = pot
	pot_mesh.material_override = pot_material
	pot_mesh.position = Vector3(0, 0.55, 0)
	mesh_root.add_child(pot_mesh)

	# Fire light
	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.light_color = Color(1.0, 0.6, 0.2)
	fire_light.light_energy = 1.5
	fire_light.omni_range = 5.0
	fire_light.position = Vector3(0, 0.5, 0)
	mesh_root.add_child(fire_light)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0.5, 0)
	interaction_area.add_child(area_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Play cooking sizzle sound when interacting with fire
	if AudioManager:
		AudioManager.play_cooking_sound(true)  # Sizzle sound
	_open_crafting_ui()


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Use Cooking Fire"


func _open_crafting_ui() -> void:
	## Create and show the crafting UI
	if crafting_ui and is_instance_valid(crafting_ui):
		crafting_ui.queue_free()

	# Create the UI
	crafting_ui = Control.new()
	crafting_ui.set_script(crafting_ui_script)
	crafting_ui.name = "CraftingUI"

	# Set station type to cooking (only show Food category)
	crafting_ui.set("station_type", "cooking")

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


## Static factory method for spawning cooking stations
static func spawn_cooking_station(parent: Node, pos: Vector3) -> CookingStation:
	var instance := CookingStation.new()
	instance.position = pos

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.7
	cylinder.height = 0.8
	col_shape.shape = cylinder
	col_shape.position = Vector3(0, 0.4, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
