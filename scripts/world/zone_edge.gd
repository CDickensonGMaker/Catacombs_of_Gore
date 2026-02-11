## zone_edge.gd - Invisible zone boundary transition
## Creates an edge trigger at zone boundaries for seamless world transitions
## Player walks to edge and gets prompted to travel to adjacent zone
class_name ZoneEdge
extends Area3D

## Configuration
@export var target_scene: String = ""
@export var spawn_point_id: String = "default"
@export var zone_name: String = "Unknown"
@export var edge_length: float = 100.0  # Length of the trigger area
@export var edge_depth: float = 5.0     # How far into the zone the trigger extends

## State
var player_in_zone: bool = false
var prompt_visible: bool = false

## Edge directions
enum EdgeDirection { NORTH, SOUTH, EAST, WEST }
var edge_direction: EdgeDirection = EdgeDirection.NORTH


func _ready() -> void:
	add_to_group("zone_edges")

	# Setup collision
	collision_layer = 256  # Layer 9 for interactables
	collision_mask = 2     # Layer 2 for player

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Register as compass POI at zone edge
	_register_as_poi()


func _input(event: InputEvent) -> void:
	if not player_in_zone:
		return

	# Check for interaction input
	if event.is_action_pressed("interact"):
		_travel_to_zone()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_zone = true
	_show_travel_prompt()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_zone = false
	_hide_travel_prompt()


func _show_travel_prompt() -> void:
	prompt_visible = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_interaction_prompt"):
		hud.show_interaction_prompt("Travel to %s" % zone_name)


func _hide_travel_prompt() -> void:
	prompt_visible = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_interaction_prompt"):
		hud.hide_interaction_prompt()


func _travel_to_zone() -> void:
	if target_scene.is_empty():
		push_warning("[ZoneEdge] No target scene configured for: " + zone_name)
		return

	_hide_travel_prompt()

	# Play transition sound
	AudioManager.play_sfx("door_open")

	# Transition to target scene
	SceneManager.change_scene(target_scene, spawn_point_id)


func _register_as_poi() -> void:
	add_to_group("compass_poi")
	set_meta("poi_id", "edge_%d" % get_instance_id())
	set_meta("poi_name", zone_name)
	set_meta("poi_color", Color(0.5, 0.7, 0.9))  # Light blue for zone edges


## Static factory method for spawning zone edges
## edge_pos: Center of the edge trigger
## direction: Which edge of the zone (NORTH, SOUTH, EAST, WEST)
## length: How long the edge trigger is
static func spawn_edge(parent: Node, edge_pos: Vector3, direction: EdgeDirection,
		target: String, spawn_id: String, display_name: String,
		length: float = 100.0, depth: float = 8.0) -> ZoneEdge:

	var edge := ZoneEdge.new()
	edge.position = edge_pos
	edge.target_scene = target
	edge.spawn_point_id = spawn_id
	edge.zone_name = display_name
	edge.edge_length = length
	edge.edge_depth = depth
	edge.edge_direction = direction

	# Create collision shape based on direction
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()

	match direction:
		EdgeDirection.NORTH, EdgeDirection.SOUTH:
			# East-West aligned edge
			box.size = Vector3(length, 4.0, depth)
		EdgeDirection.EAST, EdgeDirection.WEST:
			# North-South aligned edge
			box.size = Vector3(depth, 4.0, length)

	col_shape.shape = box
	col_shape.position = Vector3(0, 2, 0)
	edge.add_child(col_shape)

	parent.add_child(edge)
	return edge


## Convenience methods for each direction
static func spawn_north_edge(parent: Node, center_x: float, z_pos: float,
		target: String, spawn_id: String, name: String, length: float = 100.0) -> ZoneEdge:
	return spawn_edge(parent, Vector3(center_x, 0, z_pos), EdgeDirection.NORTH,
		target, spawn_id, name, length)


static func spawn_south_edge(parent: Node, center_x: float, z_pos: float,
		target: String, spawn_id: String, name: String, length: float = 100.0) -> ZoneEdge:
	return spawn_edge(parent, Vector3(center_x, 0, z_pos), EdgeDirection.SOUTH,
		target, spawn_id, name, length)


static func spawn_east_edge(parent: Node, x_pos: float, center_z: float,
		target: String, spawn_id: String, name: String, length: float = 100.0) -> ZoneEdge:
	return spawn_edge(parent, Vector3(x_pos, 0, center_z), EdgeDirection.EAST,
		target, spawn_id, name, length)


static func spawn_west_edge(parent: Node, x_pos: float, center_z: float,
		target: String, spawn_id: String, name: String, length: float = 100.0) -> ZoneEdge:
	return spawn_edge(parent, Vector3(x_pos, 0, center_z), EdgeDirection.WEST,
		target, spawn_id, name, length)
