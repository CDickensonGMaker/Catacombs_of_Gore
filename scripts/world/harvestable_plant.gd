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
	"res://Sprite folders grab bag/barren_bush.png",
	"res://Sprite folders grab bag/barren_bush2.png"
]

func _ready() -> void:
	add_to_group("harvestable_plants")
	add_to_group("interactable")

	_setup_collision()
	_setup_interaction_area()
	_setup_visuals()

func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0   # Doesn't collide with anything

	var col_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 0.5
	col_shape.shape = cylinder
	col_shape.position.y = 0.25
	add_child(col_shape)

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
	# Map plant types to textures (can expand as more plant types are added)
	match plant_type:
		"red_herb":
			return "res://Sprite folders grab bag/autmun bush.png"
		_:
			return "res://Sprite folders grab bag/autmun bush.png"

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

	# Swap sprite to barren bush (randomly pick one of two variants)
	if sprite:
		var barren_tex_path: String = BARREN_BUSH_TEXTURES[randi() % BARREN_BUSH_TEXTURES.size()]
		var barren_tex := load(barren_tex_path) as Texture2D
		if barren_tex:
			sprite.texture = barren_tex
			# Reposition sprite based on new texture height
			var tex_height := barren_tex.get_height() * sprite.pixel_size
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

## Static method to spawn a random plant type
static func spawn_random_plant(parent: Node, pos: Vector3) -> HarvestablePlant:
	# Define available plant types with weights
	var plant_types: Array[Dictionary] = [
		{"id": "red_herb", "name": "Red Herb", "yield": 1, "weight": 0.6},  # 60%
		# Future plant types can be added here:
		# {"id": "blue_flower", "name": "Blue Flower", "yield": 1, "weight": 0.3},
		# {"id": "mushroom", "name": "Mushroom", "yield": 2, "weight": 0.1},
	]

	# For now, just spawn red herb (add weighted selection when more plants exist)
	var selected: Dictionary = plant_types[0]

	return spawn_plant(parent, pos, selected["id"], selected["name"], selected["yield"])
