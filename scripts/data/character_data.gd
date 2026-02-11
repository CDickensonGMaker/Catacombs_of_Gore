## character_data.gd - Player/NPC character statistics and progression
class_name CharacterData
extends Resource

## Signals for UI updates
signal hp_changed(old_hp: int, new_hp: int, max_hp: int)
signal stamina_changed(old_stamina: int, new_stamina: int, max_stamina: int)
signal mana_changed(old_mana: int, new_mana: int, max_mana: int)
signal condition_applied(condition: Enums.Condition)
signal condition_removed(condition: Enums.Condition)
signal stat_changed(stat: Enums.Stat, old_value: int, new_value: int)
signal skill_changed(skill: Enums.Skill, old_value: int, new_value: int)
signal level_up(new_level: int)
signal ip_gained(amount: int)

## Character identity
@export var character_name: String = "Unnamed"
@export var race: Enums.Race = Enums.Race.HUMAN
@export var career: Enums.Career = Enums.Career.FARMER

## Core attributes (1-10 scale, starting around 3-5)
@export var grit: int = 3       # Melee damage, stagger resistance
@export var agility: int = 3    # Movement, dodge, attack speed
@export var will: int = 3       # Spell slots, magic resistance
@export var speech: int = 3     # Shop prices, dialogue
@export var knowledge: int = 3  # Spell power, crafting, XP bonus
@export var vitality: int = 3   # Max HP, HP regen

## Derived stats
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_stamina: int = 100
@export var current_stamina: int = 100
@export var max_mana: int = 50
@export var current_mana: int = 50
@export var max_spell_slots: int = 5
@export var current_spell_slots: int = 5

## Progression
@export var level: int = 1
@export var improvement_points: int = 0  # XP/IP for buying skills/stats
@export var total_ip_earned: int = 0     # Total IP ever earned (for level calculation)

## Level thresholds - level is based on total IP earned (not spent)
const IP_PER_LEVEL: Array[int] = [0, 100, 300, 600, 1000, 1500, 2500, 4000, 6000, 9000, 13000, 18000, 25000]

## Note: XP costs for stats now use Enums.get_stat_xp_cost() - unified with skill costs

## Skills dictionary (Enums.Skill -> level 0-10)
var skills: Dictionary = {}

## Active conditions dictionary (Enums.Condition -> time_remaining)
var conditions: Dictionary = {}

func _init() -> void:
	# Initialize all skills to 0
	for skill in Enums.Skill.values():
		skills[skill] = 0

## Get a skill level
func get_skill(skill: Enums.Skill) -> int:
	if skills.has(skill):
		return skills[skill]
	return 0

## Set a skill level
func set_skill(skill: Enums.Skill, new_level: int) -> void:
	var old_level: int = skills.get(skill, 0)
	skills[skill] = clamp(new_level, 0, 10)
	if skills[skill] != old_level:
		skill_changed.emit(skill, old_level, skills[skill])

## Increase a skill by 1 (if IP available)
func increase_skill(skill: Enums.Skill) -> bool:
	var current_level: int = get_skill(skill)
	if current_level >= 10:
		return false

	var cost: int = Enums.get_skill_ip_cost(current_level + 1)
	if improvement_points < cost:
		return false

	improvement_points -= cost
	skills[skill] = current_level + 1
	skill_changed.emit(skill, current_level, current_level + 1)
	return true

## Get XP cost to increase a stat from current value
func get_stat_ip_cost(current_value: int) -> int:
	# Stats start at 3, level = current_value - 2 (so stat 3->4 is level 1, stat 4->5 is level 2, etc.)
	var level := current_value - 2
	if level < 1:
		return Enums.XP_COSTS[0]  # Minimum cost to reach baseline
	if level > 10:
		return 200000  # Very expensive for stats beyond 12
	return Enums.get_stat_xp_cost(level)

## Increase a stat by 1 (if IP available)
func increase_stat(stat: Enums.Stat) -> bool:
	var current_value := get_stat(stat)
	if current_value >= 15:  # Max stat cap
		return false

	var cost := get_stat_ip_cost(current_value)
	if improvement_points < cost:
		return false

	improvement_points -= cost
	set_stat(stat, current_value + 1)
	recalculate_derived_stats()
	return true

