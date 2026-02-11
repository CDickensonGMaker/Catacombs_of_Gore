## boat_travel_manager.gd - Manages boat travel between ports
## Handles route registration, journey execution, and encounter triggering
extends Node

signal journey_started(route: BoatTravelData)
signal journey_segment_complete(segment: int, total_segments: int)
signal encounter_triggered(encounter: SeaEncounter)
signal encounter_resolved(encounter: SeaEncounter, result: EncounterResult)
signal journey_complete(route: BoatTravelData, encounters_faced: int)
signal journey_cancelled(route: BoatTravelData, reason: String)

## Result of an encounter
enum EncounterResult {
	VICTORY,       # Player won combat
	FLED,          # Player successfully fled
	PEACEFUL,      # Resolved without combat
	TRADED,        # Merchant trade completed
	STORM_SURVIVED, # Survived storm
	DISCOVERED,    # Island discovered
	FAILED         # Player defeated/fled failed
}

## Current journey state
enum JourneyState {
	IDLE,          # Not traveling
	TRAVELING,     # Moving between segments
	IN_ENCOUNTER,  # Currently in an encounter
	COMPLETE       # Journey finished
}

## All registered boat routes
var routes: Dictionary = {}  # route_id -> BoatTravelData

## Sea routes with hex waypoints (from hex_map_data.json)
var sea_routes: Dictionary = {
	"town_02_to_elven": {
		"from_port": "Town-02",
		"to_port": "elven_city",
		"waypoints": [Vector2i(4, 30), Vector2i(-4, 28), Vector2i(-6, 34), Vector2i(-12, 35)],
		"danger_zones": ["pirate_waters"],
		"travel_segments": 4,
		"base_cost": 50
	},
	"town_04_to_elven": {
		"from_port": "Town-04",
		"to_port": "elven_city",
		"waypoints": [Vector2i(18, 40), Vector2i(8, 38), Vector2i(-2, 38), Vector2i(-12, 35)],
		"danger_zones": ["deep_waters"],
		"travel_segments": 4,
		"base_cost": 35
	}
}

## Encounter zones from hex_map_data
var encounter_zones: Dictionary = {}  # zone_id -> {q_center, r_center, radius, encounter_types}

## Current journey state
var current_state: JourneyState = JourneyState.IDLE
var current_route: BoatTravelData = null
var current_segment: int = 0
var encounters_this_journey: int = 0
var pending_encounter: SeaEncounter = null

## Current hex waypoints for journey
var current_waypoints: Array[Vector2i] = []
var current_waypoint_index: int = 0

## Path to encounter data resources
const ENCOUNTER_DATA_PATH := "res://data/travel/sea_encounters/"

## Path to route data resources
const ROUTE_DATA_PATH := "res://data/travel/boat_routes/"


func _ready() -> void:
	_load_encounter_data()
	_load_route_data()
	_load_sea_routes_from_hex_data()
	_register_default_routes()
	print("[BoatTravelManager] Initialized with %d routes, %d sea routes" % [routes.size(), sea_routes.size()])


## Load all encounter data from the data folder
func _load_encounter_data() -> void:
	var dir := DirAccess.open(ENCOUNTER_DATA_PATH)
	if not dir:
		print("[BoatTravelManager] No encounter data directory found at %s" % ENCOUNTER_DATA_PATH)
		return

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if filename.ends_with(".tres"):
			var path: String = ENCOUNTER_DATA_PATH + filename
			var resource: Resource = load(path)
			if resource is SeaEncounter:
				print("[BoatTravelManager] Loaded encounter: %s" % resource.id)
		filename = dir.get_next()
	dir.list_dir_end()


## Load all route data from the data folder
func _load_route_data() -> void:
	var dir := DirAccess.open(ROUTE_DATA_PATH)
	if not dir:
		print("[BoatTravelManager] No route data directory found at %s" % ROUTE_DATA_PATH)
		return

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if filename.ends_with(".tres"):
			var path: String = ROUTE_DATA_PATH + filename
			var resource: Resource = load(path)
			if resource is BoatTravelData:
				register_route(resource)
		filename = dir.get_next()
	dir.list_dir_end()


