## enemy_base.gd - Base class for all enemies
class_name EnemyBase
extends CharacterBody3D

const DEBUG := true  # Set to true for AI diagnosis - TESTING FIX

signal damaged(amount: int, damage_type: Enums.DamageType, attacker: Node)
signal died(killer: Node)
signal state_changed(old_state: int, new_state: int)
signal alert_state_changed(old_state: int, new_state: int)
signal attack_started(attack: EnemyAttackData)
signal target_acquired(target: Node)
signal target_lost

## Behavior mode - determines base movement pattern when not in combat
enum BehaviorMode {
	STATIONARY,  ## Stay in place, only react to threats
	PATROL,      ## Move between patrol points
	WANDER       ## Randomly wander within a radius of spawn position
}

## Patrol style - how the enemy moves between patrol points
enum PatrolStyle {
	LOOP,      ## Go A->B->C->A->B->C...
	PING_PONG  ## Go A->B->C->B->A->B...
}

## Alert state - awareness level separate from AI state
enum AlertState {
	IDLE,       ## Unaware, normal behavior
	ALERTED,    ## Heard/saw something, investigating
	COMBAT,     ## Actively engaged with target
	SEARCHING   ## Lost target, checking last known position
}

## Enemy data resource
@export var enemy_data: EnemyData

## Node references
@export var mesh_root: Node3D
@export var animation_player: AnimationPlayer
@export var nav_agent: NavigationAgent3D
@export var hitbox: Hitbox
@export var hurtbox: Hurtbox
@export var aggro_area: Area3D

## Behavior configuration
@export_group("Behavior")
@export var behavior_mode: BehaviorMode = BehaviorMode.STATIONARY
@export var patrol_style: PatrolStyle = PatrolStyle.LOOP
@export var patrol_wait_time: float = 2.0  ## Time to wait at each patrol point
@export var wander_radius: float = 5.0    ## How far from spawn the enemy can wander
@export var wander_wait_time: float = 2.0 ## How long to wait at each wander point

## Random behavior selection on spawn
@export_subgroup("Random Behavior")
@export var randomize_behavior: bool = true
@export var stationary_weight: float = 1.0
@export var patrol_weight: float = 2.0
@export var wander_weight: float = 2.0

## Ranged enemy randomization
@export_subgroup("Ranged Randomization")
@export var randomize_ranged: bool = false        ## Enable random ranged selection on spawn
@export var ranged_chance: float = 0.3            ## Chance (0-1) to become ranged on spawn
@export var ranged_projectile_on_random: ProjectileData  ## Projectile to use if randomly selected as ranged

## Auto-generate patrol points
@export_subgroup("Auto Patrol")
@export var auto_generate_patrol_points: bool = true
@export var patrol_point_count: int = 3
@export var patrol_radius: float = 12.0

## Alert configuration
@export_group("Alert System")
@export var alert_duration: float = 3.0       ## How long to stay alerted before returning to idle
@export var search_duration: float = 5.0      ## How long to search before giving up
@export var investigation_speed_mult: float = 0.7  ## Speed multiplier when investigating
@export var look_around_time: float = 1.5     ## Time spent looking around at search location
@export var search_radius: float = 3.0        ## Radius to check around last known position

## Leash configuration
@export_group("Leash System")
@export var leash_radius: float = 25.0        ## Max distance from spawn before returning
@export var leash_return_speed_mult: float = 1.5  ## Speed multiplier when returning to spawn

## Totem defense state (set when spawner is attacked)
var defending_totem: bool = false
var totem_position: Vector3 = Vector3.ZERO

## Ranged combat configuration
@export_group("Ranged Combat")
@export var is_ranged: bool = false           ## Uses ranged attacks
@export var preferred_range: float = 10.0     ## Distance to maintain from target
@export var min_range: float = 3.0            ## Minimum distance - will back away if closer (reduced from 5.0 for less fleeing)
@export var ranged_attack_projectile: ProjectileData  ## Projectile to fire
@export var ranged_attack_cooldown: float = 2.0  ## Time between ranged attacks
@export var ranged_attack_windup: float = 0.5 ## Wind-up time before firing
@export var strafe_speed_mult: float = 0.7    ## Speed when strafing
@export var strafe_chance: float = 0.3        ## Chance to strafe after attacking
@export var strafe_duration: float = 1.0      ## How long to strafe

## Ammo system for ranged enemies
@export_subgroup("Ammo System")
@export var max_ammo: int = 15                ## Maximum ammo capacity
@export var ammo_restock_time_min: float = 30.0   ## Minimum time before restock (seconds)
@export var ammo_restock_time_max: float = 120.0  ## Maximum time before restock (seconds)

## Stats (copied from data for runtime modification)
var current_hp: int = 25
var max_hp: int = 25
var armor_value: int = 8
var base_damage: int = 0  ## Base damage for scaling (from first attack)

## Zone danger level for stat scaling (set by spawner)
var zone_danger: int = 1

## AI State
enum AIState {
	IDLE,
	PATROL,
	WANDER,
	CHASE,
	ATTACK,
	RETREAT,
	STAGGERED,
	DEAD,
	DISENGAGE,    ## Returning to spawn position (leash)
	RANGED_ATTACK, ## Charging/firing ranged attack
	STRAFE        ## Strafing to reposition
}

var current_state: AIState = AIState.IDLE
var previous_state: AIState = AIState.IDLE

## Alert state tracking (separate from AI state)
var current_alert_state: AlertState = AlertState.IDLE
var previous_alert_state: AlertState = AlertState.IDLE

## Target tracking
var current_target: Node3D = null
var last_known_target_position: Vector3 = Vector3.ZERO
var has_line_of_sight: bool = false
var investigation_position: Vector3 = Vector3.ZERO  ## Position to investigate when alerted

## Movement
var move_direction: Vector3 = Vector3.ZERO
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_direction: int = 1  ## 1 = forward, -1 = backward (for ping-pong)
var patrol_wait_timer: float = 0.0  ## Timer for waiting at patrol points
var spawn_position: Vector3 = Vector3.ZERO  ## Original position for stationary enemies

## Wander state
var wander_target_position: Vector3 = Vector3.ZERO  ## Current wander destination
var wander_wait_timer: float = 0.0  ## Timer for waiting at wander points
var has_wander_target: bool = false  ## Whether we have a valid wander destination

## Alert/Search timers
var alert_timer: float = 0.0      ## Time remaining in alerted state
var search_timer: float = 0.0     ## Time remaining in searching state
var look_around_timer: float = 0.0  ## Timer for looking around behavior
var search_points_checked: int = 0  ## Number of search points visited
var current_search_point: Vector3 = Vector3.ZERO  ## Current point being searched

## Ranged combat state
var ranged_attack_timer: float = 0.0  ## Cooldown timer for ranged attacks
var ranged_windup_timer: float = 0.0  ## Windup timer for current ranged attack
var is_firing_ranged: bool = false    ## Currently in ranged attack animation
var strafe_timer: float = 0.0         ## Time remaining in strafe
var strafe_direction: int = 1         ## 1 = right, -1 = left

## Ammo system state
var current_ammo: int = 0             ## Current ammo count
var ammo_restock_timer: float = 0.0   ## Timer for restocking ammo
var was_originally_ranged: bool = false  ## Track if enemy spawned as ranged

## Stuck detection and recovery
var stuck_check_timer: float = 0.0           ## Timer for stuck detection checks
var last_position_check: Vector3 = Vector3.ZERO  ## Position at last stuck check
var stuck_time_accumulated: float = 0.0      ## How long enemy has been stuck
var unstuck_attempts: int = 0                ## Number of consecutive unstuck attempts
var unstuck_target: Vector3 = Vector3.ZERO   ## Temporary target to get unstuck
var is_unstucking: bool = false              ## Currently executing unstuck behavior
var unstuck_timer: float = 0.0               ## Timer for unstuck movement duration
var path_recalc_timer: float = 0.0           ## Timer for periodic path recalculation

const STUCK_CHECK_INTERVAL: float = 0.5      ## How often to check if stuck (seconds)
const STUCK_THRESHOLD: float = 0.3           ## Min distance to move in check interval to not be stuck
const STUCK_TIME_TRIGGER: float = 1.5        ## Accumulated stuck time before triggering unstuck
const UNSTUCK_DURATION: float = 1.0          ## How long to execute unstuck movement
const PATH_RECALC_INTERVAL: float = 1.5      ## How often to recalculate nav path (seconds)
const MAX_UNSTUCK_ATTEMPTS: int = 5          ## Max attempts before giving up temporarily
const UNSTUCK_COOLDOWN: float = 3.0          ## Cooldown after max attempts reached

## Minimum combat distance - enemies won't walk closer than this to the player
## This prevents enemies from blocking the player's view during combat
## Set lower than default attack_range (2.0) to ensure enemies can attack
const MIN_COMBAT_DISTANCE: float = 1.2       ## Minimum distance to maintain from target

## Ranged enemy visual tint
var _original_material: Material = null
var _ranged_tint_applied: bool = false
const RANGED_TINT_COLOR := Color(1.0, 0.3, 0.3, 1.0)  ## Red tint for ranged enemies (strong red)

## Combat
var attack_cooldown: float = 0.0
var current_attack: EnemyAttackData = null
var is_attacking: bool = false
var stagger_timer: float = 0.0

## Chase timeout - enemy gives up chasing after this duration without hitting target
var chase_timer: float = 0.0
const CHASE_TIMEOUT: float = 15.0  ## Seconds before enemy gives up chasing

## Disengage cooldown - prevents immediate re-aggro after returning to spawn
var disengage_cooldown: float = 0.0
const DISENGAGE_COOLDOWN_DURATION: float = 5.0  ## Seconds to ignore player after disengaging

## Intimidation system - when player intimidates successfully, enemy flees
var is_intimidated: bool = false
var intimidation_cooldown: float = 0.0
const INTIMIDATION_COOLDOWN_DURATION: float = 30.0  ## Can't be re-intimidated for 30 seconds

## Conditions
var active_conditions: Dictionary = {}

## Stealth awareness system
var awareness_level: float = 0.0  # 0.0 = unaware, builds toward thresholds
var player_in_detection_range: bool = false  # True when player is in aggro area
var _awareness_target: Node3D = null  # Reference to player being tracked for awareness

## Persistent ID for enemy kill tracking (set by spawner for procedural dungeons)
## If not empty, death will be recorded in SaveManager so enemy doesn't respawn
var persistent_id: String = ""

## Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## PERFORMANCE: Cached player reference to avoid get_nodes_in_group("player") spam
var _cached_player: Node3D = null

## PERFORMANCE: Cached distance to player (recalculated at start of each physics frame)
var _cached_player_distance_sq: float = INF

func _ready() -> void:
	add_to_group("enemies")
	CombatManager.register_enemy(self)
	# Defer hiding mesh placeholders - if a billboard is set up later, they'll be hidden anyway
	# This ensures enemies without explicit billboard setup don't show ugly 3D placeholders
	call_deferred("_hide_mesh_placeholders_if_no_billboard")

	# PERFORMANCE: Cache player reference at startup
	_cached_player = get_tree().get_first_node_in_group("player")

	# Store spawn position for stationary enemies
	spawn_position = global_position
	var enemy_name: String = enemy_data.display_name if enemy_data else name
	print("[Enemy] ", enemy_name, " _ready() - spawn_position set to: ", spawn_position, " (global_pos=", global_position, ")")

	# Connect to floating origin shift signal to update stored positions
	if CellStreamer and CellStreamer.has_signal("origin_shifted"):
		if not CellStreamer.origin_shifted.is_connected(_on_origin_shifted):
			CellStreamer.origin_shifted.connect(_on_origin_shifted)

	# Register with WorldData for tracking
	_register_with_world_data()

	# Initialize stuck detection position
	last_position_check = global_position

	# Initialize from data
	if enemy_data:
		_initialize_from_data()

	# Fallback: get nodes by path if exports weren't resolved
	if not hitbox:
		hitbox = get_node_or_null("MeshRoot/Hitbox") as Hitbox
	if not hurtbox:
		hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	if not aggro_area:
		aggro_area = get_node_or_null("AggroArea") as Area3D
	if not mesh_root:
		mesh_root = get_node_or_null("MeshRoot") as Node3D
	if not nav_agent:
		nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D

	# Setup hitbox
	if hitbox:
		hitbox.set_owner_entity(self)
		hitbox.add_to_group("enemy_hitbox")
		if DEBUG:
			print("[Enemy] Hitbox configured: ", hitbox.name, " layer=", hitbox.collision_layer, " mask=", hitbox.collision_mask)
	elif DEBUG:
		print("[Enemy] WARNING: No hitbox found!")

	# Setup hurtbox
	if hurtbox:
		hurtbox.set_owner_entity(self)
		hurtbox.add_to_group("enemy_hurtbox")
		hurtbox.hurt.connect(_on_hurtbox_hurt)

	# Setup aggro detection
	if aggro_area:
		aggro_area.body_entered.connect(_on_aggro_area_body_entered)
		aggro_area.body_exited.connect(_on_aggro_area_body_exited)

	# Randomly select ranged if enabled and not already ranged
	if randomize_ranged and not is_ranged:
		_try_become_ranged()

	# Apply ranged enemy visual tint
	if is_ranged:
		_apply_ranged_tint()

	# Initialize ammo system for ranged enemies
	was_originally_ranged = is_ranged
	if is_ranged:
		current_ammo = max_ammo

	# Randomly select behavior mode if enabled
	if randomize_behavior:
		_select_random_behavior()

	# Auto-generate patrol points if PATROL was chosen and no points exist
	if behavior_mode == BehaviorMode.PATROL and patrol_points.is_empty() and auto_generate_patrol_points:
		_generate_patrol_points()

	# Wait for navigation to be ready before starting behavior
	call_deferred("_wait_for_navigation_then_start")


## Hide 3D mesh placeholders if no billboard sprite was set up
## Called deferred from _ready to allow billboard setup to happen first
func _hide_mesh_placeholders_if_no_billboard() -> void:
	# If billboard sprite already exists, meshes are already hidden
	if billboard_sprite:
		return

	# Hide placeholder meshes
	if mesh_root:
		for child in mesh_root.get_children():
			if child is MeshInstance3D:
				child.visible = false

func _exit_tree() -> void:
	# Safety cleanup - ensure we're unregistered even if freed without proper death
	CombatManager.unregister_enemy(self)
	# Disconnect from origin shift signal
	if CellStreamer and CellStreamer.has_signal("origin_shifted"):
		if CellStreamer.origin_shifted.is_connected(_on_origin_shifted):
			CellStreamer.origin_shifted.disconnect(_on_origin_shifted)


