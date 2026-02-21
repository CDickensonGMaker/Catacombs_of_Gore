## cell_edge.gd - Simple boundary walls for impassable terrain edges
## Replaces the old RoomEdge transition system
## Only creates collision walls - NO transition triggers
class_name CellEdge
extends StaticBody3D

## Direction enum for wall placement
enum Direction { NORTH, SOUTH, EAST, WEST }

## Default dimensions
const DEFAULT_WALL_HEIGHT := 10.0
const DEFAULT_WALL_THICKNESS := 2.0


## Create boundary walls on all impassable edges of a cell
## parent: Node to add walls to
## coords: Cell coordinates (Elder Moor-relative)
## cell_size: Size of the cell in world units
static func create_boundary_walls(parent: Node3D, coords: Vector2i, cell_size: float = 100.0) -> void:
	var directions: Dictionary = {
		Direction.NORTH: Vector2i(0, -1),
		Direction.SOUTH: Vector2i(0, 1),
		Direction.EAST: Vector2i(1, 0),
		Direction.WEST: Vector2i(-1, 0)
	}

	for dir: Direction in directions:
		var offset: Vector2i = directions[dir]
		var adjacent: Vector2i = coords + offset
		if not WorldGrid.is_passable(adjacent):
			var wall: StaticBody3D = _create_wall(dir, cell_size)
			parent.add_child(wall)


## Create a single boundary wall
static func _create_wall(direction: Direction, cell_size: float) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "BoundaryWall_%s" % Direction.keys()[direction]

	# Set collision layers - blocks player movement
	wall.collision_layer = 1  # World layer
	wall.collision_mask = 0   # Doesn't detect anything

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()

	var half_size: float = cell_size / 2.0

	# Configure shape and position based on direction
	match direction:
		Direction.NORTH:
			shape.size = Vector3(cell_size, DEFAULT_WALL_HEIGHT, DEFAULT_WALL_THICKNESS)
			collision.position = Vector3(0, DEFAULT_WALL_HEIGHT / 2.0, -half_size)
		Direction.SOUTH:
			shape.size = Vector3(cell_size, DEFAULT_WALL_HEIGHT, DEFAULT_WALL_THICKNESS)
			collision.position = Vector3(0, DEFAULT_WALL_HEIGHT / 2.0, half_size)
		Direction.EAST:
			shape.size = Vector3(DEFAULT_WALL_THICKNESS, DEFAULT_WALL_HEIGHT, cell_size)
			collision.position = Vector3(half_size, DEFAULT_WALL_HEIGHT / 2.0, 0)
		Direction.WEST:
			shape.size = Vector3(DEFAULT_WALL_THICKNESS, DEFAULT_WALL_HEIGHT, cell_size)
			collision.position = Vector3(-half_size, DEFAULT_WALL_HEIGHT / 2.0, 0)

	collision.shape = shape
	wall.add_child(collision)

	return wall


## Create visual boundary indicators (optional, for debugging or aesthetics)
## Creates visible mesh walls instead of invisible collision only
static func create_visible_boundaries(parent: Node3D, coords: Vector2i, cell_size: float = 100.0) -> void:
	var directions: Dictionary = {
		Direction.NORTH: Vector2i(0, -1),
		Direction.SOUTH: Vector2i(0, 1),
		Direction.EAST: Vector2i(1, 0),
		Direction.WEST: Vector2i(-1, 0)
	}

	for dir: Direction in directions:
		var offset: Vector2i = directions[dir]
		var adjacent: Vector2i = coords + offset
		if not WorldGrid.is_passable(adjacent):
			var wall: Node3D = _create_visible_wall(dir, cell_size)
			parent.add_child(wall)


## Create a visible wall with mesh
static func _create_visible_wall(direction: Direction, cell_size: float) -> Node3D:
	var wall_node: Node3D = Node3D.new()
	wall_node.name = "VisibleWall_%s" % Direction.keys()[direction]

	# Create collision
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()

	# Create mesh
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()

	var half_size: float = cell_size / 2.0
	var wall_height: float = 5.0  # Shorter for visibility

	# Configure based on direction
	match direction:
		Direction.NORTH:
			shape.size = Vector3(cell_size, wall_height, DEFAULT_WALL_THICKNESS)
			box_mesh.size = shape.size
			collision.position = Vector3(0, wall_height / 2.0, -half_size)
			mesh_instance.position = collision.position
		Direction.SOUTH:
			shape.size = Vector3(cell_size, wall_height, DEFAULT_WALL_THICKNESS)
			box_mesh.size = shape.size
			collision.position = Vector3(0, wall_height / 2.0, half_size)
			mesh_instance.position = collision.position
		Direction.EAST:
			shape.size = Vector3(DEFAULT_WALL_THICKNESS, wall_height, cell_size)
			box_mesh.size = shape.size
			collision.position = Vector3(half_size, wall_height / 2.0, 0)
			mesh_instance.position = collision.position
		Direction.WEST:
			shape.size = Vector3(DEFAULT_WALL_THICKNESS, wall_height, cell_size)
			box_mesh.size = shape.size
			collision.position = Vector3(-half_size, wall_height / 2.0, 0)
			mesh_instance.position = collision.position

	collision.shape = shape
	mesh_instance.mesh = box_mesh

	# Simple material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material

	static_body.add_child(collision)
	wall_node.add_child(static_body)
	wall_node.add_child(mesh_instance)

	return wall_node


## Check if a direction is blocked (has impassable adjacent cell)
static func is_direction_blocked(coords: Vector2i, direction: Direction) -> bool:
	var offsets: Dictionary = {
		Direction.NORTH: Vector2i(0, -1),
		Direction.SOUTH: Vector2i(0, 1),
		Direction.EAST: Vector2i(1, 0),
		Direction.WEST: Vector2i(-1, 0)
	}

	var adjacent: Vector2i = coords + offsets[direction]
	return not WorldGrid.is_passable(adjacent)


## Get the opposite direction
static func get_opposite(direction: Direction) -> Direction:
	match direction:
		Direction.NORTH: return Direction.SOUTH
		Direction.SOUTH: return Direction.NORTH
		Direction.EAST: return Direction.WEST
		Direction.WEST: return Direction.EAST
		_: return Direction.NORTH


## Convert direction to offset vector
static func direction_to_offset(direction: Direction) -> Vector2i:
	match direction:
		Direction.NORTH: return Vector2i(0, -1)
		Direction.SOUTH: return Vector2i(0, 1)
		Direction.EAST: return Vector2i(1, 0)
		Direction.WEST: return Vector2i(-1, 0)
		_: return Vector2i.ZERO


## Convert direction to 3D world direction
static func direction_to_world(direction: Direction) -> Vector3:
	match direction:
		Direction.NORTH: return Vector3(0, 0, -1)
		Direction.SOUTH: return Vector3(0, 0, 1)
		Direction.EAST: return Vector3(1, 0, 0)
		Direction.WEST: return Vector3(-1, 0, 0)
		_: return Vector3.ZERO