## Register default routes programmatically (fallback if no .tres files)
func _register_default_routes() -> void:
	# Only create default if no routes loaded from files
	if routes.size() > 0:
		return

	# Elder Moor Docks -> Elven City (main route across the lake)
	var lake_crossing := BoatTravelData.new()
	lake_crossing.id = "lake_crossing_elven"
	lake_crossing.display_name = "Lake Crossing to Elven City"
	lake_crossing.description = "A boat journey across the great lake to the Elven City."
	lake_crossing.departure_port = "elder_moor_docks"
	lake_crossing.destination_port = "elven_city_harbor"
	lake_crossing.travel_duration_hours = 6.0
	lake_crossing.journey_segments = 4
	lake_crossing.encounter_chance_per_segment = 0.3
	lake_crossing.max_encounters_per_journey = 2
	lake_crossing.base_cost = 100
	register_route(lake_crossing)

	# Coastal route between harbor towns
	var coastal_route := BoatTravelData.new()
	coastal_route.id = "coastal_south"
	coastal_route.display_name = "Southern Coastal Route"
	coastal_route.description = "A journey along the southern coast."
	coastal_route.departure_port = "dalhurst_harbor"
	coastal_route.destination_port = "desert_port"
	coastal_route.travel_duration_hours = 8.0
	coastal_route.journey_segments = 5
	coastal_route.encounter_chance_per_segment = 0.25
	coastal_route.max_encounters_per_journey = 3
	coastal_route.base_cost = 150
	register_route(coastal_route)


## Load sea routes and encounter zones from hex_map_data.json
func _load_sea_routes_from_hex_data() -> void:
	var file_path := "res://data/world/hex_map_data.json"
	if not FileAccess.file_exists(file_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: Variant = JSON.parse_string(json_text)
	if not json is Dictionary:
		return

	var hex_data: Dictionary = json as Dictionary

	# Load encounter zones
	if hex_data.has("water") and hex_data["water"] is Dictionary:
		var water_data: Dictionary = hex_data["water"]
		if water_data.has("encounter_zones"):
			for zone: Dictionary in water_data["encounter_zones"]:
				var zone_id: String = zone.get("id", "")
				if not zone_id.is_empty():
					encounter_zones[zone_id] = {
						"q_center": zone.get("q_center", 0),
						"r_center": zone.get("r_center", 0),
						"radius": zone.get("radius", 3),
						"encounter_types": zone.get("encounter_types", [])
					}

		# Load sea routes
		if water_data.has("sea_routes"):
			for route: Dictionary in water_data["sea_routes"]:
				var route_id: String = route.get("id", "")
				var waypoints: Array[Vector2i] = []
				for wp: Array in route.get("waypoints", []):
					waypoints.append(Vector2i(int(wp[0]), int(wp[1])))

				sea_routes[route_id] = {
					"from_port": route.get("from", ""),
					"to_port": route.get("to", ""),
					"waypoints": waypoints,
					"danger_zones": [],  # Calculated based on waypoint positions
					"travel_segments": waypoints.size(),
					"base_cost": 50  # Default cost
				}

	print("[BoatTravelManager] Loaded %d encounter zones" % encounter_zones.size())


## Register a new boat route
func register_route(route: BoatTravelData) -> void:
	if route.id.is_empty():
		push_warning("[BoatTravelManager] Cannot register route with empty ID")
		return

	routes[route.id] = route
	print("[BoatTravelManager] Registered route: %s" % route.id)

	# Register reverse route if bidirectional
	if route.is_bidirectional:
		var reverse_id := route.id + "_reverse"
		if not routes.has(reverse_id):
			var reverse := BoatTravelData.new()
			reverse.id = reverse_id
			reverse.display_name = route.display_name + " (Return)"
			reverse.description = route.description
			reverse.departure_port = route.destination_port
			reverse.destination_port = route.departure_port
			reverse.travel_duration_hours = route.travel_duration_hours
			reverse.journey_segments = route.journey_segments
			reverse.encounter_chance_per_segment = route.encounter_chance_per_segment
			reverse.max_encounters_per_journey = route.max_encounters_per_journey
			reverse.base_cost = route.base_cost
			reverse.cost_negotiable = route.cost_negotiable
			reverse.possible_encounters = route.possible_encounters
			reverse.encounter_weights = route.encounter_weights
			routes[reverse_id] = reverse


## Get a route by ID
func get_route(route_id: String) -> BoatTravelData:
	return routes.get(route_id, null)


## Get all routes departing from a specific port
func get_routes_from_port(port_id: String) -> Array[BoatTravelData]:
	var result: Array[BoatTravelData] = []
	for route_id in routes:
		var route: BoatTravelData = routes[route_id]
		if route.departure_port == port_id:
			result.append(route)
	return result


## Get all available routes for the player at their current location
func get_available_routes(current_port: String) -> Array[BoatTravelData]:
	var available: Array[BoatTravelData] = []
	var player_level: int = 1
	var completed_quests: Array[String] = []

	# Get player data
	if GameManager and GameManager.player_data:
		player_level = GameManager.player_data.level

	# Get completed quests
	if QuestManager:
		for quest_id in QuestManager.active_quests:
			var quest: Dictionary = QuestManager.active_quests[quest_id]
			if quest.get("state", 0) == Enums.QuestState.COMPLETED:
				completed_quests.append(quest_id)

	# Filter routes
	for route_id in routes:
		var route: BoatTravelData = routes[route_id]
		if route.departure_port != current_port:
			continue
		if not route.can_player_use(player_level, completed_quests):
			continue
		if not route.is_available_at_time(GameManager.current_time_of_day if GameManager else 0):
			continue
		available.append(route)

	return available


## Calculate the cost for a route based on player's negotiation skill
func get_route_cost(route: BoatTravelData) -> int:
	var negotiation_skill: int = 0
	if GameManager and GameManager.player_data:
		negotiation_skill = GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)
	return route.get_negotiated_cost(negotiation_skill)


