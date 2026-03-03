## cave_generator.gd - Procedural cave generation using cellular automata
## Creates organic-looking cave rooms for dungeons
class_name CaveGenerator
extends RefCounted

## Grid cell states
const WALL := 1
const FLOOR := 0

## Generate a cave room using cellular automata
static func generate_cave_room(
	grid_width: int,
	grid_height: int,
	cell_size: float,
	height: float,
	floor_y: float,
	fill_percent: float,
	iterations: int,
	cave_seed: int
) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = cave_seed

	# Initialize grid with random noise
	var grid: Array[Array] = []
	for x in range(grid_width):
		var column: Array[int] = []
		for y in range(grid_height):
			# Edges are always walls
			if x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1:
				column.append(WALL)
			elif rng.randf() < fill_percent:
				column.append(WALL)
			else:
				column.append(FLOOR)
		grid.append(column)

	# Run cellular automata iterations
	for _i in range(iterations):
		grid = _smooth_grid(grid, grid_width, grid_height)

	# Generate mesh from grid
	var cave_node := Node3D.new()
	cave_node.name = "CaveRoom"

	# Store grid data for spawn position calculations
	cave_node.set_meta("cave_grid", grid)
	cave_node.set_meta("cell_size", cell_size)
	cave_node.set_meta("floor_y", floor_y)
	cave_node.set_meta("cave_height", height)

	# Create floor
	var floor_mesh := _create_cave_floor(grid, grid_width, grid_height, cell_size, floor_y)
	if floor_mesh:
		cave_node.add_child(floor_mesh)

	# Create walls
	var walls := _create_cave_walls(grid, grid_width, grid_height, cell_size, floor_y, height)
	for wall in walls:
		cave_node.add_child(wall)

	# Create ceiling
	var ceiling := _create_cave_ceiling(grid, grid_width, grid_height, cell_size, floor_y + height)
	if ceiling:
		cave_node.add_child(ceiling)

	return cave_node


## Smooth the grid using cellular automata rules
static func _smooth_grid(grid: Array[Array], width: int, height: int) -> Array[Array]:
	var new_grid: Array[Array] = []

	for x in range(width):
		var column: Array[int] = []
		for y in range(height):
			var wall_count := _count_walls_around(grid, x, y, width, height)
			if wall_count > 4:
				column.append(WALL)
			elif wall_count < 4:
				column.append(FLOOR)
			else:
				column.append(grid[x][y])
		new_grid.append(column)

	return new_grid


## Count walls in 3x3 area around cell
static func _count_walls_around(grid: Array[Array], cx: int, cy: int, width: int, height: int) -> int:
	var count := 0
	for x in range(cx - 1, cx + 2):
		for y in range(cy - 1, cy + 2):
			if x < 0 or x >= width or y < 0 or y >= height:
				count += 1  # Out of bounds = wall
			elif x != cx or y != cy:
				count += grid[x][y]
	return count


## Create floor mesh from grid
static func _create_cave_floor(grid: Array[Array], width: int, height: int, cell_size: float, floor_y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(width):
		for y in range(height):
			if grid[x][y] == FLOOR:
				var pos := Vector3(x * cell_size, floor_y, y * cell_size)
				_add_quad(st, pos, Vector3(cell_size, 0, 0), Vector3(0, 0, cell_size), Vector3.UP)

	st.generate_normals()
	var mesh := st.commit()

	if mesh.get_surface_count() == 0:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "CaveFloor"

	# Create material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.2)
	mat.roughness = 0.9
	mesh_instance.material_override = mat

	# Add collision
	mesh_instance.create_trimesh_collision()

	return mesh_instance


## Create wall segments where floor meets wall
static func _create_cave_walls(grid: Array[Array], width: int, height: int, cell_size: float, floor_y: float, wall_height: float) -> Array[MeshInstance3D]:
	var walls: Array[MeshInstance3D] = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(width):
		for y in range(height):
			if grid[x][y] == FLOOR:
				var pos := Vector3(x * cell_size, floor_y, y * cell_size)

				# Check each adjacent cell
				if x > 0 and grid[x - 1][y] == WALL:
					_add_quad(st, pos, Vector3(0, wall_height, 0), Vector3(0, 0, cell_size), Vector3.RIGHT)
				if x < width - 1 and grid[x + 1][y] == WALL:
					_add_quad(st, pos + Vector3(cell_size, 0, 0), Vector3(0, wall_height, 0), Vector3(0, 0, cell_size), Vector3.LEFT)
				if y > 0 and grid[x][y - 1] == WALL:
					_add_quad(st, pos, Vector3(cell_size, 0, 0), Vector3(0, wall_height, 0), Vector3.FORWARD)
				if y < height - 1 and grid[x][y + 1] == WALL:
					_add_quad(st, pos + Vector3(0, 0, cell_size), Vector3(cell_size, 0, 0), Vector3(0, wall_height, 0), Vector3.BACK)

	st.generate_normals()
	var mesh := st.commit()

	if mesh.get_surface_count() > 0:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.name = "CaveWalls"

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.2, 0.15)
		mat.roughness = 0.95
		mesh_instance.material_override = mat

		mesh_instance.create_trimesh_collision()
		walls.append(mesh_instance)

	return walls


