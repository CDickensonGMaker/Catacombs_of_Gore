## hitbox.gd - Reusable hitbox component for dealing damage
## Attach to any entity that can deal damage
class_name Hitbox
extends Area3D

const DEBUG := true  # TEMP: Enable to debug enemy damage issues

signal hit_landed(target: Node)

## Configuration
@export var damage: int = 10
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var stagger_power: float = 1.0
@export var knockback_force: float = 5.0

## Condition infliction
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE
@export var condition_chance: float = 0.0
@export var condition_duration: float = 0.0

## Owner reference (who is attacking)
var owner_entity: Node = null

## Track what we've hit this activation
var hit_targets: Array[Node] = []

## Is this hitbox currently active
var is_active: bool = false

func _ready() -> void:
	# CRITICAL: Set up collision properly
	# Hitbox should detect hurtboxes
	monitoring = false  # Start disabled
	monitorable = false  # Other areas shouldn't detect us as a target

	# Set collision layers/masks
	# Layer 4 = player_hitbox, Layer 5 = enemy_hitbox
	# Mask should detect the opposite hurtbox layer
	# Layer 6 = player_hurtbox, Layer 7 = enemy_hurtbox

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Store damage info as metadata for receivers
	set_meta("damage", damage)
	set_meta("damage_type", damage_type)
	set_meta("stagger_power", stagger_power)

## Activate the hitbox (call when attack starts)
func activate() -> void:
	hit_targets.clear()
	is_active = true
	monitoring = true
	monitorable = true  # Allow detection in both directions

	if DEBUG:
		print("[Hitbox] Activated! layer=", collision_layer, " mask=", collision_mask, " owner=", str(owner_entity.name) if owner_entity else "none")
		print("[Hitbox] Global position: ", global_position)
		var player_hurtboxes := get_tree().get_nodes_in_group("player_hurtbox")
		print("[Hitbox] Player hurtboxes in scene: ", player_hurtboxes.size())
		for hb in player_hurtboxes:
			if hb is Area3D:
				var area := hb as Area3D
				print("[Hitbox] - ", area.name, " at ", area.global_position, " layer=", area.collision_layer, " monitorable=", area.monitorable)

	# Force physics update to detect overlaps immediately
	force_update_transform()

	# Use call_deferred to check overlaps after physics processes the change
	call_deferred("_check_initial_overlaps")

## Check for overlaps that existed when hitbox was activated
func _check_initial_overlaps() -> void:
	if not is_active:
		return

	var overlapping := get_overlapping_areas()
	if DEBUG:
		print("[Hitbox] Checking initial overlaps, found: ", overlapping.size())
	for area in overlapping:
		if DEBUG:
			print("[Hitbox] - Overlapping: ", area.name, " layer=", area.collision_layer, " monitorable=", area.monitorable)
		if area not in hit_targets:
			_on_area_entered(area)

	# If no overlaps found, do a manual proximity check
	if DEBUG and overlapping.is_empty():
		print("[Hitbox] No overlaps detected! Checking player hurtboxes manually...")
		var player_hurtboxes := get_tree().get_nodes_in_group("player_hurtbox")
		for hb in player_hurtboxes:
			if hb is Area3D:
				var hb_area := hb as Area3D
				var dist := global_position.distance_to(hb_area.global_position)
				print("[Hitbox] Distance to ", hb_area.name, ": ", snapped(dist, 0.1))
				if dist < 3.0:
					print("[Hitbox] Player hurtbox is close but not detected! This is the collision bug.")
					print("[Hitbox] My mask=", collision_mask, " their layer=", hb_area.collision_layer)
					print("[Hitbox] Mask & Layer = ", collision_mask & hb_area.collision_layer)
					print("[Hitbox] My monitoring=", monitoring, " their monitorable=", hb_area.monitorable)

## Deactivate the hitbox (call when attack ends)
func deactivate() -> void:
	is_active = false
	monitoring = false

## Called when we overlap with another Area3D (hurtbox)
func _on_area_entered(area: Area3D) -> void:
	if DEBUG:
		print("[Hitbox] Area entered: ", area.name, " is_active=", is_active)
	if not is_active:
		return

	# Check if it's a hurtbox
	if not area is Hurtbox:
		# Fallback: check group
		if not area.is_in_group("hurtbox") and not area.is_in_group("enemy_hurtbox") and not area.is_in_group("player_hurtbox"):
			if DEBUG:
				print("[Hitbox] Area is not a hurtbox, ignoring")
			return

	var target := area.get_parent()
	if not target:
		if DEBUG:
			print("[Hitbox] No parent found for hurtbox")
		return

	# Don't hit ourselves
	if target == owner_entity:
		if DEBUG:
			print("[Hitbox] Ignoring self-hit")
		return

	# Don't hit same target twice per activation
	if target in hit_targets:
		return

	if DEBUG:
		print("[Hitbox] Hitting target: ", target.name)
	hit_targets.append(target)
	_apply_hit(target)

## Called when we overlap with a physics body
func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	# Don't hit ourselves
	if body == owner_entity:
		return

	# Don't hit same target twice
	if body in hit_targets:
		return

	# Only hit valid targets
	if not body.is_in_group("enemies") and not body.is_in_group("player"):
		return

	hit_targets.append(body)
	_apply_hit(body)

## Apply the hit to a target
func _apply_hit(target: Node) -> void:
	hit_landed.emit(target)
	if DEBUG:
		print("[Hitbox] Applying hit to ", target.name, " damage=", damage, " type=", damage_type)

	# Apply damage if target can receive it
	if target.has_method("take_damage"):
		target.take_damage(damage, damage_type, owner_entity)
	elif DEBUG:
		print("[Hitbox] Target has no take_damage method!")

	# Apply stagger
	if stagger_power > 0 and target.has_method("apply_stagger"):
		target.apply_stagger(stagger_power)

	# Apply knockback
	if knockback_force > 0 and target is CharacterBody3D and owner_entity is Node3D:
		var direction: Vector3 = (target.global_position - (owner_entity as Node3D).global_position).normalized()
		direction.y = 0.2  # Slight upward
		(target as CharacterBody3D).velocity += direction * knockback_force

	# Apply condition
	if inflicts_condition != Enums.Condition.NONE and randf() < condition_chance:
		if target.has_method("apply_condition"):
			target.apply_condition(inflicts_condition, condition_duration)

## Set owner (the entity this hitbox belongs to)
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity

## Update damage values (for weapons with different stats)
func set_damage_values(new_damage: int, new_type: Enums.DamageType = Enums.DamageType.PHYSICAL) -> void:
	damage = new_damage
	damage_type = new_type
	set_meta("damage", damage)
	set_meta("damage_type", damage_type)
