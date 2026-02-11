## wander_behavior.gd - Simple reusable wandering AI component
## Attach to any CharacterBody3D to give it random wandering behavior
## Works for civilians, animals, birds, etc.
class_name WanderBehavior
extends Node

## Configuration
@export var wander_radius: float = 8.0      ## How far from home to wander
@export var move_speed: float = 1.5         ## Walking speed
@export var min_wait_time: float = 2.0      ## Minimum time to wait at destination
@export var max_wait_time: float = 6.0      ## Maximum time to wait at destination
@export var min_wander_dist: float = 2.0    ## Minimum distance to pick for new target
@export var gravity: float = 20.0           ## Gravity strength
@export var can_fly: bool = false           ## If true, ignores gravity and can move vertically
@export var fly_height: float = 3.0         ## Base height for flying creatures
@export var fly_variance: float = 2.0       ## Random height variance for flying

## Stuck detection settings
@export var stuck_threshold: float = 0.15   ## Min distance to move per check
@export var stuck_check_interval: float = 1.0  ## How often to check if stuck
@export var max_stuck_count: int = 3        ## How many stuck checks before recovery

## State
enum State { IDLE, MOVING, WAITING, PAUSED }
var current_state: State = State.IDLE
var _state_before_pause: State = State.IDLE  # Store state when pausing
var home_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var wait_timer: float = 0.0
var is_paused: bool = false

## Stuck detection
var last_position: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var stuck_count: int = 0

## Reference to parent body
var body: CharacterBody3D = null

## Raycast for obstacle detection
var ray_query: PhysicsRayQueryParameters3D

## Signals for animation control
signal started_moving
signal stopped_moving
signal reached_destination

func _ready() -> void:
	# Get parent as CharacterBody3D
	body = get_parent() as CharacterBody3D
	if not body:
		push_warning("[WanderBehavior] Parent must be CharacterBody3D!")
		return

	# Initialize home position
	home_position = body.global_position
	target_position = home_position
	last_position = home_position

	# Setup raycast query for obstacle detection
	ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.collision_mask = 1  # World collision layer
	ray_query.exclude = [body.get_rid()]  # Exclude self

	# Start with random wait
	wait_timer = randf_range(min_wait_time, max_wait_time)
	current_state = State.WAITING


func _physics_process(delta: float) -> void:
	if not body:
		return

	# Apply gravity for ground creatures
	if not can_fly:
		if not body.is_on_floor():
			body.velocity.y -= gravity * delta
		else:
			body.velocity.y = 0

	# Stuck detection while moving
	if current_state == State.MOVING:
		_check_if_stuck(delta)

	# Process current state
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.WAITING:
			_process_waiting(delta)
		State.PAUSED:
			# Do nothing when paused
			body.velocity.x = 0
			body.velocity.z = 0

	body.move_and_slide()


func _process_idle(delta: float) -> void:
	body.velocity.x = 0
	body.velocity.z = 0
	if can_fly:
		body.velocity.y = 0

	# After brief idle, start waiting
	wait_timer -= delta
	if wait_timer <= 0:
		_pick_new_target()
		current_state = State.MOVING
		started_moving.emit()


func _process_moving(delta: float) -> void:
	var to_target := target_position - body.global_position

	# For ground creatures, ignore Y difference
	if not can_fly:
		to_target.y = 0

	var distance := to_target.length()

	# Check if reached destination
	var arrival_dist := 0.5 if not can_fly else 1.0
	if distance < arrival_dist:
		current_state = State.WAITING
		wait_timer = randf_range(min_wait_time, max_wait_time)
		body.velocity.x = 0
		body.velocity.z = 0
		if can_fly:
			body.velocity.y = 0
		stopped_moving.emit()
		reached_destination.emit()
		return

	# Move toward target
	var direction := to_target.normalized()
	body.velocity.x = direction.x * move_speed
	body.velocity.z = direction.z * move_speed

	if can_fly:
		body.velocity.y = direction.y * move_speed