## Create ceiling mesh
static func _create_cave_ceiling(grid: Array[Array], width: int, height: int, cell_size: float, ceiling_y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(width):
		for y in range(height):
			if grid[x][y] == FLOOR:
				var pos := Vector3(x * cell_size, ceiling_y, y * cell_size)
				_add_quad(st, pos, Vector3(cell_size, 0, 0), Vector3(0, 0, cell_size), Vector3.DOWN)

	st.generate_normals()
	var mesh := st.commit()

	if mesh.get_surface_count() == 0:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "CaveCeiling"

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.1)
	mat.roughness = 0.95
	mesh_instance.material_override = mat

	return mesh_instance


## Add a quad to surface tool
static func _add_quad(st: SurfaceTool, origin: Vector3, axis_u: Vector3, axis_v: Vector3, normal: Vector3) -> void:
	var v0 := origin
	var v1 := origin + axis_u
	var v2 := origin + axis_u + axis_v
	var v3 := origin + axis_v

	st.set_normal(normal)
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)

	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)


## Get valid spawn positions within a cave
static func get_spawn_positions(grid: Array, cell_size: float, floor_y: float, min_distance: int, count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var floor_cells: Array[Vector2i] = []

	# Find all floor cells
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] == FLOOR:
				# Check if surrounded by floor (not edge)
				if _is_interior_cell(grid, x, y):
					floor_cells.append(Vector2i(x, y))

	# Shuffle and pick cells with minimum distance
	floor_cells.shuffle()

	for cell in floor_cells:
		if positions.size() >= count:
			break

		var world_pos := Vector3(
			(cell.x + 0.5) * cell_size,
			floor_y,
			(cell.y + 0.5) * cell_size
		)

		# Check distance from existing positions
		var too_close := false
		for existing in positions:
			if world_pos.distance_to(existing) < min_distance * cell_size:
				too_close = true
				break

		if not too_close:
			positions.append(world_pos)

	return positions


## Check if cell is interior (surrounded by floor)
static func _is_interior_cell(grid: Array, x: int, y: int) -> bool:
	if x <= 0 or x >= grid.size() - 1:
		return false
	if y <= 0 or y >= grid[x].size() - 1:
		return false

	# Check all 4 cardinal neighbors
	return grid[x - 1][y] == FLOOR and grid[x + 1][y] == FLOOR and grid[x][y - 1] == FLOOR and grid[x][y + 1] == FLOOR


## Get cave bounds as AABB
static func get_cave_bounds(grid: Array, cell_size: float, floor_y: float, cave_height: float) -> AABB:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] == FLOOR:
				min_x = minf(min_x, x * cell_size)
				max_x = maxf(max_x, (x + 1) * cell_size)
				min_z = minf(min_z, y * cell_size)
				max_z = maxf(max_z, (y + 1) * cell_size)

	if min_x == INF:
		return AABB()

	return AABB(
		Vector3(min_x, floor_y, min_z),
		Vector3(max_x - min_x, cave_height, max_z - min_z)
	)
