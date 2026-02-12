## world_data.gd - World grid data defining biomes and locations per cell
## Each cell is a wilderness room in the grid-based world system
## CANONICAL WORLD MAP - Permanent layout for all playthroughs
class_name WorldData
extends RefCounted

## Biome types matching WildernessRoom.Biome
enum Biome { FOREST, PLAINS, SWAMP, HILLS, ROCKY, MOUNTAINS, COAST, UNDEAD, HORDE, DESERT }

## Location types for special cells
enum LocationType { NONE, VILLAGE, TOWN, CITY, CAPITAL, DUNGEON, LANDMARK, BRIDGE, OUTPOST }

## Cell data structure
class CellData:
	var biome: Biome = Biome.FOREST
	var location_type: LocationType = LocationType.NONE
	var location_id: String = ""  # Zone ID for towns/dungeons
	var location_name: String = ""  # Display name
	var region_name: String = ""  # Region this cell belongs to
	var is_passable: bool = true  # Can player enter this cell?
	var discovered: bool = false  # Has player visited?
	var is_road: bool = false  # Is this a road cell (safer travel)?
	var background_asset: String = ""  # Horizon skybox image
	var cell_scene_path: String = ""  # Path to hand-placed cell scene (empty = procedural)

	func _init(b: Biome = Biome.FOREST, loc_type: LocationType = LocationType.NONE,
			   loc_id: String = "", loc_name: String = "", region: String = "",
			   passable: bool = true, road: bool = false, bg: String = "",
			   scene_path: String = "") -> void:
		biome = b
		location_type = loc_type
		location_id = loc_id
		location_name = loc_name
		region_name = region
		is_passable = passable
		is_road = road
		background_asset = bg
		cell_scene_path = scene_path


## World grid - Dictionary of Vector2i -> CellData
## Coordinates: X = East/West (+ = East), Y = North/South (+ = South in this layout)
## Elder Moor is at (0, 0), Dalhurst south at (0, -3), etc.
static var world_grid: Dictionary = {}

## Region names
const REGION_ELDER_MOOR := "Elder Moor Swamps"
const REGION_DALHURST := "Dalhurst Coast"
const REGION_KAZAN_DUN := "Kazan-Dun Mountains"
const REGION_ABERDEEN := "Aberdeen Foothills"
const REGION_LARTON := "Larton Bay"
const REGION_EASTERN := "Eastern Reaches"
const REGION_TENGER := "Tenger Desert"
const REGION_FALKENHAFEN := "Falkenhafen Province"
const REGION_ELVEN := "Elven Lands"
const REGION_MOUNTAINS := "Iron Mountains"

## Background assets
const BG_SWAMP := "swampbackground.png"
const BG_PLAINS := "plains_background.png"
const BG_ROCKY := "rockhill_background.png"
const BG_MOUNTAIN := "mountianforest_background.png"
const BG_SEAPORT := "seaport_city_background.png"
const BG_DESERT := "desertcity_background.png"
const BG_KAZAN := "road_to_kazan_dun_background.png"
const BG_ENCHANTED := "enchantedforest_background.png"
const BG_BATTLEFIELD := "forgottenbattlefield_background.png"
const BG_SPOOKY := "spookytemple_background.png"
const BG_GRAVEYARD := "spookygraveyard_background.png"


