## world_grid.gd - Single source of truth for world grid data
## Uses Elder Moor at (0,0) as the ONLY coordinate origin
## Replaces the dual coordinate system from world_data.gd
## NOTE: This is an autoload singleton - do not use class_name
extends Node

## Grid cell size in world units (matches existing wilderness room size)
const CELL_SIZE := 100.0

## Internal offset: Elder Moor is at (12,8) in the raw GRID_DATA
## All public API uses Elder Moor-relative coordinates where Elder Moor = (0,0)
const _INTERNAL_OFFSET := Vector2i(12, 8)

## Grid bounds relative to Elder Moor
const GRID_MIN := Vector2i(-12, -8)  # Top-left corner relative to Elder Moor
const GRID_MAX := Vector2i(7, 11)    # Bottom-right corner relative to Elder Moor

## Terrain types
enum Terrain { BLOCKED, HIGHLANDS, FOREST, WATER, COAST, SWAMP, ROAD, POI, DESERT }

## Biome types matching WildernessRoom.Biome
enum Biome { FOREST, PLAINS, SWAMP, HILLS, ROCKY, MOUNTAINS, COAST, UNDEAD, HORDE, DESERT }

## Location types for special cells
enum LocationType { NONE, VILLAGE, TOWN, CITY, CAPITAL, DUNGEON, LANDMARK, BRIDGE, OUTPOST, BLOCKED }

## Cell data structure
class CellInfo:
	var terrain: Terrain = Terrain.FOREST
	var biome: Biome = Biome.FOREST
	var location_type: LocationType = LocationType.NONE
	var location_id: String = ""
	var location_name: String = ""
	var region_name: String = ""
	var passable: bool = true
	var discovered: bool = false
	var dungeon_discovered: bool = false
	var is_road: bool = false
	var scene_path: String = ""  # Hand-crafted scene path (empty = procedural)
	var danger_level: int = 1
	var description: String = ""

	func _init(t: Terrain = Terrain.FOREST, b: Biome = Biome.FOREST) -> void:
		terrain = t
		biome = b
		passable = (t != Terrain.BLOCKED and t != Terrain.WATER)


## Main cell storage - keyed by Elder Moor-relative Vector2i
static var cells: Dictionary = {}

## Location ID to coordinates lookup
static var locations: Dictionary = {}

## Road connections
static var roads: Array = []

## Terrain character mapping
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

## Terrain colors for map rendering
const TERRAIN_COLORS: Dictionary = {
	Terrain.BLOCKED: Color("3a3a3a"),
	Terrain.HIGHLANDS: Color("6a6a5a"),
	Terrain.FOREST: Color("3d6b30"),
	Terrain.WATER: Color("38578a"),
	Terrain.COAST: Color("3e5e3e"),
	Terrain.SWAMP: Color("2e4a28"),
	Terrain.ROAD: Color("7a6545"),
	Terrain.POI: Color("6a5a2a"),
	Terrain.DESERT: Color("a89840")
}

## Location ID to scene path mapping
const LOCATION_SCENES: Dictionary = {
	"elder_moor": "res://scenes/levels/elder_moor.tscn",
	"dalhurst": "res://scenes/levels/dalhurst.tscn",
	"thornfield": "res://scenes/levels/thornfield.tscn",
	"millbrook": "res://scenes/levels/millbrook.tscn",
	"willow_dale": "res://scenes/levels/willow_dale.tscn",
	"bandit_hideout": "res://scenes/levels/bandit_hideout_exterior.tscn",
	"kazer_dun_entrance": "res://scenes/levels/kazan_dun_entrance.tscn",
	"sunken_crypts": "res://scenes/levels/sunken_crypt.tscn",
	"crossroads": "",  # Procedural
}

## The canonical 20x20 terrain grid (row 0 = North, row 19 = South)
const GRID_DATA: Array = [
	["B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B"],
	["B","B","B","B","F","F","F","F","F","F","F","F","F","F","B","B","B","B","B","P"],
	["B","B","B","F","F","F","F","F","F","F","F","F","F","F","F","B","B","B","B","B"],
	["W","W","F","F","F","F","F","P","F","F","F","F","F","F","F","H","B","B","B","B"],
	["W","W","F","F","F","F","F","R","F","F","F","F","F","P","F","H","P","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","F","F","F","H","B","B","B","B"],
	["W","W","C","F","P","F","F","R","R","R","R","R","R","R","R","P","H","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","F","F","F","H","B","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","P","F","F","H","H","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","F","F","F","F","H","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","F","F","F","H","H","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","F","F","H","H","B","B","B","B"],
	["W","W","C","F","F","P","F","R","F","F","F","F","F","F","H","H","B","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","F","H","H","B","B","B","B","B"],
	["W","W","C","F","F","F","F","R","F","F","F","F","H","H","B","B","B","B","B","B"],
	["W","C","F","F","F","F","F","R","F","F","F","F","H","H","B","B","B","B","B","B"],
	["W","C","F","F","F","F","F","R","F","F","F","H","H","B","B","B","B","B","B","B"],
	["W","C","F","F","F","F","F","P","F","F","H","H","B","B","B","B","B","B","B","B"],
	["W","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B"],
	["W","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B","B"]
]

