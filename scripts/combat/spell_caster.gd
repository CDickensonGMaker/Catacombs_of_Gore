## spell_caster.gd - Handles spell casting for player and NPCs
class_name SpellCaster
extends Node

signal cast_started(spell: SpellData)
signal cast_completed(spell: SpellData)
signal cast_interrupted
signal mana_consumed(amount: int, current: int, maximum: int)

## Owner reference
@export var owner_entity: Node3D
@export var cast_origin: Node3D  # Where projectiles spawn from

## Equipped spells (quick spell slots)
var equipped_spells: Array[SpellData] = [null, null, null, null]

## Known spells
var known_spells: Array[SpellData] = []

## Casting state
var is_casting: bool = false
var current_spell: SpellData = null
var cast_timer: float = 0.0
var cast_charge: float = 0.0  # For charged spells

## Spell database
var spell_database: Dictionary = {}

## Summons tracking
var active_summons: Array[Node] = []

func _ready() -> void:
	_load_spell_database()
	# Auto-set owner_entity to parent if not configured
	if not owner_entity:
		var parent := get_parent()
		if parent is Node3D:
			owner_entity = parent as Node3D

func _process(delta: float) -> void:
	if is_casting and current_spell:
		cast_timer += delta
		if cast_timer >= current_spell.cast_time:
			_complete_cast()

