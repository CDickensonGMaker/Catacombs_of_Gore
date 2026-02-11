## wilderness_tile.gd - Base class for hand-crafted wilderness tile templates
## These tiles are instanced by the world generator to create editable biome content
class_name WildernessTile
extends Node3D

## Biome type this tile represents
@export var biome: String = "plains"

## Variation number (for multiple tiles of same biome)
@export var variant: int = 1

## Base danger level multiplier for encounters
@export var danger_level: float = 1.0

## Whether this tile has a road passing through
@export var has_road: bool = false

## Whether this tile contains a dungeon entrance
@export var has_dungeon_entrance: bool = false

## Whether this tile has a merchant spawn point
@export var has_merchant: bool = false

## Movement speed modifier (1.0 = normal, 0.7 = swamp slowdown)
@export var movement_modifier: float = 1.0

## Ambient sound category for this tile
@export var ambient_sound: String = "wilderness_default"


## Called by world generator to get spawn points for enemies
func get_enemy_spawn_points() -> Array[Node3D]:
	var spawns: Array[Node3D] = []
	var spawn_container: Node = get_node_or_null("Spawns")
	if spawn_container:
		for child in spawn_container.get_children():
			if child.name.begins_with("EnemySpawn"):
				spawns.append(child)
	return spawns


## Get exit marker for connecting tiles in a specific direction
func get_exit(direction: String) -> Node3D:
	return get_node_or_null("Exits/Exit_" + direction)


## Get all exit markers
func get_all_exits() -> Dictionary:
	var exits: Dictionary = {}
	var exit_container: Node = get_node_or_null("Exits")
	if exit_container:
		for child in exit_container.get_children():
			var dir_name: String = child.name.replace("Exit_", "")
			exits[dir_name] = child
	return exits


## Get dungeon entrance marker (if any)
func get_dungeon_entrance() -> Node3D:
	return get_node_or_null("POIs/DungeonEntrance")


## Get merchant spawn marker (if any)
func get_merchant_spawn() -> Node3D:
	return get_node_or_null("POIs/MerchantSpawn")


## Get ruin location marker (if any)
func get_ruin_location() -> Node3D:
	return get_node_or_null("POIs/RuinLocation")


## Get all POI markers
func get_all_pois() -> Array[Node3D]:
	var pois: Array[Node3D] = []
	var poi_container: Node = get_node_or_null("POIs")
	if poi_container:
		for child in poi_container.get_children():
			pois.append(child)
	return pois


## Get terrain features container
func get_terrain_features() -> Node3D:
	return get_node_or_null("Terrain/TerrainFeatures")


## Get props container
func get_props() -> Node3D:
	return get_node_or_null("Props")


## Get lights container
func get_lights() -> Node3D:
	return get_node_or_null("Lights")


## Apply biome-specific visual effects (called after instantiation)
func apply_biome_effects() -> void:
	match biome:
		"swamp":
			movement_modifier = 0.7
			ambient_sound = "swamp_ambient"
		"forest":
			ambient_sound = "forest_ambient"
		"desert":
			ambient_sound = "desert_wind"
		"coast":
			ambient_sound = "ocean_waves"
		_:
			ambient_sound = "wilderness_default"


## Get a description of this tile for debugging
func get_tile_info() -> String:
	return "WildernessTile[%s_%d] danger=%.1f road=%s dungeon=%s merchant=%s" % [
		biome, variant, danger_level, has_road, has_dungeon_entrance, has_merchant
	]
