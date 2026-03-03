## glb_collision_processor.gd - Automatic collision generation for imported GLB/Blender models
## Uses naming conventions to determine which meshes should have collision
##
## BLENDER NAMING CONVENTIONS:
## ===========================
## Godot automatically recognizes these suffixes during GLB import:
##   -col        → Creates trimesh collision (for complex shapes)
##   -colonly    → Creates collision but hides the mesh (invisible walls)
##   -convcolonly → Creates convex collision, hides mesh
##
## CUSTOM NAMING CONVENTIONS (processed by this tool):
## ===========================
## Meshes WITH collision (solid objects):
##   _floor, _ground    → Floor/ground surfaces (trimesh collision)
##   _wall, _walls      → Solid walls (trimesh collision)
##   _pillar, _column   → Pillars/columns (convex collision)
##   _solid, _block     → Generic solid objects (convex collision)
##   _stairs, _steps    → Stairways (trimesh collision)
##   _platform          → Platforms (trimesh collision)
##   _barrier, _fence   → Barriers/fences (trimesh collision)
##
## Meshes WITHOUT collision (passable/decorative):
##   _decor, _decoration → Decorative elements
##   _arch, _archway     → Archways (player walks through)
##   _frame, _doorframe  → Door/window frames
##   _railing, _rail     → Railings (visual only)
##   _trim, _molding     → Trim/molding details
##   _banner, _flag      → Hanging banners/flags
##   _prop, _detail      → Generic props/details
##   _foliage, _plant    → Plants/foliage
##   _light, _lamp       → Light fixtures
##
## DEFAULT BEHAVIOR:
## If a mesh has no recognized suffix, it gets NO collision by default.
## This prevents accidental blocking of passable areas.
##
## USAGE:
## 1. In Blender, name your objects with the appropriate suffix
## 2. Export as GLB
## 3. Import into Godot
## 4. Call GLBCollisionProcessor.process_scene(your_imported_scene)
##
## Or use in level scripts:
##   GLBCollisionProcessor.process_node(get_node("Terrain/YourGLBModel"))
##
class_name GLBCollisionProcessor
extends RefCounted

## Suffixes that indicate mesh should have TRIMESH collision (complex shapes)
const TRIMESH_SUFFIXES: Array[String] = [
	"_floor", "_ground", "_terrain",
	"_wall", "_walls",
	"_stairs", "_steps", "_stairway",
	"_platform", "_ledge",
	"_barrier", "_fence",
	"_roof", "_ceiling",
	"_bridge",
	"_rock", "_boulder",
]

## Suffixes that indicate mesh should have CONVEX collision (simpler, faster)
const CONVEX_SUFFIXES: Array[String] = [
	"_pillar", "_column",
	"_solid", "_block", "_cube",
	"_crate", "_box", "_barrel",
	"_table", "_chair", "_bench",
	"_statue", "_monument",
]

## Suffixes that indicate mesh should have NO collision (decorative/passable)
const NO_COLLISION_SUFFIXES: Array[String] = [
	"_decor", "_decoration", "_deco",
	"_arch", "_archway",
	"_frame", "_doorframe", "_windowframe",
	"_railing", "_rail", "_handrail",
	"_trim", "_molding", "_moulding",
	"_banner", "_flag", "_cloth",
	"_prop", "_detail", "_accent",
	"_foliage", "_plant", "_vine", "_grass",
	"_light", "_lamp", "_torch", "_candle",
	"_sign", "_plaque",
	"_chain", "_rope",
	"_debris", "_rubble",
	"_water", "_liquid",
	"_smoke", "_fog", "_particle",
	"_grate", "_grating",  # Usually walkable grates
]

## Keywords that indicate NO collision even without suffix
const NO_COLLISION_KEYWORDS: Array[String] = [
	"archway", "doorway", "passage", "opening",
	"decoration", "ornament", "ornamental",
	"transparent", "passable", "walkthrough",
]

## Result statistics
class ProcessResult:
	var trimesh_count: int = 0
	var convex_count: int = 0
	var skipped_count: int = 0
	var already_has_collision: int = 0
	var meshes_processed: Array[String] = []

	func get_summary() -> String:
		return "Collision processed: %d trimesh, %d convex, %d skipped, %d already had collision" % [
			trimesh_count, convex_count, skipped_count, already_has_collision
		]


## Process an entire scene/node tree and add appropriate collision
static func process_node(root: Node, verbose: bool = true) -> ProcessResult:
	var result := ProcessResult.new()
	_process_recursive(root, result, verbose)

	if verbose:
		print("[GLBCollisionProcessor] %s" % result.get_summary())

	return result


## Process a scene file path and return the modified scene
static func process_scene_file(scene_path: String, verbose: bool = true) -> ProcessResult:
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_error("[GLBCollisionProcessor] Failed to load scene: %s" % scene_path)
		return ProcessResult.new()

	var instance: Node = scene.instantiate()
	var result := process_node(instance, verbose)

	# Note: To save the modified scene, you'd need to pack it back
	# This is typically done in editor, not at runtime

	return result


## Recursive processing of nodes
static func _process_recursive(node: Node, result: ProcessResult, verbose: bool) -> void:
	if node is MeshInstance3D:
		_process_mesh_instance(node as MeshInstance3D, result, verbose)

	for child in node.get_children():
		_process_recursive(child, result, verbose)