## Location definitions (coordinates are Elder Moor-relative)
const LOCATIONS: Array = [
	{"id": "elder_moor", "name": "Elder Moor", "x": 0, "y": 0, "type": "landmark", "is_start": true,
	 "description": "Rolling moorland dotted with standing stones. Your journey begins here."},
	{"id": "willow_dale", "name": "Willow Dale Ruins", "x": -5, "y": -5, "type": "dungeon",
	 "description": "Crumbling stone ruins deep in the foothills."},
	{"id": "bandit_hideout", "name": "Bandit Hideout", "x": 1, "y": -4, "type": "dungeon",
	 "description": "A fortified cave entrance crawling with bandits."},
	{"id": "dalhurst", "name": "Dalhurst", "x": -8, "y": -2, "type": "town",
	 "description": "A quiet settlement on the western road."},
	{"id": "crossroads", "name": "Crossroads", "x": -5, "y": -2, "type": "landmark",
	 "description": "A weathered signpost marks where the roads meet."},
	{"id": "thornfield", "name": "Thornfield", "x": 3, "y": -2, "type": "town",
	 "description": "The easternmost town in the valley."},
	{"id": "millbrook", "name": "Millbrook", "x": -7, "y": 4, "type": "town",
	 "description": "A rickety little town clinging to the lakeshore."},
	{"id": "kazer_dun_entrance", "name": "Kazer-Dun Entrance", "x": -5, "y": 9, "type": "dungeon",
	 "description": "The great northern gate of Kazer-Dun Dwarf Hold."},
]

## Road connections (Elder Moor-relative coordinates)
const ROAD_CONNECTIONS: Array = [
	# North road: Crossroads to Willow Dale
	[[-5,-2], [-5,-3]], [[-5,-3], [-5,-4]], [[-5,-4], [-5,-5]],
	# West road: Crossroads to Dalhurst
	[[-5,-2], [-6,-2]], [[-6,-2], [-7,-2]], [[-7,-2], [-8,-2]],
	# East road: Crossroads to Thornfield
	[[-5,-2], [-4,-2]], [[-4,-2], [-3,-2]], [[-3,-2], [-2,-2]], [[-2,-2], [-1,-2]],
	[[-1,-2], [0,-2]], [[0,-2], [1,-2]], [[1,-2], [2,-2]], [[2,-2], [3,-2]],
	# South road: Crossroads to Kazer-Dun
	[[-5,-2], [-5,-1]], [[-5,-1], [-5,0]], [[-5,0], [-5,1]], [[-5,1], [-5,2]],
	[[-5,2], [-5,3]], [[-5,3], [-5,4]], [[-5,4], [-5,5]], [[-5,5], [-5,6]],
	[[-5,6], [-5,7]], [[-5,7], [-5,8]], [[-5,8], [-5,9]],
	# Spur to Millbrook
	[[-5,4], [-6,4]], [[-6,4], [-7,4]],
	# Spur to Bandit Hideout
	[[1,-2], [1,-3]], [[1,-3], [1,-4]],
	# Spur to Elder Moor
	[[0,-2], [0,-1]], [[0,-1], [0,0]]
]

## Region name constants
const REGION_WESTERN_SHORE := "Western Shore"
const REGION_ELDER_MOOR := "Elder Moor"
const REGION_EASTERN_HIGHLANDS := "Eastern Highlands"
const REGION_SOUTHERN_FOREST := "Southern Forest"
const REGION_MOUNTAINS := "Iron Mountains"