## Handle floating origin shift - update all stored world positions
func _on_origin_shifted(shift: Vector3) -> void:
	spawn_position -= shift
	last_known_target_position -= shift
	last_position_check -= shift
	wander_target_position -= shift
	unstuck_target -= shift
	investigation_position -= shift
	current_search_point -= shift

	# Update patrol points
	for i in range(patrol_points.size()):
		patrol_points[i] -= shift

	if DEBUG:
		var enemy_name: String = enemy_data.display_name if enemy_data else name
		print("[Enemy] ", enemy_name, " origin shifted by ", shift, " - spawn_position now: ", spawn_position)


func _initialize_from_data() -> void:
	# Get player level for scaling (default to 1 if not available)
	var player_level: int = 1
	if GameManager and GameManager.player_data:
		player_level = GameManager.player_data.level

	# Calculate effective level based on zone danger
	var effective_level: int = enemy_data.get_effective_level(player_level, zone_danger)
	var level_ratio: float = float(effective_level) / float(maxi(enemy_data.level, 1))

	# Scale HP linearly with level ratio
	var scaled_hp: int = int(enemy_data.max_hp * level_ratio)
	max_hp = maxi(scaled_hp, 1)  # Ensure at least 1 HP
	current_hp = max_hp
	armor_value = enemy_data.armor_value

	# Calculate base damage from first attack for damage scaling
	if not enemy_data.attacks.is_empty():
		var first_attack: EnemyAttackData = enemy_data.attacks[0]
		if first_attack:
			# Store base damage for reference (average of dice roll)
			var dice_count: int = first_attack.damage[0] if first_attack.damage.size() > 0 else 1
			var dice_sides: int = first_attack.damage[1] if first_attack.damage.size() > 1 else 4
			var flat_bonus: int = first_attack.damage[2] if first_attack.damage.size() > 2 else 0
			base_damage = int(dice_count * (dice_sides + 1) / 2.0 + flat_bonus)

	# Scale damage using sqrt for smoother curve (applied via attack damage modifier)
	# Damage scaling is handled at attack time, not here

	if aggro_area:
		# Adjust aggro range from data
		var shape := aggro_area.get_child(0)
		if shape is CollisionShape3D and shape.shape is SphereShape3D:
			(shape.shape as SphereShape3D).radius = enemy_data.aggro_range

	# Apply scale from enemy data (affects mesh size)
	if enemy_data.scale > 0 and enemy_data.scale != 1.0:
		var scale_factor: float = enemy_data.scale
		# Scale the mesh root
		if mesh_root:
			mesh_root.scale = Vector3(scale_factor, scale_factor, scale_factor)
		# Scale collision shape to match
		var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision and collision.shape is CapsuleShape3D:
			var capsule := collision.shape.duplicate() as CapsuleShape3D
			capsule.radius *= scale_factor
			capsule.height *= scale_factor
			collision.shape = capsule
			collision.position.y *= scale_factor
		# Scale hurtbox to match
		if hurtbox:
			var hurtbox_shape := hurtbox.get_node_or_null("HurtboxShape") as CollisionShape3D
			if hurtbox_shape and hurtbox_shape.shape is CapsuleShape3D:
				var hcapsule := hurtbox_shape.shape.duplicate() as CapsuleShape3D
				hcapsule.radius *= scale_factor
				hcapsule.height *= scale_factor
				hurtbox_shape.shape = hcapsule
			hurtbox.position.y *= scale_factor

## Register this enemy with WorldData for tracking
## Note: Enemy tracking removed - enemies are found dynamically via "enemies" group
func _register_with_world_data() -> void:
	# Legacy function - enemy spawns are tracked in-scene via groups, not a global registry
	pass


## Randomly select behavior mode based on weights
func _select_random_behavior() -> void:
	var total_weight := stationary_weight + patrol_weight + wander_weight
	if total_weight <= 0:
		return  # Keep current behavior_mode if all weights are zero

	var roll := randf() * total_weight
	var cumulative := 0.0

	cumulative += stationary_weight
	if roll < cumulative:
		behavior_mode = BehaviorMode.STATIONARY
		if DEBUG:
			print("[Enemy] Random behavior selected: STATIONARY")
		return

	cumulative += patrol_weight
	if roll < cumulative:
		behavior_mode = BehaviorMode.PATROL
		if DEBUG:
			print("[Enemy] Random behavior selected: PATROL")
		return

	behavior_mode = BehaviorMode.WANDER
	if DEBUG:
		print("[Enemy] Random behavior selected: WANDER")

## Randomly become a ranged enemy based on ranged_chance
func _try_become_ranged() -> void:
	if randf() < ranged_chance:
		is_ranged = true
		# Use the designated ranged projectile, or fall back to default arrow
		if ranged_projectile_on_random:
			ranged_attack_projectile = ranged_projectile_on_random
		elif not ranged_attack_projectile:
			# Try to load default arrow projectile
			var default_arrow := load("res://resources/projectiles/arrow_basic.tres") as ProjectileData
			if default_arrow:
				ranged_attack_projectile = default_arrow
		if DEBUG:
			print("[Enemy] Randomly became RANGED enemy")

## Generate random patrol points around spawn position
func _generate_patrol_points() -> void:
	patrol_points.clear()

	for i in range(patrol_point_count):
		var angle := (float(i) / patrol_point_count) * TAU + randf_range(-0.3, 0.3)
		var distance := randf_range(patrol_radius * 0.5, patrol_radius)
		var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var point := spawn_position + offset
		patrol_points.append(point)

	if DEBUG:
		print("[Enemy] Generated ", patrol_point_count, " patrol points within radius ", patrol_radius)
		for i in range(patrol_points.size()):
			print("  Point ", i, ": ", patrol_points[i])

## Wait for navigation mesh to be ready before starting behavior
## Simple approach: wait 2 physics frames for NavigationServer3D to sync after baking
## This works regardless of when the enemy spawns (initial load, save load, or late spawn)
func _wait_for_navigation_then_start() -> void:
	# Wait 2 physics frames for NavigationServer3D to sync
	await get_tree().physics_frame
	await get_tree().physics_frame
	_start_initial_behavior()


## Start the initial behavior state immediately
func _start_initial_behavior() -> void:
	if DEBUG:
		print("[Enemy] _start_initial_behavior called")
		print("[Enemy]   behavior_mode=", behavior_mode, " nav_agent=", nav_agent)
		print("[Enemy]   patrol_points=", patrol_points.size(), " spawn_position=", spawn_position)

	match behavior_mode:
		BehaviorMode.STATIONARY:
			if DEBUG:
				print("[Enemy]   Starting STATIONARY -> IDLE")
			_change_state(AIState.IDLE)
		BehaviorMode.PATROL:
			if patrol_points.size() > 0:
				current_patrol_index = 0
				if DEBUG:
					print("[Enemy]   Starting PATROL with ", patrol_points.size(), " points")
				_change_state(AIState.PATROL)
			else:
				if DEBUG:
					print("[Enemy]   No patrol points, falling back to IDLE")
				_change_state(AIState.IDLE)
		BehaviorMode.WANDER:
			has_wander_target = false
			if DEBUG:
				print("[Enemy]   Starting WANDER")
			_change_state(AIState.WANDER)

var _physics_frame_count: int = 0

func _physics_process(delta: float) -> void:
	_physics_frame_count += 1

	# Debug: confirm physics process is running
	if DEBUG and _physics_frame_count <= 5:
		print("[Enemy] _physics_process frame ", _physics_frame_count, " state=", current_state, " velocity=", velocity)

	if current_state == AIState.DEAD:
		return

	# RECOVERY: Detect broken spawn_position (from origin shift desync or bad save)
	# If spawn is impossibly far (>150 units) and we're in DISENGAGE, reset to current position
	if current_state == AIState.DISENGAGE:
		var dist_to_spawn: float = global_position.distance_to(spawn_position)
		if dist_to_spawn > 150.0:  # Way beyond any reasonable leash
			var enemy_name: String = enemy_data.display_name if enemy_data else name
			print("[AI] ", enemy_name, " RECOVERY: spawn_position was broken (dist=", snapped(dist_to_spawn, 0.1), "). Resetting to current position.")
			spawn_position = global_position
			_change_state(AIState.IDLE)
			return

	# PERFORMANCE: Re-cache player if invalid (scene changed, etc.)
	if not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
		if not _cached_player or not is_instance_valid(_cached_player):
			return  # No player, skip all updates

	# Safety check - player might have been freed between cache and use
	if not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		_cached_player = null
		return

	# PERFORMANCE: Cache distance to player once per frame (used by multiple systems)
	_cached_player_distance_sq = global_position.distance_squared_to(_cached_player.global_position)

	# PERFORMANCE: Enemy LOD system - skip updates for distant enemies
	# > 60 units: skip all updates
	# > 30 units: update at 1/4 rate
	# > 20 units: update at 1/2 rate
	if _cached_player_distance_sq > 3600.0:  # > 60 units
		return  # Skip all updates for distant enemies
	elif _cached_player_distance_sq > 900.0:  # > 30 units
		if _physics_frame_count % 4 != 0:
			return  # Update at 1/4 rate
	elif _cached_player_distance_sq > 400.0:  # > 20 units
		if _physics_frame_count % 2 != 0:
			return  # Update at 1/2 rate
	# else: full update rate for nearby enemies

	# AI THOUGHT PROCESS DEBUG - every 60 frames (~1 second)
	if _physics_frame_count % 60 == 0:
		var enemy_name: String = enemy_data.display_name if enemy_data else name
		var state_name: String = AIState.keys()[current_state] if current_state < AIState.size() else str(current_state)
		var dist_to_player: float = sqrt(_cached_player_distance_sq)
		var dist_to_spawn: float = global_position.distance_to(spawn_position)
		var aggro_range_val: float = enemy_data.aggro_range if enemy_data else 12.0
		print("═══════════════════════════════════════════════════════════")
		print("[AI] ", enemy_name, " THOUGHT PROCESS:")
		print("  State: ", state_name, " | Alert: ", AlertState.keys()[current_alert_state])
		print("  Position: ", snapped(global_position, Vector3(0.1, 0.1, 0.1)))
		print("  Spawn Position: ", snapped(spawn_position, Vector3(0.1, 0.1, 0.1)))
		print("  Distance to PLAYER: ", snapped(dist_to_player, 0.1), " (aggro_range=", aggro_range_val, ")")
		print("  Distance to SPAWN: ", snapped(dist_to_spawn, 0.1), " (leash_radius=", leash_radius, ")")
		print("  Target: ", current_target.name if current_target else "NONE")
		print("  Has LOS: ", has_line_of_sight)
		print("  Disengage Cooldown: ", snapped(disengage_cooldown, 0.1))
		print("  Nav Agent: ", nav_agent != null, " | Nav Target: ", nav_agent.target_position if nav_agent else "N/A")
		if nav_agent:
			print("  Nav Finished: ", nav_agent.is_navigation_finished(), " | Reachable: ", nav_agent.is_target_reachable())
		print("═══════════════════════════════════════════════════════════")

	_update_timers(delta)
	_update_conditions(delta)
	_update_awareness(delta)  # Stealth awareness system
	_update_target()
	_update_state_machine(delta)
	_update_movement(delta)

	move_and_slide()

	# Update rat directional sprite based on movement direction
	if _is_rat_enemy:
		_update_rat_directional_sprite()

	# Debug: confirm movement is being applied
	if DEBUG and _physics_frame_count <= 10:
		print("[Enemy] After move_and_slide: position=", global_position, " velocity=", velocity)