## Start a boat journey
## Returns true if journey started successfully
func start_journey(route_id: String) -> bool:
	if current_state != JourneyState.IDLE:
		push_warning("[BoatTravelManager] Cannot start journey - already traveling")
		return false

	var route: BoatTravelData = get_route(route_id)
	if not route:
		push_warning("[BoatTravelManager] Route not found: %s" % route_id)
		return false

	# Check player can afford
	var cost: int = get_route_cost(route)
	if GameManager and GameManager.player_data:
		if GameManager.player_data.gold < cost:
			journey_cancelled.emit(route, "Not enough gold")
			return false

		# Deduct cost
		GameManager.player_data.gold -= cost

	# Initialize journey state
	current_route = route
	current_segment = 0
	encounters_this_journey = 0
	current_state = JourneyState.TRAVELING

	journey_started.emit(route)
	print("[BoatTravelManager] Started journey: %s (cost: %d gold)" % [route.display_name, cost])

	# Begin processing segments
	_process_next_segment()
	return true


## Process the next segment of the journey
func _process_next_segment() -> void:
	if current_state != JourneyState.TRAVELING:
		return

	current_segment += 1
	var total_segments: int = current_route.journey_segments

	print("[BoatTravelManager] Processing segment %d/%d" % [current_segment, total_segments])

	# Advance game time for this segment
	var time_per_segment: float = current_route.travel_duration_hours / total_segments
	if GameManager:
		GameManager.advance_time(time_per_segment)

	journey_segment_complete.emit(current_segment, total_segments)

	# Roll for encounter
	if encounters_this_journey < current_route.max_encounters_per_journey:
		var encounter_resource: Resource = current_route.roll_encounter()
		if encounter_resource and encounter_resource is SeaEncounter:
			var encounter: SeaEncounter = encounter_resource as SeaEncounter
			_trigger_encounter(encounter)
			return

	# Check if journey complete
	if current_segment >= total_segments:
		_complete_journey()
	else:
		# Continue to next segment after a short delay (for UI purposes)
		# In actual gameplay this would be handled by the travel UI
		call_deferred("_process_next_segment")


## Trigger an encounter during travel
func _trigger_encounter(encounter: SeaEncounter) -> void:
	current_state = JourneyState.IN_ENCOUNTER
	pending_encounter = encounter
	encounters_this_journey += 1

	print("[BoatTravelManager] Encounter triggered: %s" % encounter.display_name)
	encounter_triggered.emit(encounter)

	# The encounter scene/UI should call resolve_encounter when done
	# For now, we'll handle different encounter types

	match encounter.encounter_type:
		SeaEncounter.EncounterType.STORM:
			_handle_storm_encounter(encounter)
		SeaEncounter.EncounterType.MERCHANT_SHIP:
			# Merchant encounters need UI interaction
			# The UI should call resolve_encounter when done
			pass
		SeaEncounter.EncounterType.ISLAND_DISCOVERY:
			_handle_island_discovery(encounter)
		_:
			# Combat encounters load a scene
			_load_encounter_scene(encounter)


