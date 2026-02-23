## daggerfall_terrain.gd - Seamless terrain generation using world-space noise
## Creates continuous terrain across cell boundaries
## Heights are deterministic based on world coordinates
class_name DaggerfallTerrain
extends RefCounted


## Grid configuration
const GRID_SIZE: int = 17          # 17x17 vertices per cell (289 total)
const CELL_SIZE: float = 100.0     # World units per cell

## Height settings
const MAX_HEIGHT: float = 3.0      # Maximum terrain height (hills)
const MIN_HEIGHT: float = -1.0     # Minimum terrain height (shallow valleys)

## Noise settings - world-space continuous noise
const NOISE_FREQUENCY: float = 0.012  # Controls hill size (lower = larger hills)
const NOISE_SEED: int = 42069         # Fixed seed for deterministic generation


## Generate complete terrain for a cell
## Returns: Dictionary with "node" (Node3D), "heights" (PackedFloat32Array)
static func generate(
	cell_x: int,
	cell_z: int,
	biome: int,
	material: Material = null
) -> Dictionary:
	# Generate height grid
	var heights: PackedFloat32Array = _generate_height_grid(cell_x, cell_z)

	# Create root node
	var root := Node3D.new()
	root.name = "DaggerfallTerrain"

	# Create and add mesh
	var mesh_instance: MeshInstance3D = _create_mesh(heights, material)
	root.add_child(mesh_instance)

	# Create and add collision
	var collision: StaticBody3D = _create_collision(heights)
	root.add_child(collision)

	# Store heights as metadata for external access
	root.set_meta("heights", heights)
	root.set_meta("grid_size", GRID_SIZE)
	root.set_meta("cell_size", CELL_SIZE)

	return {
		"node": root,
		"heights": heights
	}


## Get height at local position (for prop placement)
## Uses bilinear interpolation between grid points
static func get_height_at(
	heights: PackedFloat32Array,
	local_x: float,
	local_z: float
) -> float:
	var half_size: float = CELL_SIZE * 0.5
	var step: float = CELL_SIZE / (GRID_SIZE - 1)

	# Convert local position to grid position
	var grid_x: float = (local_x + half_size) / step
	var grid_z: float = (local_z + half_size) / step

	# Clamp to valid range
	grid_x = clampf(grid_x, 0.0, GRID_SIZE - 1.0)
	grid_z = clampf(grid_z, 0.0, GRID_SIZE - 1.0)

	# Get integer grid coordinates
	var x0: int = int(grid_x)
	var z0: int = int(grid_z)
	var x1: int = mini(x0 + 1, GRID_SIZE - 1)
	var z1: int = mini(z0 + 1, GRID_SIZE - 1)

	# Get fractional parts for interpolation
	var fx: float = grid_x - x0
	var fz: float = grid_z - z0

	# Get heights at four corners
	var h00: float = heights[z0 * GRID_SIZE + x0]
	var h10: float = heights[z0 * GRID_SIZE + x1]
	var h01: float = heights[z1 * GRID_SIZE + x0]
	var h11: float = heights[z1 * GRID_SIZE + x1]

	# Bilinear interpolation
	var h0: float = lerpf(h00, h10, fx)
	var h1: float = lerpf(h01, h11, fx)
	return lerpf(h0, h1, fz)


## Generate height grid using world-space noise coordinates
## This ensures seamless terrain across cell boundaries - edge vertices
## at adjacent cells sample the exact same world position and get identical heights
static func _generate_height_grid(cell_x: int, cell_z: int) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = NOISE_FREQUENCY
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.seed = NOISE_SEED

	var heights := PackedFloat32Array()
	heights.resize(GRID_SIZE * GRID_SIZE)

	var step: float = CELL_SIZE / (GRID_SIZE - 1)

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			# Calculate world-space coordinates for this vertex
			# This is the key to seamless terrain - same world pos = same height
			var world_x: float = cell_x * CELL_SIZE + x * step
			var world_z: float = cell_z * CELL_SIZE + z * step

			# Sample noise at world coordinates (returns -1 to 1)
			var noise_value: float = noise.get_noise_2d(world_x, world_z)

			# Map noise directly to height: 0 noise = 0 height (ground level)
			# Positive noise = hills, negative noise = shallow valleys
			# This ensures road cells (y=0) connect seamlessly with average terrain
			var height: float
			if noise_value >= 0.0:
				height = noise_value * MAX_HEIGHT  # 0 to MAX_HEIGHT
			else:
				height = noise_value * absf(MIN_HEIGHT)  # MIN_HEIGHT to 0

			heights[z * GRID_SIZE + x] = height

	return heights