func _update_timers(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

	if stagger_timer > 0:
		stagger_timer -= delta
		if stagger_timer <= 0 and current_state == AIState.STAGGERED:
			_change_state(AIState.CHASE if current_target else AIState.IDLE)

	# Patrol wait timer
	if patrol_wait_timer > 0:
		patrol_wait_timer -= delta

	# Wander wait timer
	if wander_wait_timer > 0:
		wander_wait_timer -= delta

	# Ranged attack cooldown
	if ranged_attack_timer > 0:
		ranged_attack_timer -= delta

	# Strafe timer
	if strafe_timer > 0:
		strafe_timer -= delta
		if strafe_timer <= 0 and current_state == AIState.STRAFE:
			_change_state(AIState.CHASE)

	# Chase timeout timer
	if current_state == AIState.CHASE:
		chase_timer += delta
		if chase_timer >= CHASE_TIMEOUT:
			if DEBUG:
				print("[Enemy] Chase timeout reached, disengaging")
			chase_timer = 0.0
			_change_state(AIState.DISENGAGE)

	# Disengage cooldown timer (prevents immediate re-aggro after returning to spawn)
	if disengage_cooldown > 0:
		disengage_cooldown -= delta

	# Intimidation cooldown timer (prevents re-intimidation spam)
	if intimidation_cooldown > 0:
		intimidation_cooldown -= delta
		if intimidation_cooldown <= 0:
			is_intimidated = false  # Can be intimidated again

	# Ammo restock timer (for ranged enemies that ran out of ammo)
	if ammo_restock_timer > 0:
		ammo_restock_timer -= delta
		if ammo_restock_timer <= 0:
			_on_ammo_restocked()

	# Alert state timers
	_update_alert_timers(delta)

	# Stuck detection and path recalculation (only when actively moving)
	_update_stuck_detection(delta)
	_update_path_recalculation(delta)

func _update_alert_timers(delta: float) -> void:
	match current_alert_state:
		AlertState.ALERTED:
			alert_timer -= delta
			if alert_timer <= 0:
				# If we reached investigation point without finding target, start searching
				if _is_near_position(investigation_position, 2.0):
					_change_alert_state(AlertState.SEARCHING)
				else:
					# Timeout while still moving to position - give up
					_change_alert_state(AlertState.IDLE)

		AlertState.SEARCHING:
			search_timer -= delta
			look_around_timer -= delta

			if search_timer <= 0:
				# Search timeout - return to idle
				_change_alert_state(AlertState.IDLE)
			elif look_around_timer <= 0:
				# Done looking at current point, pick next search point
				_pick_next_search_point()

		AlertState.COMBAT:
			# Combat state is managed by target tracking, not timers
			pass

		AlertState.IDLE:
			# Nothing to update
			pass

## Stuck detection - checks if enemy hasn't moved significantly while trying to move
func _update_stuck_detection(delta: float) -> void:
	# Only check stuck state when enemy should be moving
	if not _should_check_stuck():
		_reset_stuck_state()
		return

	# Handle ongoing unstuck behavior
	if is_unstucking:
		unstuck_timer -= delta
		if unstuck_timer <= 0:
			is_unstucking = false
			if DEBUG:
				print("[Enemy] Unstuck behavior complete, resuming normal movement")
		return

	# Periodic stuck check
	stuck_check_timer += delta
	if stuck_check_timer >= STUCK_CHECK_INTERVAL:
		stuck_check_timer = 0.0

		# Check if we've moved enough since last check
		var distance_moved := global_position.distance_to(last_position_check)
		last_position_check = global_position

		if distance_moved < STUCK_THRESHOLD:
			# Haven't moved enough - accumulate stuck time
			stuck_time_accumulated += STUCK_CHECK_INTERVAL
			if DEBUG:
				print("[Enemy] Stuck check: moved ", snapped(distance_moved, 0.01), " (threshold: ", STUCK_THRESHOLD, ") - stuck time: ", snapped(stuck_time_accumulated, 0.1))

			# Trigger unstuck behavior if stuck too long
			if stuck_time_accumulated >= STUCK_TIME_TRIGGER:
				_trigger_unstuck_behavior()
		else:
			# Moving normally - reset stuck tracking
			stuck_time_accumulated = 0.0
			unstuck_attempts = 0

## Check if enemy is in a state where stuck detection should apply
func _should_check_stuck() -> bool:
	# Only check when actively trying to move toward something
	match current_state:
		AIState.CHASE, AIState.PATROL, AIState.WANDER, AIState.DISENGAGE, AIState.RETREAT, AIState.STRAFE:
			return true
		AIState.IDLE:
			# Also check if investigating or searching
			return current_alert_state in [AlertState.ALERTED, AlertState.SEARCHING]
		_:
			return false

## Reset stuck detection state
func _reset_stuck_state() -> void:
	stuck_time_accumulated = 0.0
	stuck_check_timer = 0.0
	is_unstucking = false

## Trigger unstuck behavior when enemy is detected as stuck
func _trigger_unstuck_behavior() -> void:
	unstuck_attempts += 1
	stuck_time_accumulated = 0.0

	if DEBUG:
		print("[Enemy] Triggering unstuck behavior (attempt ", unstuck_attempts, "/", MAX_UNSTUCK_ATTEMPTS, ")")

	# If too many attempts, give up temporarily and force path recalculation
	if unstuck_attempts >= MAX_UNSTUCK_ATTEMPTS:
		if DEBUG:
			print("[Enemy] Max unstuck attempts reached, forcing path recalc and cooldown")
		unstuck_attempts = 0
		_force_path_recalculation()
		# Add small random offset to target to try different path
		if nav_agent:
			var offset := Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
			nav_agent.target_position = nav_agent.target_position + offset
		return

	# Pick unstuck strategy based on attempt number
	match unstuck_attempts % 3:
		0:
			_unstuck_strafe()
		1:
			_unstuck_random_nearby()
		2:
			_unstuck_backup()

	is_unstucking = true
	unstuck_timer = UNSTUCK_DURATION

## Unstuck strategy: Strafe left or right to get around obstacle
func _unstuck_strafe() -> void:
	var strafe_dir: int = 1 if randf() > 0.5 else -1

	# Calculate strafe direction perpendicular to intended movement
	var intended_dir := Vector3.ZERO
	if current_target and is_instance_valid(current_target):
		intended_dir = (current_target.global_position - global_position).normalized()
	elif nav_agent:
		intended_dir = (nav_agent.target_position - global_position).normalized()

	if intended_dir.length() < 0.1:
		intended_dir = Vector3.FORWARD.rotated(Vector3.UP, mesh_root.rotation.y if mesh_root else 0)

	intended_dir.y = 0
	var strafe_vector := intended_dir.cross(Vector3.UP) * strafe_dir
	unstuck_target = global_position + strafe_vector * 3.0

	if DEBUG:
		print("[Enemy] Unstuck: strafing ", "right" if strafe_dir > 0 else "left", " to ", unstuck_target)

## Unstuck strategy: Pick a random nearby point
func _unstuck_random_nearby() -> void:
	var angle := randf() * TAU
	var distance := randf_range(2.0, 4.0)
	var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	unstuck_target = global_position + offset

	if DEBUG:
		print("[Enemy] Unstuck: moving to random nearby point ", unstuck_target)

## Unstuck strategy: Back up from current position
func _unstuck_backup() -> void:
	var backup_dir := Vector3.BACK.rotated(Vector3.UP, mesh_root.rotation.y if mesh_root else 0)
	unstuck_target = global_position + backup_dir * 2.5

	if DEBUG:
		print("[Enemy] Unstuck: backing up to ", unstuck_target)

## Periodic path recalculation to handle moving targets and changing environments
func _update_path_recalculation(delta: float) -> void:
	if not nav_agent:
		return

	# Only recalculate when actively navigating
	if not _should_check_stuck():
		path_recalc_timer = 0.0
		return

	path_recalc_timer += delta
	if path_recalc_timer >= PATH_RECALC_INTERVAL:
		path_recalc_timer = 0.0
		_recalculate_nav_path()

## Recalculate navigation path based on current state
func _recalculate_nav_path() -> void:
	if not nav_agent:
		return

	var new_target := Vector3.ZERO

	match current_state:
		AIState.CHASE:
			if current_target and is_instance_valid(current_target):
				new_target = current_target.global_position
			elif last_known_target_position != Vector3.ZERO:
				new_target = last_known_target_position
		AIState.PATROL:
			if patrol_points.size() > 0:
				new_target = patrol_points[current_patrol_index]
		AIState.WANDER:
			if has_wander_target:
				new_target = wander_target_position
		AIState.DISENGAGE:
			new_target = spawn_position
		AIState.RETREAT:
			if current_target and is_instance_valid(current_target):
				var away_dir := (global_position - current_target.global_position).normalized()
				new_target = global_position + away_dir * 10.0
		AIState.STRAFE:
			# Strafe handles its own targeting
			return
		AIState.IDLE:
			if current_alert_state == AlertState.ALERTED:
				new_target = investigation_position
			elif current_alert_state == AlertState.SEARCHING:
				new_target = current_search_point
			else:
				return

	if new_target != Vector3.ZERO:
		nav_agent.target_position = new_target
		if DEBUG and Engine.get_physics_frames() % 90 == 0:
			print("[Enemy] Path recalculated to ", new_target)

## Force immediate path recalculation
func _force_path_recalculation() -> void:
	path_recalc_timer = PATH_RECALC_INTERVAL  # This will trigger recalc on next update
	if DEBUG:
		print("[Enemy] Forced path recalculation")

func _update_conditions(delta: float) -> void:
	var to_remove: Array = []
	for condition in active_conditions:
		active_conditions[condition] -= delta

		# Apply DOT effects
		match condition:
			Enums.Condition.POISONED:
				take_damage(1, Enums.DamageType.POISON, null)
			Enums.Condition.BURNING:
				take_damage(2, Enums.DamageType.FIRE, null)

		if active_conditions[condition] <= 0:
			to_remove.append(condition)

	for condition in to_remove:
		active_conditions.erase(condition)

## Update stealth awareness system
func _update_awareness(delta: float) -> void:
	# Already have a target - awareness maxed
	if current_target and is_instance_valid(current_target):
		awareness_level = 1.0
		return

	# No player in detection range - decay awareness
	if not player_in_detection_range or not _awareness_target or not is_instance_valid(_awareness_target):
		awareness_level = maxf(0.0, awareness_level - StealthConstants.AWARENESS_DECAY_RATE * delta)
		return

	# Player is in range - check visibility and LOS
	var player: Node3D = _awareness_target

	# Check line of sight
	if not CombatManager.has_line_of_sight(self, player):
		# Can't see player - slowly decay awareness
		awareness_level = maxf(0.0, awareness_level - StealthConstants.AWARENESS_DECAY_RATE * 0.5 * delta)
		return

	# Can see player - get their visibility
	var player_visibility: float = 1.0
	if player.has_method("get_visibility"):
		player_visibility = player.get_visibility()

	# If player is undetectable, don't build awareness at all
	if StealthConstants.is_undetectable(player_visibility):
		awareness_level = maxf(0.0, awareness_level - StealthConstants.AWARENESS_DECAY_RATE * delta)
		return

	# Build awareness based on player visibility
	var build_rate: float = StealthConstants.get_awareness_build_rate(player_visibility)
	awareness_level = minf(1.0, awareness_level + build_rate * delta)

	# Check thresholds
	if awareness_level >= StealthConstants.COMBAT_THRESHOLD and current_alert_state != AlertState.COMBAT:
		# Full detection!
		_detect_player_immediately(player)
	elif awareness_level >= StealthConstants.ALERT_THRESHOLD and current_alert_state == AlertState.IDLE:
		# Become alerted
		investigation_position = player.global_position
		_change_alert_state(AlertState.ALERTED)
		if DEBUG:
			print("[Enemy] Became ALERTED - awareness=%.2f, player visibility=%.2f" % [awareness_level, player_visibility])

## Check if enemy is unaware (for backstab)
func is_unaware() -> bool:
	return current_alert_state == AlertState.IDLE and awareness_level < StealthConstants.ALERT_THRESHOLD

func _update_target() -> void:
	# Skip all target tracking while disengaging - enemy is returning home
	if current_state == AIState.DISENGAGE:
		current_target = null
		has_line_of_sight = false
		return

	if not current_target or not is_instance_valid(current_target):
		var had_target := current_target != null
		current_target = null
		has_line_of_sight = false

		# If we lost a target during combat, transition to searching
		if had_target and current_alert_state == AlertState.COMBAT:
			_change_alert_state(AlertState.SEARCHING)

		# Fallback: manually scan for player if aggro area didn't work
		# But skip scan if we're in disengage cooldown (just returned home)
		if current_state == AIState.IDLE and current_alert_state == AlertState.IDLE and disengage_cooldown <= 0:
			_scan_for_player()
		return

	# Update line of sight
	has_line_of_sight = CombatManager.has_line_of_sight(self, current_target)

	if has_line_of_sight:
		last_known_target_position = current_target.global_position
		# Ensure we're in combat alert state when we have LOS
		if current_alert_state != AlertState.COMBAT:
			_change_alert_state(AlertState.COMBAT)

## Backup player detection - used if aggro area signals don't fire
## Also scans for hostile faction enemies
func _scan_for_player() -> void:
	var aggro_range := enemy_data.aggro_range if enemy_data else 12.0

	# PERFORMANCE: Use cached player reference instead of get_nodes_in_group()
	if _cached_player and is_instance_valid(_cached_player):
		var dist := global_position.distance_to(_cached_player.global_position)
		if dist <= aggro_range:
			current_target = _cached_player
			last_known_target_position = _cached_player.global_position
			target_acquired.emit(_cached_player)
			_change_state(AIState.CHASE)
			if DEBUG:
				print("[Enemy] Backup scan found player at distance: ", dist)
			return

	# Second priority: scan for hostile faction enemies
	_scan_for_hostile_enemies()

## Active player detection during movement states - checks aggro range + LOS
func _check_for_player_during_movement() -> bool:
	if DEBUG:
		print("[Enemy] _check_for_player_during_movement() called - state=", current_state)

	# Skip if in disengage cooldown
	if disengage_cooldown > 0:
		if DEBUG:
			print("[Enemy]   Skipped: disengage_cooldown=", snapped(disengage_cooldown, 0.1))
		return false

	# Already have a target
	if current_target and is_instance_valid(current_target):
		if DEBUG:
			print("[Enemy]   Already has target: ", current_target.name)
		return true

	# PERFORMANCE: Use cached player reference instead of get_nodes_in_group()
	if not _cached_player or not is_instance_valid(_cached_player):
		return false

	var aggro_range := enemy_data.aggro_range if enemy_data else 12.0

	if DEBUG:
		print("[Enemy]   Checking player aggro_range=", aggro_range)

	var dist := global_position.distance_to(_cached_player.global_position)
	if DEBUG:
		print("[Enemy]   Checking player '", _cached_player.name, "' at distance=", snapped(dist, 0.1))
	if dist <= aggro_range:
		# Check line of sight before acquiring target
		var has_los := CombatManager.has_line_of_sight(self, _cached_player)
		if DEBUG:
			print("[Enemy]   In range! LOS check=", has_los)
		if has_los:
			current_target = _cached_player
			last_known_target_position = _cached_player.global_position
			target_acquired.emit(_cached_player)
			_change_alert_state(AlertState.COMBAT)
			_change_state(AIState.CHASE)
			if DEBUG:
				print("[Enemy] Movement scan found player at distance: ", dist)
			return true
		elif DEBUG:
			print("[Enemy]   LOS blocked - not acquiring target")
	elif DEBUG:
		print("[Enemy]   Out of aggro range (", dist, " > ", aggro_range, ")")

	return false

## AI State Machine

func _update_state_machine(delta: float) -> void:
	# Check leash distance first (except when already disengaging or dead)
	if current_state not in [AIState.DISENGAGE, AIState.DEAD, AIState.STAGGERED]:
		if _is_beyond_leash():
			var enemy_name: String = enemy_data.display_name if enemy_data else name
			print("[AI] ", enemy_name, " LEASH TRIGGERED! dist_to_spawn=", snapped(global_position.distance_to(spawn_position), 0.1), " > leash_radius=", leash_radius)
			print("[AI]   Current position: ", global_position, " | Spawn position: ", spawn_position)
			_change_state(AIState.DISENGAGE)
			return

	match current_state:
		AIState.IDLE:
			_state_idle(delta)
		AIState.PATROL:
			_state_patrol(delta)
		AIState.WANDER:
			_state_wander(delta)
		AIState.CHASE:
			_state_chase(delta)
		AIState.ATTACK:
			_state_attack(delta)
		AIState.RETREAT:
			_state_retreat(delta)
		AIState.STAGGERED:
			pass  # Just wait for timer
		AIState.DEAD:
			pass
		AIState.DISENGAGE:
			_state_disengage(delta)
		AIState.RANGED_ATTACK:
			_state_ranged_attack(delta)
		AIState.STRAFE:
			_state_strafe(delta)

func _state_idle(_delta: float) -> void:
	# Check for target (but only if not in disengage cooldown)
	if current_target and disengage_cooldown <= 0:
		_change_state(AIState.CHASE)
		return

	# Handle alert states when idle
	match current_alert_state:
		AlertState.ALERTED:
			# Move toward investigation position
			_move_to_investigation_position()
			return
		AlertState.SEARCHING:
			# Search behavior
			_perform_search_behavior()
			return

	# Could transition to patrol or wander based on behavior mode
	if behavior_mode == BehaviorMode.PATROL and patrol_points.size() > 0:
		_change_state(AIState.PATROL)
	elif behavior_mode == BehaviorMode.WANDER:
		_change_state(AIState.WANDER)

func _state_patrol(_delta: float) -> void:
	# Active player detection during patrol
	if _check_for_player_during_movement():
		return

	# Check for target
	if current_target:
		_change_state(AIState.CHASE)
		return

	# Handle alert states during patrol
	match current_alert_state:
		AlertState.ALERTED:
			_move_to_investigation_position()
			return
		AlertState.SEARCHING:
			_perform_search_behavior()
			return

	# Check if behavior mode changed to stationary
	if behavior_mode == BehaviorMode.STATIONARY:
		_change_state(AIState.IDLE)
		return

	# Move to patrol point
	if patrol_points.size() > 0:
		# Wait at patrol points if timer is active
		if patrol_wait_timer > 0:
			return

		var target_point: Vector3 = patrol_points[current_patrol_index]
		if global_position.distance_to(target_point) < 1.0:
			# Reached patrol point, start wait timer
			patrol_wait_timer = patrol_wait_time

			# Advance to next patrol point based on style
			match patrol_style:
				PatrolStyle.LOOP:
					current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
				PatrolStyle.PING_PONG:
					var next_index := current_patrol_index + patrol_direction
					if next_index >= patrol_points.size() or next_index < 0:
						patrol_direction *= -1
						next_index = current_patrol_index + patrol_direction
					current_patrol_index = next_index

		if nav_agent:
			nav_agent.target_position = patrol_points[current_patrol_index]
	else:
		# No patrol points, return to idle
		_change_state(AIState.IDLE)

func _state_wander(_delta: float) -> void:
	# Active player detection during wander
	if _check_for_player_during_movement():
		return

	# Check for target
	if current_target:
		_change_state(AIState.CHASE)
		return

	# Handle alert states during wander
	match current_alert_state:
		AlertState.ALERTED:
			_move_to_investigation_position()
			return
		AlertState.SEARCHING:
			_perform_search_behavior()
			return

	# Check if behavior mode changed
	if behavior_mode != BehaviorMode.WANDER:
		_change_state(AIState.IDLE)
		return

	# Wait at wander points if timer is active
	if wander_wait_timer > 0:
		return

	# Check if we need a new wander target or reached current one
	if not has_wander_target or _is_near_position(wander_target_position, 1.0):
		# Start wait timer if we just arrived
		if has_wander_target:
			wander_wait_timer = wander_wait_time

		# Pick a new random wander point
		_pick_random_wander_point()

	# Navigate to wander target
	if has_wander_target:
		if nav_agent:
			nav_agent.target_position = wander_target_position
		else:
			# Direct movement fallback if no navmesh
			var direction := (wander_target_position - global_position).normalized()
			direction.y = 0
			move_direction = direction

## Pick a random point within wander_radius of spawn_position
func _pick_random_wander_point() -> void:
	var angle := randf() * TAU
	var distance := randf_range(1.0, wander_radius)
	var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	wander_target_position = spawn_position + offset

	# If using navmesh, try to find a valid position on the navmesh
	if nav_agent:
		# Set the target and check if reachable
		nav_agent.target_position = wander_target_position
		# Give the navmesh a frame to compute, we'll validate next frame
		has_wander_target = true
	else:
		has_wander_target = true

	if DEBUG:
		print("[Enemy] New wander target: ", wander_target_position, " (distance from spawn: ", distance, ")")

var _chase_debug_timer: float = 0.0

func _state_chase(delta: float) -> void:
	if not current_target or not is_instance_valid(current_target):
		current_target = null
		_change_state(AIState.IDLE)
		return

	var distance := global_position.distance_to(current_target.global_position)

	# Debug output every second
	_chase_debug_timer += delta
	if DEBUG and _chase_debug_timer >= 1.0:
		_chase_debug_timer = 0.0
		var debug_attack_range := enemy_data.attack_range if enemy_data else 2.0
		print("[Enemy] CHASE: distance=", snapped(distance, 0.1), " attack_range=", debug_attack_range, " cooldown=", snapped(attack_cooldown, 0.1), " is_ranged=", is_ranged)

	# Check if should retreat (low HP)
	if enemy_data and float(current_hp) / max_hp < enemy_data.flee_hp_threshold:
		if enemy_data.behavior != Enums.AIBehavior.BRUTE:  # Brutes don't retreat
			_change_state(AIState.RETREAT)
			return

	# Ranged enemy behavior
	if is_ranged and ranged_attack_projectile:
		# Too close - back away
		if distance < min_range:
			_move_away_from_target()
			return

		# In preferred range - try to attack or strafe
		if distance <= preferred_range and has_line_of_sight:
			if ranged_attack_timer <= 0:
				_change_state(AIState.RANGED_ATTACK)
				return
			else:
				# Strafe while waiting for cooldown
				if randf() < 0.02:  # Small chance per frame to start strafe
					_start_strafe()
					return
				# Otherwise hold position at preferred range
				return

		# Too far - close the distance
		if nav_agent:
			nav_agent.target_position = last_known_target_position
		return

	# Melee enemy behavior - check if in attack range
	var current_attack_range := enemy_data.attack_range if enemy_data else 2.0
	if distance <= current_attack_range and attack_cooldown <= 0:
		_change_state(AIState.ATTACK)
		return

	# Navigate to target
	if nav_agent:
		nav_agent.target_position = last_known_target_position

func _state_attack(_delta: float) -> void:
	# Reset chase timer when attacking (enemy is actively engaged)
	chase_timer = 0.0

	if is_attacking:
		return

	if not current_target:
		_change_state(AIState.IDLE)
		return

	# Select and perform attack
	if enemy_data and enemy_data.attacks.size() > 0:
		current_attack = _select_attack()
		if current_attack:
			_perform_attack()
		else:
			_change_state(AIState.CHASE)
	else:
		_perform_basic_attack()

func _state_retreat(_delta: float) -> void:
	if not current_target or not is_instance_valid(current_target):
		current_target = null
		_change_state(AIState.IDLE)
		return

	# Move away from target
	var away_direction := (global_position - current_target.global_position).normalized()
	var retreat_position := global_position + away_direction * 10.0

	if nav_agent:
		nav_agent.target_position = retreat_position

	# If far enough, go back to chase or idle
	var distance := global_position.distance_to(current_target.global_position)
	if distance > 15.0:
		_change_state(AIState.CHASE)

func _state_disengage(_delta: float) -> void:
	# Ignore player completely while disengaging - clear any target that might have been set
	current_target = null

	# Set nav target to spawn position every frame to ensure we keep moving there
	if nav_agent:
		nav_agent.target_position = spawn_position

	# Check if we've returned home (within ~1.5 units of spawn)
	if _is_near_position(spawn_position, 1.5):
		# Full heal when returning home
		current_hp = max_hp
		# Start cooldown to prevent immediate re-aggro
		disengage_cooldown = DISENGAGE_COOLDOWN_DURATION
		# Return to normal behavior
		_change_alert_state(AlertState.IDLE)
		_return_to_normal_behavior()
		if DEBUG:
			print("[Enemy] Returned to spawn, fully healed, cooldown started")

func _state_ranged_attack(delta: float) -> void:
	if not current_target or not is_instance_valid(current_target):
		current_target = null
		_change_state(AIState.IDLE)
		return

	# Face target
	if mesh_root:
		var to_target := current_target.global_position - global_position
		to_target.y = 0
		if to_target.length() > 0.1:
			var target_rot := atan2(to_target.x, to_target.z)
			mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rot, delta * 10.0)

	# Windup phase
	if not is_firing_ranged:
		ranged_windup_timer += delta
		if ranged_windup_timer >= ranged_attack_windup:
			_fire_ranged_attack()
			is_firing_ranged = true
	else:
		# Attack fired, decide what to do next
		if randf() < strafe_chance:
			_start_strafe()
		else:
			_change_state(AIState.CHASE)

