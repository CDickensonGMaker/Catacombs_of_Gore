## combat_manager.gd - Handles all combat calculations and damage processing
extends Node

signal damage_dealt(attacker: Node, target: Node, damage: int, damage_type: Enums.DamageType)
signal entity_killed(entity: Node, killer: Node)
signal condition_applied(target: Node, condition: Enums.Condition)
signal critical_hit(attacker: Node, target: Node)
signal horror_check_triggered(source: Node, target: Node, passed: bool)
signal humanoid_dialogue_requested(enemy: Node, group: Array)  ## Emitted when humanoid combat dialogue should open

## Active combatants tracking
var active_enemies: Array[Node] = []
var player: Node = null

## Damage number spawning (for UI)
var damage_number_scene: PackedScene = null

## Projectile pool for all projectiles in the game
var projectile_pool: ProjectilePool = null

## Cleanup timer for invalid enemies
var _cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 5.0

func _ready() -> void:
	# Try to load damage number scene if it exists
	if ResourceLoader.exists("res://scenes/ui/damage_number.tscn"):
		damage_number_scene = load("res://scenes/ui/damage_number.tscn")

	# Create and initialize the projectile pool
	projectile_pool = ProjectilePool.new()
	projectile_pool.name = "ProjectilePool"
	add_child(projectile_pool)

func _process(delta: float) -> void:
	# Periodically clean up invalid enemies to prevent iteration over freed nodes
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_cleanup_invalid_enemies()

	# Update horror check cooldowns
	update_horror_cooldowns(delta)

## Register player reference
func register_player(player_node: Node) -> void:
	player = player_node

## Register an enemy
func register_enemy(enemy: Node) -> void:
	if enemy not in active_enemies:
		active_enemies.append(enemy)

## Unregister an enemy
func unregister_enemy(enemy: Node) -> void:
	active_enemies.erase(enemy)

## Calculate and apply melee damage
## Returns actual damage dealt
func apply_melee_damage(
	attacker: Node,
	target: Node,
	weapon: WeaponData,
	quality: Enums.ItemQuality,
	is_heavy_attack: bool = false,
	is_backstab: bool = false
) -> int:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0

	# Get attacker stats
	var attacker_grit: int = 0
	var attacker_melee_skill: int = 0
	var attacker_data: CharacterData = null

	if attacker.has_method("get_character_data"):
		attacker_data = attacker.get_character_data()
		attacker_grit = attacker_data.get_effective_stat(Enums.Stat.GRIT)
		attacker_melee_skill = attacker_data.get_skill(Enums.Skill.MELEE)

	# Roll base weapon damage
	var base_damage: int = weapon.roll_damage(quality)

	# Apply damage formula: Base × (1 + Grit/10 + Melee/20)
	var damage_multiplier: float = 1.0 + (attacker_grit / 10.0) + (attacker_melee_skill / 20.0)
	var total_damage: int = int(base_damage * damage_multiplier)

	# Heavy attack bonus (+50%)
	if is_heavy_attack:
		total_damage = int(total_damage * 1.5)

	# Backstab bonus (Stealth skill based)
	if is_backstab and attacker_data:
		var stealth_skill: int = attacker_data.get_skill(Enums.Skill.STEALTH)
		var backstab_mult: float = 1.5 + (stealth_skill * 0.1)  # 1.5x to 2.5x
		total_damage = int(total_damage * backstab_mult)

	# Critical hit check
	var crit_chance: float = weapon.crit_chance
	if attacker_data:
		crit_chance += attacker_data.get_skill(Enums.Skill.MELEE) * 0.01
	if randf() < crit_chance:
		total_damage = int(total_damage * weapon.crit_multiplier)
		critical_hit.emit(attacker, target)

	# Apply armor reduction
	var target_av: int = _get_target_armor(target)
	var armor_pierce: float = weapon.armor_pierce
	var effective_av: float = target_av * (1.0 - armor_pierce)
	total_damage = _reduce_by_armor(total_damage, effective_av)

	# Apply damage type resistance/weakness
	total_damage = _apply_damage_type_modifier(total_damage, weapon.damage_type, target)

	# Ensure minimum 1 damage
	total_damage = max(1, total_damage)

	# Apply the damage
	var actual_damage: int = target.take_damage(total_damage, weapon.damage_type, attacker)

	# Handle secondary damage (elemental)
	var secondary: int = weapon.roll_secondary_damage(quality)
	if secondary > 0:
		secondary = _apply_damage_type_modifier(secondary, weapon.secondary_damage_type, target)
		target.take_damage(secondary, weapon.secondary_damage_type, attacker)
		actual_damage += secondary

	# Apply condition if weapon inflicts one
	if weapon.inflicts_condition != Enums.Condition.NONE:
		if randf() < weapon.condition_chance:
			apply_condition(target, weapon.inflicts_condition, weapon.condition_duration)

	# Handle lifesteal
	if weapon.lifesteal_percent > 0 and attacker.has_method("heal"):
		var lifesteal_amount: int = int(actual_damage * weapon.lifesteal_percent)
		attacker.heal(lifesteal_amount)

	# Handle stagger
	if weapon.stagger_power > 0 and target.has_method("apply_stagger"):
		target.apply_stagger(weapon.stagger_power)

	# Emit signal
	damage_dealt.emit(attacker, target, actual_damage, weapon.damage_type)

	# Degrade attacker's weapon if it's the player
	if attacker.is_in_group("player"):
		InventoryManager.degrade_weapon(1)

	# Degrade target's armor if it's the player
	if target.is_in_group("player"):
		var degrade_amount: int = maxi(1, actual_damage / 10)
		InventoryManager.degrade_armor(degrade_amount)

	# Spawn damage number
	_spawn_damage_number(target, actual_damage, weapon.damage_type)

	# Check for kill
	if target.has_method("is_dead") and target.is_dead():
		entity_killed.emit(target, attacker)
		_handle_kill_rewards(attacker, target)

	return actual_damage

