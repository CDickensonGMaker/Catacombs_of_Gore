## spell_creator.gd - Autoload for custom spell creation logic
extends Node

signal spell_created(spell: CustomSpellData)
signal spell_deleted(spell_id: String)

## Minimum Arcana Lore required to use spell creation
const MIN_ARCANA_FOR_SPELLMAKING: int = 5

## Maximum effects per custom spell
const MAX_EFFECTS_PER_SPELL: int = 3

## Spell effect database (base effects that can be combined)
var effect_database: Dictionary = {}  # id -> SpellEffectData

## Player's created spells
var custom_spells: Dictionary = {}  # id -> CustomSpellData

func _ready() -> void:
	_load_effect_database()

## Load all spell effect resources
func _load_effect_database() -> void:
	var effect_files: Array[String] = [
		"fire_damage", "frost_damage", "lightning_damage", "poison_damage",
		"holy_damage", "necrotic_damage",
		"heal", "restore_stamina", "restore_mana",
		"apply_burn", "apply_freeze", "apply_slow", "apply_stun", "apply_poison",
		"fortify_grit", "fortify_agility", "fortify_will",
		"drain_grit", "drain_agility"
	]

	for effect_id in effect_files:
		var path := "res://data/spell_effects/%s.tres" % effect_id
		if ResourceLoader.exists(path):
			var effect: SpellEffectData = load(path) as SpellEffectData
			if effect and effect.id:
				effect_database[effect.id] = effect
				print("[SpellCreator] Loaded effect: ", effect.id)

	print("[SpellCreator] Loaded %d spell effects" % effect_database.size())

## Get a spell effect by ID (non-static, use SpellCreator.get_effect_by_id())
func get_effect_by_id(effect_id: String) -> SpellEffectData:
	return effect_database.get(effect_id)

## Static helper to get effect - accesses autoload via tree
static func get_effect(effect_id: String) -> SpellEffectData:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		var instance: Node = tree.root.get_node_or_null("SpellCreator")
		if instance and instance.has_method("get_effect_by_id"):
			return instance.get_effect_by_id(effect_id)
	return null

## Get all available effects
func get_all_effects() -> Array[SpellEffectData]:
	var result: Array[SpellEffectData] = []
	for effect_id in effect_database:
		result.append(effect_database[effect_id])
	return result

## Get effects player can use (meets Arcana requirement)
func get_available_effects() -> Array[SpellEffectData]:
	var result: Array[SpellEffectData] = []
	var player_arcana: int = 0
	if GameManager and GameManager.player_data:
		player_arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)

	for effect_id in effect_database:
		var effect: SpellEffectData = effect_database[effect_id]
		if player_arcana >= effect.required_arcana:
			result.append(effect)
	return result

## Check if player can use spell creation
func can_use_spell_altar() -> bool:
	var arcana: int = 0
	if GameManager and GameManager.player_data:
		arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)
	return arcana >= MIN_ARCANA_FOR_SPELLMAKING

## Get reason why player can't use spell altar
func get_altar_requirement_message() -> String:
	if can_use_spell_altar():
		return ""
	var arcana: int = 0
	if GameManager and GameManager.player_data:
		arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)
	return "You need at least %d Arcana Lore to create custom spells. (Current: %d)" % [MIN_ARCANA_FOR_SPELLMAKING, arcana]

## Calculate total mana cost for a spell configuration
func calculate_spell_cost(effect_configs: Array[Dictionary]) -> int:
	var total_cost: int = 0
	for config in effect_configs:
		var effect: SpellEffectData = effect_database.get(config.effect_id)
		if effect:
			total_cost += effect.calculate_cost(
				config.get("magnitude", effect.base_magnitude),
				config.get("duration", effect.base_duration),
				config.get("aoe_radius", 0.0),
				config.get("delivery", SpellEffectData.DeliveryType.PROJECTILE)
			)
	return total_cost

