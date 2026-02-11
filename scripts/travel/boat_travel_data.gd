## boat_travel_data.gd - Resource class for boat travel route definitions
## Stores route information between ports including duration, cost, and encounter chances
@tool
class_name BoatTravelData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Route")
## The port where this route departs from (location_id)
@export var departure_port: String = ""
## The destination port (location_id)
@export var destination_port: String = ""
## Whether this route can be traveled in reverse
@export var is_bidirectional: bool = true

@export_group("Time")
## Travel duration in game-time hours
@export var travel_duration_hours: float = 4.0
## Number of segments the journey is divided into (for encounter rolls)
@export var journey_segments: int = 3

@export_group("Encounters")
## Chance of an encounter per segment (0.0 to 1.0)
@export var encounter_chance_per_segment: float = 0.25
## Maximum encounters per journey (prevents endless combat)
@export var max_encounters_per_journey: int = 2
## Array of SeaEncounter resources that can occur on this route
@export var possible_encounters: Array[Resource] = []
## Weighted chances for each encounter (must match possible_encounters length)
@export var encounter_weights: Array[float] = []

@export_group("Cost")
## Base gold cost for passage
@export var base_cost: int = 50
## Whether the cost is affected by player's NEGOTIATION skill
@export var cost_negotiable: bool = true
## Minimum cost after negotiation (percentage of base)
@export var min_cost_multiplier: float = 0.5

@export_group("Requirements")
## Minimum player level to use this route (0 = no restriction)
@export var min_level: int = 0
## Quest that must be completed to unlock this route (empty = no requirement)
@export var required_quest_id: String = ""
## Time of day restrictions (empty = available all times)
@export var available_times: Array[int] = []  # Enums.TimeOfDay values

@export_group("Visuals")
## Scene to show during travel (optional, for cutscenes)
@export var travel_scene_path: String = ""
## Icon for the route on maps
@export var icon_path: String = ""


## Calculate the actual cost after negotiation skill
func get_negotiated_cost(negotiation_skill: int) -> int:
	if not cost_negotiable:
		return base_cost

	# Each point of negotiation reduces cost by 5%, max 50% reduction
	var discount: float = minf(negotiation_skill * 0.05, 1.0 - min_cost_multiplier)
	return int(base_cost * (1.0 - discount))


## Roll for an encounter based on segment chance
func roll_encounter() -> Resource:
	if randf() > encounter_chance_per_segment:
		return null

	if possible_encounters.is_empty():
		return null

	# Use weights if provided, otherwise equal chance
	if encounter_weights.size() == possible_encounters.size():
		return _weighted_random_encounter()
	else:
		return possible_encounters[randi() % possible_encounters.size()]


## Pick an encounter using weighted random selection
func _weighted_random_encounter() -> Resource:
	var total_weight: float = 0.0
	for weight in encounter_weights:
		total_weight += weight

	if total_weight <= 0.0:
		return possible_encounters[randi() % possible_encounters.size()]

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0

	for i in range(possible_encounters.size()):
		cumulative += encounter_weights[i]
		if roll <= cumulative:
			return possible_encounters[i]

	return possible_encounters[possible_encounters.size() - 1]


## Check if this route is available based on time of day
func is_available_at_time(time_of_day: int) -> bool:
	if available_times.is_empty():
		return true
	return time_of_day in available_times


## Check if player meets requirements for this route
func can_player_use(player_level: int, completed_quests: Array[String]) -> bool:
	if min_level > 0 and player_level < min_level:
		return false

	if not required_quest_id.is_empty() and required_quest_id not in completed_quests:
		return false

	return true


## Get the display name for departure port
func get_departure_name() -> String:
	# This would ideally look up the location name from WorldData
	return departure_port.capitalize().replace("_", " ")


## Get the display name for destination port
func get_destination_name() -> String:
	return destination_port.capitalize().replace("_", " ")