func _state_strafe(_delta: float) -> void:
	if not current_target or not is_instance_valid(current_target):
		current_target = null
		_change_state(AIState.IDLE)
		return

	# Strafe perpendicular to target
	var to_target := (current_target.global_position - global_position).normalized()
	to_target.y = 0
	var strafe_dir := to_target.cross(Vector3.UP) * strafe_direction

	# Move in strafe direction
	if nav_agent:
		var strafe_pos := global_position + strafe_dir * 3.0
		nav_agent.target_position = strafe_pos

	# Face target while strafing
	if mesh_root:
		var target_rot := atan2(to_target.x, to_target.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rot, _delta * 5.0)

	# Check if we can fire during strafe
	if ranged_attack_timer <= 0 and has_line_of_sight:
		_change_state(AIState.RANGED_ATTACK)

## Check if enemy is beyond leash distance from spawn
func _is_beyond_leash() -> bool:
	# Never leash when defending a totem - fight to the death
	if defending_totem:
		return false
	return global_position.distance_to(spawn_position) > leash_radius

## Move away from target (for ranged enemies too close)
func _move_away_from_target() -> void:
	if not current_target or not is_instance_valid(current_target):
		return

	var away_dir := (global_position - current_target.global_position).normalized()
	away_dir.y = 0

	if nav_agent:
		var retreat_pos := global_position + away_dir * 5.0
		nav_agent.target_position = retreat_pos

## Start strafing movement
func _start_strafe() -> void:
	strafe_direction = 1 if randf() > 0.5 else -1
	strafe_timer = strafe_duration
	_change_state(AIState.STRAFE)

## Fire the ranged attack projectile
func _fire_ranged_attack() -> void:
	if not ranged_attack_projectile or not current_target or not is_instance_valid(current_target):
		return

	# Calculate spawn position (in front of enemy)
	var spawn_offset := Vector3.FORWARD.rotated(Vector3.UP, mesh_root.rotation.y if mesh_root else 0) * 1.0
	spawn_offset.y = 1.0  # Chest height
	var projectile_spawn := global_position + spawn_offset

	# Calculate direction to target
	var target_pos := current_target.global_position + Vector3.UP * 1.0  # Aim at chest
	var direction := (target_pos - projectile_spawn).normalized()

	# Spawn projectile via CombatManager (which should have a projectile pool)
	if CombatManager.has_method("spawn_projectile"):
		CombatManager.spawn_projectile(ranged_attack_projectile, self, projectile_spawn, direction, current_target if ranged_attack_projectile.is_homing else null)
	else:
		# Fallback: create projectile directly
		var projectile := ProjectileBase.new()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = projectile_spawn
		projectile.initialize(ranged_attack_projectile, self, direction, current_target if ranged_attack_projectile.is_homing else null)
		projectile.activate()

	# Set cooldown and reset windup
	ranged_attack_timer = ranged_attack_cooldown
	ranged_windup_timer = 0.0

	# Play fire sound
	if not ranged_attack_projectile.fire_sound.is_empty():
		AudioManager.play_sfx_3d(ranged_attack_projectile.fire_sound, projectile_spawn)

	# Decrement ammo and check for depletion
	current_ammo -= 1
	if DEBUG:
		var target_name: String = current_target.name if is_instance_valid(current_target) else "unknown"
		print("[Enemy] Fired ranged attack at ", target_name, " (ammo: ", current_ammo, "/", max_ammo, ")")

	if current_ammo <= 0:
		_on_ammo_depleted()

## Called when ranged enemy runs out of ammo - switch to melee mode
func _on_ammo_depleted() -> void:
	if not was_originally_ranged:
		return  # Only handle restock for enemies that were originally ranged

	is_ranged = false  # Switch to melee mode

	# Start random restock timer (30-120 seconds)
	ammo_restock_timer = randf_range(ammo_restock_time_min, ammo_restock_time_max)

	if DEBUG:
		print("[Enemy] Out of ammo! Switching to melee. Restock in ", snapped(ammo_restock_timer, 0.1), " seconds")

## Called when ammo restock timer expires - restore ranged capability
func _on_ammo_restocked() -> void:
	if not was_originally_ranged:
		return  # Only restock if enemy was originally ranged

	# Restock to 50-100% of max ammo
	var restock_percent := randf_range(0.5, 1.0)
	current_ammo = int(max_ammo * restock_percent)
	current_ammo = max(current_ammo, 1)  # Ensure at least 1 ammo

	# Re-enable ranged mode
	is_ranged = true

	if DEBUG:
		print("[Enemy] Ammo restocked! (", current_ammo, "/", max_ammo, ") - Ranged mode re-enabled")

## Apply red tint to ranged enemies for visual distinction
func _apply_ranged_tint() -> void:
	if _ranged_tint_applied:
		return

	if mesh_root:
		# Find MeshInstance3D children and tint them (recursively)
		_apply_tint_recursive(mesh_root)

## Recursively apply tint to all MeshInstance3D nodes
func _apply_tint_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh:
			# Store original material
			_original_material = mesh_inst.get_active_material(0)

			# Create a new tinted material
			var tinted_mat := StandardMaterial3D.new()
			tinted_mat.albedo_color = RANGED_TINT_COLOR

			# Copy texture from original if it exists
			if _original_material is StandardMaterial3D:
				var orig_std := _original_material as StandardMaterial3D
				tinted_mat.albedo_texture = orig_std.albedo_texture
				# Ensure vertex color is handled properly
				tinted_mat.vertex_color_use_as_albedo = false
				tinted_mat.vertex_color_is_srgb = false

			# Apply the tinted material
			mesh_inst.material_override = tinted_mat
			_ranged_tint_applied = true

	# Process children
	for child in node.get_children():
		_apply_tint_recursive(child)

