## fast_travel_manager.gd - Handles fast travel between discovered locations
## Inspired by Daggerfall Unity's travel system with time passage
extends Node

signal travel_started(from_id: String, to_id: String, hours: float)
signal travel_completed(destination_id: String)
signal travel_interrupted(reason: String)

## Caravan travel signals
signal caravan_travel_started(from_location: String, to_location: String, cost: int)
signal caravan_encounter(segment: int, encounter_type: String)
signal caravan_travel_completed(destination: String, total_cost: int)

## Travel speed options
enum TravelSpeed {
	CAUTIOUS,   # Slower but safer, restore health
	NORMAL,     # Standard speed
	RECKLESS    # Faster but chance of encounters
}

## Travel mode (affects speed and encounters)
enum TravelMode {
	ROAD,       # Stick to roads (safer, slower if off-road)
	DIRECT      # Go direct (faster, more dangerous)
}

## Base hours per cell for travel
const BASE_HOURS_PER_CELL := 2.0
const ROAD_SPEED_BONUS := 0.5  # Roads are 50% faster
const RECKLESS_SPEED_BONUS := 0.3
const CAUTIOUS_SPEED_PENALTY := 0.5

## Encounter chance modifiers
const BASE_ENCOUNTER_CHANCE := 0.15
const RECKLESS_ENCOUNTER_BONUS := 0.2
const ROAD_ENCOUNTER_REDUCTION := 0.1
const NIGHT_ENCOUNTER_BONUS := 0.1

## Caravan pricing per hex based on danger level
## Low danger: 2 gold/hex, 5% encounter chance
## Medium danger: 3 gold/hex, 15% encounter chance
## High danger: 5 gold/hex, 25% encounter chance
const CARAVAN_COSTS: Dictionary = {
	"low": {"gold_per_hex": 2, "encounter_chance": 0.05},
	"medium": {"gold_per_hex": 3, "encounter_chance": 0.15},
	"high": {"gold_per_hex": 5, "encounter_chance": 0.25}
}

## Caravan route data - maps route_id to {from, to, road_id, danger_level}
## Loaded from hex_map_data.json roads
var caravan_routes: Dictionary = {}

## Current travel state
var is_traveling: bool = false
var travel_destination: String = ""
var travel_hours_remaining: float = 0.0

## Caravan travel state
var is_caravan_traveling: bool = false
var caravan_destination: String = ""
var caravan_segments: Array[Vector2i] = []
var caravan_current_segment: int = 0


## Check if fast travel is allowed to a destination
func can_fast_travel_to(destination_id: String) -> Dictionary:
	# In dev mode, skip discovery check (auto-discovered for testing)
	var is_dev_mode: bool = SceneManager.dev_mode if SceneManager else false

	# Must be discovered (unless in dev mode)
	if not is_dev_mode and not WorldManager.is_location_discovered(destination_id):
		return {"allowed": false, "reason": "Location not discovered"}

	# Can't travel to current location
	if destination_id == WorldManager.current_location_id:
		return {"allowed": false, "reason": "Already at this location"}

	# Check if player is in combat
	if GameManager and GameManager.player and GameManager.player.is_in_combat():
		return {"allowed": false, "reason": "Cannot fast travel during combat"}

	# Check for hostiles nearby (if applicable)
	# TODO: Add enemy proximity check

	return {"allowed": true, "reason": ""}


## Calculate travel time between two locations
func calculate_travel_time(from_id: String, to_id: String, speed: TravelSpeed = TravelSpeed.NORMAL, mode: TravelMode = TravelMode.ROAD) -> float:
	var from_coords := WorldManager.get_location_coords(from_id)
	var to_coords := WorldManager.get_location_coords(to_id)

	var hours: float = 0.0

	if mode == TravelMode.ROAD:
		# Use pathfinding along roads
		var path: Array[Vector2i] = WorldData.find_road_path(from_coords, to_coords)
		if path.is_empty():
			# No road path, fall back to direct
			hours = _calculate_direct_time(from_coords, to_coords)
		else:
			# Calculate time along path, accounting for road bonus
			for i: int in range(1, path.size()):
				var cell: WorldData.CellData = WorldData.get_cell(path[i])
				var cell_time: float = BASE_HOURS_PER_CELL
				if cell and cell.is_road:
					cell_time *= (1.0 - ROAD_SPEED_BONUS)
				hours += cell_time
	else:
		# Direct travel
		hours = _calculate_direct_time(from_coords, to_coords)

	# Apply speed modifiers
	match speed:
		TravelSpeed.CAUTIOUS:
			hours *= (1.0 + CAUTIOUS_SPEED_PENALTY)
		TravelSpeed.RECKLESS:
			hours *= (1.0 - RECKLESS_SPEED_BONUS)

	return maxf(hours, 0.5)  # Minimum 30 minutes