## Initialize the world grid
static func initialize() -> void:
	cells.clear()
	locations.clear()
	roads.clear()

	# First pass: Create cells from terrain grid
	for row in range(20):
		for col in range(20):
			# Convert to Elder Moor-relative coordinates
			var coords := Vector2i(col, row) - _INTERNAL_OFFSET

			var terrain_char: String = GRID_DATA[row][col]
			var terrain: Terrain = TERRAIN_MAP.get(terrain_char, Terrain.FOREST)
			var biome: Biome = TERRAIN_TO_BIOME.get(terrain, Biome.FOREST)

			var cell := CellInfo.new(terrain, biome)
			cell.is_road = (terrain == Terrain.ROAD)
			cell.region_name = _get_region_for_coords(coords)
			cell.danger_level = _get_danger_level(coords)

			cells[coords] = cell

	# Second pass: Add location data
	for loc: Dictionary in LOCATIONS:
		var coords := Vector2i(loc.get("x", 0), loc.get("y", 0))
		var cell: CellInfo = cells.get(coords)
		if not cell:
			continue

		cell.location_id = loc.get("id", "")
		cell.location_name = loc.get("name", "")
		cell.description = loc.get("description", "")
		cell.scene_path = LOCATION_SCENES.get(cell.location_id, "")

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
				cell.passable = false

		# Register in locations lookup
		locations[cell.location_id] = coords

	# Third pass: Mark road cells
	for road: Array in ROAD_CONNECTIONS:
		if road.size() >= 2:
			var from_arr: Array = road[0]
			var to_arr: Array = road[1]
			var from_coords := Vector2i(from_arr[0], from_arr[1])
			var to_coords := Vector2i(to_arr[0], to_arr[1])

			var from_cell: CellInfo = cells.get(from_coords)
			var to_cell: CellInfo = cells.get(to_coords)
			if from_cell:
				from_cell.is_road = true
			if to_cell:
				to_cell.is_road = true

			roads.append([from_coords, to_coords])

	print("[WorldGrid] Initialized with %d cells, %d locations" % [cells.size(), locations.size()])


## Get region name for coordinates
static func _get_region_for_coords(coords: Vector2i) -> String:
	# Convert back to raw grid for region logic
	var raw := coords + _INTERNAL_OFFSET
	var col: int = raw.x
	var row: int = raw.y

	if col <= 2:
		return REGION_WESTERN_SHORE
	if col >= 14:
		return REGION_EASTERN_HIGHLANDS
	if row <= 1 or col >= 16:
		return REGION_MOUNTAINS
	if row >= 14:
		return REGION_SOUTHERN_FOREST
	if col >= 10 and col <= 14 and row >= 6 and row <= 10:
		return REGION_ELDER_MOOR
	return "The Greenwood"


## Get danger level for coordinates (1-10)
static func _get_danger_level(coords: Vector2i) -> int:
	# Distance from Elder Moor increases danger
	var distance: int = abs(coords.x) + abs(coords.y)
	return clampi(1 + distance / 3, 1, 10)


## ============================================================================
## PUBLIC API
## ============================================================================

## Get cell at Elder Moor-relative coordinates
static func get_cell(coords: Vector2i) -> CellInfo:
	if cells.is_empty():
		initialize()
	return cells.get(coords, null)


## Check if cell is passable
static func is_passable(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	return cell != null and cell.passable


## Check if cell is a road
static func is_road(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	return cell != null and cell.is_road


## Check if coordinates are within world bounds
static func is_in_bounds(coords: Vector2i) -> bool:
	return coords.x >= GRID_MIN.x and coords.x <= GRID_MAX.x \
		and coords.y >= GRID_MIN.y and coords.y <= GRID_MAX.y


## Get adjacent passable cells
static func get_adjacent_passable(coords: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1),  # North, South
		Vector2i(1, 0), Vector2i(-1, 0)   # East, West
	]
	for dir: Vector2i in directions:
		var next: Vector2i = coords + dir
		if is_passable(next):
			result.append(next)
	return result


## ============================================================================
## COORDINATE CONVERSION
## ============================================================================

## Convert grid coordinates to 3D world position (center of cell)
## X increases East, Z decreases North (Godot convention)
static func cell_to_world(coords: Vector2i) -> Vector3:
	return Vector3(
		coords.x * CELL_SIZE,
		0.0,
		-coords.y * CELL_SIZE
	)


## Convert 3D world position to grid coordinates
static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_pos.x / CELL_SIZE),
		roundi(-world_pos.z / CELL_SIZE)
	)


## Convert grid coordinates to map pixel position
## map_size: size of the map image in pixels
static func grid_to_map_pixel(coords: Vector2i, map_size: Vector2i) -> Vector2:
	# Map center corresponds to Elder Moor (0,0)
	var map_center := Vector2(map_size) / 2.0
	var cell_pixel_size := float(map_size.x) / 20.0  # 20 cells across

	return map_center + Vector2(
		coords.x * cell_pixel_size,
		coords.y * cell_pixel_size  # Y increases downward on map
	)


## Convert map pixel to grid coordinates
static func map_pixel_to_grid(pixel: Vector2, map_size: Vector2i) -> Vector2i:
	var map_center := Vector2(map_size) / 2.0
	var cell_pixel_size := float(map_size.x) / 20.0

	var offset: Vector2 = pixel - map_center
	return Vector2i(
		roundi(offset.x / cell_pixel_size),
		roundi(offset.y / cell_pixel_size)
	)


## ============================================================================
## LOCATION QUERIES
## ============================================================================