func _load_spell_database() -> void:
	var spell_dir := "res://data/spells/"
	if not DirAccess.dir_exists_absolute(spell_dir):
		return

	var dir := DirAccess.open(spell_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var spell: SpellData = load(spell_dir + file_name)
			if spell:
				spell_database[spell.id] = spell
		file_name = dir.get_next()

## Start casting a spell
func start_cast(spell: SpellData, _target: Node = null) -> bool:
	if is_casting:
		return false

	# Check mana and stamina cost (2/3 mana, 1/3 stamina)
	var char_data := _get_character_data()
	var total_cost := spell.get_mana_cost()
	@warning_ignore("integer_division")
	var mana_cost := (total_cost * 2) / 3  # 2/3 from mana
	@warning_ignore("integer_division")
	var stamina_cost := total_cost / 3      # 1/3 from stamina
	if char_data and char_data.current_mana < mana_cost:
		return false
	if char_data and char_data.current_stamina < stamina_cost:
		return false

	# Check requirements (uses effective stats)
	if char_data:
		var player_know := char_data.get_effective_stat(Enums.Stat.KNOWLEDGE)
		var player_will := char_data.get_effective_stat(Enums.Stat.WILL)
		var player_arcana := char_data.get_skill(Enums.Skill.ARCANA_LORE)
		if player_know < spell.required_knowledge:
			return false
		if player_will < spell.required_will:
			return false
		if player_arcana < spell.required_arcana_lore:
			return false

	# Start cast
	current_spell = spell
	is_casting = true
	cast_timer = 0.0
	cast_charge = 0.0

	cast_started.emit(spell)

	# Play cast animation
	if owner_entity and owner_entity.has_node("AnimationPlayer"):
		var anim: AnimationPlayer = owner_entity.get_node("AnimationPlayer")
		if anim.has_animation(spell.cast_animation):
			anim.play(spell.cast_animation)

	# Play cast sound
	AudioManager.play_spell_cast(spell.school)

	# If instant cast (0 cast time), complete immediately
	if spell.cast_time <= 0:
		_complete_cast()

	return true

## Interrupt the current cast
func interrupt_cast() -> void:
	if not is_casting:
		return

	is_casting = false
	current_spell = null
	cast_timer = 0.0

	cast_interrupted.emit()

## Complete the cast and apply spell effects
func _complete_cast() -> void:
	if not current_spell:
		return

	var spell := current_spell
	is_casting = false
	current_spell = null
	cast_timer = 0.0

	# Consume mana (2/3) and stamina (1/3)
	var char_data := _get_character_data()
	if char_data:
		var total_cost := spell.get_mana_cost()
		@warning_ignore("integer_division")
		var mana_cost := (total_cost * 2) / 3  # 2/3 from mana
		@warning_ignore("integer_division")
		var stamina_cost := total_cost / 3      # 1/3 from stamina
		char_data.use_mana(mana_cost)
		char_data.use_stamina(stamina_cost)
		mana_consumed.emit(mana_cost, char_data.current_mana, char_data.max_mana)

	# Execute spell based on target type
	match spell.target_type:
		Enums.SpellTargetType.SELF:
			_cast_self_spell(spell)
		Enums.SpellTargetType.SINGLE_ENEMY:
			_cast_single_target_spell(spell, false)
		Enums.SpellTargetType.SINGLE_ALLY:
			_cast_single_target_spell(spell, true)
		Enums.SpellTargetType.PROJECTILE:
			_cast_projectile_spell(spell)
		Enums.SpellTargetType.AOE_POINT:
			_cast_aoe_spell(spell, _get_aim_point())
		Enums.SpellTargetType.AOE_SELF:
			_cast_aoe_spell(spell, owner_entity.global_position if owner_entity else Vector3.ZERO)
		Enums.SpellTargetType.CONE:
			_cast_cone_spell(spell)
		Enums.SpellTargetType.BEAM:
			_cast_beam_spell(spell)

	cast_completed.emit(spell)

## Self-targeted spell (buff/heal self)
func _cast_self_spell(spell: SpellData) -> void:
	if not owner_entity:
		return

	if spell.is_healing:
		CombatManager.apply_spell_damage(owner_entity, owner_entity, spell)
	else:
		# Apply buff or self-effect
		if spell.inflicts_condition != Enums.Condition.NONE:
			if owner_entity.has_method("apply_condition"):
				owner_entity.apply_condition(spell.inflicts_condition, spell.condition_duration)

## Single target spell
func _cast_single_target_spell(spell: SpellData, target_allies: bool) -> void:
	var target := _find_target(spell.range_distance, target_allies)
	if not target:
		return

	CombatManager.apply_spell_damage(owner_entity, target, spell)

## Projectile spell (Magic Missile, etc.)
func _cast_projectile_spell(spell: SpellData) -> void:
	var projectile_scene := _load_projectile_scene(spell)
	if not projectile_scene:
		# Fallback: instant hit on aimed target
		var target := _find_target(spell.range_distance, false)
		if target:
			CombatManager.apply_spell_damage(owner_entity, target, spell)
		return

	var projectile := projectile_scene.instantiate()
	if not projectile is SpellProjectile:
		projectile.queue_free()
		return

	# Get spawn position - need valid owner_entity
	if not owner_entity:
		projectile.queue_free()
		return

	var spawn_pos: Vector3
	if cast_origin and is_instance_valid(cast_origin):
		spawn_pos = cast_origin.global_position
	else:
		spawn_pos = owner_entity.global_position + Vector3(0, 1.5, 0)  # Chest height offset

	var direction := _get_aim_direction()

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_pos
	(projectile as SpellProjectile).initialize(
		spell,
		owner_entity,
		direction,
		spell.is_homing
	)

## AOE spell at point
func _cast_aoe_spell(spell: SpellData, center: Vector3) -> void:
	# Find all targets in radius
	var targets: Array[Node] = []
	if spell.is_healing:
		# For healing spells, target caster (and allies if we had them)
		if owner_entity:
			targets.append(owner_entity)
	else:
		# For damage spells, target enemies
		targets = CombatManager.get_enemies_in_range(center, spell.aoe_radius)

	for target in targets:
		CombatManager.apply_spell_damage(owner_entity, target, spell)

	# Spawn visual effect
	_spawn_aoe_effect(spell, center)

## Cone spell (Flame Burst)
func _cast_cone_spell(spell: SpellData) -> void:
	if not owner_entity:
		return

	var forward := _get_aim_direction()
	var origin := cast_origin.global_position if cast_origin else owner_entity.global_position

	# Find targets in cone
	var all_enemies := CombatManager.active_enemies
	var half_angle := deg_to_rad(spell.cone_angle / 2.0)

	for enemy in all_enemies:
		if not enemy is Node3D:
			continue

		var to_enemy := (enemy as Node3D).global_position - origin
		var distance := to_enemy.length()

		if distance > spell.range_distance:
			continue

		to_enemy = to_enemy.normalized()
		var angle := forward.angle_to(to_enemy)

		if angle <= half_angle:
			CombatManager.apply_spell_damage(owner_entity, enemy, spell)

	# Spawn cone effect
	_spawn_cone_effect(spell, origin, forward)

## Beam spell (Soul Drain)
func _cast_beam_spell(spell: SpellData) -> void:
	if not owner_entity:
		return

	# Use cast_origin if available, otherwise use chest height
	var origin: Vector3
	if cast_origin and is_instance_valid(cast_origin):
		origin = cast_origin.global_position
	else:
		origin = owner_entity.global_position + Vector3(0, 1.5, 0)  # Chest height
	var direction := _get_aim_direction()
	var end_point := origin + direction * spell.range_distance

	# Raycast along beam
	var space_state := owner_entity.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end_point)
	# Layer 3 (enemies body) = 4, Layer 7 (enemy_hurtbox) = 64
	query.collision_mask = 4 + 64
	query.exclude = [owner_entity]

	var result := space_state.intersect_ray(query)

	var hit_targets: Array[Node] = []
	if result:
		var target: Node = result.collider as Node
		if target.has_method("take_damage") or target.get_parent().has_method("take_damage"):
			var actual_target: Node = target if target.has_method("take_damage") else target.get_parent()
			CombatManager.apply_spell_damage(owner_entity, actual_target, spell)
			hit_targets.append(actual_target)

			# Chain to nearby enemies if spell has chain_targets
			if spell.chain_targets > 0 and actual_target is Node3D:
				var chain_origin: Vector3 = (actual_target as Node3D).global_position
				var nearby := CombatManager.get_enemies_in_range(chain_origin, spell.chain_range)
				var chains_left := spell.chain_targets
				for enemy in nearby:
					if chains_left <= 0:
						break
					if enemy in hit_targets:
						continue
					CombatManager.apply_spell_damage(owner_entity, enemy, spell)
					hit_targets.append(enemy)
					chains_left -= 1

	# Spawn beam effect
	_spawn_beam_effect(spell, origin, result.position if result else end_point)

