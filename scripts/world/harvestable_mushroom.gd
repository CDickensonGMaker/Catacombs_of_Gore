## harvestable_mushroom.gd - Interactable mushroom that can be picked without tools
class_name HarvestableMushroom
extends StaticBody3D

signal harvested(amount: int)

## Visual representation
var sprite: Sprite3D
var interaction_area: Area3D
var collision_shape: CollisionShape3D

## Harvest state
var has_been_harvested: bool = false

## Configuration
@export var yield_min: int = 1
@export var yield_max: int = 2
@export var display_name: String = "Mushroom"

## Mushroom textures - uses actual mushroom sprite
const MUSHROOM_TEXTURES: Array[String] = [
	"res://assets/sprites/environment/ground/mushroom.png"
]


func _ready() -> void:
	add_to_group("harvestable_mushrooms")
	add_to_group("interactable")

	_setup_collision()
	_setup_interaction_area()
	_setup_visuals()


func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0   # Doesn't collide with anything

	collision_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.2
	cylinder.height = 0.3
	collision_shape.shape = cylinder
	collision_shape.position.y = 0.15
	add_child(collision_shape)


func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0  # Detection radius for mushrooms
	area_shape.shape = sphere
	interaction_area.add_child(area_shape)


func _setup_visuals() -> void:
	sprite = Sprite3D.new()
	sprite.name = "MushroomSprite"
	sprite.pixel_size = 0.008  # Small mushroom size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Pick a random mushroom texture
	var tex_path: String = MUSHROOM_TEXTURES[randi() % MUSHROOM_TEXTURES.size()]
	var tex: Texture2D = load(tex_path)
	if tex:
		sprite.texture = tex
		var tex_height: float = tex.get_height() * sprite.pixel_size
		sprite.position.y = tex_height / 2.0

	# Tint mushrooms with earthy/fungal colors
	var tints: Array[Color] = [
		Color(0.9, 0.85, 0.75),   # Beige
		Color(0.8, 0.7, 0.6),    # Brown
		Color(0.75, 0.8, 0.7),   # Greenish
		Color(0.95, 0.9, 0.85),  # Pale
	]
	sprite.modulate = tints[randi() % tints.size()]

	add_child(sprite)


## Called by player interaction system - NO TOOL REQUIRED
func interact(_interactor: Node) -> void:
	if has_been_harvested:
		return

	# Calculate yield
	var yield_amount: int = randi_range(yield_min, yield_max)

	# Add items to inventory
	if InventoryManager.add_item("mushroom", yield_amount):
		has_been_harvested = true

		# Play sound
		AudioManager.play_item_pickup()

		# Notify quest system
		QuestManager.on_item_collected("mushroom", yield_amount)

		# Emit signal
		harvested.emit(yield_amount)

		# Show notification
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			if yield_amount > 1:
				hud.show_notification("Picked %d Mushrooms" % yield_amount)
			else:
				hud.show_notification("Picked Mushroom")

		# Visual feedback - remove the mushroom
		_on_harvested()
	else:
		# Inventory full
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Inventory full!")


func _on_harvested() -> void:
	# Remove from interactable group so prompt doesn't show
	remove_from_group("interactable")

	# Hide the mushroom (disappears when picked)
	if sprite:
		sprite.visible = false

	# Disable collision
	collision_layer = 0
	if collision_shape:
		collision_shape.disabled = true


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if has_been_harvested:
		return ""
	return "Pick " + display_name


## Static factory method for spawning mushrooms
static func spawn_mushroom(parent: Node, pos: Vector3, p_display_name: String = "Mushroom") -> HarvestableMushroom:
	var instance := HarvestableMushroom.new()
	instance.display_name = p_display_name
	instance.position = pos

	parent.add_child(instance)
	return instance


## Static factory method for spawning a cluster of mushrooms
static func spawn_mushroom_cluster(parent: Node, center_pos: Vector3, count: int = 3) -> Array[HarvestableMushroom]:
	var mushrooms: Array[HarvestableMushroom] = []

	for i in range(count):
		var angle: float = randf() * TAU
		var distance: float = randf_range(0.3, 1.5)
		var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var mushroom := spawn_mushroom(parent, center_pos + offset)
		mushrooms.append(mushroom)

	return mushrooms
