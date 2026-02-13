## world_data.gd - World grid data defining biomes and locations per cell
## Each cell is a wilderness room in the grid-based world system
## DEMO ZONE MAP - 17x17 grid based on canonical JSON data
class_name WorldData
extends RefCounted

## Grid dimensions
const GRID_COLS := 17
const GRID_ROWS := 17

## Player start position
const PLAYER_START := Vector2i(7, 4)  # Elder Moor

## Terrain types from JSON map
enum Terrain { BLOCKED, HIGHLANDS, FOREST, WATER, COAST, SWAMP, ROAD, POI, DESERT }

## Biome types matching WildernessRoom.Biome
enum Biome { FOREST, PLAINS, SWAMP, HILLS, ROCKY, MOUNTAINS, COAST, UNDEAD, HORDE, DESERT }

## Location types for special cells
enum LocationType { NONE, VILLAGE, TOWN, CITY, CAPITAL, DUNGEON, LANDMARK, BRIDGE, OUTPOST, BLOCKED }

## Cell data structure
class CellData:
	var terrain: Terrain = Terrain.FOREST
	var biome: Biome = Biome.FOREST
	var location_type: LocationType = LocationType.NONE
	var location_id: String = ""  # Zone ID for towns/dungeons
	var location_name: String = ""  # Display name
	var region_name: String = ""  # Region this cell belongs to
	var is_passable: bool = true  # Can player enter this cell?
	var discovered: bool = false  # Has player visited this cell?
	var dungeon_discovered: bool = false  # Has player found the dungeon entrance? (for DUNGEON cells)
	var is_road: bool = false  # Is this a road cell (safer travel)?
	var background_asset: String = ""  # Horizon skybox image
	var cell_scene_path: String = ""  # Path to hand-placed cell scene (empty = procedural)
	var description: String = ""  # Location description for map tooltip

	func _init(t: Terrain = Terrain.FOREST, b: Biome = Biome.FOREST,
			   loc_type: LocationType = LocationType.NONE,
			   loc_id: String = "", loc_name: String = "", region: String = "",
			   passable: bool = true, road: bool = false, bg: String = "",
			   desc: String = "") -> void:
		terrain = t
		biome = b
		location_type = loc_type
		location_id = loc_id
		location_name = loc_name
		region_name = region
		is_passable = passable
		is_road = road
		background_asset = bg
		description = desc
		# Towns/cities are auto-discovered when cell is visited, dungeons are not
		dungeon_discovered = (loc_type != LocationType.DUNGEON)


## World grid - Dictionary of Vector2i -> CellData
## Coordinates: col = x (0-16), row = y (0-16)
## Row 0 is NORTH, Row 16 is SOUTH
## Elder Moor is at (7, 4)
static var world_grid: Dictionary = {}

## Terrain character to enum mapping
const TERRAIN_MAP: Dictionary = {
	"B": Terrain.BLOCKED,
	"H": Terrain.HIGHLANDS,
	"F": Terrain.FOREST,
	"W": Terrain.WATER,
	"C": Terrain.COAST,
	"S": Terrain.SWAMP,
	"R": Terrain.ROAD,
	"P": Terrain.POI,
	"D": Terrain.DESERT
}

## Terrain to biome mapping
const TERRAIN_TO_BIOME: Dictionary = {
	Terrain.BLOCKED: Biome.MOUNTAINS,
	Terrain.HIGHLANDS: Biome.ROCKY,
	Terrain.FOREST: Biome.FOREST,
	Terrain.WATER: Biome.COAST,
	Terrain.COAST: Biome.COAST,
	Terrain.SWAMP: Biome.SWAMP,
	Terrain.ROAD: Biome.PLAINS,
	Terrain.POI: Biome.PLAINS,
	Terrain.DESERT: Biome.DESERT
}

## Terrain colors for map rendering (from JSON)
const TERRAIN_COLORS: Dictionary = {
	Terrain.BLOCKED: Color("3a3a3a"),    # Dark gray mountains
	Terrain.HIGHLANDS: Color("6a6a5a"),  # Rocky highlands
	Terrain.FOREST: Color("3d6b30"),     # Green forest
	Terrain.WATER: Color("38578a"),      # Blue water
	Terrain.COAST: Color("3e5e3e"),      # Coastal green
	Terrain.SWAMP: Color("2e4a28"),      # Dark swamp green
	Terrain.ROAD: Color("7a6545"),       # Brown road
	Terrain.POI: Color("6a5a2a"),        # POI brown
	Terrain.DESERT: Color("a89840")      # Sandy desert
}