## Summon spell
func cast_summon_spell(spell: SpellData) -> void:
	if spell.summon_scene_path.is_empty():
		return

	# Check summon limit
	_cleanup_dead_summons()
	if active_summons.size() >= spell.max_summons:
		# Remove oldest summon
		if active_summons.size() > 0:
			var oldest: Node = active_summons[0]
			active_summons.remove_at(0)
			if is_instance_valid(oldest):
				oldest.queue_free()

	var summon_scene := load(spell.summon_scene_path) as PackedScene
	if not summon_scene:
		return

	var summon := summon_scene.instantiate()
	var spawn_pos := owner_entity.global_position + _get_aim_direction() * 2.0

	owner_entity.get_tree().current_scene.add_child(summon)
	if summon is Node3D:
		(summon as Node3D).global_position = spawn_pos

	# Setup summon behavior
	if summon.has_method("set_master"):
		summon.set_master(owner_entity)
	if summon.has_method("set_leash_range"):
		summon.set_leash_range(spell.summon_leash_range)

	active_summons.append(summon)

	# Despawn after duration
	get_tree().create_timer(spell.summon_duration).timeout.connect(func():
		if is_instance_valid(summon):
			summon.queue_free()
		active_summons.erase(summon)
	)

func _cleanup_dead_summons() -> void:
	var alive: Array[Node] = []
	for summon in active_summons:
		if is_instance_valid(summon):
			alive.append(summon)
	active_summons = alive

## Helper: Find target
func _find_target(max_range: float, allies: bool) -> Node:
	if not owner_entity:
		return null
	if allies:
		# TODO: Find ally
		return owner_entity
	else:
		return CombatManager.get_closest_enemy(owner_entity.global_position, max_range)

## Helper: Get aim direction (uses camera-based aiming like ranged weapons)
func _get_aim_direction() -> Vector3:
	# Use camera-based aiming for accurate shooting toward crosshair
	var camera := owner_entity.get_viewport().get_camera_3d() if owner_entity else null
	if camera:
		var screen_center := owner_entity.get_viewport().get_visible_rect().size / 2
		var ray_origin := camera.project_ray_origin(screen_center)
		var ray_end := ray_origin + camera.project_ray_normal(screen_center) * 100.0

		# Raycast to find aim point
		var space_state := owner_entity.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [owner_entity]
		var result := space_state.intersect_ray(query)

		var target_point: Vector3
		if result:
			target_point = result.position
		else:
			target_point = ray_end

		# Get spawn position for direction calculation
		var spawn_pos: Vector3
		if cast_origin and is_instance_valid(cast_origin):
			spawn_pos = cast_origin.global_position
		else:
			spawn_pos = owner_entity.global_position + Vector3(0, 1.3, 0)

		return (target_point - spawn_pos).normalized()

	# Fallback to mesh direction if no camera
	if owner_entity and owner_entity.has_node("MeshRoot"):
		var mesh: Node3D = owner_entity.get_node("MeshRoot")
		return -mesh.global_transform.basis.z
	elif owner_entity:
		return -owner_entity.global_transform.basis.z
	return Vector3.FORWARD

## Helper: Get aim point
func _get_aim_point() -> Vector3:
	# Raycast from camera through crosshair
	var camera := owner_entity.get_viewport().get_camera_3d() if owner_entity else null
	if camera:
		var screen_center := owner_entity.get_viewport().get_visible_rect().size / 2
		var from := camera.project_ray_origin(screen_center)
		var to := from + camera.project_ray_normal(screen_center) * 100.0

		var space_state := owner_entity.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [owner_entity]

		var result := space_state.intersect_ray(query)
		if result:
			return result.position

	# Fallback: point in front
	return owner_entity.global_position + _get_aim_direction() * 10.0

## Helper: Load projectile scene
func _load_projectile_scene(spell: SpellData) -> PackedScene:
	if spell.projectile_scene_path.is_empty():
		return load("res://scenes/combat/default_projectile.tscn")
	return load(spell.projectile_scene_path)