## Calculate direct travel time (Manhattan distance)
func _calculate_direct_time(from_coords: Vector2i, to_coords: Vector2i) -> float:
	var distance := absi(to_coords.x - from_coords.x) + absi(to_coords.y - from_coords.y)
	return distance * BASE_HOURS_PER_CELL


## Get estimated travel time to a destination from current location
func get_travel_estimate(destination_id: String, speed: TravelSpeed = TravelSpeed.NORMAL) -> Dictionary:
	var from_id := WorldManager.current_location_id
	if from_id.is_empty():
		# Use cell coords as fallback
		from_id = "current_cell"

	var hours := calculate_travel_time(from_id, destination_id, speed)
	var distance := WorldManager.get_distance_from_current(destination_id)

	return {
		"hours": hours,
		"distance": distance,
		"formatted": _format_travel_time(hours)
	}


## Format travel time for display
func _format_travel_time(hours: float) -> String:
	if hours < 1.0:
		return "%d minutes" % roundi(hours * 60)
	elif hours < 24.0:
		var h := floori(hours)
		var m := roundi((hours - h) * 60)
		if m > 0:
			return "%d hours %d minutes" % [h, m]
		else:
			return "%d hours" % h
	else:
		var days := floori(hours / 24.0)
		var remaining_hours := roundi(hours - days * 24)
		if remaining_hours > 0:
			return "%d days %d hours" % [days, remaining_hours]
		else:
			return "%d days" % days


## Perform fast travel to a destination
func travel_to(destination_id: String, speed: TravelSpeed = TravelSpeed.NORMAL, mode: TravelMode = TravelMode.ROAD) -> bool:
	# Validate travel
	var check := can_fast_travel_to(destination_id)
	if not check.allowed:
		push_warning("[FastTravel] Cannot travel: " + check.reason)
		return false

	var from_id := WorldManager.current_location_id
	var hours := calculate_travel_time(from_id, destination_id, speed, mode)

	is_traveling = true
	travel_destination = destination_id
	travel_hours_remaining = hours

	travel_started.emit(from_id, destination_id, hours)

	# Apply travel effects
	_apply_travel_effects(hours, speed)

	# Check for random encounters (reckless mode has higher chance)
	var encounter := _check_for_encounter(speed, mode, hours)
	if encounter:
		is_traveling = false
		travel_interrupted.emit("Ambush!")
		return false  # Travel interrupted

	# Complete travel
	_complete_travel(destination_id)
	return true


## Apply effects of travel (time passage, health regen for cautious)
func _apply_travel_effects(hours: float, speed: TravelSpeed) -> void:
	# Advance game time
	if GameManager and GameManager.has_method("advance_time"):
		GameManager.advance_time(hours)

	# Cautious travel restores health
	if speed == TravelSpeed.CAUTIOUS and GameManager and GameManager.player_data:
		var heal_amount := roundi(GameManager.player_data.max_hp * 0.5)
		GameManager.player_data.heal(heal_amount)

	# Consume food/supplies (future feature)
	# TODO: Add food consumption during travel


## Check for random encounters during travel
func _check_for_encounter(speed: TravelSpeed, mode: TravelMode, hours: float) -> bool:
	# Base chance modified by factors
	var chance := BASE_ENCOUNTER_CHANCE

	# Speed modifiers
	if speed == TravelSpeed.RECKLESS:
		chance += RECKLESS_ENCOUNTER_BONUS
	elif speed == TravelSpeed.CAUTIOUS:
		chance -= 0.05

	# Mode modifiers
	if mode == TravelMode.ROAD:
		chance -= ROAD_ENCOUNTER_REDUCTION
	else:
		chance += 0.05  # Direct travel is riskier

	# Night travel is more dangerous
	# TODO: Check DayNightCycle for time of day

	# Longer trips have more encounter opportunities
	var encounter_checks: int = ceili(hours / 4.0)  # Check every 4 hours
	for i: int in range(encounter_checks):
		if randf() < chance:
			return true

	return false


