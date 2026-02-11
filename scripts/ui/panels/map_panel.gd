## map_panel.gd - Simple 2D area map display
class_name MapPanel
extends Control

## Map display
@export var map_container: Control
@export var player_marker: Control
@export var area_name_label: Label

## Map settings
@export var map_scale: float = 5.0  ## World units per pixel
@export var map_size: Vector2 = Vector2(400, 300)

## Marker colors
const PLAYER_COLOR := Color(0.2, 0.8, 0.2)
const ENEMY_COLOR := Color(0.8, 0.2, 0.2)
const ITEM_COLOR := Color(0.8, 0.8, 0.2)
const NPC_COLOR := Color(0.2, 0.5, 0.8)

## Tracked markers
var enemy_markers: Array[Control] = []
var item_markers: Array[Control] = []
var npc_markers: Array[Control] = []

func _ready() -> void:
	# Create player marker if not assigned
	if not player_marker and map_container:
		player_marker = _create_marker(PLAYER_COLOR, 8)
		map_container.add_child(player_marker)

	refresh()

func _process(_delta: float) -> void:
	if visible:
		_update_player_position()

func refresh() -> void:
	_update_area_name()
	_refresh_markers()

func _update_area_name() -> void:
	if not area_name_label:
		return

	# Get current area name from GameManager or scene
	var area_name := "Unknown Area"
	if GameManager.has_method("get_current_area_name"):
		area_name = GameManager.get_current_area_name()
	else:
		var current_scene := get_tree().current_scene
		if current_scene:
			area_name = current_scene.name.replace("_", " ").capitalize()

	area_name_label.text = area_name

func _update_player_position() -> void:
	if not player_marker or not map_container:
		return

	var player := get_tree().get_first_node_in_group("player")
	if not player or not player is Node3D:
		return

	var world_pos: Vector3 = (player as Node3D).global_position
	var map_pos := _world_to_map(world_pos)
	player_marker.position = map_pos

	# Rotate marker based on player facing
	if player.has_node("MeshRoot"):
		var mesh_root: Node3D = player.get_node("MeshRoot")
		player_marker.rotation = -mesh_root.rotation.y

func _world_to_map(world_pos: Vector3) -> Vector2:
	# Convert 3D world position to 2D map position
	# Center of map is (0, 0) in world space
	var map_center := map_size / 2.0
	var map_x := map_center.x + (world_pos.x / map_scale)
	var map_y := map_center.y + (world_pos.z / map_scale)

	# Clamp to map bounds
	map_x = clampf(map_x, 0, map_size.x)
	map_y = clampf(map_y, 0, map_size.y)

	return Vector2(map_x, map_y)

func _refresh_markers() -> void:
	# Clear old markers
	for marker in enemy_markers:
		marker.queue_free()
	enemy_markers.clear()

	for marker in item_markers:
		marker.queue_free()
	item_markers.clear()

	for marker in npc_markers:
		marker.queue_free()
	npc_markers.clear()

	if not map_container:
		return

	# Add enemy markers
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D and enemy.has_method("is_alive") and enemy.is_alive():
			var marker := _create_marker(ENEMY_COLOR, 4)
			map_container.add_child(marker)
			marker.position = _world_to_map((enemy as Node3D).global_position)
			enemy_markers.append(marker)

	# Add item markers
	for item in get_tree().get_nodes_in_group("world_items"):
		if item is Node3D:
			var marker := _create_marker(ITEM_COLOR, 3)
			map_container.add_child(marker)
			marker.position = _world_to_map((item as Node3D).global_position)
			item_markers.append(marker)

	# Add NPC markers
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc is Node3D:
			var marker := _create_marker(NPC_COLOR, 5)
			map_container.add_child(marker)
			marker.position = _world_to_map((npc as Node3D).global_position)
			npc_markers.append(marker)

func _create_marker(color: Color, size: int) -> Control:
	var marker := ColorRect.new()
	marker.color = color
	marker.custom_minimum_size = Vector2(size, size)
	marker.size = Vector2(size, size)
	marker.pivot_offset = Vector2(size / 2.0, size / 2.0)
	return marker
