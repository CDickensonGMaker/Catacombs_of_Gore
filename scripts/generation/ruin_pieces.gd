## ruin_pieces.gd - Modular ruin component factory
## Creates individual ruin pieces that combine into larger structures
## PS1 aesthetic: 8-15 faces per piece, hard edges, nearest-neighbor textures
##
## TODO: [INACTIVE] This ruin generation system is complete but not integrated.
## Future work: Use in WildernessRoom for procedural ruin placement.
class_name RuinPieces
extends RefCounted


## Ruin piece types
enum PieceType {
	BROKEN_COLUMN,
	CRUMBLING_WALL,
	COLLAPSED_ARCH,
	RUBBLE_PILE,
	OVERGROWN_STONE,
	ANCIENT_ALTAR
}

## Complex ruin types (combinations of pieces)
enum RuinType {
	COLLAPSED_TEMPLE,
	SHRINE_REMNANTS,
	ANCIENT_WALL_SEGMENT
}


## Standard ruin material (stone texture)
static func _create_ruin_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.albedo_color = Color(0.5, 0.48, 0.45)

	var tex: Texture2D = load("res://assets/textures/environment/walls/stonewall.png") if ResourceLoader.exists("res://assets/textures/environment/walls/stonewall.png") else null
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	return mat


## Create a broken column (CSGCylinder with jagged top)
static func create_broken_column(height: float = 4.0, radius: float = 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "BrokenColumn"

	var mat := _create_ruin_material()

	# Main column shaft (8 sides for PS1 look)
	var column := CSGCylinder3D.new()
	column.name = "ColumnShaft"
	column.radius = radius
	column.height = height
	column.sides = 8
	column.position.y = height * 0.5
	column.material = mat
	column.use_collision = true
	root.add_child(column)

	# Jagged top using tilted boxes
	var top_debris := CSGBox3D.new()
	top_debris.name = "JaggedTop"
	top_debris.size = Vector3(radius * 1.8, height * 0.15, radius * 1.4)
	top_debris.position = Vector3(radius * 0.2, height + height * 0.05, 0)
	top_debris.rotation.z = 0.3
	top_debris.material = mat
	root.add_child(top_debris)

	return root


## Create a crumbling wall with missing chunks
static func create_crumbling_wall(width: float = 5.0, height: float = 3.0, depth: float = 0.6) -> Node3D:
	var root := Node3D.new()
	root.name = "CrumblingWall"

	var mat := _create_ruin_material()

	# Main wall section
	var wall := CSGBox3D.new()
	wall.name = "WallBase"
	wall.size = Vector3(width, height, depth)
	wall.position.y = height * 0.5
	wall.material = mat
	wall.use_collision = true
	root.add_child(wall)

	# Subtract chunks to create crumbled look
	var chunk1 := CSGBox3D.new()
	chunk1.name = "Chunk1"
	chunk1.size = Vector3(width * 0.3, height * 0.4, depth * 1.5)
	chunk1.position = Vector3(width * 0.3, height * 0.85, 0)
	chunk1.operation = CSGShape3D.OPERATION_SUBTRACTION
	wall.add_child(chunk1)

	var chunk2 := CSGBox3D.new()
	chunk2.name = "Chunk2"
	chunk2.size = Vector3(width * 0.25, height * 0.3, depth * 1.5)
	chunk2.position = Vector3(-width * 0.35, height * 0.9, 0)
	chunk2.rotation.z = 0.2
	chunk2.operation = CSGShape3D.OPERATION_SUBTRACTION
	wall.add_child(chunk2)

	# Add rubble at base
	for i in range(3):
		var rubble := CSGBox3D.new()
		rubble.name = "Rubble_%d" % i
		rubble.size = Vector3(0.4 + randf() * 0.3, 0.3 + randf() * 0.2, 0.35 + randf() * 0.25)
		rubble.position = Vector3(randf_range(-width * 0.4, width * 0.4), rubble.size.y * 0.5, depth * 0.5 + randf() * 0.3)
		rubble.rotation = Vector3(randf() * 0.3, randf() * PI, randf() * 0.3)
		rubble.material = mat
		root.add_child(rubble)

	return root


## Create a collapsed arch (half arch with rubble)
static func create_collapsed_arch(width: float = 4.0, height: float = 3.5) -> Node3D:
	var root := Node3D.new()
	root.name = "CollapsedArch"

	var mat := _create_ruin_material()

	# Left pillar (intact)
	var pillar_left := CSGBox3D.new()
	pillar_left.name = "PillarLeft"
	pillar_left.size = Vector3(0.6, height, 0.6)
	pillar_left.position = Vector3(-width * 0.5, height * 0.5, 0)
	pillar_left.material = mat
	pillar_left.use_collision = true
	root.add_child(pillar_left)

	# Right pillar (broken)
	var pillar_right := CSGBox3D.new()
	pillar_right.name = "PillarRight"
	pillar_right.size = Vector3(0.6, height * 0.6, 0.6)
	pillar_right.position = Vector3(width * 0.5, height * 0.3, 0)
	pillar_right.material = mat
	pillar_right.use_collision = true
	root.add_child(pillar_right)

	# Partial arch (just the left side)
	var arch_left := CSGBox3D.new()
	arch_left.name = "ArchLeft"
	arch_left.size = Vector3(width * 0.4, 0.5, 0.5)
	arch_left.position = Vector3(-width * 0.25, height + 0.25, 0)
	arch_left.rotation.z = -0.15
	arch_left.material = mat
	root.add_child(arch_left)

	# Fallen arch pieces
	var fallen1 := CSGBox3D.new()
	fallen1.name = "FallenArch1"
	fallen1.size = Vector3(width * 0.35, 0.45, 0.45)
	fallen1.position = Vector3(width * 0.15, 0.25, 0.8)
	fallen1.rotation = Vector3(0.4, 0.3, 0.6)
	fallen1.material = mat
	fallen1.use_collision = true
	root.add_child(fallen1)

	var fallen2 := CSGBox3D.new()
	fallen2.name = "FallenArch2"
	fallen2.size = Vector3(width * 0.25, 0.4, 0.4)
	fallen2.position = Vector3(0, 0.2, -0.6)
	fallen2.rotation = Vector3(-0.5, -0.2, 0.8)
	fallen2.material = mat
	fallen2.use_collision = true
	root.add_child(fallen2)

	return root


## Create a rubble pile (clustered CSGBox debris)
static func create_rubble_pile(radius: float = 2.0, piece_count: int = 8) -> Node3D:
	var root := Node3D.new()
	root.name = "RubblePile"

	var mat := _create_ruin_material()

	for i in range(piece_count):
		var rubble := CSGBox3D.new()
		rubble.name = "Rubble_%d" % i

		# Random size
		var size_x: float = 0.3 + randf() * 0.6
		var size_y: float = 0.2 + randf() * 0.4
		var size_z: float = 0.25 + randf() * 0.5
		rubble.size = Vector3(size_x, size_y, size_z)

		# Random position in circular area, stacked toward center
		var angle: float = randf() * TAU
		var dist: float = randf() * radius * 0.8
		rubble.position = Vector3(
			cos(angle) * dist,
			size_y * 0.5 + (1.0 - dist / radius) * 0.3,  # Stack higher in center
			sin(angle) * dist
		)

		# Random rotation
		rubble.rotation = Vector3(randf() * 0.5, randf() * PI, randf() * 0.5)

		rubble.material = mat
		rubble.use_collision = true
		root.add_child(rubble)

	return root


## Create an overgrown stone (stone with vine billboard)
static func create_overgrown_stone(size: float = 1.5) -> Node3D:
	var root := Node3D.new()
	root.name = "OvergrownStone"

	var mat := _create_ruin_material()
	mat.albedo_color = Color(0.4, 0.42, 0.38)  # Slightly green tint

	# Main stone
	var stone := CSGBox3D.new()
	stone.name = "Stone"
	stone.size = Vector3(size, size * 0.7, size * 0.9)
	stone.position.y = size * 0.35
	stone.rotation.y = randf() * PI
	stone.material = mat
	stone.use_collision = true
	root.add_child(stone)

	# Vine billboard (simple green sprite)
	var vine_sprite := Sprite3D.new()
	vine_sprite.name = "Vines"
	vine_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	vine_sprite.pixel_size = 0.02
	vine_sprite.modulate = Color(0.3, 0.5, 0.25, 0.8)
	vine_sprite.position = Vector3(0, size * 0.5, size * 0.45)

	# Create simple vine texture if none exists
	var vine_tex: Texture2D = load("res://assets/sprites/environment/trees/herb_bush2.png") if ResourceLoader.exists("res://assets/sprites/environment/trees/herb_bush2.png") else null
	if vine_tex:
		vine_sprite.texture = vine_tex
	else:
		# Fallback: create a simple green quad
		var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.5, 0.2, 0.7))
		vine_sprite.texture = ImageTexture.create_from_image(img)

	root.add_child(vine_sprite)

	return root