## Add improvement points (XP)
func add_ip(amount: int) -> void:
	improvement_points += amount
	total_ip_earned += amount
	ip_gained.emit(amount)
	_check_level_up()

## Check if player should level up based on total IP earned
func _check_level_up() -> void:
	var new_level := 1
	for i in range(IP_PER_LEVEL.size()):
		if total_ip_earned >= IP_PER_LEVEL[i]:
			new_level = i + 1
	if new_level > level:
		level = new_level
		level_up.emit(level)

## Get XP multiplier based on Knowledge
func get_xp_multiplier() -> float:
	# +5% XP per Knowledge point (uses effective stat)
	return 1.0 + (get_effective_stat(Enums.Stat.KNOWLEDGE) * 0.05)

## Get base stat value by enum (without equipment bonuses)
func get_stat(stat: Enums.Stat) -> int:
	match stat:
		Enums.Stat.GRIT: return grit
		Enums.Stat.AGILITY: return agility
		Enums.Stat.WILL: return will
		Enums.Stat.SPEECH: return speech
		Enums.Stat.KNOWLEDGE: return knowledge
		Enums.Stat.VITALITY: return vitality
	return 0

## Get effective stat value (base + equipment bonuses)
func get_effective_stat(stat: Enums.Stat) -> int:
	var base_value := get_stat(stat)
	var stat_name: String
	match stat:
		Enums.Stat.GRIT: stat_name = "grit"
		Enums.Stat.AGILITY: stat_name = "agility"
		Enums.Stat.WILL: stat_name = "will"
		Enums.Stat.SPEECH: stat_name = "speech"
		Enums.Stat.KNOWLEDGE: stat_name = "knowledge"
		Enums.Stat.VITALITY: stat_name = "vitality"
		_: return base_value
	return base_value + InventoryManager.get_equipment_stat_bonus(stat_name)

## Set stat value by enum
func set_stat(stat: Enums.Stat, value: int) -> void:
	var old_value := get_stat(stat)
	match stat:
		Enums.Stat.GRIT: grit = value
		Enums.Stat.AGILITY: agility = value
		Enums.Stat.WILL: will = value
		Enums.Stat.SPEECH: speech = value
		Enums.Stat.KNOWLEDGE: knowledge = value
		Enums.Stat.VITALITY: vitality = value
	if value != old_value:
		stat_changed.emit(stat, old_value, value)

## Initialize racial bonuses
func initialize_race_bonuses() -> void:
	match race:
		Enums.Race.HUMAN:
			# Versatile - +1d4 to Grit, Will, Speech
			grit += randi_range(1, 4)
			will += randi_range(1, 4)
			speech += randi_range(1, 4)
		Enums.Race.ELF:
			# Graceful - +2+1d4 to Vitality, Will, Speech
			vitality += 2 + randi_range(1, 4)
			will += 2 + randi_range(1, 4)
			speech += 2 + randi_range(1, 4)
		Enums.Race.HALFLING:
			# Quick and cunning - +1+1d4 to Agility, Speech, Knowledge
			agility += 1 + randi_range(1, 4)
			speech += 1 + randi_range(1, 4)
			knowledge += 1 + randi_range(1, 4)
		Enums.Race.DWARF:
			# Tough and stubborn - +3+1d4 to Grit, Knowledge, Vitality
			grit += 3 + randi_range(1, 4)
			knowledge += 3 + randi_range(1, 4)
			vitality += 3 + randi_range(1, 4)

## Initialize career starting skills
func initialize_career() -> void:
	match career:
		Enums.Career.APPRENTICE:
			skills[Enums.Skill.ARCANA_LORE] = 2
			skills[Enums.Skill.HISTORY] = 1
		Enums.Career.FARMER:
			skills[Enums.Skill.ENDURANCE] = 2
			skills[Enums.Skill.SURVIVAL] = 1
		Enums.Career.GRAVE_DIGGER:
			skills[Enums.Skill.ENDURANCE] = 1
			skills[Enums.Skill.RELIGION] = 1
			skills[Enums.Skill.BRAVERY] = 1
		Enums.Career.SCOUT:
			skills[Enums.Skill.PERCEPTION] = 2
			skills[Enums.Skill.STEALTH] = 1
		Enums.Career.SOLDIER:
			skills[Enums.Skill.MELEE] = 2
			skills[Enums.Skill.ATHLETICS] = 1
		Enums.Career.MERCHANT:
			skills[Enums.Skill.PERSUASION] = 2
			skills[Enums.Skill.DECEPTION] = 1
		Enums.Career.PRIEST:
			skills[Enums.Skill.RELIGION] = 2
			skills[Enums.Skill.FIRST_AID] = 1
		Enums.Career.THIEF:
			skills[Enums.Skill.STEALTH] = 2
			skills[Enums.Skill.LOCKPICKING] = 1

