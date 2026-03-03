## multi_level_structure.gd - Factory for multi-level structures
## Creates towers, platforms, watch towers, and stairs
## PS1 aesthetic: 8-sided cylinders, low poly, hard edges
##
## TODO: [INACTIVE] This structure generation system is complete but not integrated.
## Future work: Use in TownGenerator or for procedural outpost/camp generation.
class_name MultiLevelStructure
extends RefCounted


## Structure types
enum StructureType {
	TOWER,
	PLATFORM,
	WATCH_TOWER,
	STAIRS
}

## Default materials
static func _create_stone_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.albedo_color = Color(0.45, 0.43, 0.4)

	var tex: Texture2D = load("res://assets/textures/environment/walls/stonewall.png") if ResourceLoader.exists("res://assets/textures/environment/walls/stonewall.png") else null
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(0.25, 0.25, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	return mat


static func _create_wood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.albedo_color = Color(0.4, 0.3, 0.2)

	var tex: Texture2D = load("res://assets/textures/environment/walls/wood.png") if ResourceLoader.exists("res://assets/textures/environment/walls/wood.png") else null
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	return mat


## Spawn a tower with spiral stairs and platforms
## levels: Number of floors (1-4)
## radius: Tower radius
static func spawn_tower(parent: Node, pos: Vector3, levels: int = 2, radius: float = 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Tower"
	root.position = pos

	var stone_mat := _create_stone_material()
	var wood_mat := _create_wood_material()

	var level_height: float = 4.0
	var wall_thickness: float = 0.8
	var total_height: float = levels * level_height

	# Outer wall (8-sided cylinder for PS1)
	var outer_wall := CSGCylinder3D.new()
	outer_wall.name = "OuterWall"
	outer_wall.radius = radius
	outer_wall.height = total_height
	outer_wall.sides = 8
	outer_wall.position.y = total_height * 0.5
	outer_wall.material = stone_mat
	outer_wall.use_collision = true
	root.add_child(outer_wall)

	# Hollow interior (subtraction)
	var inner_hollow := CSGCylinder3D.new()
	inner_hollow.name = "InnerHollow"
	inner_hollow.radius = radius - wall_thickness
	inner_hollow.height = total_height + 1.0
	inner_hollow.sides = 8
	inner_hollow.position.y = total_height * 0.5
	inner_hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	outer_wall.add_child(inner_hollow)

	# Floor platforms per level
	for level in range(levels):
		var floor_y: float = level * level_height

		# Floor platform (donut shape - outer with inner cutout for stairs)
		var floor_outer := CSGCylinder3D.new()
		floor_outer.name = "Floor_%d" % level
		floor_outer.radius = radius - wall_thickness + 0.1
		floor_outer.height = 0.3
		floor_outer.sides = 8
		floor_outer.position.y = floor_y + 0.15
		floor_outer.material = wood_mat
		floor_outer.use_collision = true
		root.add_child(floor_outer)

		# Stair opening
		if level > 0:
			var stair_hole := CSGBox3D.new()
			stair_hole.name = "StairHole_%d" % level
			stair_hole.size = Vector3(1.5, 0.5, 2.0)
			stair_hole.position = Vector3(radius * 0.4, 0, 0)
			stair_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
			floor_outer.add_child(stair_hole)

	# Spiral staircase
	var stair_steps: int = 8  # Steps per level
	var stair_width: float = 1.2
	var stair_depth: float = 0.8

	for level in range(levels - 1):
		var base_y: float = level * level_height
		for step in range(stair_steps):
			var angle: float = (float(step) / stair_steps) * PI * 0.6  # Partial spiral
			var step_y: float = base_y + (float(step + 1) / stair_steps) * level_height

			var stair := CSGBox3D.new()
			stair.name = "Stair_%d_%d" % [level, step]
			stair.size = Vector3(stair_width, 0.25, stair_depth)

			var stair_radius: float = radius * 0.5
			stair.position = Vector3(
				cos(angle) * stair_radius,
				step_y,
				sin(angle) * stair_radius
			)
			stair.rotation.y = -angle

			stair.material = wood_mat
			stair.use_collision = true
			root.add_child(stair)

	# Battlements at top (optional)
	var battlement_count: int = 8
	for i in range(battlement_count):
		var angle: float = (float(i) / battlement_count) * TAU
		var battlement := CSGBox3D.new()
		battlement.name = "Battlement_%d" % i
		battlement.size = Vector3(1.2, 1.0, 0.5)
		battlement.position = Vector3(
			cos(angle) * (radius - 0.25),
			total_height + 0.5,
			sin(angle) * (radius - 0.25)
		)
		battlement.rotation.y = -angle
		battlement.material = stone_mat
		root.add_child(battlement)

	parent.add_child(root)
	return root


## Spawn a raised platform (wooden or stone)
static func spawn_platform(parent: Node, pos: Vector3, width: float = 6.0, depth: float = 6.0, height: float = 2.0, is_wooden: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Platform"
	root.position = pos

	var mat := _create_wood_material() if is_wooden else _create_stone_material()

	# Platform top
	var top := CSGBox3D.new()
	top.name = "PlatformTop"
	top.size = Vector3(width, 0.3, depth)
	top.position.y = height
	top.material = mat
	top.use_collision = true
	root.add_child(top)

	# Support posts (4 corners)
	var post_radius: float = 0.3 if is_wooden else 0.4
	var post_positions: Array[Vector2] = [
		Vector2(-width * 0.4, -depth * 0.4),
		Vector2(width * 0.4, -depth * 0.4),
		Vector2(-width * 0.4, depth * 0.4),
		Vector2(width * 0.4, depth * 0.4)
	]

	for i in range(post_positions.size()):
		var post_pos: Vector2 = post_positions[i]
		if is_wooden:
			var post := CSGCylinder3D.new()
			post.name = "Post_%d" % i
			post.radius = post_radius
			post.height = height
			post.sides = 6
			post.position = Vector3(post_pos.x, height * 0.5, post_pos.y)
			post.material = mat
			post.use_collision = true
			root.add_child(post)
		else:
			var post := CSGBox3D.new()
			post.name = "Post_%d" % i
			post.size = Vector3(post_radius * 2, height, post_radius * 2)
			post.position = Vector3(post_pos.x, height * 0.5, post_pos.y)
			post.material = mat
			post.use_collision = true
			root.add_child(post)

	# Access ramp/stairs
	var ramp := CSGBox3D.new()
	ramp.name = "AccessRamp"
	ramp.size = Vector3(1.5, 0.2, height * 1.2)
	ramp.position = Vector3(0, height * 0.5, -depth * 0.5 - height * 0.5)
	ramp.rotation.x = -atan2(height, height * 1.2)
	ramp.material = mat
	ramp.use_collision = true
	root.add_child(ramp)

	parent.add_child(root)
	return root


## Spawn a watch tower (shorter tower with torch at top)
static func spawn_watch_tower(parent: Node, pos: Vector3, height: float = 6.0) -> Node3D:
	var root := Node3D.new()
	root.name = "WatchTower"
	root.position = pos

	var stone_mat := _create_stone_material()
	var wood_mat := _create_wood_material()

	var radius: float = 2.0

	# Tower base (8-sided)
	var base := CSGCylinder3D.new()
	base.name = "TowerBase"
	base.radius = radius
	base.height = height
	base.sides = 8
	base.position.y = height * 0.5
	base.material = stone_mat
	base.use_collision = true
	root.add_child(base)

	# Hollow interior
	var hollow := CSGCylinder3D.new()
	hollow.name = "Hollow"
	hollow.radius = radius - 0.5
	hollow.height = height + 0.5
	hollow.sides = 8
	hollow.position.y = height * 0.5
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	base.add_child(hollow)

	# Observation platform at top
	var platform := CSGCylinder3D.new()
	platform.name = "Platform"
	platform.radius = radius + 0.5
	platform.height = 0.3
	platform.sides = 8
	platform.position.y = height
	platform.material = wood_mat
	platform.use_collision = true
	root.add_child(platform)

	# Railing posts
	for i in range(6):
		var angle: float = (float(i) / 6) * TAU
		var post := CSGCylinder3D.new()
		post.name = "RailingPost_%d" % i
		post.radius = 0.08
		post.height = 1.0
		post.sides = 4
		post.position = Vector3(
			cos(angle) * (radius + 0.3),
			height + 0.5,
			sin(angle) * (radius + 0.3)
		)
		post.material = wood_mat
		root.add_child(post)

	# Torch holder at top
	var torch_holder := CSGBox3D.new()
	torch_holder.name = "TorchHolder"
	torch_holder.size = Vector3(0.3, 1.5, 0.3)
	torch_holder.position = Vector3(0, height + 1.0, 0)
	torch_holder.material = wood_mat
	root.add_child(torch_holder)

	# Simple ladder for access
	var ladder_height: float = height
	var ladder := CSGBox3D.new()
	ladder.name = "Ladder"
	ladder.size = Vector3(0.6, ladder_height, 0.1)
	ladder.position = Vector3(radius - 0.3, ladder_height * 0.5, 0)
	ladder.material = wood_mat
	ladder.use_collision = true
	root.add_child(ladder)

	# Ladder rungs
	var rung_count: int = int(ladder_height / 0.4)
	for i in range(rung_count):
		var rung := CSGBox3D.new()
		rung.name = "Rung_%d" % i
		rung.size = Vector3(0.6, 0.08, 0.15)
		rung.position = Vector3(radius - 0.3, 0.4 + i * 0.4, 0.1)
		rung.material = wood_mat
		root.add_child(rung)

	parent.add_child(root)
	return root


## Spawn stairs connecting two levels
static func spawn_stairs(parent: Node, pos: Vector3, height_diff: float = 3.0, width: float = 2.0, direction: Vector3 = Vector3.FORWARD) -> Node3D:
	var root := Node3D.new()
	root.name = "Stairs"
	root.position = pos

	var stone_mat := _create_stone_material()

	var step_height: float = 0.3
	var step_count: int = int(height_diff / step_height)
	var step_depth: float = height_diff / step_count * 1.2

	# Rotate to face direction
	root.rotation.y = atan2(direction.x, direction.z)

	for i in range(step_count):
		var step := CSGBox3D.new()
		step.name = "Step_%d" % i
		step.size = Vector3(width, step_height, step_depth)
		step.position = Vector3(0, step_height * 0.5 + i * step_height, -step_depth * i)
		step.material = stone_mat
		step.use_collision = true
		root.add_child(step)

	# Side rails
	var rail_height: float = height_diff + 1.0
	var rail_length: float = step_count * step_depth

	for side in [-1, 1]:
		var rail := CSGBox3D.new()
		rail.name = "Rail_%s" % ("Left" if side < 0 else "Right")
		rail.size = Vector3(0.15, 0.8, rail_length)
		rail.position = Vector3(side * width * 0.55, height_diff * 0.5 + 0.4, -rail_length * 0.5 + step_depth * 0.5)
		rail.rotation.x = -atan2(height_diff, rail_length)
		rail.material = stone_mat
		root.add_child(rail)

	parent.add_child(root)
	return root


## Create a structure by type
static func create_structure(parent: Node, pos: Vector3, structure_type: StructureType) -> Node3D:
	match structure_type:
		StructureType.TOWER:
			return spawn_tower(parent, pos, randi_range(2, 3), randf_range(3.5, 5.0))
		StructureType.PLATFORM:
			return spawn_platform(parent, pos, randf_range(5.0, 8.0), randf_range(5.0, 8.0), randf_range(1.5, 3.0))
		StructureType.WATCH_TOWER:
			return spawn_watch_tower(parent, pos, randf_range(5.0, 8.0))
		StructureType.STAIRS:
			return spawn_stairs(parent, pos, randf_range(2.0, 4.0))
	return Node3D.new()