## Handle storm encounter (no combat, just damage/cargo loss)
func _handle_storm_encounter(encounter: SeaEncounter) -> void:
	var results: Dictionary = encounter.apply_storm_effects()

	# Apply damage to player
	if GameManager and GameManager.player_data and results.damage_dealt > 0:
		GameManager.player_data.take_damage(results.damage_dealt)
		print("[BoatTravelManager] Storm dealt %d damage" % results.damage_dealt)

	# Cargo loss chance
	if randf() < results.get("cargo_loss_chance", 0.0):
		# Could remove random items from inventory here
		print("[BoatTravelManager] Lost some cargo in the storm!")

	resolve_encounter(EncounterResult.STORM_SURVIVED)


## Handle island discovery
func _handle_island_discovery(encounter: SeaEncounter) -> void:
	# Mark island as discovered in WorldData
	if encounter.discovered_location_id:
		print("[BoatTravelManager] Discovered island: %s" % encounter.discovered_location_id)
		# WorldData integration would go here

	resolve_encounter(EncounterResult.DISCOVERED)


## Load the encounter combat scene
func _load_encounter_scene(encounter: SeaEncounter) -> void:
	if encounter.encounter_scene_path.is_empty():
		# Use a default encounter scene or handle in-place
		print("[BoatTravelManager] No scene for encounter, resolving immediately")
		# For now, auto-resolve (in real implementation, show combat UI)
		resolve_encounter(EncounterResult.VICTORY)
		return

	# Store encounter data for the scene
	# SceneManager integration
	if SceneManager:
		SceneManager.change_scene(encounter.encounter_scene_path, "encounter_spawn")


## Resolve the current encounter
func resolve_encounter(result: EncounterResult) -> void:
	if current_state != JourneyState.IN_ENCOUNTER:
		push_warning("[BoatTravelManager] Cannot resolve encounter - not in encounter")
		return

	if not pending_encounter:
		push_warning("[BoatTravelManager] No pending encounter to resolve")
		return

	print("[BoatTravelManager] Encounter resolved: %s" % EncounterResult.keys()[result])

	# Handle rewards based on result
	match result:
		EncounterResult.VICTORY:
			_award_encounter_loot(pending_encounter)
		EncounterResult.PEACEFUL:
			# Reduced rewards for peaceful resolution
			_award_encounter_xp(pending_encounter, 0.5)
		EncounterResult.TRADED:
			# Merchant interaction handled separately
			pass
		EncounterResult.FLED:
			# No rewards for fleeing
			pass
		EncounterResult.FAILED:
			# Player defeated - journey ends
			journey_cancelled.emit(current_route, "Defeated in encounter")
			_reset_journey_state()
			encounter_resolved.emit(pending_encounter, result)
			return

	encounter_resolved.emit(pending_encounter, result)
	pending_encounter = null
	current_state = JourneyState.TRAVELING

	# Check if journey complete, otherwise continue
	if current_segment >= current_route.journey_segments:
		_complete_journey()
	else:
		call_deferred("_process_next_segment")


## Award loot from an encounter
func _award_encounter_loot(encounter: SeaEncounter) -> void:
	# Award XP
	_award_encounter_xp(encounter, 1.0)

	# Award gold
	var gold: int = encounter.roll_gold_reward()
	if GameManager and GameManager.player_data:
		GameManager.player_data.gold += gold
		print("[BoatTravelManager] Awarded %d gold" % gold)

	# Award guaranteed loot
	for item_id in encounter.guaranteed_loot:
		if InventoryManager:
			InventoryManager.add_item(item_id, 1)
			print("[BoatTravelManager] Awarded item: %s" % item_id)

	# Roll loot table
	if LootTables:
		for i in range(encounter.loot_rolls):
			var tier: int = encounter.loot_tier
			var loot: Array[Dictionary] = LootTables.generate_enemy_loot(tier + 2)
			for drop in loot:
				var item_id: String = drop.get("item_id", "")
				var quantity: int = drop.get("quantity", 1)
				if item_id == "_gold":
					if GameManager and GameManager.player_data:
						GameManager.player_data.gold += quantity
				elif item_id and InventoryManager:
					InventoryManager.add_item(item_id, quantity)


## Award XP from encounter
func _award_encounter_xp(encounter: SeaEncounter, multiplier: float) -> void:
	var xp: int = int(encounter.xp_reward * multiplier)
	if GameManager and GameManager.player_data:
		GameManager.player_data.add_ip(xp)
		print("[BoatTravelManager] Awarded %d XP" % xp)