## Create an ancient altar (low platform)
static func create_ancient_altar(width: float = 2.5, depth: float = 1.5) -> Node3D:
	var root := Node3D.new()
	root.name = "AncientAltar"

	var mat := _create_ruin_material()
	mat.albedo_color = Color(0.45, 0.43, 0.4)

	# Base platform
	var base := CSGBox3D.new()
	base.name = "AltarBase"
	base.size = Vector3(width, 0.4, depth)
	base.position.y = 0.2
	base.material = mat
	base.use_collision = true
	root.add_child(base)

	# Top slab
	var top := CSGBox3D.new()
	top.name = "AltarTop"
	top.size = Vector3(width * 0.85, 0.15, depth * 0.85)
	top.position.y = 0.475
	top.material = mat
	root.add_child(top)

	# Corner decorations
	for i in range(4):
		var corner := CSGBox3D.new()
		corner.name = "Corner_%d" % i
		corner.size = Vector3(0.2, 0.25, 0.2)
		var x_off: float = (width * 0.4) * (1 if i % 2 == 0 else -1)
		var z_off: float = (depth * 0.4) * (1 if i < 2 else -1)
		corner.position = Vector3(x_off, 0.525, z_off)
		corner.material = mat
		root.add_child(corner)

	return root


## Create a piece by type
static func create_piece(piece_type: PieceType) -> Node3D:
	match piece_type:
		PieceType.BROKEN_COLUMN:
			return create_broken_column()
		PieceType.CRUMBLING_WALL:
			return create_crumbling_wall()
		PieceType.COLLAPSED_ARCH:
			return create_collapsed_arch()
		PieceType.RUBBLE_PILE:
			return create_rubble_pile()
		PieceType.OVERGROWN_STONE:
			return create_overgrown_stone()
		PieceType.ANCIENT_ALTAR:
			return create_ancient_altar()
	return Node3D.new()