## Create mesh from height grid
## Builds terrain mesh from the 17x17 vertex grid
static func _create_mesh(
	heights: PackedFloat32Array,
	material: Material
) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var step: float = CELL_SIZE / (GRID_SIZE - 1)
	var half_size: float = CELL_SIZE * 0.5

	# Generate vertices (17x17 = 289)
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var height: float = heights[z * GRID_SIZE + x]
			vertices.append(Vector3(
				x * step - half_size,
				height,
				z * step - half_size
			))
			uvs.append(Vector2(
				float(x) / (GRID_SIZE - 1),
				float(z) / (GRID_SIZE - 1)
			))

	# Generate indices for quads
	for z in range(GRID_SIZE - 1):
		for x in range(GRID_SIZE - 1):
			var tl: int = z * GRID_SIZE + x
			var tr: int = tl + 1
			var bl: int = (z + 1) * GRID_SIZE + x
			var br: int = bl + 1

			# Two triangles per quad - CCW winding when viewed from above (+Y looking down)
			# Triangle 1: tl -> tr -> bl
			indices.append(tl)
			indices.append(tr)
			indices.append(bl)

			# Triangle 2: tr -> br -> bl
			indices.append(tr)
			indices.append(br)
			indices.append(bl)

	# Calculate normals - start with up vector
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	# Compute face normals and accumulate at vertices
	# For CCW winding (tl->tr->bl), use (v1-v0).cross(v2-v0) for upward normals
	for i in range(0, indices.size(), 3):
		var i0: int = indices[i]
		var i1: int = indices[i + 1]
		var i2: int = indices[i + 2]

		var v0: Vector3 = vertices[i0]
		var v1: Vector3 = vertices[i1]
		var v2: Vector3 = vertices[i2]

		var normal: Vector3 = (v1 - v0).cross(v2 - v0).normalized()

		normals[i0] += normal
		normals[i1] += normal
		normals[i2] += normal

	# Normalize accumulated normals
	for i in range(normals.size()):
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = mesh
	if material:
		mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return mesh_instance


## Create collision from height grid
## Uses ConcavePolygonShape3D (trimesh) to exactly match visual geometry
static func _create_collision(heights: PackedFloat32Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1
	body.collision_mask = 0

	var faces := PackedVector3Array()
	var step: float = CELL_SIZE / (GRID_SIZE - 1)
	var half_size: float = CELL_SIZE * 0.5

	# Build triangle faces for collision (same geometry as mesh)
	for z in range(GRID_SIZE - 1):
		for x in range(GRID_SIZE - 1):
			var tl := Vector3(
				x * step - half_size,
				heights[z * GRID_SIZE + x],
				z * step - half_size
			)
			var tr := Vector3(
				(x + 1) * step - half_size,
				heights[z * GRID_SIZE + (x + 1)],
				z * step - half_size
			)
			var bl := Vector3(
				x * step - half_size,
				heights[(z + 1) * GRID_SIZE + x],
				(z + 1) * step - half_size
			)
			var br := Vector3(
				(x + 1) * step - half_size,
				heights[(z + 1) * GRID_SIZE + (x + 1)],
				(z + 1) * step - half_size
			)

			# Triangle 1 - same winding as mesh for collision
			faces.append(tl)
			faces.append(tr)
			faces.append(bl)

			# Triangle 2 - same winding as mesh
			faces.append(tr)
			faces.append(br)
			faces.append(bl)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	collision.shape = shape
	body.add_child(collision)

	return body
