## room_template.gd - Resource defining a room template for procedural dungeons
class_name RoomTemplate
extends Resource

## Room identification
@export var room_id: String = ""
@export var room_type: String = "generic"  # entrance, corridor, guard, treasure, shrine, prison, boss

## Room dimensions (in world units)
@export var width: int = 10
@export var depth: int = 10
@export var height: int = 5
@export var floor_y: float = 0.0  # Y offset for multi-floor dungeons

## Door definitions - where other rooms can connect
## Each door: {"position": Vector3, "direction": Vector3, "width": float}
## direction: Vector3.LEFT, RIGHT, FORWARD, BACK (relative to room center)
@export var doors: Array[Dictionary] = []

## Spawn zones (local coordinates relative to room center)
@export var enemy_spawn_zones: Array[Vector3] = []
@export var loot_spawn_zones: Array[Vector3] = []
@export var spawner_zones: Array[Vector3] = []  # For EnemySpawner totems

## Enemy configuration
@export var min_enemies: int = 0
@export var max_enemies: int = 3
@export var enemy_data_paths: Array[String] = []  # Paths to .tres enemy data files
@export var enemy_sprite_paths: Array[String] = []  # Matching sprite paths (empty = mesh enemy)
@export var enemy_h_frames: Array[int] = []  # Sprite sheet columns
@export var enemy_v_frames: Array[int] = []  # Sprite sheet rows

## Loot configuration
@export var loot_tier: int = 1  # LootTables.LootTier value
@export var chest_count: int = 0
@export var chest_locked: bool = false
@export var chest_lock_dc: int = 10

## Special features
@export var has_rest_spot: bool = false
@export var rest_spot_name: String = "Rest Area"
@export var has_portal: bool = false
@export var portal_target_scene: String = ""
@export var portal_spawn_id: String = ""
@export var portal_display_name: String = ""

## Quest NPC configuration (for room_type "quest")
@export var has_quest_npc: bool = false
@export var quest_npc_name: String = "Dungeon Wanderer"
@export var quest_data_path: String = "res://data/quests/dungeon_clear.json"
@export var quest_npc_position: Vector3 = Vector3.ZERO  # Local offset from room center

## Visual customization
@export var floor_color: Color = Color(0.15, 0.13, 0.17)
@export var wall_color: Color = Color(0.2, 0.18, 0.22)
@export var ceiling_color: Color = Color(0.18, 0.16, 0.2)

## Decorations (coffins, pillars, etc.)
@export var decorations: Array[Dictionary] = []
# Example: {"type": "coffin", "position": Vector3, "rotation_y": float}

## Boss room specific
@export var is_boss_room: bool = false
@export var boss_data_path: String = ""
@export var boss_sprite_path: String = ""
@export var boss_h_frames: int = 4
@export var boss_v_frames: int = 4


## Get a random enemy configuration from this room's pool
func get_random_enemy() -> Dictionary:
	if enemy_data_paths.is_empty():
		return {}

	var idx := randi() % enemy_data_paths.size()
	return {
		"data_path": enemy_data_paths[idx],
		"sprite_path": enemy_sprite_paths[idx] if idx < enemy_sprite_paths.size() else "",
		"h_frames": enemy_h_frames[idx] if idx < enemy_h_frames.size() else 4,
		"v_frames": enemy_v_frames[idx] if idx < enemy_v_frames.size() else 4,
	}


## Get the bounds of this room as a Rect2 (for 2D map)
func get_bounds_2d() -> Rect2:
	return Rect2(
		Vector2(-width / 2.0, -depth / 2.0),
		Vector2(width, depth)
	)


## Get door on a specific side (or null if none)
func get_door_on_side(direction: Vector3) -> Dictionary:
	for door in doors:
		if door.has("direction") and door.direction.is_equal_approx(direction):
			return door
	return {}


## Check if room has a door on given side
func has_door_on_side(direction: Vector3) -> bool:
	return not get_door_on_side(direction).is_empty()


## Get all door directions
func get_door_directions() -> Array[Vector3]:
	var directions: Array[Vector3] = []
	for door in doors:
		if door.has("direction"):
			directions.append(door.direction)
	return directions


## Calculate spawn count for enemies
func get_enemy_spawn_count() -> int:
	if max_enemies <= min_enemies:
		return min_enemies
	return randi_range(min_enemies, max_enemies)


## Static helper to create a basic door definition
static func make_door(local_pos: Vector3, direction: Vector3, door_width: float = 4.0) -> Dictionary:
	return {
		"position": local_pos,
		"direction": direction,
		"width": door_width
	}


## Static helper to create a door flush against the wall edge
## Automatically calculates position based on room dimensions and direction
static func make_wall_door(room_width: int, room_depth: int, direction: Vector3, door_width: float = 4.0) -> Dictionary:
	var half_w := room_width / 2.0
	var half_d := room_depth / 2.0
	var pos := Vector3.ZERO

	# Position door at the center of the appropriate wall
	if direction.is_equal_approx(Vector3.FORWARD):  # North wall (+Z)
		pos = Vector3(0, 0, half_d)
	elif direction.is_equal_approx(Vector3.BACK):  # South wall (-Z)
		pos = Vector3(0, 0, -half_d)
	elif direction.is_equal_approx(Vector3.RIGHT):  # East wall (+X)
		pos = Vector3(half_w, 0, 0)
	elif direction.is_equal_approx(Vector3.LEFT):  # West wall (-X)
		pos = Vector3(-half_w, 0, 0)

	return {
		"position": pos,
		"direction": direction,
		"width": door_width
	}


## Validate and fix door positions to ensure they're flush against walls
func validate_doors() -> void:
	var half_w := width / 2.0
	var half_d := depth / 2.0

	for i in range(doors.size()):
		var door: Dictionary = doors[i]
		var dir: Vector3 = door.get("direction", Vector3.ZERO)
		var pos: Vector3 = door.get("position", Vector3.ZERO)
		var corrected_pos := pos

		# Ensure door position is at the wall edge for its direction
		if dir.is_equal_approx(Vector3.FORWARD):
			corrected_pos.z = half_d  # Must be at north wall
		elif dir.is_equal_approx(Vector3.BACK):
			corrected_pos.z = -half_d  # Must be at south wall
		elif dir.is_equal_approx(Vector3.RIGHT):
			corrected_pos.x = half_w  # Must be at east wall
		elif dir.is_equal_approx(Vector3.LEFT):
			corrected_pos.x = -half_w  # Must be at west wall

		if not pos.is_equal_approx(corrected_pos):
			print("[RoomTemplate] Corrected door position in '%s': %s -> %s" % [room_id, pos, corrected_pos])
			doors[i].position = corrected_pos


## Static helper to create a decoration definition
static func make_decoration(dec_type: String, local_pos: Vector3, rot_y: float = 0.0) -> Dictionary:
	return {
		"type": dec_type,
		"position": local_pos,
		"rotation_y": rot_y
	}