## Helper: Get character data
func _get_character_data() -> CharacterData:
	if owner_entity and owner_entity.has_method("get_character_data"):
		return owner_entity.get_character_data()
	# Fallback to GameManager.player_data for player spellcaster
	if owner_entity and owner_entity.is_in_group("player"):
		return GameManager.player_data
	# Last fallback - just try GameManager directly
	return GameManager.player_data

## Visual effect spawning

func _spawn_aoe_effect(spell: SpellData, center: Vector3) -> void:
	# Create a simple expanding ring effect
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = spell.aoe_radius * 0.9
	torus.outer_radius = spell.aoe_radius
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_spell_color(spell)
	mat.emission_enabled = true
	mat.emission = _get_spell_color(spell)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	ring.material_override = mat

	get_tree().current_scene.add_child(ring)
	ring.global_position = center
	ring.rotation_degrees.x = 90  # Lay flat

	# Fade out and remove
	var tween := get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

func _spawn_cone_effect(_spell: SpellData, _origin: Vector3, _direction: Vector3) -> void:
	pass  # TODO: Implement cone visual

func _spawn_beam_effect(spell: SpellData, origin: Vector3, end: Vector3) -> void:
	var beam_length := origin.distance_to(end)
	if beam_length < 0.1:
		return  # No beam if too short

	# Create main beam (thick glowing core)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	var beam_width := maxf(spell.beam_width, 0.4)  # Minimum 0.4 width for visibility
	box.size = Vector3(beam_width, beam_width, beam_length)
	beam.mesh = box

	# Create bright glowing material
	var mat := StandardMaterial3D.new()
	var beam_color := _get_spell_color(spell)
	mat.albedo_color = beam_color
	mat.emission_enabled = true
	mat.emission = beam_color
	mat.emission_energy_multiplier = 5.0  # Very bright
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Full bright, no shadows
	beam.material_override = mat

	# Create outer glow (larger, more transparent)
	var glow := MeshInstance3D.new()
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(beam_width * 2.5, beam_width * 2.5, beam_length)
	glow.mesh = glow_box

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = beam_color
	glow_mat.albedo_color.a = 0.3
	glow_mat.emission_enabled = true
	glow_mat.emission = beam_color
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat

	# Add to scene
	get_tree().current_scene.add_child(beam)
	get_tree().current_scene.add_child(glow)

	# Position at midpoint and rotate to face end
	var midpoint := (origin + end) / 2.0
	beam.global_position = midpoint
	beam.look_at(end, Vector3.UP)
	glow.global_position = midpoint
	glow.look_at(end, Vector3.UP)

	# Fade out over 0.4 seconds (longer for visibility)
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(glow_mat, "albedo_color:a", 0.0, 0.4)
	tween.set_parallel(false)
	tween.tween_callback(beam.queue_free)
	tween.tween_callback(glow.queue_free)

	# Play zap sound for lightning
	if spell.damage_type == Enums.DamageType.LIGHTNING:
		AudioManager.play_sfx_3d("projectile_fire", origin)
	AudioManager.play_sfx_3d("projectile_hit", end)

## Get color based on spell damage type
func _get_spell_color(spell: SpellData) -> Color:
	match spell.damage_type:
		Enums.DamageType.FIRE:
			return Color(1.0, 0.4, 0.1)  # Orange-red
		Enums.DamageType.LIGHTNING:
			return Color(0.6, 0.8, 1.0)  # Electric blue-white
		Enums.DamageType.FROST:
			return Color(0.5, 0.8, 1.0)  # Ice blue
		Enums.DamageType.POISON:
			return Color(0.4, 0.8, 0.2)  # Toxic green
		Enums.DamageType.NECROTIC:
			return Color(0.5, 0.2, 0.6)  # Dark purple
		Enums.DamageType.HOLY:
			return Color(1.0, 0.95, 0.7)  # Golden white
		_:
			return Color(0.8, 0.6, 1.0)  # Default arcane purple

## Equip spell to quick slot
func equip_spell(spell: SpellData, slot: int) -> void:
	if slot >= 0 and slot < 4:
		equipped_spells[slot] = spell

## Learn a new spell
func learn_spell(spell: SpellData) -> bool:
	if spell in known_spells:
		return false
	known_spells.append(spell)
	return true

## Learn spell by ID
func learn_spell_by_id(spell_id: String) -> bool:
	if not spell_database.has(spell_id):
		return false
	return learn_spell(spell_database[spell_id])

## Cast equipped spell by slot
func cast_equipped_spell(slot: int, target: Node = null) -> bool:
	if slot < 0 or slot >= 4:
		return false
	if not equipped_spells[slot]:
		return false
	return start_cast(equipped_spells[slot], target)
