## marching_squares.gd - 2D mesh generation from boolean grid using marching squares algorithm
## Generates smooth floor/ceiling meshes from cellular automata cave data
## Maintains PS1 aesthetic with low-poly output
##
## TODO: [INACTIVE] This mesh generation system is complete but not integrated.
## Future work: Use for cave/dungeon floor/ceiling mesh generation.
class_name MarchingSquares
extends RefCounted


## Lookup table for marching squares edge cases
## Each case (0-15) defines which edges to connect
## Edge indices: 0=top, 1=right, 2=bottom, 3=left
## Values are arrays of edge pairs to connect
const EDGE_TABLE: Array = [
	[],                          # 0:  0000 - empty
	[[3, 2]],                    # 1:  0001 - bottom-left
	[[2, 1]],                    # 2:  0010 - bottom-right
	[[3, 1]],                    # 3:  0011 - bottom
	[[0, 1]],                    # 4:  0100 - top-right
	[[3, 0], [2, 1]],            # 5:  0101 - top-right + bottom-left (saddle)
	[[0, 2]],                    # 6:  0110 - right
	[[3, 0]],                    # 7:  0111 - all except top-left
	[[0, 3]],                    # 8:  1000 - top-left
	[[0, 2]],                    # 9:  1001 - left
	[[0, 3], [1, 2]],            # 10: 1010 - top-left + bottom-right (saddle)
	[[0, 1]],                    # 11: 1011 - all except top-right
	[[1, 3]],                    # 12: 1100 - top
	[[1, 2]],                    # 13: 1101 - all except bottom-right
	[[2, 3]],                    # 14: 1110 - all except bottom-left
	[],                          # 15: 1111 - full
]


## Generate floor mesh from a 2D boolean grid
## grid: 2D array where true = solid (wall), false = empty (floor)
## cell_size: World units per grid cell
## height_offset: Y position for the floor mesh
## Returns: ArrayMesh suitable for floor rendering and collision
static func generate_floor_mesh(grid: Array, cell_size: float, height_offset: float = 0.0) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()

	var grid_height: int = grid.size()
	if grid_height == 0:
		return null
	var grid_width: int = grid[0].size()

	# Generate floor polygons for empty cells (non-wall areas)
	# Using simple quad-based approach for PS1 aesthetic
	for y in range(grid_height):
		for x in range(grid_width):
			if not grid[y][x]:  # Empty cell = floor
				var base_idx: int = vertices.size()

				# Calculate world position
				var world_x: float = x * cell_size
				var world_z: float = y * cell_size

				# Add quad vertices (floor faces up)
				vertices.append(Vector3(world_x, height_offset, world_z))
				vertices.append(Vector3(world_x + cell_size, height_offset, world_z))
				vertices.append(Vector3(world_x + cell_size, height_offset, world_z + cell_size))
				vertices.append(Vector3(world_x, height_offset, world_z + cell_size))

				# UVs for texturing
				uvs.append(Vector2(0, 0))
				uvs.append(Vector2(1, 0))
				uvs.append(Vector2(1, 1))
				uvs.append(Vector2(0, 1))

				# Normals pointing up for floor
				for i in range(4):
					normals.append(Vector3.UP)

				# Two triangles per quad
				indices.append(base_idx)
				indices.append(base_idx + 1)
				indices.append(base_idx + 2)
				indices.append(base_idx)
				indices.append(base_idx + 2)
				indices.append(base_idx + 3)

	# Now generate smooth boundary edges using marching squares
	_add_boundary_geometry(grid, cell_size, height_offset, vertices, indices, uvs, normals, true)

	return _create_mesh_from_arrays(vertices, indices, uvs, normals)