## Recalculate derived stats based on attributes (uses effective stats)
func recalculate_derived_stats() -> void:
	var eff_vitality := get_effective_stat(Enums.Stat.VITALITY)
	var eff_grit := get_effective_stat(Enums.Stat.GRIT)
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var eff_will := get_effective_stat(Enums.Stat.WILL)
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)

	# Skill bonuses
	var endurance_skill := get_skill(Enums.Skill.ENDURANCE)
	var concentration_skill := get_skill(Enums.Skill.CONCENTRATION)

	# Max HP = 50 + (Vitality * 10) + (Grit * 5)
	max_hp = 50 + (eff_vitality * 10) + (eff_grit * 5)

	# Max Stamina = 50 + (Agility * 5) + (Vitality * 5) + (Endurance * 10)
	# ENDURANCE: +10 max stamina per level
	max_stamina = 50 + (eff_agility * 5) + (eff_vitality * 5) + (endurance_skill * 10)

	# Max Mana = 20 + (Will * 10) + (Knowledge * 5) + (Concentration * 8)
	# CONCENTRATION: +8 max mana per level
	max_mana = 20 + (eff_will * 10) + (eff_knowledge * 5) + (concentration_skill * 8)

## Heal HP
func heal(amount: int) -> int:
	var old_hp: int = current_hp
	current_hp = min(current_hp + amount, max_hp)
	if current_hp != old_hp:
		hp_changed.emit(old_hp, current_hp, max_hp)
	return current_hp - old_hp

## Take damage (returns actual damage taken)
func take_damage(amount: int) -> int:
	var old_hp: int = current_hp
	current_hp = max(current_hp - amount, 0)
	if current_hp != old_hp:
		hp_changed.emit(old_hp, current_hp, max_hp)
	return old_hp - current_hp

## Check if dead
func is_dead() -> bool:
	return current_hp <= 0

## Restore stamina
func restore_stamina(amount: int) -> void:
	var old_stamina := current_stamina
	current_stamina = min(current_stamina + amount, max_stamina)
	if current_stamina != old_stamina:
		stamina_changed.emit(old_stamina, current_stamina, max_stamina)

## Use stamina (returns true if had enough)
func use_stamina(amount: int) -> bool:
	if current_stamina >= amount:
		var old_stamina := current_stamina
		current_stamina -= amount
		stamina_changed.emit(old_stamina, current_stamina, max_stamina)
		return true
	return false

## Restore mana
func restore_mana(amount: int) -> void:
	var old_mana := current_mana
	current_mana = min(current_mana + amount, max_mana)
	if current_mana != old_mana:
		mana_changed.emit(old_mana, current_mana, max_mana)

## Use mana (returns true if had enough)
func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		var old_mana := current_mana
		current_mana -= amount
		mana_changed.emit(old_mana, current_mana, max_mana)
		return true
	return false

## Use spell slots (returns true if had enough)
func use_spell_slots(amount: int) -> bool:
	if current_spell_slots >= amount:
		current_spell_slots -= amount
		return true
	return false

## Restore spell slots
func restore_spell_slots(amount: int) -> void:
	current_spell_slots = min(current_spell_slots + amount, max_spell_slots)

## Get movement speed multiplier based on Agility (uses effective stat)
func get_movement_multiplier() -> float:
	return 1.0 + (get_effective_stat(Enums.Stat.AGILITY) * 0.05)

## Get attack speed multiplier (uses effective stat)
func get_attack_speed_multiplier() -> float:
	return 1.0 + (get_effective_stat(Enums.Stat.AGILITY) * 0.03)