## Complete the journey
func _complete_journey() -> void:
	current_state = JourneyState.COMPLETE

	print("[BoatTravelManager] Journey complete: %s" % current_route.display_name)
	print("[BoatTravelManager] Faced %d encounters" % encounters_this_journey)

	# Teleport player to destination
	# This would integrate with SceneManager/WorldData to load destination scene
	var destination: String = current_route.destination_port
	print("[BoatTravelManager] Player arrived at: %s" % destination)

	journey_complete.emit(current_route, encounters_this_journey)
	_reset_journey_state()


## Attempt to flee from current encounter
## Returns true if flee successful
func attempt_flee() -> bool:
	if current_state != JourneyState.IN_ENCOUNTER or not pending_encounter:
		return false

	if not pending_encounter.can_flee:
		print("[BoatTravelManager] Cannot flee from this encounter")
		return false

	# Use AGILITY + ATHLETICS for flee check
	var flee_skill: int = 0
	if GameManager and GameManager.player_data:
		var agility: int = GameManager.player_data.get_effective_stat(Enums.Stat.AGILITY)
		var athletics: int = GameManager.player_data.get_skill(Enums.Skill.ATHLETICS)
		flee_skill = agility + athletics

	# Roll flee check using DiceManager if available
	var success: bool = false
	if DiceManager:
		var result: Dictionary = DiceManager.skill_check(
			flee_skill,
			pending_encounter.flee_difficulty * 2  # Convert 1-10 to DC
		)
		success = result.get("success", false)
	else:
		# Fallback simple roll
		var roll: int = randi_range(1, 20) + flee_skill
		success = roll >= pending_encounter.flee_difficulty * 2

	if success:
		resolve_encounter(EncounterResult.FLED)
		return true
	else:
		print("[BoatTravelManager] Flee attempt failed!")
		return false


## Attempt peaceful resolution of encounter
func attempt_peaceful_resolution() -> bool:
	if current_state != JourneyState.IN_ENCOUNTER or not pending_encounter:
		return false

	if not pending_encounter.can_resolve_peacefully:
		print("[BoatTravelManager] Cannot resolve this encounter peacefully")
		return false

	# Get the skill for peaceful resolution
	var skill_value: int = 0
	if GameManager and GameManager.player_data:
		skill_value = GameManager.player_data.get_skill(pending_encounter.peaceful_skill)

	# Roll skill check
	var success: bool = false
	if DiceManager:
		var result: Dictionary = DiceManager.skill_check(
			skill_value,
			pending_encounter.peaceful_skill_dc
		)
		success = result.get("success", false)
	else:
		var roll: int = randi_range(1, 20) + skill_value
		success = roll >= pending_encounter.peaceful_skill_dc

	if success:
		resolve_encounter(EncounterResult.PEACEFUL)
		return true
	else:
		print("[BoatTravelManager] Peaceful resolution failed!")
		return false


## Cancel the current journey
func cancel_journey(reason: String = "Player cancelled") -> void:
	if current_state == JourneyState.IDLE:
		return

	journey_cancelled.emit(current_route, reason)
	_reset_journey_state()


## Reset journey state
func _reset_journey_state() -> void:
	current_state = JourneyState.IDLE
	current_route = null
	current_segment = 0
	encounters_this_journey = 0
	pending_encounter = null


## Check if currently traveling
func is_traveling() -> bool:
	return current_state != JourneyState.IDLE


## Check if in an encounter
func is_in_encounter() -> bool:
	return current_state == JourneyState.IN_ENCOUNTER


## Get current journey progress (0.0 to 1.0)
func get_journey_progress() -> float:
	if not current_route or current_route.journey_segments == 0:
		return 0.0
	return float(current_segment) / float(current_route.journey_segments)


## Get current route being traveled
func get_current_route() -> BoatTravelData:
	return current_route


## Get current encounter
func get_current_encounter() -> SeaEncounter:
	return pending_encounter


# =============================================================================
# HEX WAYPOINT TRAVEL SYSTEM
# =============================================================================