## Generate ceiling mesh from a 2D boolean grid
## Similar to floor but normals face down and Y is offset by cave height
static func generate_ceiling_mesh(grid: Array, cell_size: float, height_offset: float, cave_height: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()

	var grid_height: int = grid.size()
	if grid_height == 0:
		return null
	var grid_width: int = grid[0].size()

	var ceiling_y: float = height_offset + cave_height

	# Generate ceiling polygons for empty cells
	for y in range(grid_height):
		for x in range(grid_width):
			if not grid[y][x]:  # Empty cell = ceiling above floor
				var base_idx: int = vertices.size()

				var world_x: float = x * cell_size
				var world_z: float = y * cell_size

				# Add quad vertices (ceiling faces down - reverse winding)
				vertices.append(Vector3(world_x, ceiling_y, world_z))
				vertices.append(Vector3(world_x, ceiling_y, world_z + cell_size))
				vertices.append(Vector3(world_x + cell_size, ceiling_y, world_z + cell_size))
				vertices.append(Vector3(world_x + cell_size, ceiling_y, world_z))

				uvs.append(Vector2(0, 0))
				uvs.append(Vector2(0, 1))
				uvs.append(Vector2(1, 1))
				uvs.append(Vector2(1, 0))

				# Normals pointing down for ceiling
				for i in range(4):
					normals.append(Vector3.DOWN)

				# Two triangles per quad (reverse winding for downward facing)
				indices.append(base_idx)
				indices.append(base_idx + 1)
				indices.append(base_idx + 2)
				indices.append(base_idx)
				indices.append(base_idx + 2)
				indices.append(base_idx + 3)

	# Add boundary geometry for ceiling
	_add_boundary_geometry(grid, cell_size, ceiling_y, vertices, indices, uvs, normals, false)

	return _create_mesh_from_arrays(vertices, indices, uvs, normals)


## Generate wall mesh between floor and ceiling at boundaries
## Creates vertical walls where empty cells meet solid cells
static func generate_wall_mesh(grid: Array, cell_size: float, floor_y: float, cave_height: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()

	var grid_height: int = grid.size()
	if grid_height == 0:
		return null
	var grid_width: int = grid[0].size()

	var ceiling_y: float = floor_y + cave_height

	# Check each cell for boundary edges
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x]:  # Solid cell
				continue

			var world_x: float = x * cell_size
			var world_z: float = y * cell_size

			# Check each direction for wall edges
			# North edge (negative Z direction in grid, but we check y-1)
			if y == 0 or grid[y - 1][x]:
				_add_wall_quad(
					vertices, indices, uvs, normals,
					Vector3(world_x, floor_y, world_z),
					Vector3(world_x + cell_size, floor_y, world_z),
					Vector3(world_x + cell_size, ceiling_y, world_z),
					Vector3(world_x, ceiling_y, world_z),
					Vector3(0, 0, -1)  # Normal pointing into empty cell
				)

			# South edge
			if y == grid_height - 1 or grid[y + 1][x]:
				_add_wall_quad(
					vertices, indices, uvs, normals,
					Vector3(world_x + cell_size, floor_y, world_z + cell_size),
					Vector3(world_x, floor_y, world_z + cell_size),
					Vector3(world_x, ceiling_y, world_z + cell_size),
					Vector3(world_x + cell_size, ceiling_y, world_z + cell_size),
					Vector3(0, 0, 1)
				)

			# West edge
			if x == 0 or grid[y][x - 1]:
				_add_wall_quad(
					vertices, indices, uvs, normals,
					Vector3(world_x, floor_y, world_z + cell_size),
					Vector3(world_x, floor_y, world_z),
					Vector3(world_x, ceiling_y, world_z),
					Vector3(world_x, ceiling_y, world_z + cell_size),
					Vector3(-1, 0, 0)
				)

			# East edge
			if x == grid_width - 1 or grid[y][x + 1]:
				_add_wall_quad(
					vertices, indices, uvs, normals,
					Vector3(world_x + cell_size, floor_y, world_z),
					Vector3(world_x + cell_size, floor_y, world_z + cell_size),
					Vector3(world_x + cell_size, ceiling_y, world_z + cell_size),
					Vector3(world_x + cell_size, ceiling_y, world_z),
					Vector3(1, 0, 0)
				)

	return _create_mesh_from_arrays(vertices, indices, uvs, normals)


## Add boundary geometry using marching squares for smoother edges
## This creates transition geometry at the edges of the cave
static func _add_boundary_geometry(
	grid: Array,
	cell_size: float,
	y_offset: float,
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	normals: PackedVector3Array,
	is_floor: bool
) -> void:
	var grid_height: int = grid.size()
	if grid_height < 2:
		return
	var grid_width: int = grid[0].size()
	if grid_width < 2:
		return

	var normal: Vector3 = Vector3.UP if is_floor else Vector3.DOWN

	# Process each 2x2 cell group for marching squares
	for y in range(grid_height - 1):
		for x in range(grid_width - 1):
			# Get the 4 corners (1 = solid/wall, 0 = empty/floor)
			var tl: int = 1 if grid[y][x] else 0
			var tr: int = 1 if grid[y][x + 1] else 0
			var br: int = 1 if grid[y + 1][x + 1] else 0
			var bl: int = 1 if grid[y + 1][x] else 0

			# Calculate case index
			var case_idx: int = (tl << 3) | (tr << 2) | (br << 1) | bl

			# Skip empty (0) and full (15) cases
			if case_idx == 0 or case_idx == 15:
				continue

			# Get edge pairs for this case
			var edges: Array = EDGE_TABLE[case_idx]
			if edges.is_empty():
				continue

			# Calculate cell world position
			var world_x: float = x * cell_size
			var world_z: float = y * cell_size
			var half_cell: float = cell_size * 0.5

			# Edge midpoints
			var edge_points: Array[Vector3] = [
				Vector3(world_x + half_cell, y_offset, world_z),              # 0: top
				Vector3(world_x + cell_size, y_offset, world_z + half_cell),  # 1: right
				Vector3(world_x + half_cell, y_offset, world_z + cell_size),  # 2: bottom
				Vector3(world_x, y_offset, world_z + half_cell),              # 3: left
			]

			# Center point for triangulation
			var center: Vector3 = Vector3(world_x + half_cell, y_offset, world_z + half_cell)

			# Create triangles for boundary transition
			for edge_pair in edges:
				var e1: int = edge_pair[0]
				var e2: int = edge_pair[1]

				var base_idx: int = vertices.size()

				# Add triangle from center to edge midpoints
				vertices.append(center)
				vertices.append(edge_points[e1])
				vertices.append(edge_points[e2])

				uvs.append(Vector2(0.5, 0.5))
				uvs.append(Vector2(0, 0))
				uvs.append(Vector2(1, 0))

				for i in range(3):
					normals.append(normal)

				if is_floor:
					indices.append(base_idx)
					indices.append(base_idx + 1)
					indices.append(base_idx + 2)
				else:
					# Reverse winding for ceiling
					indices.append(base_idx)
					indices.append(base_idx + 2)
					indices.append(base_idx + 1)


## Add a wall quad (4 vertices, 2 triangles)
static func _add_wall_quad(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	normals: PackedVector3Array,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	normal: Vector3
) -> void:
	var base_idx: int = vertices.size()

	vertices.append(v0)
	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)

	# UVs based on wall dimensions
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 0))

	for i in range(4):
		normals.append(normal)

	# Two triangles
	indices.append(base_idx)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)