func _change_state(new_state: AIState) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, new_state)

	# Reset stuck detection on state change to prevent false positives
	_reset_stuck_state()
	last_position_check = global_position

	if DEBUG:
		var state_names: Array[String] = ["IDLE", "PATROL", "WANDER", "CHASE", "ATTACK", "RETREAT", "STAGGERED", "DEAD", "DISENGAGE", "RANGED_ATTACK", "STRAFE"]
		var prev_name: String = state_names[previous_state] if previous_state < state_names.size() else str(previous_state)
		var new_name: String = state_names[new_state] if new_state < state_names.size() else str(new_state)
		print("[Enemy] State change: ", prev_name, " -> ", new_name)

	# State entry logic
	match new_state:
		AIState.ATTACK:
			is_attacking = false
		AIState.CHASE:
			# Entering chase means we have a target - ensure combat alert state
			chase_timer = 0.0  # Reset chase timeout
			var enemy_name: String = enemy_data.display_name if enemy_data else name
			print("[AI] ", enemy_name, " ENTERING CHASE! Target=", current_target.name if current_target else "NONE")
			if current_alert_state != AlertState.COMBAT:
				_change_alert_state(AlertState.COMBAT)
		AIState.DEAD:
			_on_death()
		AIState.RANGED_ATTACK:
			ranged_windup_timer = 0.0
			is_firing_ranged = false
		AIState.DISENGAGE:
			# Clear target when disengaging
			current_target = null
			_change_alert_state(AlertState.IDLE)
			# Set nav target to spawn position immediately
			if nav_agent:
				nav_agent.target_position = spawn_position
		AIState.PATROL:
			# Set nav target to first patrol point immediately
			if nav_agent and patrol_points.size() > 0:
				nav_agent.target_position = patrol_points[current_patrol_index]
			if DEBUG:
				print("[Enemy] Entering PATROL state, patrol_points=", patrol_points.size())
		AIState.WANDER:
			# Pick a wander target immediately on entering wander state
			if not has_wander_target:
				_pick_random_wander_point()
			if DEBUG:
				print("[Enemy] Entering WANDER state, target=", wander_target_position)

## Alert State Management

func _change_alert_state(new_alert_state: AlertState) -> void:
	if new_alert_state == current_alert_state:
		return

	previous_alert_state = current_alert_state
	current_alert_state = new_alert_state
	alert_state_changed.emit(previous_alert_state, new_alert_state)

	if DEBUG:
		var alert_names := ["IDLE", "ALERTED", "COMBAT", "SEARCHING"]
		print("[Enemy] Alert state change: ", alert_names[previous_alert_state], " -> ", alert_names[new_alert_state])

	# Alert state entry logic
	match new_alert_state:
		AlertState.ALERTED:
			alert_timer = alert_duration
		AlertState.SEARCHING:
			search_timer = search_duration
			search_points_checked = 0
			current_search_point = last_known_target_position
			look_around_timer = look_around_time
		AlertState.IDLE:
			# Return to normal behavior
			_return_to_normal_behavior()
		AlertState.COMBAT:
			# Play aggro sound (use attack sounds for war cry effect)
			if enemy_data and not enemy_data.attack_sounds.is_empty():
				AudioManager.play_enemy_sound(enemy_data.attack_sounds, global_position, 2.0)
			# Clear any search/alert timers
			alert_timer = 0.0
			search_timer = 0.0

## Trigger an alert at a specific position (e.g., from hearing a sound)
func trigger_alert(alert_position: Vector3) -> void:
	if current_alert_state == AlertState.COMBAT:
		# Already in combat, don't downgrade to alerted
		return

	investigation_position = alert_position
	_change_alert_state(AlertState.ALERTED)

	if DEBUG:
		print("[Enemy] Alert triggered at position: ", alert_position)

## Alert enemy to a specific target and set totem defense mode
## Called by EnemySpawner when the totem is attacked
func alert_to_target(target: Node, defend_position: Vector3) -> void:
	if current_state == AIState.DEAD:
		return

	# Enable totem defense mode - disables leash behavior
	defending_totem = true
	totem_position = defend_position

	# Set the attacker as our target and enter combat
	if target is Node3D and (not current_target or not is_instance_valid(current_target)):
		current_target = target as Node3D
		last_known_target_position = current_target.global_position
		target_acquired.emit(current_target)
		_change_alert_state(AlertState.COMBAT)
		_change_state(AIState.CHASE)

		if DEBUG:
			print("[Enemy] TOTEM DEFENSE: Alerted to attack ", target.name, " - leash disabled!")

## Attempt to intimidate this enemy
## Returns true if intimidation succeeded, false otherwise
## Intimidator should be the player or NPC attempting intimidation
## Formula: (Intimidator Grit + Intimidation) vs (Enemy Will + Bravery) + d10 roll
func attempt_intimidation(_intimidator: Node) -> bool:
	# Can't intimidate if dead, already intimidated, or on cooldown
	if current_state == AIState.DEAD:
		return false
	if is_intimidated or intimidation_cooldown > 0:
		if DEBUG:
			print("[Enemy] Cannot be intimidated - already intimidated or on cooldown")
		return false

	# Bosses cannot be intimidated
	if enemy_data and enemy_data.is_boss:
		if DEBUG:
			print("[Enemy] Cannot intimidate a boss!")
		return false

	# Get intimidator's stats (must be player with CharacterData)
	var intimidator_grit: int = 5
	var intimidator_intimidation: int = 0
	if GameManager.player_data:
		intimidator_grit = GameManager.player_data.get_effective_stat(Enums.Stat.GRIT)
		intimidator_intimidation = GameManager.player_data.get_skill(Enums.Skill.INTIMIDATION)

	# Get enemy's resistance stats
	var enemy_will: int = enemy_data.will if enemy_data else 5
	var enemy_bravery: int = enemy_data.bravery if enemy_data else 3

	# Roll d10 for both sides (0-9, with 0 counting as 10 for crit)
	var intimidator_roll := randi_range(1, 10)
	var enemy_roll := randi_range(1, 10)

	# Calculate totals
	var intimidator_total := intimidator_grit + intimidator_intimidation + intimidator_roll
	var enemy_total := enemy_will + enemy_bravery + enemy_roll

	if DEBUG:
		print("[Enemy] Intimidation check:")
		print("  Intimidator: Grit(%d) + Intimidation(%d) + Roll(%d) = %d" % [intimidator_grit, intimidator_intimidation, intimidator_roll, intimidator_total])
		print("  Enemy: Will(%d) + Bravery(%d) + Roll(%d) = %d" % [enemy_will, enemy_bravery, enemy_roll, enemy_total])

	# Check if intimidation succeeded
	if intimidator_total > enemy_total:
		# Success! Enemy is intimidated and flees
		is_intimidated = true
		intimidation_cooldown = INTIMIDATION_COOLDOWN_DURATION
		current_target = null
		_change_alert_state(AlertState.IDLE)
		_change_state(AIState.DISENGAGE)

		if DEBUG:
			print("[Enemy] INTIMIDATED! Fleeing to spawn position.")

		return true
	else:
		# Failed intimidation - enemy is now angry and has a brief cooldown
		intimidation_cooldown = 5.0  # Short cooldown to prevent spam even on failure
		if DEBUG:
			print("[Enemy] Intimidation failed! Enemy resisted.")
		return false

## Check if this enemy can be intimidated (for UI feedback)
func can_be_intimidated() -> bool:
	if current_state == AIState.DEAD:
		return false
	if is_intimidated or intimidation_cooldown > 0:
		return false
	if enemy_data and enemy_data.is_boss:
		return false
	return true

## Move toward the investigation position during ALERTED state
func _move_to_investigation_position() -> void:
	if nav_agent:
		nav_agent.target_position = investigation_position

	# Check if we reached the investigation point
	if _is_near_position(investigation_position, 1.5):
		# Reached the point, transition to searching
		_change_alert_state(AlertState.SEARCHING)

## Perform search behavior - look around at current search point, then move to next
func _perform_search_behavior() -> void:
	if look_around_timer > 0:
		# Looking around at current point - rotate slowly
		_perform_look_around()
	else:
		# Move to current search point
		if nav_agent:
			nav_agent.target_position = current_search_point

## Rotate to look around during search
func _perform_look_around() -> void:
	if mesh_root:
		# Slowly rotate to scan the area
		var rotation_speed := 1.5  # radians per second
		mesh_root.rotation.y += rotation_speed * get_physics_process_delta_time()

## Pick the next point to search around the last known position
func _pick_next_search_point() -> void:
	search_points_checked += 1

	# After checking several points, give up
	if search_points_checked >= 4:
		_change_alert_state(AlertState.IDLE)
		return

	# Pick a random point within search radius of last known position
	var angle := randf() * TAU
	var distance := randf_range(1.0, search_radius)
	var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	current_search_point = last_known_target_position + offset

	look_around_timer = look_around_time

	if DEBUG:
		print("[Enemy] Searching point ", search_points_checked, ": ", current_search_point)

## Return to normal behavior after alert/search ends
func _return_to_normal_behavior() -> void:
	match behavior_mode:
		BehaviorMode.STATIONARY:
			# Return to spawn position
			if nav_agent:
				nav_agent.target_position = spawn_position
			_change_state(AIState.IDLE)
		BehaviorMode.PATROL:
			if patrol_points.size() > 0:
				_change_state(AIState.PATROL)
			else:
				_change_state(AIState.IDLE)
		BehaviorMode.WANDER:
			# Reset wander state and resume wandering
			has_wander_target = false
			wander_wait_timer = 0.0
			_change_state(AIState.WANDER)

## Check if enemy is near a position
func _is_near_position(pos: Vector3, threshold: float = 1.0) -> bool:
	var dist := global_position.distance_to(pos)
	return dist < threshold

## Movement

func _update_movement(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Don't move in certain states (but allow movement during IDLE if in alert state)
	if current_state == AIState.DEAD or current_state == AIState.STAGGERED:
		velocity.x = 0
		velocity.z = 0
		return

	# Handle IDLE state - only stop if truly idle (not alerted/searching)
	if current_state == AIState.IDLE:
		if current_alert_state == AlertState.IDLE:
			velocity.x = 0
			velocity.z = 0
			return
		# If alerted or searching, continue with movement logic below

	# Reduced movement during attack or ranged attack
	if current_state == AIState.ATTACK and is_attacking:
		velocity.x = move_toward(velocity.x, 0, 10 * delta)
		velocity.z = move_toward(velocity.z, 0, 10 * delta)
		return

	# No movement during ranged attack windup
	if current_state == AIState.RANGED_ATTACK:
		velocity.x = move_toward(velocity.x, 0, 15 * delta)
		velocity.z = move_toward(velocity.z, 0, 15 * delta)
		return

	var speed := enemy_data.movement_speed if enemy_data else 4.0
	# Safeguard: ensure speed is at least a minimum value
	if speed < 0.5:
		speed = 4.0
		if DEBUG:
			print("[Enemy] WARNING: movement_speed too low (", enemy_data.movement_speed if enemy_data else 0, "), using default 4.0")
	var direction := Vector3.ZERO

	# Apply investigation speed multiplier when alerted/searching
	if current_alert_state in [AlertState.ALERTED, AlertState.SEARCHING]:
		speed *= investigation_speed_mult

	# Apply strafe speed multiplier
	if current_state == AIState.STRAFE:
		speed *= strafe_speed_mult

	# Apply leash return speed multiplier
	if current_state == AIState.DISENGAGE:
		speed *= leash_return_speed_mult

	# Apply SLOWED condition penalty (-50% speed)
	if has_condition(Enums.Condition.SLOWED):
		speed *= 0.5

	# If looking around during search, don't move
	if current_alert_state == AlertState.SEARCHING and look_around_timer > 0:
		velocity.x = 0
		velocity.z = 0
		return

	# Handle unstuck movement - override normal navigation
	if is_unstucking:
		var unstuck_direction := (unstuck_target - global_position)
		unstuck_direction.y = 0
		if unstuck_direction.length() > 0.5:
			direction = unstuck_direction.normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			# Face movement direction during unstuck
			if mesh_root:
				var target_rotation := atan2(direction.x, direction.z)
				mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation, delta * 5.0)
			return
		else:
			# Reached unstuck target, end unstuck behavior
			is_unstucking = false
			unstuck_timer = 0.0

	# Try navigation movement first
	# Check if nav agent has a valid path that isn't finished
	var nav_finished := nav_agent.is_navigation_finished() if nav_agent else true
	var use_nav_agent := false

	if nav_agent and not nav_finished:
		var next_pos := nav_agent.get_next_path_position()
		var nav_direction := (next_pos - global_position)
		nav_direction.y = 0

		# Only use nav agent if it gives us a meaningful direction
		# (get_next_path_position can return current position if no path)
		if nav_direction.length() > 0.1:
			direction = nav_direction.normalized()
			use_nav_agent = true

	# Debug movement state periodically
	if DEBUG and Engine.get_physics_frames() % 60 == 0:
		print("[Enemy] _update_movement: state=", current_state, " nav_agent=", nav_agent != null, " nav_finished=", nav_finished, " use_nav=", use_nav_agent, " speed=", speed)
		if nav_agent:
			print("[Enemy]   nav target=", nav_agent.target_position, " distance_to_target=", nav_agent.distance_to_target(), " is_target_reachable=", nav_agent.is_target_reachable())

	# IMPORTANT: If nav reports finished but we're still far from target, force fallback
	# This handles cases where the nav mesh isn't ready or target is unreachable
	if use_nav_agent == false and nav_agent and nav_finished:
		var dist_to_nav_target := global_position.distance_to(nav_agent.target_position)
		if dist_to_nav_target > 1.5:
			# Nav says finished but we're not there - force fallback movement
			if DEBUG and Engine.get_physics_frames() % 60 == 0:
				print("[Enemy]   Nav finished but far from target (", dist_to_nav_target, ") - using fallback")

	# If nav agent didn't provide direction, use fallback movement
	if not use_nav_agent:
		if current_target and is_instance_valid(current_target):
			# Fallback: direct movement toward target (no navmesh)
			direction = (current_target.global_position - global_position).normalized()
			if DEBUG and Engine.get_physics_frames() % 60 == 0:
				print("[Enemy]   Fallback: moving toward target")
		elif current_state == AIState.PATROL and patrol_points.size() > 0:
			# Fallback for patrol: direct movement toward patrol point
			var target_point := patrol_points[current_patrol_index]
			direction = (target_point - global_position).normalized()
			if DEBUG and Engine.get_physics_frames() % 60 == 0:
				print("[Enemy]   Fallback: patrol toward point ", current_patrol_index, " at ", target_point)
		elif current_state == AIState.WANDER and has_wander_target:
			# Fallback for wander: direct movement toward wander target
			direction = (wander_target_position - global_position).normalized()
			if DEBUG and Engine.get_physics_frames() % 60 == 0:
				print("[Enemy]   Fallback: wander toward ", wander_target_position)
		elif current_state == AIState.DISENGAGE:
			# Fallback for disengage: direct movement toward spawn
			direction = (spawn_position - global_position).normalized()
			if DEBUG and Engine.get_physics_frames() % 60 == 0:
				print("[Enemy]   Fallback: disengage toward spawn")
		elif current_state == AIState.CHASE and last_known_target_position != Vector3.ZERO:
			# Fallback for chase: move toward last known position
			direction = (last_known_target_position - global_position).normalized()
			if DEBUG and Engine.get_physics_frames() % 60 == 0:
				print("[Enemy]   Fallback: chase toward last known position")
	else:
		if DEBUG and Engine.get_physics_frames() % 60 == 0:
			print("[Enemy]   Using nav_agent, direction=", direction)

	direction.y = 0

	if direction.length() > 0.1:
		# Check minimum combat distance - don't walk closer than this to the target
		# This prevents enemies from blocking the player's view during combat
		# IMPORTANT: Only apply during CHASE state, NOT during ATTACK state
		# During ATTACK, enemy needs to be able to approach to complete the attack
		if current_target and is_instance_valid(current_target):
			var dist := global_position.distance_to(current_target.global_position)

			# When at minimum combat distance, ALWAYS stop and try to attack
			# Don't check movement direction - at this range, attack is the priority
			# The old moving_toward check caused enemies to "fly past" the player when
			# the nav path direction didn't align with the direct line to target
			if dist <= MIN_COMBAT_DISTANCE and current_state == AIState.CHASE:
				velocity.x = 0
				velocity.z = 0
				if DEBUG and Engine.get_physics_frames() % 60 == 0:
					print("[Enemy]   At min combat distance (", snapped(dist, 0.1), "), stopping to attack")
				if attack_cooldown <= 0:
					_change_state(AIState.ATTACK)
				return

			# Slow down when approaching target in attack state
			if current_state == AIState.ATTACK and dist < 3.0:
				speed *= 0.3

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		if DEBUG and Engine.get_physics_frames() % 60 == 0:
			print("[Enemy]   MOVING: velocity=", Vector2(velocity.x, velocity.z), " speed=", speed)

		# Face movement direction
		if mesh_root:
			var target_rotation := atan2(direction.x, direction.z)
			mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation, delta * 5.0)
	else:
		velocity.x = 0
		velocity.z = 0
		if DEBUG and Engine.get_physics_frames() % 60 == 0:
			print("[Enemy]   NOT MOVING: direction too small (", direction.length(), ")")

