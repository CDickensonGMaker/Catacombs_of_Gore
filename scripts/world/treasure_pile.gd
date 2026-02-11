## treasure_pile.gd - Interactable treasure pile (gold coins, silver, gems)
## Can be picked up by player to receive gold
class_name TreasurePile
extends Area3D

## Pile type enumeration
enum PileType {
	GOLD,   ## Worth 1000 gold
	SILVER  ## Worth 250 gold
}

## Configuration
@export var pile_type: PileType = PileType.GOLD
@export var pile_id: String = ""  ## Unique ID for persistence - if empty, not saved
@export var gold_value: int = 0   ## Override value (0 = use default for pile type)

## Visual mesh reference (set if using external mesh, otherwise auto-created)
var mesh_instance: MeshInstance3D

## Default values by pile type
const DEFAULT_VALUES := {
	PileType.GOLD: 1000,
	PileType.SILVER: 250
}

## Display names for interaction prompt
const PILE_NAMES := {
	PileType.GOLD: "gold",
	PileType.SILVER: "silver"
}

## Has this pile been looted?
var is_looted: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("treasure_piles")

	# Setup collision for interaction detection
	collision_layer = 256  # Layer 9 for interactables (2^8)
	collision_mask = 0

	# Check if already looted from save data
	if not pile_id.is_empty():
		if SaveManager.was_container_opened(pile_id):
			is_looted = true
			_hide_pile()
			return

	# Find or create mesh
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		# Check for any MeshInstance3D child
		for child in get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break

	# Create collision shape if none exists
	if not get_node_or_null("CollisionShape3D"):
		_create_collision_shape()


func _create_collision_shape() -> void:
	## Create interaction area collision shape
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.0, 1.5)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.5, 0)
	add_child(col_shape)


## Get the actual gold value for this pile
func _get_gold_value() -> int:
	if gold_value > 0:
		return gold_value
	return DEFAULT_VALUES.get(pile_type, 1000)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	if is_looted:
		return

	var value: int = _get_gold_value()

	# Add gold to player inventory
	InventoryManager.add_gold(value)

	# Play pickup sound
	AudioManager.play_gold_pickup()

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Picked up %d gold!" % value)

	# Mark as looted
	is_looted = true

	# Save to persistence if has ID
	if not pile_id.is_empty():
		SaveManager.mark_container_opened(pile_id)

	# Remove from interactable group immediately
	remove_from_group("interactable")
	remove_from_group("treasure_piles")

	# Hide and clean up
	_hide_pile()


## Get display text for interaction prompt
func get_interaction_prompt() -> String:
	var pile_name: String = PILE_NAMES.get(pile_type, "treasure")
	var value: int = _get_gold_value()
	return "Take %s (%d gold)" % [pile_name, value]


## Hide the pile visually and queue for deletion
func _hide_pile() -> void:
	# Hide immediately
	visible = false

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	# Queue for deletion
	queue_free()


## Static factory method for spawning treasure piles
static func spawn_pile(parent: Node, pos: Vector3, p_pile_type: PileType, p_pile_id: String = "", p_value: int = 0) -> TreasurePile:
	var instance := TreasurePile.new()
	instance.position = pos
	instance.pile_type = p_pile_type
	instance.pile_id = p_pile_id
	instance.gold_value = p_value

	# Create collision shape
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.0, 1.5)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.5, 0)
	instance.add_child(col_shape)

	# Create a simple visual mesh (gold coins)
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"

	# Try to load treasure mesh based on type
	var mesh_path: String
	match p_pile_type:
		PileType.GOLD:
			mesh_path = "res://assets/models/dwarven/vault/treasure_coins_large.obj"
		PileType.SILVER:
			mesh_path = "res://assets/models/dwarven/vault/treasure_coins_small.obj"

	if ResourceLoader.exists(mesh_path):
		mesh.mesh = load(mesh_path)
	else:
		# Fallback to simple cylinder
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.6
		cylinder.height = 0.3
		mesh.mesh = cylinder

	# Apply material based on type
	var mat := StandardMaterial3D.new()
	match p_pile_type:
		PileType.GOLD:
			mat.albedo_color = Color(0.9, 0.75, 0.3)
			mat.metallic = 0.7
			mat.roughness = 0.25
		PileType.SILVER:
			mat.albedo_color = Color(0.75, 0.75, 0.8)
			mat.metallic = 0.6
			mat.roughness = 0.3

	mesh.material_override = mat
	instance.add_child(mesh)
	instance.mesh_instance = mesh

	parent.add_child(instance)
	return instance