## Background assets
const BG_SWAMP := "swampbackground.png"
const BG_PLAINS := "plains_background.png"
const BG_ROCKY := "rockhill_background.png"
const BG_MOUNTAIN := "mountianforest_background.png"
const BG_SEAPORT := "seaport_city_background.png"
const BG_DESERT := "desertcity_background.png"
const BG_FOREST := "enchantedforest_background.png"
const BG_GRAVEYARD := "spookygraveyard_background.png"

## The canonical 17x17 terrain grid from JSON
## Row 0 = North edge, Row 16 = South edge
const GRID_DATA: Array = [
	["B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B"],
	["W","W","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B"],
	["W","W","W","B","B","P","F","F","F","H","B","B","B","B","B","B","B"],
	["W","W","W","C","F","R","F","F","F","P","B","B","B","B","B","B","B"],
	["W","W","W","P","R","R","R","P","R","P","B","B","B","B","B","B","B"],
	["W","W","C","F","F","R","P","S","S","H","H","B","B","B","B","B","B"],
	["W","W","C","F","F","R","S","F","F","F","H","H","B","B","B","B","B"],
	["W","W","C","F","F","R","F","F","F","F","F","H","B","B","B","B","B"],
	["W","W","C","F","F","R","F","F","F","F","F","H","H","B","B","B","B"],
	["W","W","C","P","R","R","F","F","F","F","F","F","H","B","B","B","B"],
	["W","C","F","F","F","R","F","F","F","F","H","H","H","B","B","B","B"],
	["W","C","F","F","H","R","F","F","H","H","B","B","B","B","B","B","B"],
	["W","C","F","H","H","P","H","H","B","B","B","B","B","B","B","B","B"],
	["W","B","B","B","B","B","B","B","B","F","F","H","F","F","F","F","F"],
	["W","C","F","F","S","F","F","F","F","S","F","F","F","F","H","F","F"],
	["W","F","F","F","F","F","H","F","F","F","F","F","F","H","H","F","F"],
	["W","F","F","F","F","F","F","F","F","F","F","F","F","F","F","F","F"]
]

## Location definitions from JSON
const LOCATIONS: Array = [
	{
		"id": "willow_dale",
		"name": "Willow Dale Ruins",
		"col": 5, "row": 2,
		"type": "dungeon",
		"dungeon_levels": 0,
		"description": "Crumbling stone ruins deep in the foothills. Ancient carvings cover the walls."
	},
	{
		"id": "dalhurst",
		"name": "Dalhurst",
		"col": 3, "row": 4,
		"type": "town",
		"description": "A quiet settlement on the western road, close to the lakeshore. Has a tavern and general store."
	},
	{
		"id": "crossroads",
		"name": "Crossroads",
		"col": 5, "row": 4,
		"type": "landmark",
		"description": "A weathered signpost marks where the roads meet."
	},
	{
		"id": "elder_moor",
		"name": "Elder Moor",
		"col": 7, "row": 4,
		"type": "landmark",
		"is_start": true,
		"description": "Rolling moorland dotted with standing stones. Your journey begins here."
	},
	{
		"id": "thornfield",
		"name": "Thornfield",
		"col": 9, "row": 4,
		"type": "town",
		"description": "The easternmost town in the valley. The pass beyond has collapsed."
	},
	{
		"id": "collapsed_pass",
		"name": "Collapsed Pass",
		"col": 10, "row": 4,
		"type": "blocked",
		"unlock_quest": "clear_the_pass",
		"description": "A massive rockslide has sealed the mountain pass. A future quest may clear the way."
	},
	{
		"id": "sunken_crypts",
		"name": "Sunken Crypts",
		"col": 6, "row": 5,
		"type": "dungeon",
		"dungeon_levels": 3,
		"description": "A sunken entrance half-hidden by swamp growth leads down into a sprawling three-level crypt."
	},
	{
		"id": "bandit_hideout",
		"name": "Bandit Hideout",
		"col": 9, "row": 3,
		"type": "dungeon",
		"dungeon_levels": 2,
		"description": "A fortified cave entrance north of Thornfield, crawling with bandits."
	},
	{
		"id": "millbrook",
		"name": "Millbrook",
		"col": 3, "row": 9,
		"type": "town",
		"description": "A rickety little town clinging to the lakeshore. Last stop before Kazer-Dun."
	},
	{
		"id": "kazer_dun_entrance",
		"name": "Kazer-Dun Entrance",
		"col": 5, "row": 12,
		"type": "dungeon",
		"is_demo_wall": true,
		"description": "The great northern gate of Kazer-Dun Dwarf Hold. The doors remain sealed. For now."
	}
]

