## world_item.gd - Physical item in the game world that can be picked up
class_name WorldItem
extends RigidBody3D

signal picked_up(item_id: String, quality: Enums.ItemQuality, quantity: int)

@export var item_id: String = ""
@export var quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE
@export var quantity: int = 1

## Visual representation
var mesh_instance: MeshInstance3D
var interaction_area: Area3D

## Bobbing animation (PS1 style)
var bob_time: float = 0.0
var base_y_offset: float = 0.3
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.1

## Rotation animation
const ROTATE_SPEED := 1.0

func _ready() -> void:
	add_to_group("world_items")
	add_to_group("interactable")

	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	mesh_instance.position.y = base_y_offset
	add_child(mesh_instance)

	# Create interaction area for raycast detection
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	area_shape.shape = sphere
	interaction_area.add_child(area_shape)

	# Setup physics
	collision_layer = 1  # World layer
	collision_mask = 1
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	# Random initial rotation
	bob_time = randf() * TAU

	# Setup visuals
	_setup_visuals()

func _process(delta: float) -> void:
	# Bobbing animation
	bob_time += delta * BOB_SPEED
	if mesh_instance:
		mesh_instance.position.y = base_y_offset + sin(bob_time) * BOB_HEIGHT
		mesh_instance.rotation.y += delta * ROTATE_SPEED

func _setup_visuals() -> void:
	if not mesh_instance:
		return

	# Try to get mesh from item data
	var mesh_path := ""

	if InventoryManager.weapon_database.has(item_id):
		mesh_path = InventoryManager.weapon_database[item_id].mesh_path
	elif InventoryManager.armor_database.has(item_id):
		mesh_path = InventoryManager.armor_database[item_id].mesh_path
	elif InventoryManager.item_database.has(item_id):
		mesh_path = InventoryManager.item_database[item_id].mesh_path

	if not mesh_path.is_empty() and ResourceLoader.exists(mesh_path):
		mesh_instance.mesh = load(mesh_path)
	else:
		# Default box for items without mesh
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		mesh_instance.mesh = box

	# Color by quality
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_quality_color()
	mesh_instance.material_override = mat

func _get_quality_color() -> Color:
	match quality:
		Enums.ItemQuality.POOR: return Color(0.5, 0.5, 0.5)
		Enums.ItemQuality.BELOW_AVERAGE: return Color(0.7, 0.7, 0.7)
		Enums.ItemQuality.AVERAGE: return Color.WHITE
		Enums.ItemQuality.ABOVE_AVERAGE: return Color(0.3, 0.8, 1.0)
		Enums.ItemQuality.PERFECT: return Color(1.0, 0.8, 0.2)
	return Color.WHITE

## Called by player interaction system
func interact(interactor: Node) -> void:
	if InventoryManager.add_item(item_id, quantity, quality):
		# Remove from groups immediately so interaction prompt clears
		remove_from_group("interactable")
		remove_from_group("world_items")
		AudioManager.play_item_pickup()
		picked_up.emit(item_id, quality, quantity)
		# Notify quest manager for collect objectives
		QuestManager.on_item_collected(item_id, quantity)

		# Warn if now overencumbered
		if InventoryManager.is_overencumbered():
			var hud := interactor.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("You are overencumbered!")

		queue_free()
	else:
		# Item doesn't exist in database - show error
		var hud := interactor.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Unknown item: " + item_id)

## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	var item_name := item_id

	if InventoryManager.weapon_database.has(item_id):
		item_name = InventoryManager.weapon_database[item_id].display_name
	elif InventoryManager.armor_database.has(item_id):
		item_name = InventoryManager.armor_database[item_id].display_name
	elif InventoryManager.item_database.has(item_id):
		item_name = InventoryManager.item_database[item_id].display_name

	var quality_str := ""
	match quality:
		Enums.ItemQuality.POOR: quality_str = "Poor "
		Enums.ItemQuality.BELOW_AVERAGE: quality_str = "Worn "
		Enums.ItemQuality.ABOVE_AVERAGE: quality_str = "Fine "
		Enums.ItemQuality.PERFECT: quality_str = "Perfect "

	var qty_str := " (%d)" % quantity if quantity > 1 else ""
	return "Pick up " + quality_str + item_name + qty_str

## Initialize with item data
func setup(p_item_id: String, p_quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE, p_quantity: int = 1) -> void:
	item_id = p_item_id
	quality = p_quality
	quantity = p_quantity
	_setup_visuals()

## Static factory method for spawning items
static func spawn_item(parent: Node, pos: Vector3, p_item_id: String, p_quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE, p_quantity: int = 1) -> WorldItem:
	var instance := WorldItem.new()
	instance.item_id = p_item_id
	instance.quality = p_quality
	instance.quantity = p_quantity
	instance.position = pos

	# Add collision shape
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	col_shape.shape = sphere
	col_shape.position.y = 0.25
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance

## Static factory method for spawning items with random quality
## Uses weighted distribution: Poor 10%, Below Average 25%, Average 40%, Above Average 20%, Perfect 5%
static func spawn_item_random_quality(parent: Node, pos: Vector3, p_item_id: String, p_quantity: int = 1) -> WorldItem:
	var quality := _roll_random_quality()
	return spawn_item(parent, pos, p_item_id, quality, p_quantity)

## Roll random quality with weighted distribution
static func _roll_random_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.10:
		return Enums.ItemQuality.POOR          # 10%
	if roll < 0.35:
		return Enums.ItemQuality.BELOW_AVERAGE # 25% (0.10 to 0.35)
	if roll < 0.75:
		return Enums.ItemQuality.AVERAGE       # 40% (0.35 to 0.75)
	if roll < 0.95:
		return Enums.ItemQuality.ABOVE_AVERAGE # 20% (0.75 to 0.95)
	return Enums.ItemQuality.PERFECT           # 5%  (0.95 to 1.0)
