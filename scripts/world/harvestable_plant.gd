## harvestable_plant.gd - Interactable plant that yields herbs based on Herbalism skill
class_name HarvestablePlant
extends StaticBody3D

signal harvested(plant_type: String, amount: int)

## Plant configuration
@export var plant_type: String = "red_herb"  # Item ID to give
@export var base_yield: int = 1  # Base amount before Herbalism multiplier
@export var display_name: String = "Red Herb"  # Name shown in interaction prompt

## Visual representation
var sprite: Sprite3D
var interaction_area: Area3D

## Harvest state
var has_been_harvested: bool = false

## Respawn timer (plants regrow after zone reload or time)
var respawn_timer: float = -1.0
const RESPAWN_TIME := 300.0  # 5 minutes in-game

## Barren bush textures (shown after harvesting)
const BARREN_BUSH_TEXTURES := [
	"res://assets/sprites/environment/trees/barren_bush.png",
	"res://assets/sprites/environment/trees/barren_bush2.png"
]

## Plant type definitions with weights and textures
## weight is cumulative for weighted random selection
const PLANT_TYPES: Array[Dictionary] = [
	{
		"id": "red_herb",
		"name": "Red Herb",
		"yield": 1,
		"weight": 0.45,  # 45%
		"fresh_texture": "res://assets/sprites/environment/trees/herb_bush2.png",
		"harvested_texture": "res://assets/sprites/environment/trees/herb_bush_picked2.png"
	},
	{
		"id": "wild_berry",
		"name": "Wild Berry Bush",
		"yield": 1,
		"weight": 0.25,  # 25%
		"fresh_texture": "res://assets/sprites/environment/trees/autumn_bush.png",
		"harvested_texture": "res://assets/sprites/environment/trees/barren_bush.png"
	},
	{
		"id": "blue_flower",
		"name": "Blue Flower",
		"yield": 1,
		"weight": 0.20,  # 20%
		"fresh_texture": "res://assets/sprites/environment/trees/herb_bush2.png",
		"harvested_texture": "res://assets/sprites/environment/trees/herb_bush_picked2.png"
	},
	{
		"id": "mushroom",
		"name": "Mushroom",
		"yield": 1,
		"weight": 0.10,  # 10%
		"fresh_texture": "res://assets/sprites/environment/ground/mushroom.png",
		"harvested_texture": "res://assets/sprites/environment/ground/mushroom.png"  # Mushroom disappears when picked (same texture, just hides)
	}
]

## Reference to collision shape for disabling after harvest
var collision_shape: CollisionShape3D = null

func _ready() -> void:
	add_to_group("harvestable_plants")
	add_to_group("interactable")

	_setup_collision()
	_setup_interaction_area()
	_setup_visuals()

func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0   # Doesn't collide with anything

	collision_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 0.5
	collision_shape.shape = cylinder
	collision_shape.position.y = 0.25
	add_child(collision_shape)

func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0  # Larger detection radius for plants
	area_shape.shape = sphere
	interaction_area.add_child(area_shape)

func _setup_visuals() -> void:
	sprite = Sprite3D.new()
	sprite.name = "PlantSprite"
	sprite.pixel_size = 0.012  # Similar to bush size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Try to load plant-specific texture, fallback to bush
	var texture_path := _get_plant_texture()
	var tex := load(texture_path) as Texture2D
	if tex:
		sprite.texture = tex
		var tex_height := tex.get_height() * sprite.pixel_size
		sprite.position.y = tex_height / 2.0

	add_child(sprite)

func _get_plant_texture() -> String:
	# Find texture for current plant type from PLANT_TYPES definitions
	for plant_def in PLANT_TYPES:
		if plant_def["id"] == plant_type:
			return plant_def["fresh_texture"]

	# Fallback to autumn bush
	return "res://assets/sprites/environment/trees/autumn_bush.png"


## Get harvested texture for current plant type
func _get_harvested_texture() -> String:
	for plant_def in PLANT_TYPES:
		if plant_def["id"] == plant_type:
			return plant_def["harvested_texture"]

	# Fallback to barren bush
	return BARREN_BUSH_TEXTURES[randi() % BARREN_BUSH_TEXTURES.size()]

func _process(delta: float) -> void:
	# Handle respawn timer if implemented
	if respawn_timer > 0:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_respawn()

## Called by player interaction system
func interact(_interactor: Node) -> void:
	if has_been_harvested:
		return

	# Calculate yield with Herbalism bonus
	var yield_multiplier := 1.0
	if GameManager.player_data:
		yield_multiplier = GameManager.player_data.get_herbalism_yield_multiplier()

	var final_yield := int(ceil(base_yield * yield_multiplier))
	final_yield = maxi(1, final_yield)  # Always give at least 1

	# Add items to inventory
	if InventoryManager.add_item(plant_type, final_yield):
		has_been_harvested = true

		# Play pickup sound
		AudioManager.play_item_pickup()

		# Notify quest system
		QuestManager.on_item_collected(plant_type, final_yield)

		# Emit signal
		harvested.emit(plant_type, final_yield)

		# Show notification
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			var herb_name := display_name
			if final_yield > 1:
				hud.show_notification("Harvested %d %s" % [final_yield, herb_name])
			else:
				hud.show_notification("Harvested %s" % herb_name)

		# Visual feedback - hide the plant
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

	# Swap sprite to harvested texture (plant-type specific)
	if sprite:
		var harvested_tex_path: String = _get_harvested_texture()
		var harvested_tex := load(harvested_tex_path) as Texture2D
		if harvested_tex:
			sprite.texture = harvested_tex
			# Reposition sprite based on new texture height
			var tex_height := harvested_tex.get_height() * sprite.pixel_size
			sprite.position.y = tex_height / 2.0

	# Start respawn timer (or just stay harvested until zone reload)
	# For now, plants stay harvested until zone is reloaded
	# respawn_timer = RESPAWN_TIME

func _respawn() -> void:
	has_been_harvested = false
	add_to_group("interactable")

	# Restore original plant texture
	if sprite:
		var texture_path := _get_plant_texture()
		var tex := load(texture_path) as Texture2D
		if tex:
			sprite.texture = tex
			var tex_height := tex.get_height() * sprite.pixel_size
			sprite.position.y = tex_height / 2.0

## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if has_been_harvested:
		return ""
	return "Harvest " + display_name

## Static factory method for spawning plants
static func spawn_plant(parent: Node, pos: Vector3, p_plant_type: String = "red_herb", p_display_name: String = "Red Herb", p_base_yield: int = 1) -> HarvestablePlant:
	var instance := HarvestablePlant.new()
	instance.plant_type = p_plant_type
	instance.display_name = p_display_name
	instance.base_yield = p_base_yield
	instance.position = pos

	parent.add_child(instance)
	return instance

## Static method to spawn a random plant type using weighted selection
static func spawn_random_plant(parent: Node, pos: Vector3) -> HarvestablePlant:
	# Weighted random selection from PLANT_TYPES
	var roll: float = randf()
	var cumulative: float = 0.0
	var selected: Dictionary = PLANT_TYPES[0]  # Default to first type

	for plant_def in PLANT_TYPES:
		cumulative += plant_def["weight"]
		if roll <= cumulative:
			selected = plant_def
			break

	return spawn_plant(parent, pos, selected["id"], selected["name"], selected["yield"])