## Road connections from JSON [[from_col, from_row], [to_col, to_row]]
const ROADS: Array = [
	[[3,4],[4,4]], [[4,4],[5,4]],
	[[5,4],[6,4]], [[6,4],[7,4]],
	[[7,4],[8,4]], [[8,4],[9,4]],
	[[9,4],[10,4]],
	[[9,4],[9,3]],
	[[5,4],[5,3]], [[5,3],[5,2]],
	[[5,4],[5,5]], [[5,5],[5,6]], [[5,6],[5,7]], [[5,7],[5,8]], [[5,8],[5,9]],
	[[5,9],[4,9]], [[4,9],[3,9]],
	[[3,9],[4,9]], [[4,9],[5,9]],
	[[5,9],[5,10]], [[5,10],[5,11]], [[5,11],[5,12]]
]

## Region definitions (for grouping cells)
const REGION_WESTERN_SHORE := "Western Shore"
const REGION_ELDER_MOOR := "Elder Moor"
const REGION_EASTERN_HIGHLANDS := "Eastern Highlands"
const REGION_SWAMPLANDS := "Swamplands"
const REGION_SOUTHERN_FOREST := "Southern Forest"
const REGION_MOUNTAINS := "Iron Mountains"


## Initialize the world grid from the canonical JSON data
static func initialize() -> void:
	world_grid.clear()

	# First pass: Create cells from terrain grid
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var terrain_char: String = GRID_DATA[row][col]
			var terrain: Terrain = TERRAIN_MAP.get(terrain_char, Terrain.FOREST)
			var biome: Biome = TERRAIN_TO_BIOME.get(terrain, Biome.FOREST)
			var passable: bool = (terrain != Terrain.BLOCKED and terrain != Terrain.WATER)
			var is_road: bool = (terrain == Terrain.ROAD)

			# Determine region based on position
			var region: String = _get_region_for_coords(col, row)

			# Determine background asset based on biome
			var bg: String = _get_background_for_biome(biome)

			# Create cell
			var cell := CellData.new(terrain, biome, LocationType.NONE, "", "", region, passable, is_road, bg)
			world_grid[Vector2i(col, row)] = cell

	# Second pass: Add location data
	for loc: Dictionary in LOCATIONS:
		var col: int = loc.get("col", 0)
		var row: int = loc.get("row", 0)
		var coords := Vector2i(col, row)

		var cell: CellData = world_grid.get(coords)
		if not cell:
			continue

		cell.location_id = loc.get("id", "")
		cell.location_name = loc.get("name", "")
		cell.description = loc.get("description", "")

		# Set location type
		var type_str: String = loc.get("type", "")
		match type_str:
			"dungeon":
				cell.location_type = LocationType.DUNGEON
				cell.dungeon_discovered = false
			"town":
				cell.location_type = LocationType.TOWN
			"landmark":
				cell.location_type = LocationType.LANDMARK
			"blocked":
				cell.location_type = LocationType.BLOCKED
				cell.is_passable = false
			_:
				cell.location_type = LocationType.NONE

	# Third pass: Mark road cells from road connections
	for road: Array in ROADS:
		if road.size() >= 2:
			var from: Array = road[0]
			var to: Array = road[1]
			if from.size() >= 2 and to.size() >= 2:
				var from_coords := Vector2i(from[0], from[1])
				var to_coords := Vector2i(to[0], to[1])
				var from_cell: CellData = world_grid.get(from_coords)
				var to_cell: CellData = world_grid.get(to_coords)
				if from_cell:
					from_cell.is_road = true
				if to_cell:
					to_cell.is_road = true

	print("[WorldData] Initialized demo zone grid with %d cells" % world_grid.size())


## Get region name for coordinates
static func _get_region_for_coords(col: int, row: int) -> String:
	# Western shore (near water)
	if col <= 3:
		return REGION_WESTERN_SHORE
	# Eastern highlands
	if col >= 9:
		return REGION_EASTERN_HIGHLANDS
	# Mountains (row 0-2, blocked areas)
	if row <= 2 and col >= 10:
		return REGION_MOUNTAINS
	# Swamplands (around swamp terrain)
	if row >= 5 and row <= 8 and col >= 6 and col <= 8:
		return REGION_SWAMPLANDS
	# Southern forest
	if row >= 13:
		return REGION_SOUTHERN_FOREST
	# Default to Elder Moor (central area)
	return REGION_ELDER_MOOR