## Start a sea route journey using hex waypoints
func start_sea_route_journey(route_id: String) -> bool:
	if current_state != JourneyState.IDLE:
		push_warning("[BoatTravelManager] Cannot start journey - already traveling")
		return false

	if not sea_routes.has(route_id):
		push_warning("[BoatTravelManager] Sea route not found: %s" % route_id)
		return false

	var route_data: Dictionary = sea_routes[route_id]
	var cost: int = route_data.get("base_cost", 50)

	# Check player can afford
	if InventoryManager and InventoryManager.get_gold() < cost:
		journey_cancelled.emit(null, "Not enough gold (need %d)" % cost)
		return false

	# Deduct cost
	if InventoryManager:
		InventoryManager.remove_gold(cost)

	# Initialize journey
	current_waypoints = route_data.get("waypoints", [])
	current_waypoint_index = 0
	current_segment = 0
	encounters_this_journey = 0
	current_state = JourneyState.TRAVELING

	print("[BoatTravelManager] Started sea route: %s (cost: %d gold)" % [route_id, cost])

	# Process waypoints
	_process_sea_travel_segment()
	return true


## Process a segment of sea travel (waypoint to waypoint)
func _process_sea_travel_segment() -> void:
	if current_state != JourneyState.TRAVELING:
		return

	if current_waypoint_index >= current_waypoints.size():
		_complete_sea_journey()
		return

	var waypoint: Vector2i = current_waypoints[current_waypoint_index]
	current_segment += 1

	print("[BoatTravelManager] Reached waypoint %d: %s" % [current_waypoint_index, waypoint])

	# Advance time for this segment (1.5 hours per waypoint)
	if GameManager and GameManager.has_method("advance_time"):
		GameManager.advance_time(1.5)

	journey_segment_complete.emit(current_segment, current_waypoints.size())

	# Check for sea encounter at this waypoint
	var encounter_type: String = _check_sea_encounter(waypoint)
	if not encounter_type.is_empty():
		encounters_this_journey += 1
		print("[BoatTravelManager] Sea encounter at waypoint: %s" % encounter_type)
		_trigger_sea_encounter(encounter_type, waypoint)
		return  # Encounter must resolve before continuing

	# Move to next waypoint
	current_waypoint_index += 1
	call_deferred("_process_sea_travel_segment")


## Check for sea encounter at a waypoint
func _check_sea_encounter(waypoint: Vector2i) -> String:
	# Check if waypoint is within any encounter zone
	for zone_id: String in encounter_zones:
		var zone: Dictionary = encounter_zones[zone_id]
		var center := Vector2i(zone.q_center, zone.r_center)
		var distance: int = _hex_distance(waypoint, center)

		if distance <= zone.radius:
			# Inside encounter zone - roll for encounter
			var encounter_chance: float = 0.3  # 30% base chance per zone
			if randf() < encounter_chance:
				# Pick random encounter type from zone
				var types: Array = zone.get("encounter_types", [])
				if not types.is_empty():
					return types[randi() % types.size()]

	# Generic sea encounter chance outside zones
	if randf() < 0.1:  # 10% generic chance
		var generic_encounters: Array[String] = ["storm", "floating_debris", "dolphins"]
		return generic_encounters[randi() % generic_encounters.size()]

	return ""


## Calculate hex distance (axial coordinates)
func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2


## Trigger a sea-specific encounter
func _trigger_sea_encounter(encounter_type: String, waypoint: Vector2i) -> void:
	current_state = JourneyState.IN_ENCOUNTER

	match encounter_type:
		"pirate":
			print("[BoatTravelManager] Pirates attacking!")
			_handle_pirate_encounter()
		"ghost_pirate":
			print("[BoatTravelManager] Ghost pirates emerging from the mist!")
			_handle_ghost_pirate_encounter()
		"sea_monster":
			print("[BoatTravelManager] Sea monster spotted!")
			_handle_sea_monster_encounter()
		"storm":
			print("[BoatTravelManager] Storm approaching!")
			_handle_storm_at_sea()
		"floating_debris":
			print("[BoatTravelManager] Debris in the water - may contain treasure!")
			_handle_debris_encounter()
		"dolphins":
			print("[BoatTravelManager] Dolphins swimming alongside - good omen!")
			_resolve_sea_encounter_peaceful()
		_:
			# Unknown encounter type - resolve peacefully
			_resolve_sea_encounter_peaceful()


