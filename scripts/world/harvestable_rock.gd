## harvestable_rock.gd - Interactable rock that yields stone/ore when mined with a pickaxe
class_name HarvestableRock
extends StaticBody3D

signal harvested(yield_amount: int)

## Rock types with different yields
enum RockType { STONE, IRON_VEIN, RICH_IRON, SILVER_VEIN, GOLD_VEIN }

## Sprite paths for rock types
const ROCK_SPRITE_PATH := "res://assets/sprites/world/rock.png"
const IRON_VEIN_SPRITE_PATH := "res://assets/sprites/world/iron_vein.png"
const SILVER_VEIN_SPRITE_PATH := "res://assets/sprites/world/silver_vein.png"
const GOLD_VEIN_SPRITE_PATH := "res://assets/sprites/world/gold_vein.png"

## Visual representation
var sprite: Sprite3D
var interaction_area: Area3D
var collision_shape: CollisionShape3D

## Harvest state
var has_been_harvested: bool = false

## Configuration
@export var rock_type: RockType = RockType.STONE
@export var yield_min: int = 1
@export var yield_max: int = 2
@export var display_name: String = "Rock"


func _ready() -> void:
	add_to_group("harvestable_rocks")
	add_to_group("interactable")

	_setup_material()
	_setup_collision()
	_setup_interaction_area()
	_setup_visuals()


func _setup_material() -> void:
	# Material setup no longer needed - using sprites instead
	pass


func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0   # Doesn't collide with anything


func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2  # Detection radius for rocks
	area_shape.shape = sphere
	interaction_area.add_child(area_shape)


func _setup_visuals() -> void:
	# Create billboard sprite for rock
	sprite = Sprite3D.new()
	sprite.name = "RockSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = false
	sprite.transparent = true

	# Load appropriate texture based on rock type
	var tex_path: String = ROCK_SPRITE_PATH
	match rock_type:
		RockType.IRON_VEIN, RockType.RICH_IRON:
			tex_path = IRON_VEIN_SPRITE_PATH
		RockType.SILVER_VEIN:
			tex_path = SILVER_VEIN_SPRITE_PATH
		RockType.GOLD_VEIN:
			tex_path = GOLD_VEIN_SPRITE_PATH

	var tex: Texture2D = load(tex_path)
	if tex:
		sprite.texture = tex
		# Random size variation
		var base_size: float = randf_range(0.018, 0.028)
		# Rich iron is slightly larger
		if rock_type == RockType.RICH_IRON:
			base_size *= 1.3
		sprite.pixel_size = base_size
		# Position sprite so bottom is at ground level
		sprite.position = Vector3(0, tex.get_height() * base_size * 0.5, 0)
	else:
		push_warning("Failed to load rock texture: %s" % tex_path)

	# Slight random Y rotation for variety
	sprite.rotation_degrees.y = randf_range(0, 360)

	add_child(sprite)

	# Add collision shape for the rock
	var coll := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.5, 1.0)
	coll.shape = box
	coll.position = Vector3(0, 0.75, 0)
	add_child(coll)


## Check if player has a pickaxe equipped
func _has_pickaxe_equipped() -> bool:
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()
	if not weapon:
		return false
	return weapon.weapon_type == Enums.WeaponType.PICKAXE


## Called by player interaction system
func interact(_interactor: Node) -> void:
	if has_been_harvested:
		return

	if not _has_pickaxe_equipped():
		# Show notification that pickaxe is required
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Requires a Pickaxe to mine")
		return

	# Calculate yields based on rock type
	var yields: Array[Dictionary] = _get_yields_for_rock_type()
	var success := true
	var notification_parts: Array[String] = []

	# Try to add all items
	for yield_info: Dictionary in yields:
		var item_id: String = yield_info["item_id"]
		var amount: int = randi_range(yield_info["min"], yield_info["max"])
		if amount > 0:
			if InventoryManager.add_item(item_id, amount):
				QuestManager.on_item_collected(item_id, amount)
				notification_parts.append("%d %s" % [amount, InventoryManager.get_item_name(item_id)])
			else:
				success = false
				break

	if success and notification_parts.size() > 0:
		has_been_harvested = true

		# Play sound
		AudioManager.play_item_pickup()

		# Calculate total yield for signal
		var total_yield := 0
		for yield_info: Dictionary in yields:
			total_yield += randi_range(yield_info["min"], yield_info["max"])

		# Emit signal
		harvested.emit(total_yield)

		# Show notification
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Mined: " + ", ".join(notification_parts))

		# Visual feedback - remove the rock
		_on_harvested()
	elif not success:
		# Inventory full
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Inventory full!")


