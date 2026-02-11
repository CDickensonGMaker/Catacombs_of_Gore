## kazan_dun_level_5_modular.gd - Goblin-Held Zone of Kazan-Dun (Modular Version)
## Level 5: Goblin Camp, Ritual Chamber, Throne Room (Boss), Barricades
## Connects to: Level 4 (above via bridge)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_5"
	zone_display_name = "Kazan-Dun - Goblin-Held Zone"
	zone_size = 120.0


## Register all rooms in this level
func _register_rooms() -> void:
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 5 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Stairwell from Level 4 connects to first barricade
	connect_rooms("kd_stairwell_down_1", "door_south", "kd_barricade_1", "door_north")

	# Barricade leads to Goblin Camp
	connect_rooms("kd_barricade_1", "door_south", "kd_goblin_camp", "door_north")

	# Goblin Camp connects to second barricade
	connect_rooms("kd_goblin_camp", "door_south", "kd_barricade_2", "door_north")

	# Second barricade leads to Ritual Chamber
	connect_rooms("kd_barricade_2", "door_south", "kd_ritual_chamber", "door_north")

	# Ritual Chamber connects to Throne Room (Boss arena)
	connect_rooms("kd_ritual_chamber", "door_south", "kd_throne_room", "door_north")


## Setup level-specific environment - corrupted goblin atmosphere
func _setup_environment() -> void:
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			# Dark, eerie green-tinted atmosphere for goblin lair
			world_env.environment.ambient_light_energy = 0.18
			world_env.environment.ambient_light_color = Color(0.4, 0.5, 0.35)
			world_env.environment.fog_enabled = true
			world_env.environment.fog_density = 0.03
			world_env.environment.fog_light_color = Color(0.3, 0.35, 0.25)
			world_env.environment.background_color = Color(0.08, 0.1, 0.07)
