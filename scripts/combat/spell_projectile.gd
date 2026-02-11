## spell_projectile.gd - Projectile for spell effects
class_name SpellProjectile
extends Area3D

signal hit_target(target: Node)
signal expired

## Projectile data
var spell_data: SpellData
var caster: Node
var direction: Vector3
var speed: float = 25.0
var is_homing: bool = false
var homing_target: Node3D = null
var homing_strength: float = 5.0

## Lifetime
var max_lifetime: float = 5.0
var lifetime_timer: float = 0.0

## Chain lightning tracking
var chain_count: int = 0
var hit_targets: Array[Node] = []

## Piercing
var is_piercing: bool = false
var pierce_count: int = 0
var max_pierces: int = 3

func _ready() -> void:
	# Set up collision
	monitoring = true
	collision_layer = 512  # Projectile layer
	collision_mask = 4 + 128  # Enemy layer + enemy hurtbox layer

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	lifetime_timer += delta
	if lifetime_timer >= max_lifetime:
		_expire()
		return

	# Homing behavior
	if is_homing and homing_target and is_instance_valid(homing_target):
		var to_target := (homing_target.global_position - global_position).normalized()
		direction = direction.lerp(to_target, homing_strength * delta).normalized()

	# Move
	global_position += direction * speed * delta

	# Face movement direction
	if direction.length() > 0.1:
		look_at(global_position + direction)

## Initialize the projectile
func initialize(spell: SpellData, source: Node, dir: Vector3, homing: bool = false) -> void:
	spell_data = spell
	caster = source
	direction = dir.normalized()
	speed = spell.projectile_speed
	is_homing = homing or spell.is_homing
	homing_strength = spell.homing_strength
	is_piercing = spell.piercing
	chain_count = spell.chain_targets

	# Find homing target
	if is_homing:
		_find_homing_target()

	# Set lifetime based on range
	max_lifetime = spell.range_distance / speed

func _find_homing_target() -> void:
	var closest := CombatManager.get_closest_enemy(global_position, 30.0)
	if closest and closest is Node3D:
		homing_target = closest as Node3D

func _on_area_entered(area: Area3D) -> void:
	var target := area.get_parent()
	_handle_hit(target)

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)

func _handle_hit(target: Node) -> void:
	if not target:
		return

	# Don't hit caster
	if target == caster:
		return

	# Don't hit same target twice
	if target in hit_targets:
		return

	# Check if valid target
	if not target.is_in_group("enemies") and not target.is_in_group("player"):
		# Hit world geometry - stop
		if not is_piercing:
			_expire()
		return

	hit_targets.append(target)
	hit_target.emit(target)

	# Apply damage
	if spell_data:
		CombatManager.apply_spell_damage(caster, target, spell_data)

	# Play impact effect
	_spawn_impact_effect()

	# Chain lightning
	if chain_count > 0 and hit_targets.size() <= chain_count:
		_chain_to_next_target()
	elif not is_piercing or pierce_count >= max_pierces:
		_expire()
	else:
		pierce_count += 1

func _chain_to_next_target() -> void:
	# Find nearby enemy that hasn't been hit
	var enemies := CombatManager.get_enemies_in_range(global_position, spell_data.chain_range if spell_data else 5.0)

	var next_target: Node = null
	var closest_dist := 999.0

	for enemy in enemies:
		if enemy in hit_targets:
			continue
		if enemy is Node3D:
			var dist := global_position.distance_to((enemy as Node3D).global_position)
			if dist < closest_dist:
				closest_dist = dist
				next_target = enemy

	if next_target and next_target is Node3D:
		# Redirect projectile
		direction = (next_target.global_position - global_position).normalized()
		homing_target = next_target as Node3D
		is_homing = true
	else:
		_expire()

func _spawn_impact_effect() -> void:
	if not spell_data or spell_data.impact_effect_path.is_empty():
		return

	var effect_scene := load(spell_data.impact_effect_path) as PackedScene
	if not effect_scene:
		return

	var effect := effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node3D:
		(effect as Node3D).global_position = global_position

	# Play impact sound
	if not spell_data.impact_sound.is_empty():
		AudioManager.play_sfx_3d(spell_data.impact_sound, global_position)

func _expire() -> void:
	expired.emit()
	queue_free()