## Get yield items based on rock type
func _get_yields_for_rock_type() -> Array[Dictionary]:
	var yields: Array[Dictionary] = []

	match rock_type:
		RockType.STONE:
			# Stone: 2-4 stone_block
			yields.append({"item_id": "stone_block", "min": 2, "max": 4})
		RockType.IRON_VEIN:
			# Iron vein: 1-2 iron_ore + 1-2 stone_block
			yields.append({"item_id": "iron_ore", "min": 1, "max": 2})
			yields.append({"item_id": "stone_block", "min": 1, "max": 2})
		RockType.RICH_IRON:
			# Rich iron: 2-4 iron_ore
			yields.append({"item_id": "iron_ore", "min": 2, "max": 4})
		RockType.SILVER_VEIN:
			# Silver vein: 1-2 silver_ore + 1 stone_block
			yields.append({"item_id": "silver_ore", "min": 1, "max": 2})
			yields.append({"item_id": "stone_block", "min": 1, "max": 1})
		RockType.GOLD_VEIN:
			# Gold vein: 1-2 gold_ore (rare, valuable)
			yields.append({"item_id": "gold_ore", "min": 1, "max": 2})

	return yields


func _on_harvested() -> void:
	# Remove from interactable group so prompt doesn't show
	remove_from_group("interactable")

	# Hide the rock sprite (disappears when mined)
	if sprite:
		sprite.visible = false

	# Disable collision
	collision_layer = 0


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if has_been_harvested:
		return ""
	if not _has_pickaxe_equipped():
		return display_name + " (requires Pickaxe)"
	return "Mine " + display_name


## Static factory method for spawning rocks
static func spawn_rock(parent: Node, pos: Vector3, p_display_name: String = "Rock", p_rock_type: RockType = RockType.STONE) -> HarvestableRock:
	var instance := HarvestableRock.new()
	instance.rock_type = p_rock_type
	instance.display_name = p_display_name
	instance.position = pos

	# Set yield ranges based on rock type
	match p_rock_type:
		RockType.STONE:
			instance.yield_min = 2
			instance.yield_max = 4
		RockType.IRON_VEIN:
			instance.yield_min = 2
			instance.yield_max = 4
		RockType.RICH_IRON:
			instance.yield_min = 2
			instance.yield_max = 4
		RockType.SILVER_VEIN:
			instance.yield_min = 1
			instance.yield_max = 2
		RockType.GOLD_VEIN:
			instance.yield_min = 1
			instance.yield_max = 2

	parent.add_child(instance)
	return instance


## Static factory method for spawning random rock type (weighted by biome)
static func spawn_random_rock(parent: Node, pos: Vector3, highlands: bool = false) -> HarvestableRock:
	var roll: float = randf()
	var rock_type_sel: RockType
	var name: String

	if highlands:
		# Highlands have more ore veins, including precious metals
		if roll < 0.4:
			rock_type_sel = RockType.STONE
			name = "Rock"
		elif roll < 0.7:
			rock_type_sel = RockType.IRON_VEIN
			name = "Iron Vein"
		elif roll < 0.85:
			rock_type_sel = RockType.RICH_IRON
			name = "Rich Iron Deposit"
		elif roll < 0.94:
			rock_type_sel = RockType.SILVER_VEIN
			name = "Silver Vein"
		else:
			rock_type_sel = RockType.GOLD_VEIN
			name = "Gold Vein"
	else:
		# Normal areas - mostly stone, rare precious metals
		if roll < 0.75:
			rock_type_sel = RockType.STONE
			name = "Rock"
		elif roll < 0.9:
			rock_type_sel = RockType.IRON_VEIN
			name = "Iron Vein"
		elif roll < 0.96:
			rock_type_sel = RockType.RICH_IRON
			name = "Rich Iron Deposit"
		elif roll < 0.99:
			rock_type_sel = RockType.SILVER_VEIN
			name = "Silver Vein"
		else:
			rock_type_sel = RockType.GOLD_VEIN
			name = "Gold Vein"

	return spawn_rock(parent, pos, name, rock_type_sel)