## Get magic resistance (0.0 to ~0.5) (uses effective stat + RESIST skill)
## RESIST: +3% magic resistance per level (stacks with Will's 2% per point)
func get_magic_resistance() -> float:
	var will_resist := get_effective_stat(Enums.Stat.WILL) * 0.02
	var skill_resist := get_skill(Enums.Skill.RESIST) * 0.03
	return minf(will_resist + skill_resist, 0.75)  # Cap at 75% resistance

## Get stamina drain multiplier based on ENDURANCE skill
## ENDURANCE: -5% stamina consumption per level (up to 50% reduction at level 10)
func get_stamina_drain_multiplier() -> float:
	var endurance_skill := get_skill(Enums.Skill.ENDURANCE)
	return maxf(0.5, 1.0 - (endurance_skill * 0.05))

## Get HP regen per second (zero - recover via potions/rest only)
func get_hp_regen() -> float:
	return 0.0

## Get stamina regen per second (slow passive regen for movement) (uses effective stat)
func get_stamina_regen() -> float:
	return 2.0 + (get_effective_stat(Enums.Stat.AGILITY) * 0.2)

## Get mana regen per second (uses effective stats)
## Same rate as stamina regen, but scales with Will instead of Agility
func get_mana_regen() -> float:
	return 2.0 + (get_effective_stat(Enums.Stat.WILL) * 0.2)

## Apply a condition with duration
func apply_condition(condition: Enums.Condition, duration: float) -> void:
	conditions[condition] = duration
	condition_applied.emit(condition)

## Remove a condition
func remove_condition(condition: Enums.Condition) -> void:
	if conditions.has(condition):
		conditions.erase(condition)
		condition_removed.emit(condition)

## Check if has a condition
func has_condition(condition: Enums.Condition) -> bool:
	return conditions.has(condition) and conditions[condition] > 0

## Update conditions (call every frame with delta)
func update_conditions(delta: float) -> void:
	var to_remove: Array = []
	for condition in conditions:
		conditions[condition] -= delta
		if conditions[condition] <= 0:
			to_remove.append(condition)

	for condition in to_remove:
		remove_condition(condition)

# =============================================================================
# COMBAT SCALING - Build choices matter in combat
# =============================================================================

## Get melee damage bonus from stats and skills
## Formula: (Grit × 0.5) + (Melee skill × 2)
func get_melee_damage_bonus() -> int:
	var eff_grit := get_effective_stat(Enums.Stat.GRIT)
	var melee_skill := get_skill(Enums.Skill.MELEE)
	return int(eff_grit * 0.5) + (melee_skill * 2)

## Get ranged damage bonus from stats and skills
## Formula: (Agility × 0.5) + (Ranged skill × 2)
func get_ranged_damage_bonus() -> int:
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var ranged_skill := get_skill(Enums.Skill.RANGED)
	return int(eff_agility * 0.5) + (ranged_skill * 2)

## Get spell damage bonus from stats and skills
## Formula: (Knowledge × 0.5) + (Arcana Lore × 2)
func get_spell_damage_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var arcana_skill := get_skill(Enums.Skill.ARCANA_LORE)
	return int(eff_knowledge * 0.5) + (arcana_skill * 2)

## Get spell cost reduction multiplier based on Will
## Formula: 1.0 - (Will × 0.02) -- Will 10 = 20% reduction
func get_spell_cost_multiplier() -> float:
	var eff_will := get_effective_stat(Enums.Stat.WILL)
	return maxf(0.5, 1.0 - (eff_will * 0.02))  # Cap at 50% reduction

## Get enemy detection range based on INTUITION skill
## INTUITION: Base 15 + 5 per level = up to 65 units at level 10
## Also influenced by Knowledge stat
func get_enemy_detection_range() -> float:
	var base_range := 15.0
	var intuition_skill := get_skill(Enums.Skill.INTUITION)
	var knowledge_bonus := get_effective_stat(Enums.Stat.KNOWLEDGE) * 0.5
	return base_range + (intuition_skill * 5.0) + knowledge_bonus

## Get intimidation check bonus (Grit + Intimidation skill)
## Used when intimidating enemies
func get_intimidation_bonus() -> int:
	var eff_grit := get_effective_stat(Enums.Stat.GRIT)
	var intimidation_skill := get_skill(Enums.Skill.INTIMIDATION)
	return eff_grit + intimidation_skill

