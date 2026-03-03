@tool
## triggered_trap.gd - Trap that activates when triggered (pressure plate, tripwire, etc.)
## Can be one-shot or repeating, with cooldown between activations
## Place in editor and configure via Inspector
class_name TriggeredTrap
extends Area3D

## Trap types for different behaviors
enum TrapType {
	SPIKE,      ## Spikes shoot up from ground
	FIRE,       ## Fire burst
	POISON_GAS, ## Poison cloud
	ARROW,      ## Arrows shoot from wall
	FALLING,    ## Rocks/debris fall
	EXPLOSIVE,  ## Explosion
	LIGHTNING,  ## Electric shock
}

## Trigger zone shape
enum ShapeType { BOX, CYLINDER }

## Configuration
@export_group("Trap Settings")
@export var trap_type: TrapType = TrapType.SPIKE:
	set(value):
		trap_type = value
		_set_damage_type_from_trap()
@export var damage: int = 25
@export var damage_type: String = "piercing"  ## Auto-set based on trap_type
@export var trigger_delay: float = 0.2  ## Delay before trap activates after trigger
@export var reset_time: float = 3.0  ## Time before trap can trigger again (0 = one-shot)
@export var is_active: bool = true  ## Can be disabled via lever/switch

## Shape settings
@export_group("Trigger Zone")
@export var shape_type: ShapeType = ShapeType.BOX:
	set(value):
		shape_type = value
		_update_collision_shape()
@export var box_size: Vector3 = Vector3(1.5, 0.3, 1.5):
	set(value):
		box_size = value
		_update_collision_shape()
@export var cylinder_radius: float = 1.0:
	set(value):
		cylinder_radius = value
		_update_collision_shape()
@export var cylinder_height: float = 0.3:
	set(value):
		cylinder_height = value
		_update_collision_shape()

## Detection settings
@export_group("Detection")
@export var detect_player: bool = true
@export var detect_enemies: bool = true
@export var detect_npcs: bool = false  ## Usually don't trap friendly NPCs

## Audio/Visual
@export_group("Effects")
@export var trigger_sound: String = "trap_trigger"
@export var activate_sound: String = "trap_spike"

## State
var _is_triggered: bool = false
var _cooldown_timer: float = 0.0
var _trigger_timer: float = 0.0
var _targets_in_zone: Array[Node3D] = []
var _collision_shape: CollisionShape3D

## Signals
signal trap_triggered(trap: TriggeredTrap)
signal trap_activated(trap: TriggeredTrap, victims: Array[Node3D])
signal trap_reset(trap: TriggeredTrap)


func _ready() -> void:
	_ensure_collision_shape()

	if Engine.is_editor_hint():
		return

	# Setup collision
	collision_layer = 0
	collision_mask = 6  # Player (2) and NPCs/enemies (3)
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Set damage type based on trap type
	_set_damage_type_from_trap()


func _ensure_collision_shape() -> void:
	# Look for existing collision shape
	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			break

	# Create if not found
	if not _collision_shape:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)
		if Engine.is_editor_hint():
			_collision_shape.owner = get_tree().edited_scene_root

	_update_collision_shape()


func _update_collision_shape() -> void:
	if not _collision_shape:
		return

	match shape_type:
		ShapeType.BOX:
			var box := BoxShape3D.new()
			box.size = box_size
			_collision_shape.shape = box
		ShapeType.CYLINDER:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = cylinder_radius
			cylinder.height = cylinder_height
			_collision_shape.shape = cylinder


func _set_damage_type_from_trap() -> void:
	match trap_type:
		TrapType.SPIKE:
			damage_type = "piercing"
			activate_sound = "trap_spike"
		TrapType.FIRE:
			damage_type = "fire"
			activate_sound = "trap_fire"
		TrapType.POISON_GAS:
			damage_type = "poison"
			activate_sound = "trap_gas"
		TrapType.ARROW:
			damage_type = "piercing"
			activate_sound = "trap_arrow"
		TrapType.FALLING:
			damage_type = "bludgeoning"
			activate_sound = "trap_falling"
		TrapType.EXPLOSIVE:
			damage_type = "fire"
			activate_sound = "trap_explosion"
		TrapType.LIGHTNING:
			damage_type = "lightning"
			activate_sound = "trap_lightning"


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Handle cooldown
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_cooldown_timer = 0
			trap_reset.emit(self)

	# Handle trigger delay
	if _is_triggered and _trigger_timer > 0:
		_trigger_timer -= delta
		if _trigger_timer <= 0:
			_activate_trap()


