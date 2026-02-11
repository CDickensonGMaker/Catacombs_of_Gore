## kazan_dun_level_4_modular.gd - Deep Mines & Great Bridge of Kazan-Dun (Modular Version)
## Level 4: Main Forge, Mine Shaft, Bridge Spans, Bridge Gatehouse
## Connects to: Level 3 (above), Level 5 (below via bridge)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_4"
	zone_display_name = "Kazan-Dun - Deep Mines & Great Bridge"
	zone_size = 150.0


## Register all rooms in this level
func _register_rooms() -> void:
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 4 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Stairwell from Level 3 connects to Forge Main
	connect_rooms("kd_stairwell_down_1", "door_south", "kd_forge_main", "door_north")

	# Forge connects to Mine Shaft
	connect_rooms("kd_forge_main", "door_east", "kd_mine_shaft", "door_west")

	# Forge connects to Bridge Gatehouse (west side)
	connect_rooms("kd_forge_main", "door_south", "kd_bridge_gatehouse_1", "door_north")

	# Bridge spans across the chasm
	connect_rooms("kd_bridge_gatehouse_1", "door_south", "kd_bridge_span_1", "door_north")
	connect_rooms("kd_bridge_span_1", "door_south", "kd_bridge_span_2", "door_north")
	connect_rooms("kd_bridge_span_2", "door_south", "kd_bridge_span_3", "door_north")
	connect_rooms("kd_bridge_span_3", "door_south", "kd_bridge_gatehouse_2", "door_north")

	# East gatehouse connects to Level 5 stairwell
	connect_rooms("kd_bridge_gatehouse_2", "door_south", "kd_stairwell_down_2", "door_north")


## Setup level-specific environment - industrial/mine atmosphere
func _setup_environment() -> void:
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			# Dark industrial atmosphere with orange forge glow
			world_env.environment.ambient_light_energy = 0.2
			world_env.environment.ambient_light_color = Color(0.6, 0.45, 0.35)
			world_env.environment.fog_enabled = true
			world_env.environment.fog_density = 0.025
			world_env.environment.fog_light_color = Color(0.4, 0.3, 0.25)