## Combat

func _select_attack() -> EnemyAttackData:
	if not enemy_data or enemy_data.attacks.is_empty():
		return null

	var distance := global_position.distance_to(current_target.global_position) if current_target else 0.0

	# Filter attacks by range
	var valid_attacks: Array[EnemyAttackData] = []
	var total_weight := 0.0

	for attack in enemy_data.attacks:
		if attack.can_use_at_range(distance):
			valid_attacks.append(attack)
			total_weight += attack.weight

	if valid_attacks.is_empty():
		return null

	# Weighted random selection
	var roll := randf() * total_weight
	var cumulative := 0.0
	for attack in valid_attacks:
		cumulative += attack.weight
		if roll <= cumulative:
			return attack

	return valid_attacks[0]

func _perform_attack() -> void:
	if not current_attack:
		return

	is_attacking = true
	attack_started.emit(current_attack)

	# Play attack sound from enemy data
	if enemy_data and not enemy_data.attack_sounds.is_empty():
		AudioManager.play_enemy_sound(enemy_data.attack_sounds, global_position, 1.0)

	# Face target
	if current_target and mesh_root:
		var to_target := current_target.global_position - global_position
		to_target.y = 0
		if to_target.length() > 0.1:
			mesh_root.rotation.y = atan2(to_target.x, to_target.z)

	# Play animation
	if animation_player and animation_player.has_animation(current_attack.animation_name):
		animation_player.play(current_attack.animation_name)

	# Schedule hitbox activation
	get_tree().create_timer(current_attack.windup_time).timeout.connect(_activate_attack_hitbox)

	# Schedule attack end
	var total_time := current_attack.windup_time + current_attack.active_time + current_attack.recovery_time
	get_tree().create_timer(total_time).timeout.connect(_end_attack)

	# Set cooldown
	attack_cooldown = current_attack.cooldown

func _perform_basic_attack() -> void:
	is_attacking = true

	# Basic melee attack
	if hitbox:
		hitbox.set_damage_values(10, Enums.DamageType.PHYSICAL)

	get_tree().create_timer(0.3).timeout.connect(_activate_attack_hitbox)
	get_tree().create_timer(0.8).timeout.connect(_end_attack)
	attack_cooldown = 1.5

func _activate_attack_hitbox() -> void:
	if DEBUG:
		print("[Enemy] _activate_attack_hitbox called. hitbox=", hitbox, " is_attacking=", is_attacking)

	# Check if this is a ranged attack - spawn a visual projectile instead of melee hitbox
	if current_attack and current_attack.is_ranged and is_attacking:
		_spawn_attack_projectile()
		return

	if hitbox and is_attacking:
		if DEBUG:
			print("[Enemy] Activating attack hitbox! Target=", str(current_target.name) if current_target else "none")
			print("[Enemy] Hitbox layer=", hitbox.collision_layer, " mask=", hitbox.collision_mask)
			print("[Enemy] Hitbox global_position=", hitbox.global_position)
			if current_target:
				print("[Enemy] Target global_position=", current_target.global_position)
				print("[Enemy] Distance to target=", hitbox.global_position.distance_to(current_target.global_position))

		var dmg: int = 10
		var dmg_type: Enums.DamageType = Enums.DamageType.PHYSICAL
		if current_attack:
			dmg = current_attack.roll_damage()
			dmg_type = current_attack.damage_type
			if DEBUG:
				print("[Enemy] Attack damage: ", dmg, " type: ", dmg_type)
			hitbox.set_damage_values(dmg, dmg_type)
			hitbox.stagger_power = current_attack.stagger_power
			hitbox.knockback_force = current_attack.knockback_force
			hitbox.inflicts_condition = current_attack.inflicts_condition
			hitbox.condition_chance = current_attack.condition_chance
			hitbox.condition_duration = current_attack.condition_duration
		else:
			if DEBUG:
				print("[Enemy] No current_attack, using defaults")
			hitbox.set_damage_values(dmg, dmg_type)

		hitbox.activate()

		# Deactivate after active time
		var active_time := current_attack.active_time if current_attack else 0.2

		# Store damage values for direct check
		var stored_dmg := dmg
		var stored_type := dmg_type
		var stored_target := current_target

		# Schedule a direct hit check after a brief delay to ensure physics has processed
		get_tree().create_timer(0.05).timeout.connect(func():
			if hitbox and is_attacking and stored_target and is_instance_valid(stored_target):
				_direct_hit_check(stored_target, stored_dmg, stored_type)
		)

		get_tree().create_timer(active_time).timeout.connect(func():
			if hitbox:
				hitbox.deactivate()
		)


## Spawn a visual projectile for ranged EnemyAttackData attacks (e.g., goblin mage fireballs)
func _spawn_attack_projectile() -> void:
	if not current_attack or not current_target:
		return

	# Calculate spawn position (chest height, slightly in front)
	var spawn_offset := Vector3.FORWARD.rotated(Vector3.UP, mesh_root.rotation.y if mesh_root else 0) * 1.0
	spawn_offset.y = 1.2  # Chest height
	var projectile_spawn := global_position + spawn_offset

	# Calculate direction to target
	var target_pos := current_target.global_position + Vector3.UP * 1.0
	var direction := (target_pos - projectile_spawn).normalized()

	# Create a visual magic projectile
	var projectile := _create_magic_projectile(current_attack)
	if projectile:
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = projectile_spawn

		# Initialize projectile movement and damage
		var dmg := current_attack.roll_damage()
		projectile.set_meta("damage", dmg)
		projectile.set_meta("damage_type", current_attack.damage_type)
		projectile.set_meta("owner", self)
		projectile.set_meta("direction", direction)
		projectile.set_meta("speed", current_attack.projectile_speed)
		projectile.set_meta("target", current_target)

		# Start projectile movement
		_animate_projectile(projectile, direction, current_attack.projectile_speed, current_attack.range_distance)

	# Play cast sound
	AudioManager.play_sfx_3d("projectile_fire", projectile_spawn)

	if DEBUG:
		print("[Enemy] Spawned ranged attack projectile toward ", current_target.name)


## Create a visual magic projectile based on attack damage type
func _create_magic_projectile(attack: EnemyAttackData) -> Node3D:
	var projectile := Node3D.new()
	projectile.name = "MagicProjectile"

	# Create glowing sphere mesh
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh.mesh = sphere

	# Color based on damage type
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true

	match attack.damage_type:
		Enums.DamageType.FIRE:
			mat.albedo_color = Color(1.0, 0.4, 0.1, 0.9)
			mat.emission = Color(1.0, 0.5, 0.2)
		Enums.DamageType.FROST:
			mat.albedo_color = Color(0.5, 0.8, 1.0, 0.9)
			mat.emission = Color(0.6, 0.9, 1.0)
		Enums.DamageType.LIGHTNING:
			mat.albedo_color = Color(0.7, 0.8, 1.0, 0.9)
			mat.emission = Color(0.8, 0.9, 1.0)
		Enums.DamageType.POISON:
			mat.albedo_color = Color(0.3, 0.8, 0.2, 0.9)
			mat.emission = Color(0.4, 0.9, 0.3)
		Enums.DamageType.NECROTIC:
			mat.albedo_color = Color(0.5, 0.2, 0.6, 0.9)
			mat.emission = Color(0.6, 0.3, 0.7)
		_:  # ARCANE or other magical
			mat.albedo_color = Color(0.8, 0.5, 1.0, 0.9)
			mat.emission = Color(0.9, 0.6, 1.0)

	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat

	projectile.add_child(mesh)

	# Add a point light for glow
	var light := OmniLight3D.new()
	light.light_color = mat.emission
	light.light_energy = 1.5
	light.omni_range = 3.0
	projectile.add_child(light)

	return projectile


## Animate projectile flight and handle collision
func _animate_projectile(projectile: Node3D, direction: Vector3, speed: float, max_range: float) -> void:
	var start_pos := projectile.global_position
	var elapsed := 0.0
	var max_time := max_range / speed

	# Create physics query for collision detection
	var space_state := get_world_3d().direct_space_state

	# Animate via process callback
	var timer := Timer.new()
	timer.wait_time = 0.016  # ~60 FPS
	timer.autostart = true
	projectile.add_child(timer)

	timer.timeout.connect(func():
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			timer.stop()
			return

		elapsed += 0.016
		if elapsed > max_time:
			timer.stop()
			projectile.queue_free()
			return

		# Move projectile
		projectile.global_position += direction * speed * 0.016

		# Check for collision with player
		var target: Node3D = projectile.get_meta("target", null) as Node3D
		if is_instance_valid(target):
			var dist := projectile.global_position.distance_to(target.global_position + Vector3.UP)
			if dist < 1.0:
				# Hit!
				var dmg: int = projectile.get_meta("damage", 10)
				var dmg_type: Enums.DamageType = projectile.get_meta("damage_type", Enums.DamageType.FIRE)
				var owner_ref: Node = projectile.get_meta("owner", null)

				if target.has_method("take_damage"):
					target.take_damage(dmg, dmg_type, owner_ref)

				# Spawn impact effect
				_spawn_projectile_impact(projectile.global_position, dmg_type)
				AudioManager.play_sfx_3d("projectile_hit", projectile.global_position)
				timer.stop()
				projectile.queue_free()
	)


## Spawn impact VFX when projectile hits
func _spawn_projectile_impact(pos: Vector3, dmg_type: Enums.DamageType) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.4

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.2

	# Color based on damage type
	match dmg_type:
		Enums.DamageType.FIRE:
			mat.color = Color(1.0, 0.5, 0.2, 1.0)
		Enums.DamageType.FROST:
			mat.color = Color(0.6, 0.9, 1.0, 1.0)
		Enums.DamageType.LIGHTNING:
			mat.color = Color(0.8, 0.9, 1.0, 1.0)
		_:
			mat.color = Color(0.9, 0.6, 1.0, 1.0)

	particles.process_material = mat

	var draw_pass := SphereMesh.new()
	draw_pass.radius = 0.08
	draw_pass.height = 0.16
	particles.draw_pass_1 = draw_pass

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos

	# Cleanup after particles finish
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)


## Direct proximity-based hit check - primary damage delivery method
func _direct_hit_check(target: Node3D, dmg: int, dmg_type: Enums.DamageType) -> void:
	if not hitbox or not hitbox.is_active:
		return

	# Check if target is already hit this activation
	if target in hitbox.hit_targets:
		return

	# Use attack range + buffer for hit detection
	var hit_range := 2.5  # Default
	if current_attack:
		hit_range = current_attack.range_distance + 0.5
	elif enemy_data:
		hit_range = enemy_data.attack_range + 0.5

	var distance := global_position.distance_to(target.global_position)

	if distance <= hit_range:
		hitbox.hit_targets.append(target)
		if target.has_method("take_damage"):
			target.take_damage(dmg, dmg_type, self)

func _end_attack() -> void:
	is_attacking = false
	current_attack = null

	if current_target:
		_change_state(AIState.CHASE)
	else:
		_change_state(AIState.IDLE)

## Damage handling

func take_damage(amount: int, damage_type: Enums.DamageType, attacker: Node) -> int:
	if current_state == AIState.DEAD:
		return 0

	# Apply resistance/weakness
	var multiplier := get_damage_type_multiplier(damage_type)
	amount = int(amount * multiplier)

	# Apply armor reduction for physical damage only
	if damage_type == Enums.DamageType.PHYSICAL:
		var effective_armor := armor_value
		amount = int(amount * (100.0 / (100.0 + effective_armor)))

	amount = max(1, amount)
	current_hp -= amount

	# Play hurt sound from enemy data
	if enemy_data and not enemy_data.hurt_sounds.is_empty():
		AudioManager.play_enemy_sound(enemy_data.hurt_sounds, global_position)

	damaged.emit(amount, damage_type, attacker)

	# Acquire target if we don't have one
	if attacker and attacker is Node3D and not current_target:
		current_target = attacker as Node3D
		last_known_target_position = current_target.global_position
		target_acquired.emit(current_target)
		# Enter combat alert state and chase
		_change_alert_state(AlertState.COMBAT)
		if current_state == AIState.IDLE or current_state == AIState.PATROL:
			_change_state(AIState.CHASE)

	# Check death
	if current_hp <= 0:
		_change_state(AIState.DEAD)
		died.emit(attacker)

	return amount

func get_damage_type_multiplier(damage_type: Enums.DamageType) -> float:
	if not enemy_data:
		return 1.0
	return enemy_data.get_damage_multiplier(damage_type)

func get_armor_value() -> int:
	return armor_value

