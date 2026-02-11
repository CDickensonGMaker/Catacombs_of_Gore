## room_edge.gd - Full-wall edge trigger for wilderness room transitions
## Creates a trigger zone that covers the entire edge of a room
## Fixes issues with narrow triggers and collision gaps
class_name RoomEdge
extends Area3D

## Edge directions
enum Direction { NORTH, SOUTH, EAST, WEST }

## Configuration
@export var direction: Direction = Direction.NORTH
@export var room_size: float = 100.0  # Size of the room (edge will match this)
@export var trigger_depth: float = 10.0  # How deep into the room the trigger extends

## Signals
signal edge_entered(edge_direction: Direction)

## State
var player_in_edge: bool = false


func _ready() -> void:
	add_to_group("room_edges")

	# Setup collision - CRITICAL: Use layer 0 for the edge, mask 2 to detect player
	# Area3D doesn't need a collision_layer for detection, only collision_mask
	collision_layer = 0
	collision_mask = 2  # Player layer
	monitoring = true
	monitorable = false

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_edge = true
	edge_entered.emit(direction)
	print("[RoomEdge] Player entered %s edge" % Direction.keys()[direction])


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_edge = false


## Create collision shape for this edge
## Called after adding to scene tree
func setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "EdgeCollision"
	var box := BoxShape3D.new()

	# Full wall coverage - 100 units long, 10 units deep, 4 units high
	# Position at Y=0 so it covers Y=0 to Y=4 (player is Y=0 to Y=1.8)
	match direction:
		Direction.NORTH, Direction.SOUTH:
			# East-West aligned edge (covers X axis)
			box.size = Vector3(room_size, 4.0, trigger_depth)
		Direction.EAST, Direction.WEST:
			# North-South aligned edge (covers Z axis)
			box.size = Vector3(trigger_depth, 4.0, room_size)

	col_shape.shape = box
	# Position at Y=2 means box extends from Y=0 to Y=4 (half-extent is 2)
	col_shape.position = Vector3(0, 2, 0)
	add_child(col_shape)


## Get the opposite direction (for spawning player on other side)
static func get_opposite(dir: Direction) -> Direction:
	match dir:
		Direction.NORTH: return Direction.SOUTH
		Direction.SOUTH: return Direction.NORTH
		Direction.EAST: return Direction.WEST
		Direction.WEST: return Direction.EAST
	return Direction.NORTH


## Get spawn offset for player entering from this direction
## Player spawns near the edge they entered from (just inside the room)
static func get_spawn_offset(from_direction: Direction, room_size: float) -> Vector3:
	var margin := 15.0  # Distance from edge to spawn player
	match from_direction:
		Direction.NORTH:
			# Came from north, entered via north edge, spawn near north side
			return Vector3(0, 0.5, -room_size / 2.0 + margin)
		Direction.SOUTH:
			# Came from south, entered via south edge, spawn near south side
			return Vector3(0, 0.5, room_size / 2.0 - margin)
		Direction.EAST:
			# Came from east, entered via east edge, spawn near east side
			return Vector3(room_size / 2.0 - margin, 0.5, 0)
		Direction.WEST:
			# Came from west, entered via west edge, spawn near west side
			return Vector3(-room_size / 2.0 + margin, 0.5, 0)
	return Vector3(0, 0.5, 0)


## Static factory to create all 4 edges for a room
static func create_room_edges(parent: Node3D, room_size: float = 100.0) -> Dictionary:
	var edges: Dictionary = {}
	var half_size := room_size / 2.0
	var edge_offset := half_size + 5.0  # Position edge just outside room bounds

	# North edge (at -Z)
	var north := RoomEdge.new()
	north.name = "NorthEdge"
	north.direction = Direction.NORTH
	north.room_size = room_size
	north.position = Vector3(0, 0, -edge_offset)
	parent.add_child(north)
	north.setup_collision()
	edges[Direction.NORTH] = north

	# South edge (at +Z)
	var south := RoomEdge.new()
	south.name = "SouthEdge"
	south.direction = Direction.SOUTH
	south.room_size = room_size
	south.position = Vector3(0, 0, edge_offset)
	parent.add_child(south)
	south.setup_collision()
	edges[Direction.SOUTH] = south

	# East edge (at +X)
	var east := RoomEdge.new()
	east.name = "EastEdge"
	east.direction = Direction.EAST
	east.room_size = room_size
	east.position = Vector3(edge_offset, 0, 0)
	parent.add_child(east)
	east.setup_collision()
	edges[Direction.EAST] = east

	# West edge (at -X)
	var west := RoomEdge.new()
	west.name = "WestEdge"
	west.direction = Direction.WEST
	west.room_size = room_size
	west.position = Vector3(-edge_offset, 0, 0)
	parent.add_child(west)
	west.setup_collision()
	edges[Direction.WEST] = west

	return edges