## Calculate and apply ranged damage
func apply_ranged_damage(
	attacker: Node,
	target: Node,
	weapon: WeaponData,
	quality: Enums.ItemQuality,
	distance: float = 0.0
) -> int:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0

	# Get attacker stats
	var attacker_agility: int = 0
	var attacker_ranged_skill: int = 0
	var attacker_data: CharacterData = null

	if attacker.has_method("get_character_data"):
		attacker_data = attacker.get_character_data()
		attacker_agility = attacker_data.get_effective_stat(Enums.Stat.AGILITY)
		attacker_ranged_skill = attacker_data.get_skill(Enums.Skill.RANGED)

	# Roll base damage
	var base_damage: int = weapon.roll_damage(quality)

	# Apply damage formula for ranged
	var damage_multiplier: float = 1.0 + (attacker_agility / 15.0) + (attacker_ranged_skill / 20.0)
	var total_damage: int = int(base_damage * damage_multiplier)

	# Distance falloff (optional, for realism)
	if distance > weapon.max_range * 0.75:
		var falloff: float = 1.0 - ((distance - weapon.max_range * 0.75) / (weapon.max_range * 0.25))
		total_damage = int(total_damage * max(0.5, falloff))

	# Critical hit
	var crit_chance: float = weapon.crit_chance + (attacker_ranged_skill * 0.02)
	if randf() < crit_chance:
		total_damage = int(total_damage * weapon.crit_multiplier)
		critical_hit.emit(attacker, target)

	# Armor reduction
	var target_av: int = _get_target_armor(target)
	total_damage = _reduce_by_armor(total_damage, target_av * (1.0 - weapon.armor_pierce))

	# Damage type
	total_damage = _apply_damage_type_modifier(total_damage, weapon.damage_type, target)
	total_damage = max(1, total_damage)

	# Apply damage
	var actual_damage: int = target.take_damage(total_damage, weapon.damage_type, attacker)

	# Conditions
	if weapon.inflicts_condition != Enums.Condition.NONE:
		if randf() < weapon.condition_chance:
			apply_condition(target, weapon.inflicts_condition, weapon.condition_duration)

	damage_dealt.emit(attacker, target, actual_damage, weapon.damage_type)
	_spawn_damage_number(target, actual_damage, weapon.damage_type)

	if target.has_method("is_dead") and target.is_dead():
		entity_killed.emit(target, attacker)
		_handle_kill_rewards(attacker, target)

	return actual_damage

