## kazan_dun_level_1_modular.gd - The Great Hall of Kazan-Dun (Modular Version)
## Level 1: Feast Hall, Council Chamber, Kitchen connected by corridor
## Connects to: Entrance (outside), Level 2 (below)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_1"
	zone_display_name = "Kazan-Dun - Great Hall"
	zone_size = 100.0


## Register all rooms in this level
func _register_rooms() -> void:
	# Get references to instanced room nodes
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 1 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Connect Feast Hall to Council Chamber (north corridor)
	connect_rooms("kd_feast_hall", "door_north", "kd_great_hall_corridor", "door_south")
	connect_rooms("kd_great_hall_corridor", "door_north", "kd_council_chamber", "door_south")

	# Connect Feast Hall to Kitchen (west)
	connect_rooms("kd_feast_hall", "door_west", "kd_kitchen", "door_east")


## Setup level-specific environment overrides
func _setup_environment() -> void:
	# Use base environment but with slightly warmer lighting for the Great Hall
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			world_env.environment.ambient_light_energy = 0.4