## Complete travel to destination
func _complete_travel(destination_id: String) -> void:
	is_traveling = false
	travel_destination = ""
	travel_hours_remaining = 0.0

	# Use SceneManager to travel
	if SceneManager:
		await SceneManager.dev_fast_travel_to(destination_id)

	travel_completed.emit(destination_id)


## Get list of valid fast travel destinations
func get_valid_destinations() -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []

	for loc: Dictionary in WorldManager.get_discovered_locations():
		var loc_id: String = loc.id
		if can_fast_travel_to(loc_id).allowed:
			var estimate: Dictionary = get_travel_estimate(loc_id)
			destinations.append({
				"id": loc_id,
				"name": loc.name,
				"type": loc.type,
				"coords": loc.coords,
				"distance": estimate.distance,
				"travel_time": estimate.formatted
			})

	# Sort by distance
	destinations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.distance < b.distance
	)

	return destinations


## Serialize for saving (not much state to save)
func to_dict() -> Dictionary:
	return {
		"is_traveling": is_traveling,
		"travel_destination": travel_destination,
		"travel_hours_remaining": travel_hours_remaining
	}


## Deserialize from save
func from_dict(data: Dictionary) -> void:
	is_traveling = data.get("is_traveling", false)
	travel_destination = data.get("travel_destination", "")
	travel_hours_remaining = data.get("travel_hours_remaining", 0.0)


# =============================================================================
# CARAVAN TRAVEL SYSTEM
# =============================================================================

func _ready() -> void:
	# Load caravan routes from hex_map_data.json
	_load_caravan_routes()


## Load caravan routes from hex_map_data.json
func _load_caravan_routes() -> void:
	var file_path := "res://data/world/hex_map_data.json"
	if not FileAccess.file_exists(file_path):
		push_warning("[FastTravelManager] hex_map_data.json not found")
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
	if not hex_data.has("roads"):
		return

	# Build caravan routes from roads
	for road: Dictionary in hex_data["roads"]:
		var road_id: String = road.get("id", "")
		var connects: Array = road.get("connects", [])
		var danger_level: float = road.get("danger_level", 1.0)
		var hexes: Array = road.get("hexes", [])

		if connects.size() >= 2:
			# Create route from first to second connection
			var route_id: String = "%s_to_%s" % [connects[0], connects[1]]
			caravan_routes[route_id] = {
				"from": connects[0],
				"to": connects[1],
				"road_id": road_id,
				"road_name": road.get("name", road_id),
				"danger_level": danger_level,
				"hexes": hexes
			}

			# Also add reverse route
			var reverse_id: String = "%s_to_%s" % [connects[1], connects[0]]
			var reversed_hexes: Array = hexes.duplicate()
			reversed_hexes.reverse()
			caravan_routes[reverse_id] = {
				"from": connects[1],
				"to": connects[0],
				"road_id": road_id,
				"road_name": road.get("name", road_id),
				"danger_level": danger_level,
				"hexes": reversed_hexes
			}

	print("[FastTravelManager] Loaded %d caravan routes" % caravan_routes.size())


## Get available caravan destinations from a location
func get_caravan_destinations(from_location: String) -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []

	for route_id: String in caravan_routes:
		var route: Dictionary = caravan_routes[route_id]
		if route.from == from_location:
			var cost: int = calculate_caravan_cost(from_location, route.to)
			var danger: String = _get_danger_tier(route.danger_level)
			destinations.append({
				"to": route.to,
				"route_id": route_id,
				"road_name": route.road_name,
				"cost": cost,
				"danger": danger,
				"hex_count": route.hexes.size()
			})

	return destinations


## Calculate caravan cost based on hex distance and danger level
func calculate_caravan_cost(from_location: String, to_location: String) -> int:
	var route: Dictionary = _find_caravan_route(from_location, to_location)
	if route.is_empty():
		return -1  # No route available

	var hex_count: int = route.hexes.size()
	var danger_tier: String = _get_danger_tier(route.danger_level)
	var cost_data: Dictionary = CARAVAN_COSTS.get(danger_tier, CARAVAN_COSTS["medium"])

	return hex_count * cost_data.gold_per_hex