## Create ArrayMesh from vertex data
static func _create_mesh_from_arrays(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	normals: PackedVector3Array
) -> ArrayMesh:
	if vertices.is_empty():
		return null

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


## Generate a combined collision shape from the grid
## Returns StaticBody3D with collision shapes for all walls
static func generate_collision_body(grid: Array, cell_size: float, floor_y: float, cave_height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CaveCollision"

	var grid_height: int = grid.size()
	if grid_height == 0:
		return body
	var grid_width: int = grid[0].size()

	var ceiling_y: float = floor_y + cave_height

	# Create collision shapes for wall cells
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x]:  # Solid cell
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(cell_size, cave_height + 2.0, cell_size)  # Extra height for safety
				shape.shape = box
				shape.position = Vector3(
					x * cell_size + cell_size * 0.5,
					floor_y + cave_height * 0.5,
					y * cell_size + cell_size * 0.5
				)
				body.add_child(shape)

	# Floor collision
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(grid_width * cell_size, 1.0, grid_height * cell_size)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(
		grid_width * cell_size * 0.5,
		floor_y - 0.5,
		grid_height * cell_size * 0.5
	)
	body.add_child(floor_shape)

	# Ceiling collision
	var ceiling_shape := CollisionShape3D.new()
	var ceiling_box := BoxShape3D.new()
	ceiling_box.size = Vector3(grid_width * cell_size, 0.5, grid_height * cell_size)
	ceiling_shape.shape = ceiling_box
	ceiling_shape.position = Vector3(
		grid_width * cell_size * 0.5,
		ceiling_y + 0.25,
		grid_height * cell_size * 0.5
	)
	body.add_child(ceiling_shape)

	return body