## Apply spell damage
func apply_spell_damage(
	caster: Node,
	target: Node,
	spell: SpellData,
	charged_multiplier: float = 1.0
) -> int:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0

	# Get caster stats
	var caster_knowledge: int = 0
	var caster_arcana: int = 0

	if is_instance_valid(caster) and caster.has_method("get_character_data"):
		var caster_data: CharacterData = caster.get_character_data()
		if caster_data:
			caster_knowledge = caster_data.get_effective_stat(Enums.Stat.KNOWLEDGE)
			caster_arcana = caster_data.get_skill(Enums.Skill.ARCANA_LORE)

	# Roll spell effect
	var base_effect: int = spell.roll_effect(caster_knowledge, caster_arcana)
	var total_damage: int = int(base_effect * charged_multiplier)

	# For healing spells
	if spell.is_healing:
		if target.has_method("heal"):
			var actual_heal: int = target.heal(total_damage)
			_spawn_damage_number(target, actual_heal, spell.damage_type, true)
			return actual_heal
		return 0

	# Apply damage type modifier
	total_damage = _apply_damage_type_modifier(total_damage, spell.damage_type, target)

	# Magic resistance (from target's Will + RESIST skill)
	var magic_resist: float = 0.0
	if target.has_method("get_character_data"):
		var target_data: CharacterData = target.get_character_data()
		if target_data:
			magic_resist = target_data.get_magic_resistance()
	total_damage = int(total_damage * (1.0 - magic_resist))

	total_damage = max(1, total_damage)

	# Apply damage
	var actual_damage: int = target.take_damage(total_damage, spell.damage_type, caster)

	# Conditions
	if spell.inflicts_condition != Enums.Condition.NONE:
		if randf() < spell.condition_chance:
			apply_condition(target, spell.inflicts_condition, spell.condition_duration)

	# Lifesteal (Soul Drain)
	if spell.lifesteal_percent > 0 and caster.has_method("heal"):
		var lifesteal: int = int(actual_damage * spell.lifesteal_percent)
		caster.heal(lifesteal)

	# Manasteal (Soul Drain) - restore mana based on damage dealt
	if spell.manasteal_percent > 0:
		var manasteal: int = int(actual_damage * spell.manasteal_percent)
		if manasteal > 0:
			# Try to restore mana via CharacterData
			if caster.is_in_group("player") and GameManager.player_data:
				GameManager.player_data.restore_mana(manasteal)
			elif caster.has_method("restore_mana"):
				caster.restore_mana(manasteal)

	damage_dealt.emit(caster, target, actual_damage, spell.damage_type)
	_spawn_damage_number(target, actual_damage, spell.damage_type)

	if target.has_method("is_dead") and target.is_dead():
		entity_killed.emit(target, caster)
		_handle_kill_rewards(caster, target)

	return actual_damage

## Apply DOT damage tick
func apply_dot_damage(target: Node, damage: int, damage_type: Enums.DamageType, source: Node = null) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	var actual_damage: int = target.take_damage(damage, damage_type, source)
	_spawn_damage_number(target, actual_damage, damage_type)

	if target.has_method("is_dead") and target.is_dead():
		entity_killed.emit(target, source)
		if source:
			_handle_kill_rewards(source, target)

## Apply a condition to a target
func apply_condition(target: Node, condition: Enums.Condition, duration: float) -> void:
	if not is_instance_valid(target):
		return

	if target.has_method("apply_condition"):
		target.apply_condition(condition, duration)
		condition_applied.emit(target, condition)