## Create a custom spell
func create_spell(
	spell_name: String,
	effect_configs: Array[Dictionary],
	primary_delivery: SpellEffectData.DeliveryType
) -> CustomSpellData:
	if spell_name.is_empty():
		push_warning("[SpellCreator] Cannot create spell with empty name")
		return null

	if effect_configs.is_empty():
		push_warning("[SpellCreator] Cannot create spell with no effects")
		return null

	if effect_configs.size() > MAX_EFFECTS_PER_SPELL:
		push_warning("[SpellCreator] Too many effects (max %d)" % MAX_EFFECTS_PER_SPELL)
		return null

	# Create the spell
	var spell := CustomSpellData.create_custom_spell(spell_name, effect_configs, primary_delivery)

	# Register it
	custom_spells[spell.id] = spell

	# Add to inventory manager spell database
	if InventoryManager:
		InventoryManager.spell_database[spell.id] = spell

	spell_created.emit(spell)
	print("[SpellCreator] Created spell: %s (cost: %d mana)" % [spell.display_name, spell.mana_cost])

	return spell

## Delete a custom spell
func delete_spell(spell_id: String) -> bool:
	if not custom_spells.has(spell_id):
		return false

	custom_spells.erase(spell_id)

	# Remove from inventory manager
	if InventoryManager and InventoryManager.spell_database.has(spell_id):
		InventoryManager.spell_database.erase(spell_id)

	spell_deleted.emit(spell_id)
	return true

## Get all custom spells
func get_custom_spells() -> Array[CustomSpellData]:
	var result: Array[CustomSpellData] = []
	for spell_id in custom_spells:
		result.append(custom_spells[spell_id])
	return result

## Get a custom spell by ID
func get_spell(spell_id: String) -> CustomSpellData:
	return custom_spells.get(spell_id)

## Validate effect configuration
func validate_effect_config(config: Dictionary) -> Dictionary:
	var result := {
		"valid": false,
		"reason": ""
	}

	if not config.has("effect_id"):
		result.reason = "Missing effect ID"
		return result

	var effect: SpellEffectData = effect_database.get(config.effect_id)
	if not effect:
		result.reason = "Unknown effect"
		return result

	# Check Arcana requirement
	var player_arcana: int = 0
	if GameManager and GameManager.player_data:
		player_arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)
	if player_arcana < effect.required_arcana:
		result.reason = "Requires Arcana Lore %d" % effect.required_arcana
		return result

	# Check delivery type
	var delivery: int = config.get("delivery", SpellEffectData.DeliveryType.PROJECTILE)
	if not effect.is_delivery_allowed(delivery):
		result.reason = "Invalid delivery type for this effect"
		return result

	# Check magnitude bounds
	var magnitude: int = config.get("magnitude", effect.base_magnitude)
	if magnitude < effect.base_magnitude or magnitude > effect.max_magnitude:
		result.reason = "Magnitude out of range (%d-%d)" % [effect.base_magnitude, effect.max_magnitude]
		return result

	# Check duration bounds for applicable effects
	if effect.has_duration():
		var duration: float = config.get("duration", effect.base_duration)
		if duration < 0 or duration > effect.max_duration:
			result.reason = "Duration out of range (0-%.1f)" % effect.max_duration
			return result

	result.valid = true
	return result

## Save custom spells
func get_save_data() -> Dictionary:
	var spells_data: Array[Dictionary] = []
	for spell_id in custom_spells:
		var spell: CustomSpellData = custom_spells[spell_id]
		spells_data.append(spell.to_save_dict())
	return {
		"custom_spells": spells_data
	}

## Load custom spells
func load_save_data(data: Dictionary) -> void:
	custom_spells.clear()
	var spells_data: Array = data.get("custom_spells", [])
	for spell_dict in spells_data:
		var spell := CustomSpellData.from_save_dict(spell_dict)
		custom_spells[spell.id] = spell
		# Also add to InventoryManager
		if InventoryManager:
			InventoryManager.spell_database[spell.id] = spell
	print("[SpellCreator] Loaded %d custom spells" % custom_spells.size())
