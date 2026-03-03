@tool
## damage_zone.gd - Area that damages entities that enter it
## Use for spike pits, lava, acid pools, poison gas, etc.
## Can be placed in editor and configured via Inspector
class_name DamageZone
extends Area3D

## Zone shape type
enum ShapeType { BOX, CYLINDER }

## Damage settings
@export_group("Damage")
@export var damage_per_tick: int = 10  ## Damage dealt each tick
@export var tick_interval: float = 0.5  ## Seconds between damage ticks
@export var damage_type: String = "piercing"  ## piercing, fire, poison, etc.
@export var instant_kill: bool = false  ## If true, kills instantly on contact

## Shape settings (editable in inspector)
@export_group("Shape")
@export var shape_type: ShapeType = ShapeType.BOX:
	set(value):
		shape_type = value
		_update_collision_shape()
@export var box_size: Vector3 = Vector3(2, 1, 2):
	set(value):
		box_size = value
		_update_collision_shape()
@export var cylinder_radius: float = 2.0:
	set(value):
		cylinder_radius = value
		_update_collision_shape()
@export var cylinder_height: float = 1.0:
	set(value):
		cylinder_height = value
		_update_collision_shape()

## Detection settings
@export_group("Detection")
@export var detect_player: bool = true
@export var detect_enemies: bool = true
@export var detect_npcs: bool = true
@export var detect_gladiators: bool = true

## Visual/audio
@export_group("Effects")
@export var play_sound_on_damage: bool = true
@export var damage_sound_event: String = "spike_trap"  ## Audio event name
@export var debug_color: Color = Color(1, 0, 0, 0.3)  ## Color in editor

## Internal tracking
var _bodies_in_zone: Array[Node3D] = []
var _tick_timer: float = 0.0
var _collision_shape: CollisionShape3D


func _ready() -> void:
	# Create collision shape if it doesn't exist
	_ensure_collision_shape()

	if Engine.is_editor_hint():
		return  # Don't run game logic in editor

	# Setup collision detection
	collision_layer = 0  # Don't block anything
	collision_mask = 6   # Detect layer 2 (player) and 3 (NPCs/enemies)

	# Enable monitoring
	monitoring = true
	monitorable = false

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _bodies_in_zone.is_empty():
		return

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_apply_damage_tick()


## Ensure collision shape exists
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


## Update collision shape based on settings
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


## Apply damage to all entities in the zone
func _apply_damage_tick() -> void:
	# Clean up invalid references first
	_bodies_in_zone = _bodies_in_zone.filter(func(b): return is_instance_valid(b))

	for body in _bodies_in_zone:
		_damage_entity(body)


## Apply damage to a single entity
func _damage_entity(entity: Node3D) -> void:
	if instant_kill:
		# Instant kill
		if entity.has_method("die"):
			entity.die()
		elif "health" in entity:
			entity.health = 0
			if entity.has_method("die"):
				entity.die()
		_play_damage_effects(entity)
		return

	# Convert string damage_type to enum
	var dmg_type: Enums.DamageType = _get_damage_type_enum()

	# Normal damage
	if entity.has_method("take_damage"):
		entity.take_damage(damage_per_tick, dmg_type, self)
		_play_damage_effects(entity)
	elif entity.has_method("apply_damage"):
		entity.apply_damage(damage_per_tick, damage_type)
		_play_damage_effects(entity)
	elif "health" in entity:
		entity.health -= damage_per_tick
		_play_damage_effects(entity)
		# Check for death
		if entity.health <= 0 and entity.has_method("die"):
			entity.die()


## Convert string damage_type to Enums.DamageType
func _get_damage_type_enum() -> Enums.DamageType:
	match damage_type.to_lower():
		"fire":
			return Enums.DamageType.FIRE
		"lightning":
			return Enums.DamageType.LIGHTNING
		"frost", "ice", "cold":
			return Enums.DamageType.FROST
		"poison":
			return Enums.DamageType.POISON
		"necrotic":
			return Enums.DamageType.NECROTIC
		"holy":
			return Enums.DamageType.HOLY
		_:
			return Enums.DamageType.PHYSICAL


## Play damage effects (sound, particles, etc.)
func _play_damage_effects(_entity: Node3D) -> void:
	if Engine.is_editor_hint():
		return

	if play_sound_on_damage and AudioManager:
		AudioManager.play_sfx(damage_sound_event)


func _on_body_entered(body: Node3D) -> void:
	# Check if it's something we should damage
	if _is_damageable(body):
		if body not in _bodies_in_zone:
			_bodies_in_zone.append(body)
			# Deal initial damage immediately
			_damage_entity(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies_in_zone.erase(body)


## Check if an entity should take damage from this zone
func _is_damageable(entity: Node3D) -> bool:
	# Player
	if detect_player and entity.is_in_group("player"):
		return true

	# Enemies
	if detect_enemies and entity.is_in_group("enemies"):
		# Check if alive
		if entity.has_method("is_dead") and entity.is_dead():
			return false
		return true

	# NPCs (civilians, etc.)
	if detect_npcs and entity.is_in_group("npcs"):
		return true

	# Gladiators in tournament
	if detect_gladiators and entity.is_in_group("gladiators"):
		return true

	return false


## Editor gizmo drawing
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if damage_per_tick <= 0 and not instant_kill:
		warnings.append("Damage per tick is 0 or negative. Zone won't deal damage.")
	return warnings


## Static factory method for easy spawning via code
static func spawn_damage_zone(
	parent: Node,
	pos: Vector3,
	size: Vector3,
	p_damage: int = 10,
	p_interval: float = 0.5,
	p_damage_type: String = "piercing"
) -> DamageZone:
	var zone := DamageZone.new()
	zone.position = pos
	zone.damage_per_tick = p_damage
	zone.tick_interval = p_interval
	zone.damage_type = p_damage_type
	zone.shape_type = ShapeType.BOX
	zone.box_size = size

	parent.add_child(zone)
	zone._ensure_collision_shape()
	return zone


## Create a cylindrical damage zone (for round pits)
static func spawn_cylinder_damage_zone(
	parent: Node,
	pos: Vector3,
	radius: float,
	height: float,
	p_damage: int = 10,
	p_interval: float = 0.5,
	p_damage_type: String = "piercing"
) -> DamageZone:
	var zone := DamageZone.new()
	zone.position = pos
	zone.damage_per_tick = p_damage
	zone.tick_interval = p_interval
	zone.damage_type = p_damage_type
	zone.shape_type = ShapeType.CYLINDER
	zone.cylinder_radius = radius
	zone.cylinder_height = height

	parent.add_child(zone)
	zone._ensure_collision_shape()
	return zone
