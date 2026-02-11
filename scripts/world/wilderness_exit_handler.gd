## wilderness_exit_handler.gd - Handles input for wilderness exit triggers
## Attached to wilderness exit areas to detect interact input
extends Node

## Set by parent (the Area3D exit)
var exit_area: Area3D
var direction: int = 0  # RoomEdge.Direction enum value
var start_coords: Vector2i = Vector2i.ZERO

## Track if player is in the exit zone
var player_in_zone: bool = false


func _ready() -> void:
	# Get data from parent if not set
	if exit_area == null:
		exit_area = get_parent() as Area3D

	if exit_area:
		exit_area.body_entered.connect(_on_body_entered)
		exit_area.body_exited.connect(_on_body_exited)

		# Get direction and coords from parent meta if not set
		if exit_area.has_meta("direction"):
			direction = exit_area.get_meta("direction")
		if exit_area.has_meta("start_coords"):
			start_coords = exit_area.get_meta("start_coords")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_zone = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_zone = false


func _input(event: InputEvent) -> void:
	if not player_in_zone:
		return

	if event.is_action_pressed("interact"):
		_enter_wilderness()
		get_viewport().set_input_as_handled()


func _enter_wilderness() -> void:
	# Hide prompt
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_interaction_prompt"):
		hud.hide_interaction_prompt()

	# Play transition sound
	AudioManager.play_sfx("door_open")

	# Enter wilderness room system
	print("[WildernessExitHandler] Entering wilderness at %s, direction %d" % [start_coords, direction])
	SceneManager.enter_wilderness(direction, start_coords)