## Horror check cooldown tracking (passive system - no popup)
var _horror_check_cooldowns: Dictionary = {}  # source_id -> cooldown_remaining
const HORROR_CHECK_COOLDOWN := 60.0  # Seconds between horror checks from same source
const HORROR_CHECK_CHANCE := 0.25    # 25% chance to even trigger a check

## Update horror check cooldowns each frame (call from _process)
func update_horror_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for source_id in _horror_check_cooldowns:
		_horror_check_cooldowns[source_id] -= delta
		if _horror_check_cooldowns[source_id] <= 0:
			to_remove.append(source_id)
	for source_id in to_remove:
		_horror_check_cooldowns.erase(source_id)

## Trigger horror check - PASSIVE (no popup, silent roll with game log)
func trigger_horror_check(source: Node, target: Node, difficulty: int) -> bool:
	if not target.has_method("get_character_data"):
		return true  # Non-character entities auto-pass

	# Check cooldown from this source
	var source_id: int = source.get_instance_id()
	if _horror_check_cooldowns.has(source_id):
		return true  # On cooldown, auto-pass silently

	# Random chance to even trigger (reduce frequency)
	if randf() > HORROR_CHECK_CHANCE:
		return true  # Lucky - no horror check this time

	# Set cooldown for this source
	_horror_check_cooldowns[source_id] = HORROR_CHECK_COOLDOWN

	var target_data: CharacterData = target.get_character_data()
	var will_score: int = target_data.get_effective_stat(Enums.Stat.WILL)
	var bravery_skill: int = target_data.get_skill(Enums.Skill.BRAVERY)

	# Silent roll - no popup (game uses d10 system)
	var roll_result: Dictionary = DiceManager.roll_d10()
	var roll: int = roll_result.d10_roll
	var modifier: int = will_score + bravery_skill
	var total: int = roll + modifier
	var passed: bool = total >= difficulty or roll_result.is_crit

	horror_check_triggered.emit(source, target, passed)

	# Log result to game log (not popup)
	var hud := target.get_tree().get_first_node_in_group("hud")
	var source_name: String = ""
	if "display_name" in source:
		source_name = str(source.get("display_name"))
	elif source.has_method("get_enemy_data"):
		var data = source.get_enemy_data()
		if data:
			source_name = data.display_name

	if hud and hud.has_method("add_game_log_entry"):
		if passed:
			hud.add_game_log_entry("Resisted horror from %s" % source_name)
		else:
			hud.add_game_log_entry("Horrified by %s!" % source_name)

	if passed:
		# Fearless Inspiration: +1d6 damage for 10 seconds
		if target.has_method("apply_buff"):
			target.apply_buff("fearless_inspiration", 10.0)
	else:
		# Apply Horrified condition
		apply_condition(target, Enums.Condition.HORRIFIED, 5.0)

	return passed

## Humanoid dialogue system - allows peaceful resolution with Human/Elf/Dwarf enemies
## Reference to the humanoid dialogue UI (created lazily)
var _humanoid_dialogue: HumanoidDialogue = null
var _humanoid_dialogue_pending: bool = false
var _pending_humanoid_enemy: EnemyBase = null
var _pending_humanoid_group: Array[EnemyBase] = []

## Check if humanoid dialogue should trigger for this enemy
## Returns true if dialogue was triggered (enemy should wait for result)
func check_humanoid_dialogue(enemy: EnemyBase) -> bool:
	if not enemy or not enemy.enemy_data:
		return false

	# Only HUMAN_BANDIT faction can be reasoned with
	if enemy.enemy_data.faction != Enums.Faction.HUMAN_BANDIT:
		return false

	# Already dealt with (bribed, intimidated, etc.)
	if enemy.is_intimidated or enemy.intimidation_cooldown > 0:
		return false

	# Don't trigger if dialogue is already open
	if _humanoid_dialogue_pending:
		return false

	# Find all nearby enemies in the same group (same faction, within 15m)
	var group: Array[EnemyBase] = _find_humanoid_group(enemy)

	# Trigger the dialogue
	_trigger_humanoid_dialogue(enemy, group)
	return true

