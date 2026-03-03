## harvestable_fallen_tree.gd - Interactable fallen/dead tree that yields wood with an axe
class_name HarvestableFallenTree
extends StaticBody3D

signal harvested(yield_amount: int)

## Visual representation
var sprite: Sprite3D
var interaction_area: Area3D
var collision_shape: CollisionShape3D

## Harvest state
var has_been_harvested: bool = false

## Configuration
@export var yield_min: int = 1
@export var yield_max: int = 2
@export var display_name: String = "Fallen Tree"

## Fallen tree textures
const FALLEN_TREE_TEXTURES: Array[String] = [
	"res://assets/sprites/environment/trees/swamp_fallen_1.png",
	"res://assets/sprites/environment/trees/swamp_fallen_2.png"
]


func _ready() -> void:
	add_to_group("harvestable_fallen_trees")
	add_to_group("interactable")

	_setup_collision()
	_setup_interaction_area()
	_setup_visuals()


func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0   # Doesn't collide with anything

	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.8, 0.6)  # Elongated obstacle
	collision_shape.shape = box
	collision_shape.position.y = 0.4
	add_child(collision_shape)


func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5  # Detection radius for fallen trees
	area_shape.shape = sphere
	interaction_area.add_child(area_shape)


func _setup_visuals() -> void:
	sprite = Sprite3D.new()
	sprite.name = "FallenTreeSprite"
	sprite.pixel_size = 0.022
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

	# Pick random fallen tree texture
	var tex_path: String = FALLEN_TREE_TEXTURES[randi() % FALLEN_TREE_TEXTURES.size()]
	var tex := load(tex_path) as Texture2D
	if tex:
		sprite.texture = tex
		var approx_height: float = tex.get_height() * sprite.pixel_size
		sprite.position.y = approx_height / 2.5  # Lower than standing trees

	# Slight X tilt to make it look more fallen/collapsed
	sprite.rotation_degrees.x = randf_range(-12, 12)

	add_child(sprite)

	# Random Y rotation
	rotation_degrees.y = randf_range(0, 360)


## Check if player has an axe equipped
func _has_axe_equipped() -> bool:
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()
	if not weapon:
		return false
	return weapon.weapon_type == Enums.WeaponType.AXE


## Called by player interaction system
func interact(_interactor: Node) -> void:
	if has_been_harvested:
		return

	if not _has_axe_equipped():
		# Show notification that axe is required
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Requires an Axe to chop")
		return

	# Calculate yield
	var yield_amount: int = randi_range(yield_min, yield_max)

	# Add items to inventory
	if InventoryManager.add_item("wood_plank", yield_amount):
		has_been_harvested = true

		# Play sound
		AudioManager.play_item_pickup()

		# Notify quest system
		QuestManager.on_item_collected("wood_plank", yield_amount)

		# Emit signal
		harvested.emit(yield_amount)

		# Show notification
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Chopped log: %d Wood Planks" % yield_amount)

		# Visual feedback - hide the log
		_on_harvested()
	else:
		# Inventory full
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Inventory full!")


func _on_harvested() -> void:
	# Remove from interactable group so prompt doesn't show
	remove_from_group("interactable")

	# Disable collision so player can walk through
	collision_layer = 0
	if collision_shape:
		collision_shape.disabled = true

	# Hide the log sprite
	if sprite:
		sprite.visible = false


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if has_been_harvested:
		return ""
	if not _has_axe_equipped():
		return display_name + " (requires Axe)"
	return "Chop " + display_name


## Static factory method for spawning fallen trees
static func spawn_fallen_tree(parent: Node, pos: Vector3, p_display_name: String = "Fallen Tree") -> HarvestableFallenTree:
	var instance := HarvestableFallenTree.new()
	instance.display_name = p_display_name
	instance.position = pos

	parent.add_child(instance)
	return instance