## Process a single MeshInstance3D
static func _process_mesh_instance(mesh_instance: MeshInstance3D, result: ProcessResult, verbose: bool) -> void:
	var mesh_name: String = mesh_instance.name.to_lower()

	# Check if collision already exists
	if _has_collision_child(mesh_instance):
		result.already_has_collision += 1
		return

	# Check if mesh is valid
	if not mesh_instance.mesh:
		return

	# Determine collision type based on name
	var collision_type: String = _get_collision_type(mesh_name)

	match collision_type:
		"trimesh":
			mesh_instance.create_trimesh_collision()
			result.trimesh_count += 1
			result.meshes_processed.append(mesh_instance.name)
			if verbose:
				print("[GLBCollisionProcessor] Added trimesh collision: %s" % mesh_instance.name)

		"convex":
			mesh_instance.create_convex_collision()
			result.convex_count += 1
			result.meshes_processed.append(mesh_instance.name)
			if verbose:
				print("[GLBCollisionProcessor] Added convex collision: %s" % mesh_instance.name)

		"none":
			result.skipped_count += 1
			if verbose:
				print("[GLBCollisionProcessor] Skipped (decorative): %s" % mesh_instance.name)

		_:  # "unknown" - no recognized suffix, skip by default
			result.skipped_count += 1


## Check if mesh already has collision
static func _has_collision_child(mesh_instance: MeshInstance3D) -> bool:
	for child in mesh_instance.get_children():
		if child is StaticBody3D or child is CollisionShape3D:
			return true
	return false


## Determine what type of collision to generate based on mesh name
static func _get_collision_type(mesh_name: String) -> String:
	# First check for explicit no-collision keywords
	for keyword in NO_COLLISION_KEYWORDS:
		if keyword in mesh_name:
			return "none"

	# Check for no-collision suffixes
	for suffix in NO_COLLISION_SUFFIXES:
		if mesh_name.ends_with(suffix):
			return "none"

	# Check for trimesh suffixes
	for suffix in TRIMESH_SUFFIXES:
		if mesh_name.ends_with(suffix) or suffix.substr(1) in mesh_name:
			return "trimesh"

	# Check for convex suffixes
	for suffix in CONVEX_SUFFIXES:
		if mesh_name.ends_with(suffix) or suffix.substr(1) in mesh_name:
			return "convex"

	# Default: no collision (safe default to avoid blocking passable areas)
	return "unknown"


## Utility: Add simple box collision to a node
static func add_box_collision(parent: Node3D, pos: Vector3, size: Vector3, collision_name: String = "BoxCollision") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = collision_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	parent.add_child(body)
	return body


## Utility: Add floor plane collision
static func add_floor_collision(parent: Node3D, size: Vector2, y_position: float = 0.0) -> StaticBody3D:
	return add_box_collision(
		parent,
		Vector3(0, y_position - 0.5, 0),
		Vector3(size.x, 1.0, size.y),
		"FloorCollision"
	)


## Utility: Add invisible wall
static func add_wall_collision(parent: Node3D, pos: Vector3, width: float, height: float, depth: float = 1.0) -> StaticBody3D:
	return add_box_collision(
		parent,
		pos,
		Vector3(width, height, depth),
		"WallCollision"
	)


## Generate a report of all meshes in a node tree and their collision status
static func generate_report(root: Node) -> String:
	var lines: Array[String] = []
	lines.append("=== GLB Collision Report ===")
	lines.append("")

	var trimesh_meshes: Array[String] = []
	var convex_meshes: Array[String] = []
	var no_collision_meshes: Array[String] = []
	var unknown_meshes: Array[String] = []

	_collect_mesh_info(root, trimesh_meshes, convex_meshes, no_collision_meshes, unknown_meshes)

	lines.append("WILL GET TRIMESH COLLISION (%d):" % trimesh_meshes.size())
	for name in trimesh_meshes:
		lines.append("  + %s" % name)

	lines.append("")
	lines.append("WILL GET CONVEX COLLISION (%d):" % convex_meshes.size())
	for name in convex_meshes:
		lines.append("  + %s" % name)

	lines.append("")
	lines.append("WILL BE SKIPPED - DECORATIVE (%d):" % no_collision_meshes.size())
	for name in no_collision_meshes:
		lines.append("  - %s" % name)

	lines.append("")
	lines.append("UNKNOWN - NO COLLISION (rename to add) (%d):" % unknown_meshes.size())
	for name in unknown_meshes:
		lines.append("  ? %s" % name)

	return "\n".join(lines)


static func _collect_mesh_info(node: Node, trimesh: Array[String], convex: Array[String], none: Array[String], unknown: Array[String]) -> void:
	if node is MeshInstance3D:
		var mesh_name: String = node.name.to_lower()
		var collision_type: String = _get_collision_type(mesh_name)

		match collision_type:
			"trimesh":
				trimesh.append(node.name)
			"convex":
				convex.append(node.name)
			"none":
				none.append(node.name)
			_:
				unknown.append(node.name)

	for child in node.get_children():
		_collect_mesh_info(child, trimesh, convex, none, unknown)
