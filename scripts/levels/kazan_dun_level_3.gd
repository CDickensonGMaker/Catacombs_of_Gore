## kazan_dun_level_3_modular.gd - War Room & Treasury of Kazan-Dun (Modular Version)
## Level 3: Treasury, Armory, Command Center, Rune Ward Hall
## Connects to: Level 2 (above), Level 4 (below)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_3"
	zone_display_name = "Kazan-Dun - War Room & Treasury"
	zone_size = 100.0


## Register all rooms in this level
func _register_rooms() -> void:
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 3 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Stairwell from Level 2 connects to Command Center
	connect_rooms("kd_stairwell_down_1", "door_south", "kd_command_center", "door_north")

	# Command Center connects to corridors leading to Treasury and Armory
	connect_rooms("kd_command_center", "door_west", "kd_armory", "door_east")
	connect_rooms("kd_command_center", "door_east", "kd_treasury", "door_west")

	# Command Center connects south to Rune Ward Hall
	connect_rooms("kd_command_center", "door_south", "kd_corridor_straight_1", "door_north")
	connect_rooms("kd_corridor_straight_1", "door_south", "kd_rune_ward_hall", "door_north")

	# Rune Ward Hall connects to Level 4 stairwell
	connect_rooms("kd_rune_ward_hall", "door_south", "kd_stairwell_down_2", "door_north")


## Setup level-specific environment
func _setup_environment() -> void:
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			# Slightly more ominous lighting for the military/treasury area
			world_env.environment.ambient_light_energy = 0.28
			world_env.environment.ambient_light_color = Color(0.5, 0.45, 0.4)
			world_env.environment.fog_density = 0.018