## Get location coordinates by ID
static func get_location_coords(location_id: String) -> Vector2i:
	if cells.is_empty():
		initialize()
	return locations.get(location_id, Vector2i.ZERO)


## Get location info by ID
static func get_location_info(location_id: String) -> Dictionary:
	var coords := get_location_coords(location_id)
	var cell := get_cell(coords)
	if cell:
		return {
			"id": cell.location_id,
			"name": cell.location_name,
			"coords": coords,
			"type": cell.location_type,
			"scene_path": cell.scene_path,
			"description": cell.description
		}
	return {}


## Get location name by ID (returns "Unknown Location" if not found)
static func get_location_name(location_id: String) -> String:
	if cells.is_empty():
		initialize()
	var coords: Vector2i = locations.get(location_id, Vector2i(-999, -999))
	if coords == Vector2i(-999, -999):
		return "Unknown Location"
	var cell: CellInfo = cells.get(coords)
	if cell and not cell.location_name.is_empty():
		return cell.location_name
	return "Unknown Location"


## Get all locations of a specific type
static func get_locations_by_type(loc_type: LocationType) -> Array[Dictionary]:
	if cells.is_empty():
		initialize()

	var result: Array[Dictionary] = []
	for coords: Vector2i in cells:
		var cell: CellInfo = cells[coords]
		if cell.location_type == loc_type:
			result.append({
				"id": cell.location_id,
				"name": cell.location_name,
				"coords": coords
			})
	return result


## Get terrain color for map rendering
static func get_terrain_color(coords: Vector2i) -> Color:
	var cell := get_cell(coords)
	if cell:
		return TERRAIN_COLORS.get(cell.terrain, Color.BLACK)
	return Color.BLACK


## ============================================================================
## DISCOVERY
## ============================================================================

## Mark a cell as discovered
static func discover_cell(coords: Vector2i) -> void:
	var cell := get_cell(coords)
	if cell:
		cell.discovered = true


## Check if cell is discovered
static func is_discovered(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	return cell != null and cell.discovered


## Mark a dungeon as discovered
static func discover_dungeon(coords: Vector2i) -> void:
	var cell := get_cell(coords)
	if cell and cell.location_type == LocationType.DUNGEON:
		cell.dungeon_discovered = true


## Get all discovered cells
static func get_discovered_cells() -> Array[Vector2i]:
	if cells.is_empty():
		initialize()

	var result: Array[Vector2i] = []
	for coords: Vector2i in cells:
		var cell: CellInfo = cells[coords]
		if cell.discovered:
			result.append(coords)
	return result


## ============================================================================
## BIOME CONVERSION
## ============================================================================

## Convert to WildernessRoom.Biome int value
## WildernessRoom.Biome: FOREST=0, PLAINS=1, SWAMP=2, HILLS=3, ROCKY=4
static func to_wilderness_biome(biome: Biome) -> int:
	match biome:
		Biome.FOREST: return 0        # FOREST
		Biome.PLAINS: return 1        # PLAINS
		Biome.SWAMP: return 2         # SWAMP
		Biome.HILLS: return 3         # HILLS
		Biome.ROCKY, Biome.MOUNTAINS: return 4  # ROCKY
		Biome.DESERT: return 1        # Map to PLAINS (dry grass)
		Biome.COAST: return 1         # Map to PLAINS (coastal grass)
		_: return 0


## ============================================================================
## PATHFINDING
## ============================================================================

## Find path between two coordinates (BFS, prefers roads)
static func find_path(from_coords: Vector2i, to_coords: Vector2i) -> Array[Vector2i]:
	if cells.is_empty():
		initialize()

	if not is_passable(from_coords) or not is_passable(to_coords):
		return []

	var visited: Dictionary = {}
	var queue: Array = [{"coords": from_coords, "path": [from_coords]}]
	visited[from_coords] = true

	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(1, 0), Vector2i(-1, 0)
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

		# Collect neighbors, prioritize roads
		var neighbors: Array[Dictionary] = []
		for dir: Vector2i in directions:
			var next: Vector2i = coords + dir
			if not visited.has(next) and is_passable(next):
				var cell := get_cell(next)
				var priority: int = 1 if (cell and cell.is_road) else 2
				neighbors.append({"coords": next, "priority": priority})

		neighbors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["priority"] < b["priority"]
		)

		for neighbor: Dictionary in neighbors:
			var next: Vector2i = neighbor["coords"]
			visited[next] = true
			var new_path: Array = path.duplicate()
			new_path.append(next)
			queue.append({"coords": next, "path": new_path})

	return []


## Calculate Manhattan distance between coordinates
static func grid_distance(from_coords: Vector2i, to_coords: Vector2i) -> int:
	return abs(from_coords.x - to_coords.x) + abs(from_coords.y - to_coords.y)