## Handle pirate encounter
func _handle_pirate_encounter() -> void:
	# Create dynamic encounter - could load pirate combat scene
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Pirates attacking!", Color(1.0, 0.3, 0.3))

	# For now, auto-resolve with player taking some damage
	if GameManager and GameManager.player_data:
		var damage: int = randi_range(10, 30)
		GameManager.player_data.current_hp = maxi(1, GameManager.player_data.current_hp - damage)
		print("[BoatTravelManager] Pirate battle - took %d damage" % damage)

	# Award some loot
	if InventoryManager:
		InventoryManager.add_gold(randi_range(20, 50))
		print("[BoatTravelManager] Looted pirate gold!")

	_resolve_sea_encounter_victory()


## Handle ghost pirate encounter
func _handle_ghost_pirate_encounter() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("The undead rise from the waves!", Color(0.6, 0.8, 1.0))

	# Tougher than regular pirates
	if GameManager and GameManager.player_data:
		var damage: int = randi_range(20, 40)
		GameManager.player_data.current_hp = maxi(1, GameManager.player_data.current_hp - damage)
		print("[BoatTravelManager] Ghost pirate battle - took %d damage" % damage)

	# Rare loot chance
	if randf() < 0.3 and InventoryManager:
		InventoryManager.add_gold(randi_range(50, 100))
		print("[BoatTravelManager] Found ghost pirate treasure!")

	_resolve_sea_encounter_victory()


## Handle sea monster encounter
func _handle_sea_monster_encounter() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("SEA MONSTER!", Color(0.3, 0.8, 0.3))

	# Very dangerous
	if GameManager and GameManager.player_data:
		var damage: int = randi_range(30, 60)
		GameManager.player_data.current_hp = maxi(1, GameManager.player_data.current_hp - damage)
		print("[BoatTravelManager] Sea monster attack - took %d damage" % damage)

	# High XP reward
	if GameManager and GameManager.player_data:
		GameManager.player_data.add_ip(100)
		print("[BoatTravelManager] Sea monster slain - 100 XP!")

	_resolve_sea_encounter_victory()


## Handle storm at sea
func _handle_storm_at_sea() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Storm! Hold on!", Color(0.5, 0.5, 0.7))

	# Small chance of damage
	if randf() < 0.3 and GameManager and GameManager.player_data:
		var damage: int = randi_range(5, 15)
		GameManager.player_data.current_hp = maxi(1, GameManager.player_data.current_hp - damage)
		print("[BoatTravelManager] Injured in storm - took %d damage" % damage)

	_resolve_sea_encounter_peaceful()


## Handle debris encounter
func _handle_debris_encounter() -> void:
	# Chance to find treasure
	if randf() < 0.5 and InventoryManager:
		var gold: int = randi_range(5, 25)
		InventoryManager.add_gold(gold)
		print("[BoatTravelManager] Found %d gold in debris!" % gold)

	_resolve_sea_encounter_peaceful()


## Resolve sea encounter with victory
func _resolve_sea_encounter_victory() -> void:
	current_state = JourneyState.TRAVELING
	current_waypoint_index += 1
	call_deferred("_process_sea_travel_segment")


## Resolve sea encounter peacefully
func _resolve_sea_encounter_peaceful() -> void:
	current_state = JourneyState.TRAVELING
	current_waypoint_index += 1
	call_deferred("_process_sea_travel_segment")


## Complete the sea journey
func _complete_sea_journey() -> void:
	current_state = JourneyState.COMPLETE

	print("[BoatTravelManager] Sea journey complete!")
	print("[BoatTravelManager] Faced %d encounters" % encounters_this_journey)

	# Get destination port
	var destination: String = ""
	for route_id: String in sea_routes:
		var route: Dictionary = sea_routes[route_id]
		if route.waypoints == current_waypoints:
			destination = route.to_port
			break

	if not destination.is_empty():
		print("[BoatTravelManager] Arrived at: %s" % destination)
		# Teleport to destination
		if SceneManager:
			await SceneManager.dev_fast_travel_to(destination)

	journey_complete.emit(null, encounters_this_journey)
	_reset_journey_state()
	current_waypoints.clear()
	current_waypoint_index = 0


## Get available sea routes from a port
func get_sea_routes_from_port(port_id: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []

	for route_id: String in sea_routes:
		var route: Dictionary = sea_routes[route_id]
		if route.from_port == port_id:
			available.append({
				"id": route_id,
				"to_port": route.to_port,
				"cost": route.base_cost,
				"segments": route.travel_segments,
				"danger_zones": route.danger_zones
			})

	return available