func _process_waiting(delta: float) -> void:
	body.velocity.x = 0
	body.velocity.z = 0
	if can_fly:
		body.velocity.y = 0

	wait_timer -= delta
	if wait_timer <= 0:
		_pick_new_target()
		current_state = State.MOVING
		started_moving.emit()


func _pick_new_target() -> void:
	# Try multiple times to find a valid target
	for attempt in range(5):
		# Pick a random point within wander radius of home
		var angle := randf() * TAU
		var dist := randf_range(min_wander_dist, wander_radius)

		var candidate := home_position + Vector3(
			cos(angle) * dist,
			0,
			sin(angle) * dist
		)

		# For flying creatures, add height variance
		if can_fly:
			candidate.y = home_position.y + fly_height + randf_range(-fly_variance, fly_variance)

		# Check if path to candidate is clear
		if _is_path_clear(body.global_position, candidate):
			target_position = candidate
			stuck_count = 0
			return

	# If all attempts fail, stay near current position
	target_position = body.global_position


## Check if there's a clear path between two points
func _is_path_clear(from: Vector3, to: Vector3) -> bool:
	if not body or not ray_query:
		return true  # Assume clear if can't check

	var space_state := body.get_world_3d().direct_space_state
	if not space_state:
		return true

	# Raycast at character height (not ground level)
	var from_elevated := from + Vector3(0, 0.5, 0)
	var to_elevated := to + Vector3(0, 0.5, 0)

	ray_query.from = from_elevated
	ray_query.to = to_elevated

	var result := space_state.intersect_ray(ray_query)
	return result.is_empty()  # Clear if no hit


## Check if NPC is stuck and needs recovery
func _check_if_stuck(delta: float) -> void:
	stuck_timer += delta

	if stuck_timer >= stuck_check_interval:
		stuck_timer = 0.0

		# Calculate distance moved since last check
		var distance_moved := body.global_position.distance_to(last_position)

		if distance_moved < stuck_threshold:
			stuck_count += 1

			if stuck_count >= max_stuck_count:
				# NPC is stuck, pick a new target
				_recover_from_stuck()
		else:
			stuck_count = 0

		last_position = body.global_position


## Recovery behavior when stuck
func _recover_from_stuck() -> void:
	stuck_count = 0

	# Try to move backward slightly first
	var backward := -get_facing_direction() * 0.5
	var escape_pos := body.global_position + backward

	# If backward is clear, go there briefly
	if _is_path_clear(body.global_position, escape_pos):
		target_position = escape_pos
	else:
		# Otherwise just wait and try a new direction
		current_state = State.WAITING
		wait_timer = randf_range(0.5, 1.5)
		stopped_moving.emit()
		_pick_new_target()


## Set a new home position (useful for relocating NPCs)
func set_home(pos: Vector3) -> void:
	home_position = pos
	target_position = pos


## Force the entity to move to a specific position
func move_to(pos: Vector3) -> void:
	target_position = pos
	current_state = State.MOVING
	started_moving.emit()


## Check if currently moving
func is_moving() -> bool:
	return current_state == State.MOVING


## Get direction entity is facing (toward target)
func get_facing_direction() -> Vector3:
	if not body:
		return Vector3.FORWARD
	var dir := (target_position - body.global_position).normalized()
	dir.y = 0
	return dir if dir.length() > 0.1 else Vector3.FORWARD


## Set the facing direction (used when entity is controlled externally)
func set_facing_direction(direction: Vector3) -> void:
	if not body:
		return
	# Update target position to be in the given direction
	var facing_dist := 2.0
	target_position = body.global_position + direction.normalized() * facing_dist


## Pause wandering behavior
func pause() -> void:
	if is_paused:
		return
	is_paused = true
	_state_before_pause = current_state
	current_state = State.PAUSED
	if body:
		body.velocity = Vector3.ZERO
	stopped_moving.emit()


## Resume wandering behavior
func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	current_state = _state_before_pause
	if current_state == State.MOVING:
		started_moving.emit()