## Create a collapsed temple (4-6 columns + arch + rubble)
static func create_collapsed_temple() -> Node3D:
	var root := Node3D.new()
	root.name = "CollapsedTemple"

	var column_count: int = randi_range(4, 6)
	var spacing: float = 3.0

	# Place columns in a rough rectangle
	for i in range(column_count):
		var column: Node3D = create_broken_column(randf_range(3.0, 5.0), randf_range(0.4, 0.6))
		var row: int = int(i / 3)
		var col: int = i % 3
		column.position = Vector3(
			(col - 1) * spacing + randf_range(-0.3, 0.3),
			0,
			(row - 0.5) * spacing * 1.5 + randf_range(-0.3, 0.3)
		)
		column.rotation.y = randf() * TAU
		root.add_child(column)

	# Central arch (collapsed)
	var arch: Node3D = create_collapsed_arch(4.5, 4.0)
	arch.position = Vector3(0, 0, 0)
	root.add_child(arch)

	# Rubble around the edges
	var rubble: Node3D = create_rubble_pile(3.0, 10)
	rubble.position = Vector3(2.5, 0, -2.0)
	root.add_child(rubble)

	return root


## Create shrine remnants (altar + fallen statue + candles)
static func create_shrine_remnants() -> Node3D:
	var root := Node3D.new()
	root.name = "ShrineRemnants"

	var mat := _create_ruin_material()

	# Central altar
	var altar: Node3D = create_ancient_altar(2.0, 1.2)
	root.add_child(altar)

	# Fallen statue (simple humanoid shape fallen over)
	var statue_body := CSGBox3D.new()
	statue_body.name = "StatueBody"
	statue_body.size = Vector3(0.5, 1.8, 0.4)
	statue_body.position = Vector3(1.5, 0.25, 0.5)
	statue_body.rotation.z = PI * 0.5
	statue_body.rotation.y = 0.3
	statue_body.material = mat
	statue_body.use_collision = true
	root.add_child(statue_body)

	var statue_head := CSGSphere3D.new()
	statue_head.name = "StatueHead"
	statue_head.radius = 0.2
	statue_head.position = Vector3(2.3, 0.2, 0.4)
	statue_head.material = mat
	root.add_child(statue_head)

	# Candle holders (simple cylinders)
	for i in range(2):
		var candle := CSGCylinder3D.new()
		candle.name = "Candle_%d" % i
		candle.radius = 0.08
		candle.height = 0.3
		candle.sides = 6
		candle.position = Vector3((i * 2 - 1) * 0.6, 0.65, 0)
		candle.material = mat
		root.add_child(candle)

	# Some rubble
	var rubble: Node3D = create_rubble_pile(1.5, 5)
	rubble.position = Vector3(-1.2, 0, 0.8)
	root.add_child(rubble)

	return root


## Create ancient wall segment (2-3 crumbling walls + overgrown)
static func create_ancient_wall_segment() -> Node3D:
	var root := Node3D.new()
	root.name = "AncientWallSegment"

	var wall_count: int = randi_range(2, 3)

	for i in range(wall_count):
		var wall: Node3D = create_crumbling_wall(
			randf_range(4.0, 6.0),
			randf_range(2.5, 4.0),
			randf_range(0.5, 0.8)
		)
		wall.position = Vector3(i * 5.5 - 2.75, 0, randf_range(-0.5, 0.5))
		wall.rotation.y = randf_range(-0.1, 0.1)
		root.add_child(wall)

	# Add overgrown stones
	for i in range(2):
		var stone: Node3D = create_overgrown_stone(randf_range(1.0, 1.8))
		stone.position = Vector3(randf_range(-3, 3), 0, randf_range(1.5, 3.0))
		root.add_child(stone)

	return root


## Create a complex ruin by type
static func create_ruin(ruin_type: RuinType) -> Node3D:
	match ruin_type:
		RuinType.COLLAPSED_TEMPLE:
			return create_collapsed_temple()
		RuinType.SHRINE_REMNANTS:
			return create_shrine_remnants()
		RuinType.ANCIENT_WALL_SEGMENT:
			return create_ancient_wall_segment()
	return Node3D.new()


## Create a random ruin
static func create_random_ruin() -> Node3D:
	var ruin_type: RuinType = randi() % RuinType.size() as RuinType
	return create_ruin(ruin_type)
