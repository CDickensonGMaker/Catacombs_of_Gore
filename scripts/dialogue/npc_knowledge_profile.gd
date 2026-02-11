## npc_knowledge_profile.gd - NPC personality and knowledge profile
## Defines what an NPC knows and how they speak
@tool
class_name NPCKnowledgeProfile
extends Resource

## NPC archetype categories - determines base knowledge and speech patterns
enum Archetype {
	GENERIC_VILLAGER,  ## Common townsperson
	FARMER,            ## Agricultural worker
	GUARD,             ## Town guard or soldier
	MERCHANT,          ## General trader
	INNKEEPER,         ## Runs an inn or tavern
	BLACKSMITH,        ## Weapons and armor smith
	SCHOLAR,           ## Learned person, mage
	PRIEST,            ## Religious figure
	HUNTER,            ## Wilderness expert
	MINER,             ## Underground worker
	NOBLE,             ## Aristocrat
	BEGGAR,            ## Street dweller
	THIEF,             ## Criminal element
	BARD               ## Entertainer
}

## The NPC's archetype - affects base knowledge and speech
@export var archetype: Archetype = Archetype.GENERIC_VILLAGER
## Personality traits affecting response selection (e.g., "grumpy", "friendly", "nervous", "stoic")
@export var personality_traits: Array[String] = []
## Knowledge tags this NPC possesses (e.g., "knows_local_dungeon", "knows_merchant_prices")
@export var knowledge_tags: Array[String] = []
## Base disposition toward strangers (0-100, 50 is neutral)
@export_range(0, 100) var base_disposition: int = 50
## Speech style affecting text presentation (e.g., "casual", "formal", "uneducated", "scholarly")
@export var speech_style: String = "casual"


# =============================================================================
# STATIC FACTORY METHODS
# =============================================================================

## Create a generic villager profile
static func generic_villager() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.GENERIC_VILLAGER
	profile.personality_traits = ["neutral"]
	profile.knowledge_tags = ["local_area"]
	profile.speech_style = "casual"
	return profile

## Create a guard profile
static func guard() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.GUARD
	profile.personality_traits = ["dutiful", "suspicious"]
	profile.knowledge_tags = ["local_area", "security", "crime"]
	profile.base_disposition = 40
	profile.speech_style = "formal"
	return profile

## Create a merchant profile
static func merchant() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.MERCHANT
	profile.personality_traits = ["friendly", "shrewd"]
	profile.knowledge_tags = ["local_area", "trade", "prices", "roads"]
	profile.base_disposition = 60
	profile.speech_style = "casual"
	return profile

## Create an innkeeper profile
static func innkeeper() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.INNKEEPER
	profile.personality_traits = ["friendly", "talkative"]
	profile.knowledge_tags = ["local_area", "rumors", "travelers", "food"]
	profile.base_disposition = 65
	profile.speech_style = "casual"
	return profile

## Create a blacksmith profile
static func blacksmith() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.BLACKSMITH
	profile.personality_traits = ["gruff", "hardworking"]
	profile.knowledge_tags = ["local_area", "weapons", "armor", "metals"]
	profile.base_disposition = 45
	profile.speech_style = "casual"
	return profile

## Create a scholar profile
static func scholar() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.SCHOLAR
	profile.personality_traits = ["curious", "verbose"]
	profile.knowledge_tags = ["local_area", "history", "magic", "lore"]
	profile.base_disposition = 55
	profile.speech_style = "scholarly"
	return profile

## Create a priest profile
static func priest() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.PRIEST
	profile.personality_traits = ["pious", "helpful"]
	profile.knowledge_tags = ["local_area", "religion", "healing", "undead"]
	profile.base_disposition = 70
	profile.speech_style = "formal"
	return profile

## Create a farmer profile
static func farmer() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.FARMER
	profile.personality_traits = ["simple", "hardworking"]
	profile.knowledge_tags = ["local_area", "weather", "crops", "animals"]
	profile.base_disposition = 50
	profile.speech_style = "uneducated"
	return profile

## Create a hunter profile
static func hunter() -> NPCKnowledgeProfile:
	var profile := NPCKnowledgeProfile.new()
	profile.archetype = Archetype.HUNTER
	profile.personality_traits = ["quiet", "observant"]
	profile.knowledge_tags = ["local_area", "wilderness", "creatures", "tracking"]
	profile.base_disposition = 45
	profile.speech_style = "casual"
	return profile


# =============================================================================
# HELPER METHODS
# =============================================================================

## Check if this NPC has a specific knowledge tag
func has_knowledge(tag: String) -> bool:
	return tag in knowledge_tags

## Check if this NPC has a specific personality trait
func has_trait(trait_name: String) -> bool:
	return trait_name in personality_traits

## Add a knowledge tag to this NPC
func add_knowledge(tag: String) -> void:
	if tag not in knowledge_tags:
		knowledge_tags.append(tag)

## Add a personality trait to this NPC
func add_trait(trait_name: String) -> void:
	if trait_name not in personality_traits:
		personality_traits.append(trait_name)

## Get the archetype name as a string
func get_archetype_name() -> String:
	match archetype:
		Archetype.GENERIC_VILLAGER:
			return "Villager"
		Archetype.FARMER:
			return "Farmer"
		Archetype.GUARD:
			return "Guard"
		Archetype.MERCHANT:
			return "Merchant"
		Archetype.INNKEEPER:
			return "Innkeeper"
		Archetype.BLACKSMITH:
			return "Blacksmith"
		Archetype.SCHOLAR:
			return "Scholar"
		Archetype.PRIEST:
			return "Priest"
		Archetype.HUNTER:
			return "Hunter"
		Archetype.MINER:
			return "Miner"
		Archetype.NOBLE:
			return "Noble"
		Archetype.BEGGAR:
			return "Beggar"
		Archetype.THIEF:
			return "Thief"
		Archetype.BARD:
			return "Bard"
		_:
			return "Unknown"

## Get a summary for editor display
func get_summary() -> String:
	var traits_str: String = ", ".join(personality_traits) if personality_traits.size() > 0 else "none"
	return "%s (%s) - %s" % [get_archetype_name(), speech_style, traits_str]
