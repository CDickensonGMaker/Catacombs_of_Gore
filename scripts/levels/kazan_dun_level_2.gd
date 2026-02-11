## kazan_dun_level_2_modular.gd - The Residential Quarter of Kazan-Dun (Modular Version)
## Level 2: Noble Quarters, Common Quarters, Bathhouse, Storage Cellar
## Connects to: Level 1 (above), Level 3 (below)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_2"
	zone_display_name = "Kazan-Dun - Residential Quarter"
	zone_size = 120.0


## Register all rooms in this level
func _register_rooms() -> void:
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 2 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Connect stairwell to noble quarters
	connect_rooms("kd_stairwell_down_1", "door_south", "kd_noble_quarters", "door_north")

	# Connect noble quarters to corridor
	connect_rooms("kd_noble_quarters", "door_south", "kd_corridor_straight_1", "door_north")

	# Connect corridor to common quarters and bathhouse
	connect_rooms("kd_corridor_straight_1", "door_south", "kd_common_quarters", "door_north")
	connect_rooms("kd_common_quarters", "door_east", "kd_bathhouse", "door_west")

	# Connect to storage cellar
	connect_rooms("kd_common_quarters", "door_south", "kd_storage_cellar", "door_north")

	# Connect to Level 3 stairwell
	connect_rooms("kd_storage_cellar", "door_south", "kd_stairwell_down_2", "door_north")


## Setup level-specific environment
func _setup_environment() -> void:
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			# Slightly darker for residential areas
			world_env.environment.ambient_light_energy = 0.3
			world_env.environment.fog_density = 0.015