func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	if not _should_detect(body):
		return

	if body not in _targets_in_zone:
		_targets_in_zone.append(body)

	# Trigger if not already triggered and not on cooldown
	if not _is_triggered and _cooldown_timer <= 0:
		_trigger_trap()


func _on_body_exited(body: Node3D) -> void:
	_targets_in_zone.erase(body)


func _should_detect(entity: Node3D) -> bool:
	if detect_player and entity.is_in_group("player"):
		return true
	if detect_enemies and entity.is_in_group("enemies"):
		if entity.has_method("is_dead") and entity.is_dead():
			return false
		return true
	if detect_npcs and entity.is_in_group("npcs"):
		return true
	if entity.is_in_group("gladiators"):
		return detect_enemies  # Gladiators count as enemies
	return false


func _trigger_trap() -> void:
	_is_triggered = true
	_trigger_timer = trigger_delay

	# Play trigger sound (click, creak, etc.)
	if AudioManager and trigger_sound != "":
		AudioManager.play_sfx(trigger_sound)

	trap_triggered.emit(self)


func _activate_trap() -> void:
	_is_triggered = false

	# Play activation sound
	if AudioManager and activate_sound != "":
		AudioManager.play_sfx(activate_sound)

	# Get valid targets still in zone
	var victims: Array[Node3D] = []
	for target in _targets_in_zone:
		if is_instance_valid(target):
			victims.append(target)
			_damage_target(target)

	trap_activated.emit(self, victims)

	# Set cooldown or disable if one-shot
	if reset_time > 0:
		_cooldown_timer = reset_time
	else:
		is_active = false  # One-shot trap, stays disabled


func _damage_target(target: Node3D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.has_method("apply_damage"):
		target.apply_damage(damage, damage_type)
	elif "health" in target:
		target.health -= damage
		if target.health <= 0 and target.has_method("die"):
			target.die()


## Enable/disable the trap (for levers, switches, etc.)
func set_trap_active(active: bool) -> void:
	is_active = active
	if not active:
		_is_triggered = false
		_trigger_timer = 0
		_cooldown_timer = 0


## Reset the trap (for puzzle rooms, etc.)
func reset_trap() -> void:
	is_active = true
	_is_triggered = false
	_trigger_timer = 0
	_cooldown_timer = 0


## Editor warnings
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if damage <= 0:
		warnings.append("Damage is 0 or negative. Trap won't deal damage.")
	if reset_time == 0:
		warnings.append("Reset time is 0 - this is a one-shot trap.")
	return warnings


## Static factory for easy spawning via code
static func spawn_trap(
	parent: Node,
	pos: Vector3,
	size: Vector3,
	p_trap_type: TrapType = TrapType.SPIKE,
	p_damage: int = 25,
	p_reset_time: float = 3.0
) -> TriggeredTrap:
	var trap := TriggeredTrap.new()
	trap.position = pos
	trap.trap_type = p_trap_type
	trap.damage = p_damage
	trap.reset_time = p_reset_time
	trap.shape_type = ShapeType.BOX
	trap.box_size = size

	parent.add_child(trap)
	trap._ensure_collision_shape()
	return trap


## Spawn a pressure plate trap
static func spawn_pressure_plate(
	parent: Node,
	pos: Vector3,
	p_trap_type: TrapType = TrapType.SPIKE,
	p_damage: int = 25
) -> TriggeredTrap:
	return spawn_trap(parent, pos, Vector3(1.5, 0.2, 1.5), p_trap_type, p_damage, 3.0)


## Spawn a tripwire trap
static func spawn_tripwire(
	parent: Node,
	pos: Vector3,
	width: float = 3.0,
	p_trap_type: TrapType = TrapType.ARROW,
	p_damage: int = 20
) -> TriggeredTrap:
	var trap := spawn_trap(parent, pos, Vector3(width, 1.0, 0.1), p_trap_type, p_damage, 0.0)
	trap.trigger_delay = 0.0  # Tripwires are instant
	return trap