## Find all humanoid enemies in the same group as the given enemy
func _find_humanoid_group(lead_enemy: EnemyBase) -> Array[EnemyBase]:
	var group: Array[EnemyBase] = [lead_enemy]
	var group_radius := 15.0

	for enemy_node in active_enemies:
		if not is_instance_valid(enemy_node) or enemy_node == lead_enemy:
			continue

		var enemy := enemy_node as EnemyBase
		if not enemy or not enemy.enemy_data:
			continue

		# Same faction
		if enemy.enemy_data.faction != lead_enemy.enemy_data.faction:
			continue

		# Within group radius
		var dist := lead_enemy.global_position.distance_to(enemy.global_position)
		if dist <= group_radius:
			group.append(enemy)

	return group

## Trigger the humanoid dialogue UI
func _trigger_humanoid_dialogue(enemy: EnemyBase, group: Array[EnemyBase]) -> void:
	_humanoid_dialogue_pending = true
	_pending_humanoid_enemy = enemy
	_pending_humanoid_group = group

	# Pause all enemies in group (they wait for dialogue result)
	for e in group:
		if is_instance_valid(e):
			e._change_state(EnemyBase.AIState.IDLE)

	# Create dialogue UI if needed
	if not _humanoid_dialogue:
		_humanoid_dialogue = HumanoidDialogue.new()
		_humanoid_dialogue.dialogue_closed.connect(_on_humanoid_dialogue_closed)
		# Add to scene tree (will be moved to proper canvas layer)
		get_tree().root.add_child(_humanoid_dialogue)

	# Open dialogue
	_humanoid_dialogue.open(enemy, group)

	# Emit signal for any listeners
	humanoid_dialogue_requested.emit(enemy, group)

## Handle humanoid dialogue result
func _on_humanoid_dialogue_closed(result: HumanoidDialogue.DialogueResult) -> void:
	_humanoid_dialogue_pending = false

	match result:
		HumanoidDialogue.DialogueResult.FIGHT, \
		HumanoidDialogue.DialogueResult.NEGOTIATE_FAIL, \
		HumanoidDialogue.DialogueResult.INTIMIDATE_FAIL, \
		HumanoidDialogue.DialogueResult.CANCELLED:
			# Combat resumes - enemies chase player
			for enemy in _pending_humanoid_group:
				if is_instance_valid(enemy) and not enemy.is_dead():
					enemy._change_state(EnemyBase.AIState.CHASE)

		HumanoidDialogue.DialogueResult.BRIBE_SUCCESS, \
		HumanoidDialogue.DialogueResult.NEGOTIATE_SUCCESS, \
		HumanoidDialogue.DialogueResult.INTIMIDATE_SUCCESS:
			# Enemies already set to disengage in dialogue handler
			pass

	_pending_humanoid_enemy = null
	_pending_humanoid_group.clear()

## Get target's armor value
func _get_target_armor(target: Node) -> int:
	if target.has_method("get_armor_value"):
		return target.get_armor_value()
	return 0

## Reduce damage by armor
## Using a simple reduction formula: damage * (100 / (100 + AV))
func _reduce_by_armor(damage: int, armor_value: float) -> int:
	# Clamp armor to prevent division by zero (armor can't go below -99)
	armor_value = maxf(armor_value, -99.0)
	var reduction: float = 100.0 / (100.0 + armor_value)
	return int(damage * reduction)

## Apply damage type resistances/weaknesses
func _apply_damage_type_modifier(damage: int, damage_type: Enums.DamageType, target: Node) -> int:
	if not target.has_method("get_damage_type_multiplier"):
		return damage

	var multiplier: float = target.get_damage_type_multiplier(damage_type)
	return int(damage * multiplier)