func apply_stagger(power: float) -> void:
	var resistance := enemy_data.stagger_resistance if enemy_data else 0.0
	if randf() > resistance:
		_change_state(AIState.STAGGERED)
		stagger_timer = 0.5 * power * (1.0 - resistance)

		if hitbox:
			hitbox.deactivate()
		is_attacking = false

		if animation_player and animation_player.has_animation("stagger"):
			animation_player.play("stagger")

func apply_condition(condition: Enums.Condition, duration: float) -> void:
	active_conditions[condition] = duration

func has_condition(condition: Enums.Condition) -> bool:
	return active_conditions.has(condition) and active_conditions[condition] > 0

func is_dead() -> bool:
	return current_state == AIState.DEAD

func get_xp_reward() -> int:
	return enemy_data.xp_reward if enemy_data else 100

func get_enemy_data() -> EnemyData:
	return enemy_data

## Death

func _on_death() -> void:
	# Play death sound from enemy data
	if enemy_data and not enemy_data.death_sounds.is_empty():
		AudioManager.play_enemy_sound(enemy_data.death_sounds, global_position, 2.0)

	# Disable collisions
	if hurtbox:
		hurtbox.disable()
	if hitbox:
		hitbox.deactivate()

	collision_layer = 0
	collision_mask = 0

	CombatManager.unregister_enemy(self)

	# Notify QuestManager of enemy death (works regardless of damage source)
	if enemy_data and enemy_data.id:
		QuestManager.on_enemy_killed(enemy_data.id)

	# Add to bestiary codex
	if enemy_data and CodexManager:
		var bestiary_data: Dictionary = {
			"name": enemy_data.display_name,
			"description": enemy_data.description,
			"level": enemy_data.level,
			"max_hp": enemy_data.max_hp,
			"fire_weakness": enemy_data.fire_weakness,
			"frost_weakness": enemy_data.frost_weakness,
			"lightning_weakness": enemy_data.lightning_weakness,
			"holy_weakness": enemy_data.holy_weakness,
			"drops": enemy_data.drop_table.keys(),
			"icon_path": enemy_data.icon_path
		}
		CodexManager.discover_bestiary_entry(enemy_data.id, bestiary_data)

	# Mark as killed in SaveManager for persistence (procedural dungeon enemies)
	if not persistent_id.is_empty():
		SaveManager.mark_enemy_killed(persistent_id)

	# Play death animation
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

	# Drop loot
	_drop_loot()

	# Queue for removal after animation
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _drop_loot() -> void:
	if not enemy_data:
		return

	var drop_pos := global_position
	var world := get_tree().current_scene

	# Award XP to player (only auto-granted reward)
	var xp := get_xp_reward()
	if xp > 0 and GameManager.player_data:
		# Apply player's XP multiplier from Knowledge stat
		xp = int(xp * GameManager.player_data.get_xp_multiplier())
		GameManager.player_data.add_ip(xp)
		if DEBUG:
			print("[Enemy] Awarded %d XP for killing %s" % [xp, enemy_data.display_name if enemy_data else "enemy"])

	# Spawn lootable corpse instead of dropping items
	_spawn_lootable_corpse(world, drop_pos)


## Spawn a lootable corpse at the death position
func _spawn_lootable_corpse(world: Node, pos: Vector3) -> void:
	if not enemy_data:
		return

	var corpse_name := enemy_data.display_name if not enemy_data.display_name.is_empty() else "Body"
	var enemy_level: int = enemy_data.level if enemy_data.level > 0 else 1

	var corpse := LootableCorpse.spawn_corpse(
		world,
		pos,
		corpse_name,
		enemy_data.id,
		enemy_level
	)

	if not corpse:
		return

	# Generate loot based on enemy type (humanoid vs creature)
	if _is_humanoid_faction():
		corpse.generate_humanoid_loot(enemy_data)
	else:
		corpse.generate_creature_loot(enemy_data)

	if DEBUG:
		print("[Enemy] Spawned lootable corpse for %s at %v" % [corpse_name, pos])


## Check if enemy is humanoid (carries gear, gold) vs creature (drops materials)
func _is_humanoid_faction() -> bool:
	if not enemy_data:
		return false

	match enemy_data.faction:
		Enums.Faction.HUMAN_BANDIT:
			return true
		Enums.Faction.CULTIST:
			return true
		Enums.Faction.TENGER:
			return true
		Enums.Faction.GOBLINOID:
			return true  # Goblins carry weapons and loot
		_:
			return false  # Beasts, undead, demons, abominations are creatures

## Aggro detection

func _on_aggro_area_body_entered(body: Node3D) -> void:
	var enemy_name: String = enemy_data.display_name if enemy_data else name
	print("[AI] ", enemy_name, " AGGRO AREA entered by: ", body.name, " groups: ", body.get_groups())

	# Ignore while disengaging or during disengage cooldown
	if current_state == AIState.DISENGAGE or disengage_cooldown > 0:
		print("[AI]   IGNORED - disengaging=", current_state == AIState.DISENGAGE, " cooldown=", snapped(disengage_cooldown, 0.1))
		return

	# Player detection - use visibility-based awareness system
	if body.is_in_group("player"):
		player_in_detection_range = true
		_awareness_target = body

		# Get player visibility
		var player_visibility: float = 1.0
		if body.has_method("get_visibility"):
			player_visibility = body.get_visibility()

		# If player is NOT hidden, detect immediately (legacy behavior)
		# If player IS hidden, use awareness system for gradual detection
		if not StealthConstants.is_hidden(player_visibility):
			_detect_player_immediately(body)
		else:
			# Hidden player - start awareness tracking
			if DEBUG:
				print("[Enemy] Player is hidden (visibility=%.2f), tracking awareness" % player_visibility)

## Immediately detect player (when not hidden or awareness threshold reached)
func _detect_player_immediately(body: Node3D) -> void:
	var enemy_name: String = enemy_data.display_name if enemy_data else name
	if current_target:
		print("[AI] ", enemy_name, " _detect_player_immediately - ALREADY HAS TARGET: ", current_target.name)
		return  # Already have a target

	current_target = body
	last_known_target_position = body.global_position
	print("[AI] ", enemy_name, " TARGET ACQUIRED: ", body.name, " at ", body.global_position)
	target_acquired.emit(body)

	# Check for humanoid dialogue (pacifist option for human/elf/dwarf enemies)
	# If dialogue triggers, enemy will wait in IDLE state for result
	if CombatManager.check_humanoid_dialogue(self):
		if DEBUG:
			print("[Enemy] Humanoid dialogue triggered - waiting for player response")
		return  # Don't enter combat yet, wait for dialogue result

	_change_alert_state(AlertState.COMBAT)
	_change_state(AIState.CHASE)

	# Horror check for certain enemies
	if enemy_data and enemy_data.causes_horror:
		CombatManager.trigger_horror_check(self, body, enemy_data.horror_difficulty)
		return

	# Hostile faction enemy detection
	if not current_target and body.is_in_group("enemies") and body != self:
		var other_enemy := body as EnemyBase
		if other_enemy and _is_hostile_faction(other_enemy):
			current_target = body
			last_known_target_position = body.global_position
			if DEBUG:
				print("[Enemy] Hostile faction target acquired: ", body.name)
			target_acquired.emit(body)
			_change_alert_state(AlertState.COMBAT)
			_change_state(AIState.CHASE)

func _on_aggro_area_body_exited(body: Node3D) -> void:
	# Player left detection range - reset awareness tracking
	if body.is_in_group("player"):
		player_in_detection_range = false
		_awareness_target = null

	if body == current_target:
		# Don't immediately lose target, keep chasing to last known position
		# The search behavior will trigger when we fully lose the target
		target_lost.emit()

func _on_hurtbox_hurt(_damage: int, _damage_type: Enums.DamageType, _attacker: Node) -> void:
	# This is called by the hurtbox when hit
	# We already handle this in take_damage, but this ensures we respond even if
	# the hitbox calls us directly
	pass

## Check if another enemy is from a hostile faction
func _is_hostile_faction(other_enemy: EnemyBase) -> bool:
	if not enemy_data or not other_enemy.enemy_data:
		return false

	var my_faction: Enums.Faction = enemy_data.faction
	var their_faction: Enums.Faction = other_enemy.enemy_data.faction

	return Enums.are_factions_hostile(my_faction, their_faction)

## Get this enemy's faction
func get_faction() -> Enums.Faction:
	if enemy_data:
		return enemy_data.faction
	return Enums.Faction.NEUTRAL

## Scan for nearby hostile faction enemies (called when idle and no player target)
func _scan_for_hostile_enemies() -> bool:
	if not enemy_data or enemy_data.faction == Enums.Faction.NEUTRAL:
		return false

	var aggro_range := enemy_data.aggro_range if enemy_data else 12.0
	var aggro_range_sq := aggro_range * aggro_range  # PERFORMANCE: Pre-compute squared distance
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == self or not enemy is EnemyBase:
			continue

		var other_enemy := enemy as EnemyBase
		if other_enemy.is_dead():
			continue

		if not _is_hostile_faction(other_enemy):
			continue

		# PERFORMANCE: Use squared distance to avoid sqrt
		var dist_sq := global_position.distance_squared_to(other_enemy.global_position)
		if dist_sq <= aggro_range_sq:
			# Check line of sight (only if in range)
			var has_los := CombatManager.has_line_of_sight(self, other_enemy)
			if has_los:
				current_target = other_enemy
				last_known_target_position = other_enemy.global_position
				target_acquired.emit(other_enemy)
				_change_alert_state(AlertState.COMBAT)
				_change_state(AIState.CHASE)
				if DEBUG:
					print("[Enemy] Found hostile faction enemy: ", other_enemy.enemy_data.display_name if other_enemy.enemy_data else "Unknown")
				return true

	return false

## Set patrol points (called from editor or spawner)
func set_patrol_points(points: Array[Vector3]) -> void:
	patrol_points = points
	if points.size() > 0:
		current_patrol_index = 0
		if behavior_mode == BehaviorMode.PATROL:
			_change_state(AIState.PATROL)

## Get current alert state for external systems
func get_alert_state() -> AlertState:
	return current_alert_state

## Check if enemy is currently aware of threats
func is_alert() -> bool:
	return current_alert_state != AlertState.IDLE

## Check if enemy is actively searching
func is_searching() -> bool:
	return current_alert_state == AlertState.SEARCHING

## Check if enemy is in combat
func is_in_combat() -> bool:
	return current_alert_state == AlertState.COMBAT

## Force return to idle alert state (e.g., for stealth kills or distractions)
func force_idle() -> void:
	current_target = null
	_change_alert_state(AlertState.IDLE)
	_change_state(AIState.IDLE)

# ============================================================================
# BILLBOARD SPRITE SUPPORT (Doom/Wolfenstein-style 2D sprites in 3D)
# ============================================================================

## Reference to billboard sprite component (if using sprites instead of 3D mesh)
var billboard_sprite: BillboardSprite = null

## Reference to enemy glow light (for undead/spectral enemies)
var enemy_glow_light: OmniLight3D = null

## Rat directional sprite support
## Rats use different textures based on movement direction relative to camera
var _is_rat_enemy: bool = false
var _rat_tex_forward: Texture2D = null  # Moving toward camera
var _rat_tex_away: Texture2D = null     # Moving away from camera
var _rat_tex_right: Texture2D = null    # Moving right (flip for left)
var _rat_current_direction: int = 0     # 0=forward, 1=away, 2=right, 3=left

## Setup billboard sprite to replace 3D mesh visuals
## texture: The sprite sheet texture
## h_frames: Number of columns in sprite sheet
## v_frames: Number of rows in sprite sheet
## pixel_size: World size per pixel (default 0.015 for ~2m tall sprite)
func setup_billboard_sprite(texture: Texture2D, h_frames: int = 4, v_frames: int = 4, pixel_size: float = 0.03) -> BillboardSprite:
	# Hide existing mesh visuals
	if mesh_root:
		for child in mesh_root.get_children():
			if child is MeshInstance3D:
				child.visible = false

	# Create billboard sprite
	billboard_sprite = BillboardSprite.new()
	billboard_sprite.sprite_sheet = texture
	billboard_sprite.h_frames = h_frames
	billboard_sprite.v_frames = v_frames
	billboard_sprite.pixel_size = pixel_size
	billboard_sprite.offset_y = 0.0  # Additional vertical offset (sprite bottom already at ground level)
	billboard_sprite.owner_enemy = self

	# Configure animation to cycle through all frames in idle
	billboard_sprite.idle_row = 0
	billboard_sprite.idle_frames = h_frames  # Use all columns for idle animation
	billboard_sprite.idle_fps = 6.0  # Moderate animation speed
	billboard_sprite.walk_row = 0  # Use same row for walking
	billboard_sprite.walk_frames = h_frames
	billboard_sprite.walk_fps = 8.0

	# Add to mesh_root so it moves with the enemy
	if mesh_root:
		mesh_root.add_child(billboard_sprite)
		# Ensure billboard is at origin of mesh_root to prevent vertical offset
		billboard_sprite.position = Vector3.ZERO
	else:
		add_child(billboard_sprite)
		billboard_sprite.position = Vector3.ZERO

	# Connect state changes to sprite animation
	state_changed.connect(_on_state_changed_for_sprite)
	damaged.connect(_on_damaged_for_sprite)

	# Setup attack and death textures from enemy_data if available
	if enemy_data:
		# Attack texture
		if enemy_data.attack_sprite_path and not enemy_data.attack_sprite_path.is_empty():
			var attack_tex: Texture2D = load(enemy_data.attack_sprite_path)
			if attack_tex:
				billboard_sprite.attack_texture = attack_tex
				billboard_sprite.attack_texture_h_frames = enemy_data.attack_hframes
				billboard_sprite.attack_texture_v_frames = enemy_data.attack_vframes
				billboard_sprite.attack_frames = enemy_data.attack_hframes
				billboard_sprite.attack_fps = 10.0

		# Death texture
		if enemy_data.death_sprite_path and not enemy_data.death_sprite_path.is_empty():
			var death_tex: Texture2D = load(enemy_data.death_sprite_path)
			if death_tex:
				billboard_sprite.death_texture = death_tex
				billboard_sprite.death_texture_h_frames = enemy_data.death_hframes
				billboard_sprite.death_texture_v_frames = enemy_data.death_vframes
				billboard_sprite.death_frames = enemy_data.death_hframes
				billboard_sprite.death_fps = 6.0

		# Setup rat directional sprites if this is a rat enemy
		if enemy_data.id == "giant_rat":
			_setup_rat_directional_sprites()

	return billboard_sprite