## Get IP needed for next level (for UI display)
func get_ip_for_next_level() -> int:
	if level >= IP_PER_LEVEL.size():
		return 0  # Max level
	return IP_PER_LEVEL[level]

## Get IP progress toward next level (for UI progress bar)
func get_level_progress() -> float:
	if level >= IP_PER_LEVEL.size():
		return 1.0  # Max level
	var current_threshold := IP_PER_LEVEL[level - 1] if level > 1 else 0
	var next_threshold := IP_PER_LEVEL[level]
	var progress_in_level := total_ip_earned - current_threshold
	var level_range := next_threshold - current_threshold
	return float(progress_in_level) / float(level_range)

# =============================================================================
# SKILL HELPER FUNCTIONS - For use by various game systems
# =============================================================================

## Get pickpocket success bonus (Agility + Thievery + Stealth/2)
## THIEVERY: Primary pickpocket skill, STEALTH provides half bonus
func get_pickpocket_bonus() -> int:
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var thievery_skill := get_skill(Enums.Skill.THIEVERY)
	var stealth_skill := get_skill(Enums.Skill.STEALTH)
	return eff_agility + thievery_skill + (stealth_skill / 2)

## Get stealth effectiveness multiplier
## STEALTH: Base detection range reduced by 5% per level (up to 50%)
## Crouching adds +10% bonus (handled by PlayerController)
func get_stealth_multiplier() -> float:
	var stealth_skill := get_skill(Enums.Skill.STEALTH)
	return maxf(0.5, 1.0 - (stealth_skill * 0.05))

## Get backstab crit chance bonus
## STEALTH: +3% backstab crit chance per level
func get_backstab_crit_bonus() -> float:
	var stealth_skill := get_skill(Enums.Skill.STEALTH)
	return stealth_skill * 0.03

## Get plant harvest yield multiplier
## HERBALISM: +20% plant yields per level (up to 200% at level 10)
func get_herbalism_yield_multiplier() -> float:
	var herbalism_skill := get_skill(Enums.Skill.HERBALISM)
	return 1.0 + (herbalism_skill * 0.2)

## Get potion effectiveness multiplier
## HERBALISM: +10% potion strength per level (up to 100% at level 10)
func get_potion_strength_multiplier() -> float:
	var herbalism_skill := get_skill(Enums.Skill.HERBALISM)
	return 1.0 + (herbalism_skill * 0.1)

## Get horror check bonus (Will + Bravery)
## BRAVERY: Resistance to horror effects, also provides Fearless Inspiration on success
func get_horror_check_bonus() -> int:
	var eff_will := get_effective_stat(Enums.Stat.WILL)
	var bravery_skill := get_skill(Enums.Skill.BRAVERY)
	return eff_will + bravery_skill

## Get trap detection bonus (Knowledge + Perception)
## PERCEPTION: General awareness, helps detect traps and hidden objects
func get_trap_detection_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var perception_skill := get_skill(Enums.Skill.PERCEPTION)
	return eff_knowledge + perception_skill

## Get hidden door/object detection bonus (Knowledge + History + Investigation)
## HISTORY: Lore knowledge helps find secret passages
## INVESTIGATION: Thorough searching
func get_hidden_detection_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var history_skill := get_skill(Enums.Skill.HISTORY)
	var investigation_skill := get_skill(Enums.Skill.INVESTIGATION)
	return eff_knowledge + history_skill + investigation_skill

## Get crafting quality bonus (Knowledge + Engineering)
## ENGINEERING: Improves crafted item quality
func get_crafting_quality_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var engineering_skill := get_skill(Enums.Skill.ENGINEERING)
	return eff_knowledge + engineering_skill

## Get repair effectiveness multiplier
## ENGINEERING: +10% repair effectiveness per level
func get_repair_effectiveness_multiplier() -> float:
	var engineering_skill := get_skill(Enums.Skill.ENGINEERING)
	return 1.0 + (engineering_skill * 0.1)

## Get wilderness rest bonus multiplier
## SURVIVAL: +15% wilderness rest recovery per level
func get_wilderness_rest_multiplier() -> float:
	var survival_skill := get_skill(Enums.Skill.SURVIVAL)
	return 1.0 + (survival_skill * 0.15)