## Initialize the world grid with all cell data
## CANONICAL WORLD LAYOUT:
##
##                Elder Moor (0,0) - START
##                      |
##                 [Road South]
##                      |
##                Dalhurst (0,-3) - Port City
##                      |
##                 [Mountain Road]
##                      |
##                Kazan-Dun (0,-6) - Dwarf Hold
##                      |
##                 [Mountain Pass]
##                      |
##                Aberdeen (0,-9) - Isolated Town
##                 /          \
##            Larton         [Road East] --> Falkenhafen
##           (-3,-9)                           (7,-9)
##              |
##           [WATER]
##              |
##         Elven Forest (-4,-12) - Boat Required
##
static func initialize() -> void:
	world_grid.clear()

	# ============================================
	# ELDER MOOR AREA (0,0) - Starting Zone
	# Swamp village surrounded by swamp/forest
	# ============================================
	_set_cell(0, 0, Biome.SWAMP, LocationType.VILLAGE, "village_elder_moor", "Elder Moor", REGION_ELDER_MOOR, true, true, BG_SWAMP)

	# Elder Moor surroundings (swamp/forest)
	_set_cell(1, 0, Biome.SWAMP, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)
	_set_cell(-1, 0, Biome.SWAMP, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)
	_set_cell(0, 1, Biome.FOREST, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)
	_set_cell(1, 1, Biome.FOREST, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)
	_set_cell(-1, 1, Biome.FOREST, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)
	_set_cell(1, -1, Biome.SWAMP, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)
	_set_cell(-1, -1, Biome.SWAMP, LocationType.NONE, "", "", REGION_ELDER_MOOR, true, false, BG_SWAMP)

	# Mountains blocking north of Elder Moor
	_set_cell(0, 2, Biome.MOUNTAINS, LocationType.NONE, "", "Northern Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(1, 2, Biome.MOUNTAINS, LocationType.NONE, "", "Northern Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(-1, 2, Biome.MOUNTAINS, LocationType.NONE, "", "Northern Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(2, 1, Biome.MOUNTAINS, LocationType.NONE, "", "Eastern Barrier", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(-2, 1, Biome.MOUNTAINS, LocationType.NONE, "", "Western Barrier", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)

	# ============================================
	# ROAD: Elder Moor to Dalhurst (0,-1 to 0,-3)
	# The ONLY road out of Elder Moor goes south
	# ============================================
	_set_cell(0, -1, Biome.SWAMP, LocationType.NONE, "", "Southern Road", REGION_ELDER_MOOR, true, true, BG_SWAMP)
	_set_cell(0, -2, Biome.PLAINS, LocationType.NONE, "", "Dalhurst Road", REGION_DALHURST, true, true, BG_PLAINS)

	# ============================================
	# DALHURST (0,-3) - Major Port City
	# Coastal city, main trade hub
	# ============================================
	_set_cell(0, -3, Biome.COAST, LocationType.CITY, "city_dalhurst", "Dalhurst", REGION_DALHURST, true, true, BG_SEAPORT)

	# Dalhurst surroundings
	_set_cell(1, -3, Biome.PLAINS, LocationType.NONE, "", "", REGION_DALHURST, true, false, BG_PLAINS)
	_set_cell(-1, -3, Biome.COAST, LocationType.NONE, "", "Dalhurst Bay", REGION_DALHURST, true, false, BG_SEAPORT)
	_set_cell(-2, -3, Biome.COAST, LocationType.NONE, "", "Western Waters", REGION_DALHURST, false, false, BG_SEAPORT)  # Water
	_set_cell(1, -2, Biome.PLAINS, LocationType.NONE, "", "", REGION_DALHURST, true, false, BG_PLAINS)
	_set_cell(-1, -2, Biome.PLAINS, LocationType.NONE, "", "", REGION_DALHURST, true, false, BG_PLAINS)

	# Willow Dale Dungeon - west of Dalhurst
	_set_cell(-2, -2, Biome.FOREST, LocationType.DUNGEON, "dungeon_willow_dale", "Willow Dale Ruins", REGION_DALHURST, true, false, BG_SPOOKY)

	# ============================================
	# ROAD: Dalhurst to Kazan-Dun (0,-4 to 0,-6)
	# Mountain road through rocky terrain
	# ============================================
	_set_cell(0, -4, Biome.ROCKY, LocationType.NONE, "", "Mountain Road", REGION_KAZAN_DUN, true, true, BG_KAZAN)
	_set_cell(0, -5, Biome.ROCKY, LocationType.NONE, "", "Kazan Approach", REGION_KAZAN_DUN, true, true, BG_KAZAN)

	# Mountain walls flanking the road
	_set_cell(1, -4, Biome.MOUNTAINS, LocationType.NONE, "", "Iron Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(-1, -4, Biome.MOUNTAINS, LocationType.NONE, "", "Iron Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(1, -5, Biome.MOUNTAINS, LocationType.NONE, "", "Iron Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(-1, -5, Biome.MOUNTAINS, LocationType.NONE, "", "Iron Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)

	# ============================================
	# KAZAN-DUN (0,-6) - Dwarven Hold
	# Mountain stronghold of the dwarves
	# ============================================
	_set_cell(0, -6, Biome.ROCKY, LocationType.CITY, "city_kazan_dun", "Kazan-Dun", REGION_KAZAN_DUN, true, true, BG_KAZAN)

	# Kazan-Dun surroundings (mountains)
	_set_cell(1, -6, Biome.ROCKY, LocationType.NONE, "", "Eastern Gate", REGION_KAZAN_DUN, true, false, BG_ROCKY)
	_set_cell(-1, -6, Biome.ROCKY, LocationType.NONE, "", "Western Gate", REGION_KAZAN_DUN, true, false, BG_ROCKY)
	_set_cell(2, -6, Biome.MOUNTAINS, LocationType.NONE, "", "Deep Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(-2, -6, Biome.MOUNTAINS, LocationType.NONE, "", "Deep Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)

	# ============================================
	# ROAD: Kazan-Dun to Aberdeen (0,-7 to 0,-9)
	# Mountain pass descending to foothills
	# ============================================
	_set_cell(0, -7, Biome.ROCKY, LocationType.NONE, "", "Southern Pass", REGION_KAZAN_DUN, true, true, BG_ROCKY)
	_set_cell(0, -8, Biome.HILLS, LocationType.NONE, "", "Aberdeen Foothills", REGION_ABERDEEN, true, true, BG_ROCKY)

	# Mountain walls continue
	_set_cell(1, -7, Biome.MOUNTAINS, LocationType.NONE, "", "Iron Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(-1, -7, Biome.MOUNTAINS, LocationType.NONE, "", "Iron Mountains", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(1, -8, Biome.HILLS, LocationType.NONE, "", "", REGION_ABERDEEN, true, false, BG_ROCKY)
	_set_cell(-1, -8, Biome.HILLS, LocationType.NONE, "", "", REGION_ABERDEEN, true, false, BG_ROCKY)

	# ============================================
	# ABERDEEN (0,-9) - Isolated Town
	# Cut-off from regular supplies, crossroads
	# ============================================
	_set_cell(0, -9, Biome.HILLS, LocationType.TOWN, "town_aberdeen", "Aberdeen", REGION_ABERDEEN, true, true, BG_MOUNTAIN)

	# Aberdeen surroundings
	_set_cell(0, -10, Biome.PLAINS, LocationType.NONE, "", "Southern Fields", REGION_ABERDEEN, true, false, BG_PLAINS)
	_set_cell(-2, -8, Biome.HILLS, LocationType.NONE, "", "", REGION_ABERDEEN, true, false, BG_ROCKY)

	# ============================================
	# ROAD WEST: Aberdeen to Larton (-1,-9 to -3,-9)
	# ============================================
	_set_cell(-1, -9, Biome.PLAINS, LocationType.NONE, "", "Western Road", REGION_LARTON, true, true, BG_PLAINS)
	_set_cell(-2, -9, Biome.PLAINS, LocationType.NONE, "", "Larton Road", REGION_LARTON, true, true, BG_PLAINS)

	# ============================================
	# LARTON (-3,-9) - Western Port Town
	# Coastal town, boat access to Elven lands
	# ============================================
	_set_cell(-3, -9, Biome.COAST, LocationType.TOWN, "town_larton", "Larton", REGION_LARTON, true, true, BG_SEAPORT)

	# Larton surroundings
	_set_cell(-3, -8, Biome.PLAINS, LocationType.NONE, "", "", REGION_LARTON, true, false, BG_PLAINS)
	_set_cell(-4, -9, Biome.COAST, LocationType.NONE, "", "Larton Harbor", REGION_LARTON, false, false, BG_SEAPORT)  # Water
	_set_cell(-3, -10, Biome.COAST, LocationType.NONE, "", "Southern Waters", REGION_LARTON, false, false, BG_SEAPORT)  # Water

	# Water barrier between Larton and Elven Forest
	_set_cell(-4, -10, Biome.COAST, LocationType.NONE, "", "Open Sea", REGION_LARTON, false, false, BG_SEAPORT)
	_set_cell(-4, -11, Biome.COAST, LocationType.NONE, "", "Open Sea", REGION_LARTON, false, false, BG_SEAPORT)
	_set_cell(-3, -11, Biome.COAST, LocationType.NONE, "", "Open Sea", REGION_LARTON, false, false, BG_SEAPORT)

	# ============================================
	# ELVEN FOREST (-4,-12) - Boat Required
	# Accessible only by sea from Larton
	# ============================================
	_set_cell(-4, -12, Biome.FOREST, LocationType.VILLAGE, "village_elven_outpost", "Elven Outpost", REGION_ELVEN, true, false, BG_ENCHANTED)
	_set_cell(-5, -12, Biome.FOREST, LocationType.NONE, "", "Elven Woods", REGION_ELVEN, true, false, BG_ENCHANTED)
	_set_cell(-4, -13, Biome.FOREST, LocationType.NONE, "", "Deep Forest", REGION_ELVEN, true, false, BG_ENCHANTED)
	_set_cell(-5, -13, Biome.FOREST, LocationType.NONE, "", "Ancient Grove", REGION_ELVEN, true, false, BG_ENCHANTED)

	# ============================================
	# ROAD EAST: Aberdeen to Eastern Reaches (1,-9 to 7,-9)
	# Main trade route to capital
	# ============================================
	_set_cell(1, -9, Biome.PLAINS, LocationType.NONE, "", "Eastern Road", REGION_ABERDEEN, true, true, BG_PLAINS)

	# ============================================
	# FORGOTTEN BATTLEGROUNDS (2,-9) - Landmark
	# Historic battlefield, east of Aberdeen
	# ============================================
	_set_cell(2, -9, Biome.PLAINS, LocationType.LANDMARK, "poi_forgotten_battlegrounds", "Forgotten Battlegrounds", REGION_EASTERN, true, true, BG_BATTLEFIELD)
	_set_cell(2, -10, Biome.PLAINS, LocationType.NONE, "", "", REGION_EASTERN, true, false, BG_PLAINS)
	_set_cell(2, -8, Biome.HILLS, LocationType.NONE, "", "", REGION_EASTERN, true, false, BG_ROCKY)

	# Continue road east
	_set_cell(3, -9, Biome.PLAINS, LocationType.NONE, "", "Trade Road", REGION_EASTERN, true, true, BG_PLAINS)

	# ============================================
	# WHAELER'S ABYSS (4,-8) - Dungeon
	# Spooky temple/dungeon north of road
	# ============================================
	_set_cell(4, -8, Biome.ROCKY, LocationType.DUNGEON, "dungeon_whaelers_abyss", "Whaeler's Abyss", REGION_EASTERN, true, false, BG_SPOOKY)
	_set_cell(3, -8, Biome.HILLS, LocationType.NONE, "", "", REGION_EASTERN, true, false, BG_ROCKY)

	# Road continues
	_set_cell(4, -9, Biome.PLAINS, LocationType.NONE, "", "Eastern Plains", REGION_EASTERN, true, true, BG_PLAINS)

	# ============================================
	# TENGER DESERT CAMP (5,-10) - Desert Outpost
	# Nomadic trading post south of main road
	# ============================================
	_set_cell(5, -10, Biome.DESERT, LocationType.OUTPOST, "outpost_tenger_camp", "Tenger Camp", REGION_TENGER, true, false, BG_DESERT)
	_set_cell(5, -11, Biome.DESERT, LocationType.NONE, "", "Tenger Desert", REGION_TENGER, true, false, BG_DESERT)
	_set_cell(4, -10, Biome.DESERT, LocationType.NONE, "", "", REGION_TENGER, true, false, BG_DESERT)
	_set_cell(6, -10, Biome.DESERT, LocationType.NONE, "", "", REGION_TENGER, true, false, BG_DESERT)
	_set_cell(5, -9, Biome.PLAINS, LocationType.NONE, "", "Desert Edge", REGION_TENGER, true, true, BG_PLAINS)

	# Continue road to Falkenhafen
	_set_cell(6, -9, Biome.PLAINS, LocationType.NONE, "", "Capital Road", REGION_FALKENHAFEN, true, true, BG_PLAINS)

	# ============================================
	# FALKENHAFEN (7,-9) - Capital City
	# Largest city in the land
	# ============================================
	_set_cell(7, -9, Biome.ROCKY, LocationType.CAPITAL, "capital_falkenhafen", "Falkenhafen", REGION_FALKENHAFEN, true, true, BG_MOUNTAIN)

	# Falkenhafen surroundings
	_set_cell(7, -8, Biome.ROCKY, LocationType.NONE, "", "Northern Gate", REGION_FALKENHAFEN, true, false, BG_MOUNTAIN)
	_set_cell(8, -9, Biome.ROCKY, LocationType.NONE, "", "Castle Grounds", REGION_FALKENHAFEN, true, false, BG_MOUNTAIN)
	_set_cell(7, -10, Biome.PLAINS, LocationType.NONE, "", "Southern Fields", REGION_FALKENHAFEN, true, false, BG_PLAINS)
	_set_cell(8, -8, Biome.MOUNTAINS, LocationType.NONE, "", "Eastern Peaks", REGION_MOUNTAINS, false, false, BG_MOUNTAIN)
	_set_cell(8, -10, Biome.PLAINS, LocationType.NONE, "", "", REGION_FALKENHAFEN, true, false, BG_PLAINS)

	# ============================================
	# PROCEDURAL SETTLEMENTS (Hardcoded Random)
	# Additional villages/hamlets away from main road
	# ============================================

	# Hamlet: Thornfield (northeast of Elder Moor, forest clearing)
	_set_cell(2, 0, Biome.FOREST, LocationType.VILLAGE, "hamlet_thornfield", "Thornfield", REGION_ELDER_MOOR, true, false, BG_SWAMP)

	# Hamlet: Millbrook (between Dalhurst and Kazan-Dun, off the main road)
	_set_cell(2, -3, Biome.PLAINS, LocationType.VILLAGE, "hamlet_millbrook", "Millbrook", REGION_DALHURST, true, false, BG_PLAINS)

	# Village: Stonehaven (near mountains south of Kazan-Dun)
	_set_cell(-2, -7, Biome.ROCKY, LocationType.VILLAGE, "village_stonehaven", "Stonehaven", REGION_KAZAN_DUN, true, false, BG_ROCKY)

	# Hamlet: Dusty Hollow (edge of desert, small trading post)
	_set_cell(6, -11, Biome.DESERT, LocationType.VILLAGE, "hamlet_dusty_hollow", "Dusty Hollow", REGION_TENGER, true, false, BG_DESERT)

	# Village: Riverside (south of Falkenhafen)
	_set_cell(7, -11, Biome.PLAINS, LocationType.VILLAGE, "village_riverside", "Riverside", REGION_FALKENHAFEN, true, false, BG_PLAINS)

	# Hamlet: Windmere (north wilderness, accessible from eastern road)
	_set_cell(4, -7, Biome.HILLS, LocationType.VILLAGE, "hamlet_windmere", "Windmere", REGION_EASTERN, true, false, BG_ROCKY)

	# Village: Old Crossing (junction village between regions)
	_set_cell(3, -10, Biome.PLAINS, LocationType.VILLAGE, "village_old_crossing", "Old Crossing", REGION_EASTERN, true, false, BG_PLAINS)

	# ============================================
	# ADDITIONAL SETTLEMENTS (Towns/Outposts)
	# ============================================

	# Town: East Hollow (Tregar-conquered town)
	_set_cell(5, -6, Biome.PLAINS, LocationType.TOWN, "town_east_hollow", "East Hollow", REGION_EASTERN, true, false, BG_PLAINS)

	# Town: Whalers Abyss (Cliffside vampire cult town)
	_set_cell(3, -7, Biome.COAST, LocationType.TOWN, "town_whalers_abyss", "Whalers Abyss", REGION_EASTERN, true, false, BG_SEAPORT)

	# Outpost: King's Watch (Mountain fortress)
	_set_cell(-1, -5, Biome.MOUNTAINS, LocationType.OUTPOST, "outpost_kings_watch", "King's Watch", REGION_KAZAN_DUN, true, false, BG_MOUNTAIN)

	# Village: Pola Perron (Peaceful mountain village)
	_set_cell(-3, -6, Biome.HILLS, LocationType.VILLAGE, "village_pola_perron", "Pola Perron", REGION_KAZAN_DUN, true, false, BG_ROCKY)

	# Town: Duncaster (Blocked mountain route)
	_set_cell(-2, -4, Biome.MOUNTAINS, LocationType.TOWN, "town_duncaster", "Duncaster", REGION_KAZAN_DUN, true, false, BG_MOUNTAIN)

	print("[WorldData] Initialized world grid with %d cells" % world_grid.size())


## Helper to set a cell
static func _set_cell(x: int, y: int, biome: Biome, loc_type: LocationType,
					   loc_id: String, loc_name: String, region: String,
					   passable: bool = true, road: bool = false, bg: String = "",
					   scene_path: String = "") -> void:
	var coords := Vector2i(x, y)
	world_grid[coords] = CellData.new(biome, loc_type, loc_id, loc_name, region, passable, road, bg, scene_path)


## Get cell data for coordinates (returns null if not defined)
static func get_cell(coords: Vector2i) -> CellData:
	if world_grid.is_empty():
		initialize()
	return world_grid.get(coords, null)


## Get biome for coordinates (defaults to FOREST for undefined cells)
static func get_biome(coords: Vector2i) -> Biome:
	var cell := get_cell(coords)
	if cell:
		return cell.biome
	# Default biome for unexplored areas based on distance from origin
	var dist := coords.length()
	if dist > 5:
		return Biome.PLAINS  # Far areas are plains
	return Biome.FOREST  # Near areas are forest


## Check if a cell is passable
static func is_passable(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if cell:
		return cell.is_passable
	return true  # Undefined cells are passable (wilderness)


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
		return "%s (%d, %d)" % [Biome.keys()[cell.biome].capitalize(), coords.x, coords.y]
	return "Wilderness (%d, %d)" % [coords.x, coords.y]


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
	# Default based on biome
	var biome := get_biome(coords)
	match biome:
		Biome.SWAMP: return "res://Sprite folders grab bag/" + BG_SWAMP
		Biome.PLAINS: return "res://Sprite folders grab bag/" + BG_PLAINS
		Biome.ROCKY, Biome.HILLS: return "res://Sprite folders grab bag/" + BG_ROCKY
		Biome.MOUNTAINS: return "res://Sprite folders grab bag/" + BG_MOUNTAIN
		Biome.COAST: return "res://Sprite folders grab bag/" + BG_SEAPORT
		Biome.DESERT: return "res://Sprite folders grab bag/" + BG_DESERT
		Biome.FOREST: return "res://Sprite folders grab bag/" + BG_ENCHANTED
		_: return "res://Sprite folders grab bag/" + BG_PLAINS


## Get cell scene path for hand-placed wilderness cells
## Returns empty string if no hand-placed scene (use procedural generation)
static func get_cell_scene(coords: Vector2i) -> String:
	var cell := get_cell(coords)
	if cell:
		return cell.cell_scene_path
	return ""


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


## Get all discovered cells
static func get_discovered_cells() -> Array[Vector2i]:
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


## Get world bounds (min/max coordinates)
static func get_world_bounds() -> Dictionary:
	if world_grid.is_empty():
		initialize()

	var min_x := 0
	var max_x := 0
	var min_y := 0
	var max_y := 0

	for coords: Vector2i in world_grid:
		min_x = mini(min_x, coords.x)
		max_x = maxi(max_x, coords.x)
		min_y = mini(min_y, coords.y)
		max_y = maxi(max_y, coords.y)

	return {
		"min": Vector2i(min_x, min_y),
		"max": Vector2i(max_x, max_y),
		"width": max_x - min_x + 1,
		"height": max_y - min_y + 1
	}


## Convert WildernessRoom.Biome to WorldData.Biome
static func to_wilderness_biome(biome: Biome) -> int:
	match biome:
		Biome.FOREST: return 0  # WildernessRoom.Biome.FOREST
		Biome.PLAINS: return 1  # WildernessRoom.Biome.PLAINS
		Biome.SWAMP: return 2   # WildernessRoom.Biome.SWAMP
		Biome.HILLS: return 3   # WildernessRoom.Biome.HILLS
		Biome.ROCKY, Biome.MOUNTAINS: return 4  # WildernessRoom.Biome.ROCKY
		Biome.COAST: return 1   # Use plains visuals for coast
		Biome.UNDEAD: return 2  # Use swamp visuals for undead (dark, murky)
		Biome.HORDE: return 1   # Use plains visuals for horde lands
		Biome.DESERT: return 1  # Use plains visuals for desert (tan/dry)
		_: return 0


## Find path between two settlements (returns array of coords)
## Simple pathfinding along roads
static func find_road_path(from_coords: Vector2i, to_coords: Vector2i) -> Array[Vector2i]:
	if world_grid.is_empty():
		initialize()

	# Simple BFS pathfinding preferring roads
	var visited: Dictionary = {}
	var queue: Array[Dictionary] = [{"coords": from_coords, "path": [from_coords]}]
	visited[from_coords] = true

	var directions: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1),
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

		# Sort neighbors to prefer roads
		var neighbors: Array[Dictionary] = []
		for dir: Vector2i in directions:
			var next: Vector2i = coords + dir
			if not visited.has(next) and is_passable(next):
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


# =============================================================================
# HEX GRID UTILITIES (Daggerfall Unity-inspired world generation)
# =============================================================================

## Hex direction bitmask constants for road/path connections
const DIR_NE := 1
const DIR_E := 2
const DIR_SE := 4
const DIR_SW := 8
const DIR_W := 16
const DIR_NW := 32

## Chunk size for streaming (world units)
const CHUNK_SIZE := 100.0

## Axial hex neighbor offsets (flat-top orientation)
const HEX_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),   # East
	Vector2i(-1, 0),  # West
	Vector2i(0, 1),   # Southeast
	Vector2i(0, -1),  # Northwest
	Vector2i(1, -1),  # Northeast
	Vector2i(-1, 1)   # Southwest
]


## Extended hex tile data for DFU-style world generation
class HexTileData:
	var hex_coords: Vector2i = Vector2i.ZERO  # Axial coordinates (q, r)
	var terrain: String = "plains"  # Terrain type string
	var elevation: String = "low"  # "sea", "low", "mid", "high"
	var biome: Biome = Biome.PLAINS
	var road_connections: int = 0  # Bitmask of DIR_* constants
	var location_id: String = ""  # Town/POI ID if present
	var location_type: LocationType = LocationType.NONE
	var danger_level: float = 1.0  # Encounter danger multiplier
	var patrol_faction: String = ""  # Faction that patrols this hex

	func _init(q: int = 0, r: int = 0) -> void:
		hex_coords = Vector2i(q, r)

	## Check if this hex has a road connection in a direction
	func has_road(direction: int) -> bool:
		return (road_connections & direction) != 0

	## Add a road connection
	func add_road(direction: int) -> void:
		road_connections = road_connections | direction

	## Check if this hex is on any road
	func is_on_road() -> bool:
		return road_connections != 0


## Convert axial hex coordinates to world position (3D)
## Uses flat-top hex orientation with CHUNK_SIZE spacing
static func axial_to_world(hex: Vector2i) -> Vector3:
	var x: float = CHUNK_SIZE * (1.5 * hex.x)
	var z: float = CHUNK_SIZE * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
	return Vector3(x, 0.0, z)


## Convert world position to axial hex coordinates
## Rounds to nearest hex center
static func world_to_axial(pos: Vector3) -> Vector2i:
	var q: float = pos.x / (CHUNK_SIZE * 1.5)
	var r: float = (pos.z / CHUNK_SIZE - sqrt(3.0) / 2.0 * q) / sqrt(3.0)
	# Round to nearest hex using cube coordinate rounding
	return _axial_round(q, r)


## Round fractional axial coordinates to nearest hex
static func _axial_round(q: float, r: float) -> Vector2i:
	# Convert to cube coordinates
	var x: float = q
	var z: float = r
	var y: float = -x - z

	# Round cube coordinates
	var rx: int = roundi(x)
	var ry: int = roundi(y)
	var rz: int = roundi(z)

	# Fix rounding errors by resetting the component with largest diff
	var x_diff: float = abs(rx - x)
	var y_diff: float = abs(ry - y)
	var z_diff: float = abs(rz - z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	# Convert back to axial (q = x, r = z)
	return Vector2i(rx, rz)


## Get all 6 neighboring hex coordinates
static func get_hex_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset: Vector2i in HEX_NEIGHBORS:
		neighbors.append(hex + offset)
	return neighbors


## Calculate hex distance (number of hexes between two points)
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	# Convert to cube coordinates and use cube distance
	var a_cube: Vector3i = Vector3i(a.x, -a.x - a.y, a.y)
	var b_cube: Vector3i = Vector3i(b.x, -b.x - b.y, b.y)
	return (abs(a_cube.x - b_cube.x) + abs(a_cube.y - b_cube.y) + abs(a_cube.z - b_cube.z)) / 2


## Get direction bitmask from one hex to adjacent hex
static func get_direction_to(from_hex: Vector2i, to_hex: Vector2i) -> int:
	var diff: Vector2i = to_hex - from_hex
	match diff:
		Vector2i(1, -1): return DIR_NE
		Vector2i(1, 0): return DIR_E
		Vector2i(0, 1): return DIR_SE
		Vector2i(-1, 1): return DIR_SW
		Vector2i(-1, 0): return DIR_W
		Vector2i(0, -1): return DIR_NW
	return 0  # Not adjacent


## Get opposite direction
static func get_opposite_direction(direction: int) -> int:
	match direction:
		DIR_NE: return DIR_SW
		DIR_E: return DIR_W
		DIR_SE: return DIR_NW
		DIR_SW: return DIR_NE
		DIR_W: return DIR_E
		DIR_NW: return DIR_SE
	return 0


# =============================================================================
# NPC AND ENEMY REGISTRY (for quest/encounter systems)
# =============================================================================

## NPC location registry: npc_id -> {hex: Vector2i, zone_id: String, npc_type: String}
static var npc_locations: Dictionary = {}

## Enemy spawn registry: enemy_type -> Array[{hex: Vector2i, zone_id: String, spawn_weight: float}]
static var enemy_spawns: Dictionary = {}


## Register an NPC location (called when NPCs are placed in zones)
static func register_npc(npc_id: String, hex: Vector2i, zone_id: String, npc_type: String = "") -> void:
	npc_locations[npc_id] = {
		"hex": hex,
		"zone_id": zone_id,
		"npc_type": npc_type
	}


## Unregister an NPC (called when NPC is removed/killed)
static func unregister_npc(npc_id: String) -> void:
	npc_locations.erase(npc_id)


## Get NPC location data
static func get_npc_location(npc_id: String) -> Dictionary:
	return npc_locations.get(npc_id, {})


## Get all NPCs in a specific hex
static func get_npcs_in_hex(hex: Vector2i) -> Array[String]:
	var npcs: Array[String] = []
	for npc_id: String in npc_locations:
		var data: Dictionary = npc_locations[npc_id]
		if data.get("hex", Vector2i.ZERO) == hex:
			npcs.append(npc_id)
	return npcs


## Get all NPCs of a specific type
static func get_npcs_by_type(npc_type: String) -> Array[String]:
	var npcs: Array[String] = []
	for npc_id: String in npc_locations:
		var data: Dictionary = npc_locations[npc_id]
		if data.get("npc_type", "") == npc_type:
			npcs.append(npc_id)
	return npcs


## Register an enemy spawn location
static func register_enemy_spawn(enemy_type: String, hex: Vector2i, zone_id: String, spawn_weight: float = 1.0) -> void:
	if not enemy_spawns.has(enemy_type):
		enemy_spawns[enemy_type] = []
	enemy_spawns[enemy_type].append({
		"hex": hex,
		"zone_id": zone_id,
		"spawn_weight": spawn_weight
	})


## Get spawn locations for an enemy type
static func get_enemy_spawn_locations(enemy_type: String) -> Array:
	return enemy_spawns.get(enemy_type, [])


## Get all enemy types that can spawn in a hex
static func get_spawnable_enemies_in_hex(hex: Vector2i) -> Array[String]:
	var enemies: Array[String] = []
	for enemy_type: String in enemy_spawns:
		var spawns: Array = enemy_spawns[enemy_type]
		for spawn: Dictionary in spawns:
			if spawn.get("hex", Vector2i.ZERO) == hex:
				if not enemy_type in enemies:
					enemies.append(enemy_type)
				break
	return enemies


## Clear all registries (called on new game)
static func clear_registries() -> void:
	npc_locations.clear()
	enemy_spawns.clear()