## Find a caravan route between two locations
func _find_caravan_route(from_location: String, to_location: String) -> Dictionary:
	var route_id: String = "%s_to_%s" % [from_location, to_location]
	return caravan_routes.get(route_id, {})


## Get danger tier from danger level
func _get_danger_tier(danger_level: float) -> String:
	if danger_level < 0.9:
		return "low"
	elif danger_level > 1.3:
		return "high"
	return "medium"


## Check if caravan travel is available between two locations
func can_travel_by_caravan(from_location: String, to_location: String) -> Dictionary:
	var route: Dictionary = _find_caravan_route(from_location, to_location)
	if route.is_empty():
		return {"allowed": false, "reason": "No caravan route available"}

	var cost: int = calculate_caravan_cost(from_location, to_location)
	if InventoryManager and InventoryManager.get_gold() < cost:
		return {"allowed": false, "reason": "Not enough gold (need %d)" % cost}

	return {"allowed": true, "reason": "", "cost": cost}


## Initiate caravan travel
func travel_by_caravan(from_location: String, to_location: String) -> bool:
	var check: Dictionary = can_travel_by_caravan(from_location, to_location)
	if not check.allowed:
		push_warning("[FastTravelManager] Caravan travel failed: %s" % check.reason)
		return false

	var route: Dictionary = _find_caravan_route(from_location, to_location)
	var cost: int = check.cost

	# Deduct gold
	if InventoryManager:
		InventoryManager.remove_gold(cost)

	is_caravan_traveling = true
	caravan_destination = to_location

	# Build segment list
	caravan_segments.clear()
	for hex_data in route.hexes:
		var hex_array: Array = hex_data
		caravan_segments.append(Vector2i(int(hex_array[0]), int(hex_array[1])))
	caravan_current_segment = 0

	print("[FastTravelManager] Caravan travel started: %s -> %s, cost: %d gold" % [from_location, to_location, cost])
	caravan_travel_started.emit(from_location, to_location, cost)

	# Process travel segments
	var encounters_happened: int = 0
	var danger_tier: String = _get_danger_tier(route.danger_level)

	for i in range(caravan_segments.size()):
		caravan_current_segment = i
		var encounter: bool = _check_caravan_encounter(danger_tier, i)
		if encounter:
			encounters_happened += 1
			caravan_encounter.emit(i, "ambush")
			# Could interrupt travel or just note the encounter

	# Advance time (roughly 1 hour per 2 hexes on caravan)
	var travel_hours: float = caravan_segments.size() * 0.5
	if GameManager and GameManager.has_method("advance_time"):
		GameManager.advance_time(travel_hours)

	# Complete travel
	is_caravan_traveling = false
	caravan_current_segment = 0

	# Teleport to destination
	if SceneManager:
		await SceneManager.dev_fast_travel_to(to_location)

	caravan_travel_completed.emit(to_location, cost)
	print("[FastTravelManager] Caravan travel completed. Encounters: %d" % encounters_happened)

	return true


## Check for encounter during caravan segment
func _check_caravan_encounter(danger_tier: String, segment: int) -> bool:
	var cost_data: Dictionary = CARAVAN_COSTS.get(danger_tier, CARAVAN_COSTS["medium"])
	var encounter_chance: float = cost_data.encounter_chance

	return randf() < encounter_chance


## Get caravan route info for display
func get_caravan_route_info(from_location: String, to_location: String) -> Dictionary:
	var route: Dictionary = _find_caravan_route(from_location, to_location)
	if route.is_empty():
		return {}

	var cost: int = calculate_caravan_cost(from_location, to_location)
	var danger: String = _get_danger_tier(route.danger_level)
	var travel_time: float = route.hexes.size() * 0.5  # Hours

	return {
		"from": from_location,
		"to": to_location,
		"road_name": route.road_name,
		"cost": cost,
		"danger": danger,
		"hex_count": route.hexes.size(),
		"travel_time_hours": travel_time,
		"travel_time_formatted": _format_travel_time(travel_time)
	}