## Handle state changes for billboard sprite animation
func _on_state_changed_for_sprite(_old_state: int, new_state: int) -> void:
	if not billboard_sprite:
		return

	match new_state:
		AIState.IDLE, AIState.DISENGAGE:
			billboard_sprite.set_walking(false)
		AIState.PATROL, AIState.WANDER, AIState.CHASE:
			billboard_sprite.set_walking(true)
		AIState.ATTACK, AIState.RANGED_ATTACK:
			billboard_sprite.play_attack()
		AIState.DEAD:
			billboard_sprite.play_death()
		_:
			billboard_sprite.set_walking(false)

## Handle damage for billboard sprite hurt animation
func _on_damaged_for_sprite(_amount: int, _damage_type: Enums.DamageType, _attacker: Node) -> void:
	if billboard_sprite and current_state != AIState.DEAD:
		billboard_sprite.play_hurt()

## Setup rat directional sprites - call after setup_billboard_sprite for rat enemies
func _setup_rat_directional_sprites() -> void:
	_is_rat_enemy = true
	_rat_tex_forward = load("res://assets/sprites/enemies/beasts/rat_moving_forward.png")
	_rat_tex_away = load("res://assets/sprites/enemies/beasts/rat_moving_away.png")
	_rat_tex_right = load("res://assets/sprites/enemies/beasts/rat_moving_right.png")

	if not _rat_tex_forward or not _rat_tex_away or not _rat_tex_right:
		push_warning("[EnemyBase] Failed to load one or more rat directional textures")
		_is_rat_enemy = false

## Update rat sprite based on movement direction relative to camera
## Called every physics frame for rat enemies
func _update_rat_directional_sprite() -> void:
	if not _is_rat_enemy or not billboard_sprite or not billboard_sprite.sprite:
		return

	# Get camera
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# Get movement direction (use velocity)
	var move_dir: Vector3 = velocity
	move_dir.y = 0

	# If not moving significantly, keep current direction
	if move_dir.length_squared() < 0.1:
		return

	move_dir = move_dir.normalized()

	# Get camera forward direction (flattened to XZ plane)
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()

	# Get camera right direction
	var cam_right: Vector3 = camera.global_transform.basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()

	# Calculate dot products to determine direction
	var forward_dot: float = move_dir.dot(cam_forward)
	var right_dot: float = move_dir.dot(cam_right)

	# Determine which direction sprite to use
	# Thresholds: if moving mostly forward/back vs left/right
	var new_direction: int = _rat_current_direction

	if absf(forward_dot) > absf(right_dot):
		# Moving more forward/backward than left/right
		if forward_dot > 0.3:
			new_direction = 0  # Moving toward camera (forward sprite)
		elif forward_dot < -0.3:
			new_direction = 1  # Moving away from camera (away sprite)
	else:
		# Moving more left/right than forward/backward
		if right_dot > 0.3:
			new_direction = 2  # Moving right
		elif right_dot < -0.3:
			new_direction = 3  # Moving left

	# Only update if direction changed
	if new_direction != _rat_current_direction:
		_rat_current_direction = new_direction
		_apply_rat_direction_sprite()

## Apply the correct sprite texture and flip for current rat direction
func _apply_rat_direction_sprite() -> void:
	if not billboard_sprite or not billboard_sprite.sprite:
		return

	var tex: Texture2D = null
	var flip_h: bool = false

	match _rat_current_direction:
		0:  # Forward (toward camera)
			tex = _rat_tex_forward
		1:  # Away (from camera)
			tex = _rat_tex_away
		2:  # Right
			tex = _rat_tex_right
		3:  # Left (flip right sprite)
			tex = _rat_tex_right
			flip_h = true

	if tex and tex != billboard_sprite.sprite.texture:
		billboard_sprite.sprite.texture = tex
		# Update sprite sheet configuration (all rat directional sprites are single frame)
		billboard_sprite.sprite.hframes = 4
		billboard_sprite.sprite.vframes = 1
		billboard_sprite.h_frames = 4
		billboard_sprite.v_frames = 1
		# Recalculate offset for new texture
		var frame_height: float = tex.get_height()
		billboard_sprite.sprite.offset = Vector2(0, frame_height / 2.0)

	# Apply horizontal flip
	billboard_sprite.sprite.flip_h = flip_h

## Static helper to spawn a billboard sprite enemy
## Returns the enemy instance with billboard sprite configured
## zone_danger: Zone danger level for stat scaling (1-10, default 1)
static func spawn_billboard_enemy(parent: Node, pos: Vector3, enemy_data_path: String, sprite_texture: Texture2D, h_frames: int = 4, v_frames: int = 4, p_zone_danger: int = 1) -> EnemyBase:
	# Load base enemy scene
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
	if not enemy_scene:
		push_error("[EnemyBase] Failed to load enemy_base.tscn")
		return null

	var enemy: EnemyBase = enemy_scene.instantiate()

	# Load and set enemy data
	var data: EnemyData = load(enemy_data_path)
	if data:
		enemy.enemy_data = data

	# Set zone danger before adding to scene (so _initialize_from_data uses it)
	enemy.zone_danger = p_zone_danger

	# IMPORTANT: Set position BEFORE add_child so _ready() gets the correct spawn_position
	# This fixes the bug where enemies would walk back to (0,0,0) because spawn_position
	# was being set to the wrong value
	enemy.position = pos

	# Add to scene (required for _ready to run)
	parent.add_child(enemy)

	# Ensure spawn_position is correctly set after _ready (belt and suspenders)
	enemy.spawn_position = enemy.global_position

	# Setup billboard sprite (after _ready has run)
	enemy.call_deferred("setup_billboard_sprite", sprite_texture, h_frames, v_frames)

	return enemy


## Static helper to spawn a mesh-based enemy (uses placeholder capsule mesh)
## Returns the enemy instance without billboard sprite
## zone_danger: Zone danger level for stat scaling (1-10, default 1)
static func spawn_mesh_enemy(parent: Node, pos: Vector3, enemy_data_path: String, p_zone_danger: int = 1) -> EnemyBase:
	# Load base enemy scene
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
	if not enemy_scene:
		push_error("[EnemyBase] Failed to load enemy_base.tscn")
		return null

	var enemy: EnemyBase = enemy_scene.instantiate()
	if not enemy:
		push_error("[EnemyBase] Failed to instantiate enemy_base.tscn")
		return null

	# Load and set enemy data
	var data: EnemyData = load(enemy_data_path)
	if data:
		enemy.enemy_data = data

	# Set zone danger before adding to scene (so _initialize_from_data uses it)
	enemy.zone_danger = p_zone_danger

	# IMPORTANT: Set position BEFORE add_child so _ready() gets the correct spawn_position
	enemy.position = pos

	# Add to scene (mesh stays visible - no billboard sprite setup)
	parent.add_child(enemy)

	# Ensure spawn_position is correctly set
	enemy.spawn_position = enemy.global_position

	return enemy


## Static helper to spawn a skeleton enemy with separate walk/attack sprite sheets
## Uses skeleton_walking.png (8x1) for idle/walk and skeleton_attacking.png (6x1) for attacks
## zone_danger: Zone danger level for stat scaling (1-10, default 1)
static func spawn_skeleton_enemy(parent: Node, pos: Vector3, enemy_data_path: String = "res://data/enemies/skeleton_warrior.tres", p_zone_danger: int = 1) -> EnemyBase:
	# Validate parent
	if not parent:
		push_error("[EnemyBase] spawn_skeleton_enemy called with null parent")
		return null

	# Load base enemy scene
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
	if not enemy_scene:
		push_error("[EnemyBase] Failed to load enemy_base.tscn")
		return null

	var enemy: EnemyBase = enemy_scene.instantiate()
	if not enemy:
		push_error("[EnemyBase] Failed to instantiate enemy_base.tscn")
		return null

	# Load and set enemy data
	var data: EnemyData = load(enemy_data_path)
	if data:
		enemy.enemy_data = data
	else:
		push_warning("[EnemyBase] Failed to load enemy data: %s" % enemy_data_path)

	# Set zone danger before adding to scene (so _initialize_from_data uses it)
	enemy.zone_danger = p_zone_danger

	# IMPORTANT: Set position BEFORE add_child so _ready() gets the correct spawn_position
	enemy.position = pos

	# Add to scene (required for _ready to run)
	parent.add_child(enemy)

	# Ensure spawn_position is correctly set
	enemy.spawn_position = enemy.global_position

	# Setup skeleton billboard sprite with multi-state textures (after _ready has run)
	enemy.call_deferred("_setup_skeleton_sprites")

	return enemy


## Setup skeleton enemy with separate walk and attack sprite sheets
func _setup_skeleton_sprites() -> void:
	# Load textures
	var walk_tex: Texture2D = load("res://assets/sprites/enemies/undead/skeleton_walking.png")
	var attack_tex: Texture2D = load("res://assets/sprites/enemies/undead/skeleton_attacking.png")

	if not walk_tex:
		push_warning("[EnemyBase] Failed to load skeleton_walking.png")
		return

	# Hide existing mesh visuals
	if mesh_root:
		for child in mesh_root.get_children():
			if child is MeshInstance3D:
				child.visible = false

	# Create billboard sprite
	billboard_sprite = BillboardSprite.new()
	billboard_sprite.sprite_sheet = walk_tex
	billboard_sprite.h_frames = 8
	billboard_sprite.v_frames = 1
	billboard_sprite.pixel_size = 0.03
	billboard_sprite.offset_y = 0.0
	billboard_sprite.owner_enemy = self

	# Configure animation for single row sprite sheets
	billboard_sprite.idle_row = 0
	billboard_sprite.idle_frames = 8
	billboard_sprite.idle_fps = 6.0
	billboard_sprite.walk_row = 0
	billboard_sprite.walk_frames = 8
	billboard_sprite.walk_fps = 8.0

	# Setup separate textures for walking/idle vs attacking
	billboard_sprite.walk_texture = walk_tex
	billboard_sprite.walk_texture_h_frames = 8
	billboard_sprite.walk_texture_v_frames = 1
	billboard_sprite.idle_texture = walk_tex
	billboard_sprite.idle_texture_h_frames = 8
	billboard_sprite.idle_texture_v_frames = 1

	if attack_tex:
		billboard_sprite.attack_texture = attack_tex
		billboard_sprite.attack_texture_h_frames = 6
		billboard_sprite.attack_texture_v_frames = 1
		billboard_sprite.attack_frames = 6
		billboard_sprite.attack_fps = 10.0
	else:
		push_warning("[EnemyBase] Failed to load skeleton_attacking.png - attacks will use walk texture")

	# Add to mesh_root so it moves with the enemy
	if mesh_root:
		mesh_root.add_child(billboard_sprite)
		billboard_sprite.position = Vector3.ZERO
	else:
		add_child(billboard_sprite)
		billboard_sprite.position = Vector3.ZERO

	# Connect state changes to sprite animation (avoid duplicates)
	if not state_changed.is_connected(_on_state_changed_for_sprite):
		state_changed.connect(_on_state_changed_for_sprite)
	if not damaged.is_connected(_on_damaged_for_sprite):
		damaged.connect(_on_damaged_for_sprite)

	print("[EnemyBase] Skeleton sprites setup: walk (8 frames), attack (6 frames)")


## Add a colored glow light emanating from the enemy
## Used for spectral/undead enemies like skeleton shades
## glow_color: The light color (e.g., purple for undead)
## energy: Light intensity (default 1.5)
## range: How far the light reaches (default 4.0)
func add_enemy_glow(glow_color: Color, energy: float = 1.5, glow_range: float = 4.0) -> void:
	if enemy_glow_light:
		return  # Already has glow

	enemy_glow_light = OmniLight3D.new()
	enemy_glow_light.name = "EnemyGlow"
	enemy_glow_light.light_color = glow_color
	enemy_glow_light.light_energy = energy
	enemy_glow_light.omni_range = glow_range
	enemy_glow_light.omni_attenuation = 1.5
	enemy_glow_light.shadow_enabled = false
	# Position at chest height
	enemy_glow_light.position = Vector3(0, 1.0, 0)

	# Add to mesh_root so it moves with the enemy
	if mesh_root:
		mesh_root.add_child(enemy_glow_light)
	else:
		add_child(enemy_glow_light)


## Remove the enemy glow light
func remove_enemy_glow() -> void:
	if enemy_glow_light:
		enemy_glow_light.queue_free()
		enemy_glow_light = null


## Check if enemy is an undead/special type and apply appropriate glow
## Called after spawning to add visual effects based on enemy type
func _check_and_apply_undead_glow(data_path: String) -> void:
	# Purple glow for skeleton shades and similar undead
	if data_path.contains("skeleton_shade") or data_path.contains("soul_shade"):
		add_enemy_glow(Color(0.5, 0.2, 0.8), 1.2, 5.0)  # Creepy purple
	elif data_path.contains("ghost") or data_path.contains("specter") or data_path.contains("wraith"):
		add_enemy_glow(Color(0.3, 0.5, 0.8), 1.0, 4.0)  # Ethereal blue
	elif data_path.contains("vampire"):
		add_enemy_glow(Color(0.6, 0.1, 0.2), 1.5, 6.0)  # Dark crimson
	elif data_path.contains("abomination"):
		add_enemy_glow(Color(0.2, 0.5, 0.2), 1.3, 5.0)  # Sickly green
	elif data_path.contains("lich") or data_path.contains("necromancer"):
		add_enemy_glow(Color(0.3, 0.1, 0.5), 1.5, 6.0)  # Dark violet


## Check if enemy should have glow based on its enemy_data
## Called automatically if enemy_data has glow settings
func check_auto_glow() -> void:
	if not enemy_data:
		return
	# Check if enemy ID indicates undead/special type
	var enemy_id := enemy_data.id if enemy_data.id else ""
	if enemy_id.contains("skeleton") or enemy_id.contains("shade"):
		add_enemy_glow(Color(0.5, 0.2, 0.8), 1.2, 5.0)
	elif enemy_id.contains("ghost") or enemy_id.contains("specter"):
		add_enemy_glow(Color(0.3, 0.5, 0.8), 1.0, 4.0)
	elif enemy_id.contains("vampire"):
		add_enemy_glow(Color(0.6, 0.1, 0.2), 1.5, 6.0)
	elif enemy_id.contains("abomination"):
		add_enemy_glow(Color(0.2, 0.5, 0.2), 1.3, 5.0)
	elif enemy_id.contains("lich") or enemy_id.contains("necromancer"):
		add_enemy_glow(Color(0.3, 0.1, 0.5), 1.5, 6.0)
