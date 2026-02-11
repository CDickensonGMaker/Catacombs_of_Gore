## enums.gd - Global enumerations for Catacombs of Gore
class_name Enums

# Character Stats
enum Stat {
	GRIT,      # Melee damage, stagger resistance, carry weight
	AGILITY,   # Movement speed, dodge i-frames, attack speed
	WILL,      # Spell slots, magic resistance, stamina regen
	SPEECH,    # Shop prices, dialogue, NPC disposition
	KNOWLEDGE, # Spell power, crafting, XP bonus
	VITALITY   # Max HP, HP regen, resistance to DOTs
}

# Character Skills (from tabletop PDF + video game additions)
enum Skill {
	# GRIT-based
	MELEE,
	INTIMIDATION,
	# AGILITY-based
	RANGED,
	DODGE,
	STEALTH,
	ENDURANCE,
	THIEVERY,       # Pickpocketing, trap support
	ACROBATICS,
	ATHLETICS,
	# WILL-based
	CONCENTRATION,  # Mana pool, spell casting, trap disarm main
	RESIST,         # Magic resistance, charm resistance
	BRAVERY,
	# SPEECH-based
	PERSUASION,
	DECEPTION,
	NEGOTIATION,    # Shop prices, quest rewards
	# KNOWLEDGE-based
	ARCANA_LORE,
	HISTORY,
	INTUITION,      # Initiative, ambush negation, detect hidden
	ENGINEERING,    # Crafting quality, repair, trap disarm bonus
	INVESTIGATION,
	PERCEPTION,
	RELIGION,
	NATURE,
	# VITALITY-based
	FIRST_AID,
	HERBALISM,      # Plant yields, potion strength
	SURVIVAL,
	# CRAFTING-related
	ALCHEMY,
	SMITHING,
	LOCKPICKING
}

# Damage Types
enum DamageType {
	PHYSICAL,
	FIRE,
	LIGHTNING,
	FROST,
	POISON,
	NECROTIC,
	HOLY
}

# Status Conditions
enum Condition {
	NONE,
	KNOCKED_DOWN,
	POISONED,
	BURNING,
	FROZEN,
	HORRIFIED,
	BLEEDING,
	STUNNED,
	SILENCED
}

# Weapon Categories
enum WeaponType {
	DAGGER,
	SWORD,
	AXE,
	MACE,
	HAMMER,
	SPEAR,
	GLAIVE,
	BOW,
	CROSSBOW,
	MUSKET,
	STAFF,
	UNARMED
}

# Weapon Class
enum WeaponClass {
	SIMPLE,
	MARTIAL,
	MAGICAL
}

# Armor Slots
enum ArmorSlot {
	HEAD,
	BODY,
	HANDS,
	FEET,
	RING_1,
	RING_2,
	AMULET,
	SHIELD
}

# Armor Weight Class
enum ArmorWeight {
	CLOTH,
	LEATHER,
	CHAIN,
	PLATE,
	SCALE
}

# Item Quality
enum ItemQuality {
	POOR,         # -4
	BELOW_AVERAGE, # -2
	AVERAGE,      # 0
	ABOVE_AVERAGE, # +3
	PERFECT       # +5
}

# Character Races
enum Race {
	HUMAN,    # +1d4 Grit/Will/Speech - Versatile, adaptable
	ELF,      # +2+1d4 Vitality/Will/Speech - Graceful, magical
	HALFLING, # +1+1d4 Agility/Speech/Knowledge - Quick, cunning
	DWARF     # +3+1d4 Grit/Knowledge/Vitality - Tough, stubborn
}

# Starting Careers
enum Career {
	APPRENTICE,
	FARMER,
	GRAVE_DIGGER,
	SCOUT,
	SOLDIER,
	MERCHANT,
	PRIEST,
	THIEF
}

# Enemy AI Behaviors
enum AIBehavior {
	MELEE_AGGRESSIVE,
	MELEE_DEFENSIVE,
	RANGED_KITE,
	MAGE_SUPPORT,
	BRUTE,
	PACK_TACTICS,
	BOSS
}

# Enemy Factions - determines hostility between enemy types
enum Faction {
	NEUTRAL,      # Won't fight other enemies
	GOBLINOID,    # Goblins, hobgoblins, etc.
	UNDEAD,       # Skeletons, zombies, etc.
	ABOMINATION,  # Mutants, flesh horrors
	BEAST,        # Wild animals
	DEMON,        # Demons, imps
	HUMAN_BANDIT, # Bandits, raiders
	CULTIST,      # Dark cultists
	TENGER        # Blood-thirsty desert marauders from the south
}