## Handle kill rewards (XP, etc.)
func _handle_kill_rewards(killer: Node, killed: Node) -> void:
	if not killer.has_method("get_character_data"):
		return

	var killer_data: CharacterData = killer.get_character_data()
	var xp_reward: int = 100  # Default

	if killed.has_method("get_xp_reward"):
		xp_reward = killed.get_xp_reward()

	# Apply Knowledge XP bonus
	var xp_mult: float = killer_data.get_xp_multiplier()
	xp_reward = int(xp_reward * xp_mult)

	killer_data.add_ip(xp_reward)

## Spawn floating damage number
func _spawn_damage_number(target: Node, damage: int, _type: Enums.DamageType, is_heal: bool = false) -> void:
	if not damage_number_scene:
		return

	if not target is Node3D:
		return

	var dmg_num: Node = damage_number_scene.instantiate()

	# Get the 3D world position above the target
	var world_pos: Vector3 = (target as Node3D).global_position + Vector3.UP * 2.0

	# Convert 3D position to 2D screen position
	var camera := target.get_viewport().get_camera_3d()
	if not camera:
		dmg_num.queue_free()
		return

	# Check if position is behind camera
	if not camera.is_position_behind(world_pos):
		var screen_pos: Vector2 = camera.unproject_position(world_pos)

		# Add to CanvasLayer or current scene
		target.get_tree().current_scene.add_child(dmg_num)

		# Set 2D position (Control uses Vector2)
		if dmg_num is Control:
			(dmg_num as Control).global_position = screen_pos
		elif dmg_num is Node2D:
			(dmg_num as Node2D).global_position = screen_pos

		if dmg_num.has_method("setup"):
			dmg_num.setup(damage, is_heal)
	else:
		dmg_num.queue_free()

## Get all enemies in range of a point
func get_enemies_in_range(point: Vector3, range_dist: float) -> Array[Node]:
	var result: Array[Node] = []
	_cleanup_invalid_enemies()
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node3D:
			var dist: float = (enemy as Node3D).global_position.distance_to(point)
			if dist <= range_dist:
				result.append(enemy)
	return result

## Remove any invalid/freed enemies from tracking array
func _cleanup_invalid_enemies() -> void:
	var valid_enemies: Array[Node] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	active_enemies = valid_enemies

## Get closest enemy to a point
func get_closest_enemy(point: Vector3, max_range: float = 100.0) -> Node:
	var closest: Node = null
	var closest_dist: float = max_range

	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node3D:
			var dist: float = (enemy as Node3D).global_position.distance_to(point)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy

	return closest

## Check line of sight between two nodes
func has_line_of_sight(from_node: Node3D, to_node: Node3D) -> bool:
	var space_state: PhysicsDirectSpaceState3D = from_node.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_node.global_position + Vector3.UP,
		to_node.global_position + Vector3.UP,
		1  # World collision layer
	)
	query.exclude = [from_node, to_node]
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

## Spawn a projectile from the pool
func spawn_projectile(data: ProjectileData, source: Node, spawn_position: Vector3, direction: Vector3, target: Node3D = null) -> ProjectileBase:
	if not projectile_pool:
		push_warning("[CombatManager] Projectile pool not initialized!")
		return null
	return projectile_pool.spawn(data, source, spawn_position, direction, target)

## Spawn a projectile aimed at a specific position
func spawn_projectile_at_target(data: ProjectileData, source: Node, spawn_position: Vector3, target_position: Vector3, target: Node3D = null) -> ProjectileBase:
	if not projectile_pool:
		push_warning("[CombatManager] Projectile pool not initialized!")
		return null
	return projectile_pool.spawn_at_target(data, source, spawn_position, target_position, target)

## Get projectile pool stats for debugging
func get_projectile_stats() -> Dictionary:
	if not projectile_pool:
		return {}
	return projectile_pool.get_stats()

## Clear all active projectiles (useful for scene transitions)
func clear_all_projectiles() -> void:
	if projectile_pool:
		projectile_pool.clear_all()