## Get background asset for biome
static func _get_background_for_biome(biome: Biome) -> String:
	match biome:
		Biome.SWAMP: return BG_SWAMP
		Biome.PLAINS: return BG_PLAINS
		Biome.ROCKY, Biome.HILLS: return BG_ROCKY
		Biome.MOUNTAINS: return BG_MOUNTAIN
		Biome.COAST: return BG_SEAPORT
		Biome.DESERT: return BG_DESERT
		Biome.FOREST: return BG_FOREST
		_: return BG_PLAINS


## Get cell data for coordinates (returns null if not defined)
static func get_cell(coords: Vector2i) -> CellData:
	if world_grid.is_empty():
		initialize()
	return world_grid.get(coords, null)


## Get terrain at coordinates
static func get_terrain(coords: Vector2i) -> Terrain:
	var cell := get_cell(coords)
	if cell:
		return cell.terrain
	return Terrain.BLOCKED


## Get terrain color for map rendering
static func get_terrain_color(coords: Vector2i) -> Color:
	var cell := get_cell(coords)
	if cell:
		return TERRAIN_COLORS.get(cell.terrain, Color.BLACK)
	return Color.BLACK


## Get biome for coordinates (defaults to FOREST for undefined cells)
static func get_biome(coords: Vector2i) -> Biome:
	var cell := get_cell(coords)
	if cell:
		return cell.biome
	return Biome.FOREST