# Faction hostility matrix - which factions attack which
# Returns true if faction_a is hostile to faction_b
static func are_factions_hostile(faction_a: Faction, faction_b: Faction) -> bool:
	# Same faction = not hostile
	if faction_a == faction_b:
		return false

	# Neutral doesn't fight anyone
	if faction_a == Faction.NEUTRAL or faction_b == Faction.NEUTRAL:
		return false

	# Define hostile pairs (bidirectional)
	var hostile_pairs := [
		[Faction.GOBLINOID, Faction.ABOMINATION],
		[Faction.GOBLINOID, Faction.UNDEAD],
		[Faction.GOBLINOID, Faction.BEAST],
		[Faction.ABOMINATION, Faction.UNDEAD],
		[Faction.ABOMINATION, Faction.BEAST],
		[Faction.BEAST, Faction.UNDEAD],
		[Faction.HUMAN_BANDIT, Faction.GOBLINOID],
		[Faction.HUMAN_BANDIT, Faction.UNDEAD],
		[Faction.HUMAN_BANDIT, Faction.ABOMINATION],
		[Faction.CULTIST, Faction.HUMAN_BANDIT],
		[Faction.DEMON, Faction.UNDEAD],
		# Tengers are hostile to almost everyone - savage desert marauders
		[Faction.TENGER, Faction.GOBLINOID],
		[Faction.TENGER, Faction.UNDEAD],
		[Faction.TENGER, Faction.ABOMINATION],
		[Faction.TENGER, Faction.BEAST],
		[Faction.TENGER, Faction.HUMAN_BANDIT],
		[Faction.TENGER, Faction.CULTIST],
	]

	for pair in hostile_pairs:
		if (faction_a == pair[0] and faction_b == pair[1]) or (faction_a == pair[1] and faction_b == pair[0]):
			return true

	return false

# Combat States
enum CombatState {
	IDLE,
	ATTACKING,
	BLOCKING,
	DODGING,
	STAGGERED,
	CASTING,
	DEAD
}

# Player States
enum PlayerState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	ATTACKING,
	HEAVY_ATTACKING,
	BLOCKING,
	DODGING,
	CASTING,
	INTERACTING,
	STAGGERED,
	DEAD
}

# Spell Target Types
enum SpellTargetType {
	SELF,
	SINGLE_ENEMY,
	SINGLE_ALLY,
	AOE_POINT,
	AOE_SELF,
	CONE,
	BEAM,
	PROJECTILE
}

# Spell Schools
enum SpellSchool {
	EVOCATION,   # Damage spells
	RESTORATION, # Healing
	NECROMANCY,  # Death magic
	CONJURATION, # Summoning
	ENCHANTMENT, # Buffs/debuffs
	ILLUSION     # Tricks
}

# Quest States
enum QuestState {
	UNAVAILABLE,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED
}

# Quest Sources - where did this quest originate
enum QuestSource {
	STORY,         # JSON-defined story/side quests from NPCs
	NPC_BOUNTY,    # Generated procedurally by BountyManager via NPC dialogue
	BOARD_BOUNTY,  # Accepted from a BountyBoard world object
	WORLD_OBJECT   # Triggered by picking up item or interacting with object
}

# Quest Turn-In Types - how can this quest be completed
enum TurnInType {
	NPC_SPECIFIC,       # Must return to specific NPC (by npc_id)
	NPC_TYPE_IN_REGION, # Any NPC of type (guard, merchant) in region accepts
	WORLD_OBJECT,       # Turn in at specific object (bounty board, altar)
	AUTO_COMPLETE       # Completes automatically when objectives done
}

# Time of Day
enum TimeOfDay {
	DAWN,
	MORNING,
	NOON,
	AFTERNOON,
	DUSK,
	NIGHT,
	MIDNIGHT
}

# Weather
enum Weather {
	CLEAR,
	CLOUDY,
	RAIN,
	STORM,
	SNOW,
	FOG
}

# Terrain Types (affects movement)
enum TerrainType {
	ROAD,      # Fast movement
	GRASS,     # Normal
	FOREST,    # Slightly slow
	SWAMP,     # Very slow
	MOUNTAIN,  # Slow, stamina drain
	SNOW,      # Slow, cold DOT without gear
	SAND       # Slow
}

# Get quality modifier value
static func get_quality_modifier(quality: ItemQuality) -> int:
	match quality:
		ItemQuality.POOR: return -4
		ItemQuality.BELOW_AVERAGE: return -2
		ItemQuality.AVERAGE: return 0
		ItemQuality.ABOVE_AVERAGE: return 3
		ItemQuality.PERFECT: return 5
	return 0

# XP cost curve for skills and stats (unified for simplicity)
# Early levels accessible, mid-game requires exploration, endgame is long-term goals
const XP_COSTS := [100, 400, 1200, 3000, 7000, 15000, 30000, 55000, 90000, 140000]

# Get skill XP cost for level
static func get_skill_ip_cost(level: int) -> int:
	if level < 1 or level > 10:
		return 0
	return XP_COSTS[level - 1]

# Get stat XP cost for level (same as skills per TTRPG rules)
static func get_stat_xp_cost(level: int) -> int:
	if level < 1 or level > 10:
		return 0
	return XP_COSTS[level - 1]
