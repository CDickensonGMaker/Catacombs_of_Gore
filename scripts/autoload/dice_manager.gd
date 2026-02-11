## dice_manager.gd - Centralized dice rolling with transparency UI
## Handles all d10 rolls and displays them via DiceRollUI
extends Node

signal roll_made(roll_data: Dictionary)

## Settings
var show_dice_rolls: bool = true  # Toggle from options menu
var show_passive_as_popup: bool = false  # If false, passive rolls go to game log instead

## UI reference
var dice_ui: DiceRollUI = null

func _ready() -> void:
	# Create the dice roll UI and add to viewport
	_setup_dice_ui()
	# Load setting from config
	_load_settings()

func _setup_dice_ui() -> void:
	dice_ui = DiceRollUI.new()
	dice_ui.name = "DiceRollUI"
	# Add to scene tree with deferred call to ensure proper initialization
	call_deferred("_add_dice_ui")

func _add_dice_ui() -> void:
	# Add to the root viewport's CanvasLayer for proper layering
	var canvas := CanvasLayer.new()
	canvas.name = "DiceRollCanvas"
	canvas.layer = 100
	get_tree().root.add_child(canvas)
	canvas.add_child(dice_ui)

## Make a standard d10 roll
## Returns: {d10_roll: int, is_crit: bool}
func roll_d10() -> Dictionary:
	var roll: int = randi_range(1, 10)
	var is_crit: bool = (roll == 10)  # Rolling 10 is a crit (displayed as 0)
	return {"d10_roll": roll, "is_crit": is_crit}

## Make a skill check with full transparency
## Returns the result and optionally displays it
func make_check(
	title: String,
	base_stat: int,
	stat_name: String,
	skill_value: int,
	skill_name: String,
	dc: int,
	extra_modifiers: Array = [],  # [{name: String, value: int}]
	active_roll: bool = false  # true for lockpicking, false for passive checks
) -> Dictionary:
	var roll_result := roll_d10()
	var d10: int = roll_result.d10_roll
	var is_crit: bool = roll_result.is_crit

	# Build modifiers list
	var modifiers: Array = []
	modifiers.append({"name": stat_name, "value": base_stat})
	if skill_value != 0:
		modifiers.append({"name": skill_name, "value": skill_value})
	modifiers.append_array(extra_modifiers)

	# Calculate total
	var total: int = d10 + base_stat + skill_value
	for mod in extra_modifiers:
		total += mod.value

	# Critical success adds bonus (double effect handled by caller)
	var success: bool = total >= dc
	if is_crit:
		success = true  # Crits always succeed

	var roll_data := {
		"title": title,
		"d10_roll": d10,
		"is_crit": is_crit,
		"modifiers": modifiers,
		"total": total,
		"dc": dc,
		"success": success,
		"mode": DiceRollUI.DisplayMode.ACTIVE if active_roll else DiceRollUI.DisplayMode.PASSIVE
	}

	# Show UI if enabled
	if show_dice_rolls:
		if active_roll and dice_ui:
			# Active rolls (lockpicking, dialogue checks) show full popup
			dice_ui.show_roll(roll_data)
		elif show_passive_as_popup and dice_ui:
			# Passive rolls show popup only if setting enabled
			dice_ui.show_roll(roll_data)
		else:
			# Passive rolls go to game log instead
			_log_roll_to_hud(roll_data)

	roll_made.emit(roll_data)
	return roll_data

## Quick passive check (less UI prominence)
func passive_check(
	title: String,
	total_bonus: int,
	dc: int
) -> Dictionary:
	var roll_result := roll_d10()
	var d10: int = roll_result.d10_roll
	var is_crit: bool = roll_result.is_crit

	var total: int = d10 + total_bonus
	var success: bool = total >= dc or is_crit

	var roll_data := {
		"title": title,
		"d10_roll": d10,
		"is_crit": is_crit,
		"modifiers": [{"name": "Bonus", "value": total_bonus}],
		"total": total,
		"dc": dc,
		"success": success,
		"mode": DiceRollUI.DisplayMode.PASSIVE
	}

	if show_dice_rolls:
		if show_passive_as_popup and dice_ui:
			dice_ui.show_roll(roll_data)
		else:
			# Log to game log instead of popup
			_log_roll_to_hud(roll_data)

	roll_made.emit(roll_data)
	return roll_data


## Log a roll result to the HUD game log (non-intrusive)
func _log_roll_to_hud(roll_data: Dictionary) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as GameHUD
	if not hud:
		return

	var title: String = roll_data.get("title", "ROLL")
	var total: int = roll_data.get("total", 0)
	var dc: int = roll_data.get("dc", 0)
	var success: bool = roll_data.get("success", false)
	var is_crit: bool = roll_data.get("is_crit", false)

	var result_text := ""
	if is_crit:
		result_text = "%s: CRIT! (%d vs %d)" % [title, total, dc]
	elif success:
		result_text = "%s: Pass (%d vs %d)" % [title, total, dc]
	else:
		result_text = "%s: Fail (%d vs %d)" % [title, total, dc]

	# Color based on result
	var color := Color(0.5, 0.8, 0.5) if success else Color(0.8, 0.5, 0.5)
	if is_crit:
		color = Color(1.0, 0.9, 0.3)  # Gold for crits

	hud.add_log_entry(result_text, color)


## Combat/damage roll (not typically shown in UI unless enabled)
func roll_damage(dice_count: int, dice_sides: int, flat_bonus: int = 0) -> int:
	var total: int = flat_bonus
	for _i in range(dice_count):
		total += randi_range(1, dice_sides)
	return total

## Horror/Bravery check with full display
func bravery_check(
	will: int,
	bravery_skill: int,
	horror_value: int
) -> Dictionary:
	return make_check(
		"HORROR CHECK",
		will,
		"Will",
		bravery_skill,
		"Bravery",
		horror_value,
		[],
		true  # Active roll - more prominent display
	)

## Lockpicking check
func lockpick_check(
	agility: int,
	lockpicking_skill: int,
	lock_dc: int,
	lockpick_bonus: float = 1.5
) -> Dictionary:
	var extra: Array = []
	if lockpick_bonus > 0:
		extra.append({"name": "Lockpick", "value": int(lockpick_bonus)})

	return make_check(
		"LOCKPICK",
		agility,
		"Agility",
		lockpicking_skill,
		"Lockpicking",
		lock_dc,
		extra,
		true  # Active roll
	)

## Speech check (persuasion, deception, negotiation, intimidation)
func speech_check(
	speech_stat: int,
	skill_value: int,
	skill_name: String,
	npc_resist: int
) -> Dictionary:
	return make_check(
		skill_name.to_upper() + " CHECK",
		speech_stat,
		"Speech",
		skill_value,
		skill_name,
		npc_resist,
		[],
		true  # Active roll
	)

## Toggle dice roll display
func set_show_dice_rolls(enabled: bool) -> void:
	show_dice_rolls = enabled
	_save_settings()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "show_dice_rolls", show_dice_rolls)
	config.save("user://settings.cfg")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		show_dice_rolls = config.get_value("display", "show_dice_rolls", true)

## Force hide UI (scene transitions)
func hide_ui() -> void:
	if dice_ui:
		dice_ui.force_hide()