## Check if a cell is passable
static func is_passable(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if cell:
		return cell.is_passable
	return false  # Out of bounds is not passable


## Check if coordinates are within bounds
static func is_in_bounds(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < GRID_COLS and coords.y >= 0 and coords.y < GRID_ROWS


## Check if a cell is a road (safer travel)
static func is_road(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if cell:
		return cell.is_road
	return false


## Get location at coordinates (returns empty string if no location)
static func get_location_id(coords: Vector2i) -> String:
	var cell := get_cell(coords)
	if cell:
		return cell.location_id
	return ""


## Get display name for coordinates
static func get_cell_name(coords: Vector2i) -> String:
	var cell := get_cell(coords)
	if cell and cell.location_name != "":
		return cell.location_name
	if cell:
		# Return terrain-based name
		var terrain_names: Dictionary = {
			Terrain.BLOCKED: "Impassable Mountains",
			Terrain.HIGHLANDS: "Rocky Highlands",
			Terrain.FOREST: "Forest",
			Terrain.WATER: "Open Water",
			Terrain.COAST: "Coastline",
			Terrain.SWAMP: "Swampland",
			Terrain.ROAD: "Road",
			Terrain.POI: "Point of Interest",
			Terrain.DESERT: "Desert"
		}
		return terrain_names.get(cell.terrain, "Wilderness")
	return "Unknown"


## Get region name for coordinates
static func get_region_name(coords: Vector2i) -> String:
	var cell := get_cell(coords)
	if cell and cell.region_name != "":
		return cell.region_name
	return "Unknown Region"


## Get background asset for coordinates
static func get_background_asset(coords: Vector2i) -> String:
	var cell := get_cell(coords)
	if cell and cell.background_asset != "":
		return "res://Sprite folders grab bag/" + cell.background_asset
	return "res://Sprite folders grab bag/" + BG_PLAINS


## Mark a cell as discovered
static func discover_cell(coords: Vector2i) -> void:
	var cell := get_cell(coords)
	if cell:
		cell.discovered = true


## Check if cell is discovered
static func is_discovered(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if cell:
		return cell.discovered
	return false


## Mark a dungeon as discovered (reveals the dungeon icon on the map)
static func discover_dungeon(coords: Vector2i) -> void:
	var cell := get_cell(coords)
	if cell and cell.location_type == LocationType.DUNGEON:
		cell.dungeon_discovered = true
		print("[WorldData] Dungeon discovered at %s: %s" % [coords, cell.location_name])


## Check if dungeon at coords has been discovered
static func is_dungeon_discovered(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if not cell:
		return false
	if cell.location_type != LocationType.DUNGEON:
		return true
	return cell.dungeon_discovered


## Check if a location should show its full icon vs "?" marker
static func should_show_location_icon(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if not cell:
		return false
	if SceneManager and not SceneManager.fog_of_war_enabled:
		return true
	if cell.location_type != LocationType.DUNGEON:
		return cell.discovered
	return cell.discovered and cell.dungeon_discovered


## Get all discovered cells
static func get_discovered_cells() -> Array[Vector2i]:
	if world_grid.is_empty():
		initialize()
	var discovered: Array[Vector2i] = []
	for coords: Vector2i in world_grid:
		var cell: CellData = world_grid[coords]
		if cell.discovered:
			discovered.append(coords)
	return discovered


## Get all cells with a specific location type
static func get_locations_by_type(loc_type: LocationType) -> Array[Dictionary]:
	if world_grid.is_empty():
		initialize()

	var locations: Array[Dictionary] = []
	for coords: Vector2i in world_grid:
		var cell: CellData = world_grid[coords]
		if cell.location_type == loc_type:
			locations.append({
				"coords": coords,
				"id": cell.location_id,
				"name": cell.location_name,
				"region": cell.region_name
			})
	return locations


## Get all town/city/village cells (settlements)
static func get_all_settlements() -> Array[Dictionary]:
	if world_grid.is_empty():
		initialize()

	var settlements: Array[Dictionary] = []
	for coords: Vector2i in world_grid:
		var cell: CellData = world_grid[coords]
		if cell.location_type in [LocationType.VILLAGE, LocationType.TOWN, LocationType.CITY, LocationType.CAPITAL, LocationType.OUTPOST]:
			settlements.append({
				"coords": coords,
				"id": cell.location_id,
				"name": cell.location_name,
				"region": cell.region_name,
				"type": cell.location_type
			})
	return settlements


## Get world bounds
static func get_world_bounds() -> Dictionary:
	return {
		"min": Vector2i(0, 0),
		"max": Vector2i(GRID_COLS - 1, GRID_ROWS - 1),
		"width": GRID_COLS,
		"height": GRID_ROWS
	}


## Convert WildernessRoom.Biome to WorldData.Biome
## WildernessRoom.Biome values: FOREST=0, PLAINS=1, SWAMP=2, HILLS=3, ROCKY=4, DESERT=5, COAST=6
static func to_wilderness_biome(biome: Biome) -> int:
	match biome:
		Biome.FOREST: return 0
		Biome.PLAINS: return 1
		Biome.SWAMP: return 2
		Biome.HILLS: return 3
		Biome.ROCKY, Biome.MOUNTAINS: return 4
		Biome.DESERT: return 5
		Biome.COAST: return 6  # Now maps to proper COAST biome instead of PLAINS
		_: return 0


## Get location info by ID
static func get_location_by_id(location_id: String) -> Dictionary:
	for loc: Dictionary in LOCATIONS:
		if loc.get("id", "") == location_id:
			return loc
	return {}


## Get player start coordinates
static func get_player_start() -> Vector2i:
	return PLAYER_START


## Find path between two points (simple A* pathfinding)
static func find_path(from_coords: Vector2i, to_coords: Vector2i) -> Array[Vector2i]:
	if world_grid.is_empty():
		initialize()

	var visited: Dictionary = {}
	var queue: Array[Dictionary] = [{"coords": from_coords, "path": [from_coords]}]
	visited[from_coords] = true

	var directions: Array[Vector2i] = [
		Vector2i(0, -1),  # North (up)
		Vector2i(0, 1),   # South (down)
		Vector2i(1, 0),   # East (right)
		Vector2i(-1, 0)   # West (left)
	]

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var coords: Vector2i = current["coords"]
		var path: Array = current["path"]

		if coords == to_coords:
			var result: Array[Vector2i] = []
			for p in path:
				result.append(p as Vector2i)
			return result

		# Sort neighbors to prefer roads
		var neighbors: Array[Dictionary] = []
		for dir: Vector2i in directions:
			var next: Vector2i = coords + dir
			if not visited.has(next) and is_passable(next) and is_in_bounds(next):
				var priority: int = 1 if is_road(next) else 2
				neighbors.append({"coords": next, "priority": priority})

		neighbors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] < b["priority"])

		for neighbor: Dictionary in neighbors:
			var next: Vector2i = neighbor["coords"]
			visited[next] = true
			var new_path: Array = path.duplicate()
			new_path.append(next)
			queue.append({"coords": next, "path": new_path})

	return []  # No path found


## Get adjacent passable cells
static func get_adjacent_passable(coords: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(1, 0), Vector2i(-1, 0)
	]
	for dir: Vector2i in directions:
		var next: Vector2i = coords + dir
		if is_in_bounds(next) and is_passable(next):
			result.append(next)
	return result


## ============================================================================
## COORDINATE CONVERSION (3D World <-> Grid)
## ============================================================================
## Grid cell size in world units (matches WildernessRoom size)
const CELL_WORLD_SIZE := 100.0

## Convert 3D world position to grid coordinates
static func world_to_axial(world_pos: Vector3) -> Vector2i:
	# Grid origin (0,0) is at world origin
	# Each cell is CELL_WORLD_SIZE x CELL_WORLD_SIZE
	var col := int(floor(world_pos.x / CELL_WORLD_SIZE)) + PLAYER_START.x
	var row := int(floor(-world_pos.z / CELL_WORLD_SIZE)) + PLAYER_START.y
	return Vector2i(col, row)


## Convert grid coordinates to 3D world position (center of cell)
static func axial_to_world(coords: Vector2i) -> Vector3:
	# Inverse of world_to_axial
	var x := (coords.x - PLAYER_START.x) * CELL_WORLD_SIZE + CELL_WORLD_SIZE / 2.0
	var z := -(coords.y - PLAYER_START.y) * CELL_WORLD_SIZE - CELL_WORLD_SIZE / 2.0
	return Vector3(x, 0.0, z)


## Calculate grid distance between two coordinates (Manhattan distance)
static func hex_distance(from_coords: Vector2i, to_coords: Vector2i) -> int:
	return abs(from_coords.x - to_coords.x) + abs(from_coords.y - to_coords.y)


## ============================================================================
## NPC & ENEMY REGISTRY (for quest tracking)
## ============================================================================
## Registered NPCs: npc_id -> { "coords": Vector2i, "name": String }
static var registered_npcs: Dictionary = {}

## Registered enemy spawn locations: coords -> Array of enemy_ids
static var enemy_spawn_locations: Dictionary = {}


## Register an NPC at a location
## Parameters: npc_id, coords, zone_id, npc_type (matching caller order)
static func register_npc(npc_id: String, coords: Vector2i, zone_id: String = "", npc_type: String = "") -> void:
	registered_npcs[npc_id] = {
		"hex": coords,
		"zone_id": zone_id,
		"type": npc_type
	}


## Unregister an NPC
static func unregister_npc(npc_id: String) -> void:
	registered_npcs.erase(npc_id)


## Get NPC location - returns Dictionary with hex, zone_id, name
static func get_npc_location(npc_id: String) -> Dictionary:
	if registered_npcs.has(npc_id):
		return registered_npcs[npc_id]
	return {}


## Register an enemy spawn at a location
static func register_enemy_spawn(enemy_id: String, coords: Vector2i, zone_id: String = "") -> void:
	if not enemy_spawn_locations.has(coords):
		enemy_spawn_locations[coords] = []
	var entry: Dictionary = {"enemy_id": enemy_id, "zone_id": zone_id}
	# Check if already registered
	var found := false
	for existing: Dictionary in enemy_spawn_locations[coords]:
		if existing.get("enemy_id", "") == enemy_id:
			found = true
			break
	if not found:
		enemy_spawn_locations[coords].append(entry)


## Get enemy spawn locations, optionally filtered by enemy_type
## Returns Array of { "hex": Vector2i, "zone_id": String, "enemy_id": String }
static func get_enemy_spawn_locations(enemy_type: String = "") -> Array:
	var results: Array = []
	for coords: Vector2i in enemy_spawn_locations:
		for entry: Dictionary in enemy_spawn_locations[coords]:
			var entry_id: String = entry.get("enemy_id", "")
			# If no filter, return all; otherwise filter by enemy_type
			if enemy_type.is_empty() or entry_id == enemy_type or entry_id.begins_with(enemy_type):
				results.append({
					"hex": coords,
					"zone_id": entry.get("zone_id", ""),
					"enemy_id": entry_id
				})
	return results


## ============================================================================
## ROAD PATHFINDING
## ============================================================================

## Find path that prefers roads between two coordinates
static func find_road_path(from_coords: Vector2i, to_coords: Vector2i) -> Array[Vector2i]:
	# Use the existing find_path which already prefers roads
	return find_path(from_coords, to_coords)


## ============================================================================
## CELL SCENE PATH
## ============================================================================

## Get custom scene path for a cell (if hand-crafted)
static func get_cell_scene(coords: Vector2i) -> String:
	var cell := get_cell(coords)
	if cell and cell.cell_scene_path != "":
		return cell.cell_scene_path
	return ""
