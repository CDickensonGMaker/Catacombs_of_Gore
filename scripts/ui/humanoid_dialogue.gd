## humanoid_dialogue.gd - Combat dialogue for humanoid enemies
## Allows pacifist resolution: FIGHT, BRIBE, NEGOTIATE, or INTIMIDATE
## Only appears for Human, Elf, Dwarf faction enemies
class_name HumanoidDialogue
extends CanvasLayer

signal dialogue_closed(result: DialogueResult)

enum DialogueResult {
	FIGHT,      ## Player chose to fight
	BRIBE_SUCCESS,
	BRIBE_FAIL,
	NEGOTIATE_SUCCESS,
	NEGOTIATE_FAIL,
	INTIMIDATE_SUCCESS,
	INTIMIDATE_FAIL,
	CANCELLED   ## Player closed dialogue (treated as fight)
}

const DEBUG := true

## UI elements
var panel: Panel
var title_label: Label
var description_label: Label
var button_container: HBoxContainer
var fight_button: Button
var bribe_button: Button
var negotiate_button: Button
var intimidate_button: Button
var result_label: Label

## State
var target_enemy: EnemyBase = null
var target_group: Array[EnemyBase] = []  ## All enemies in the group
var bribe_cost: int = 0
var dialogue_active: bool = false

## Constants
const BRIBE_BASE_COST := 50
const BRIBE_COST_PER_ENEMY := 25
const BRIBE_COST_PER_LEVEL := 10  ## Enemy "level" approximated from HP


func _ready() -> void:
	layer = 100
	_create_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	# ESC closes dialogue (treated as fight)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close_with_result(DialogueResult.CANCELLED)
		get_viewport().set_input_as_handled()


func _create_ui() -> void:
	# Main panel
	panel = Panel.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(400, 200)
	panel.position = Vector2(-200, -100)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 15
	vbox.offset_bottom = -15
	panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Hostile Encounter"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	vbox.add_child(title_label)

	# Description
	description_label = Label.new()
	description_label.text = "The bandit blocks your path. How do you respond?"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.y = 40
	vbox.add_child(description_label)

	# Result label (shows outcome of skill checks)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.visible = false
	vbox.add_child(result_label)

	# Button container
	button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(button_container)

	# FIGHT button
	fight_button = Button.new()
	fight_button.text = "FIGHT"
	fight_button.custom_minimum_size = Vector2(80, 35)
	fight_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	fight_button.pressed.connect(_on_fight_pressed)
	button_container.add_child(fight_button)

	# BRIBE button
	bribe_button = Button.new()
	bribe_button.text = "BRIBE"
	bribe_button.custom_minimum_size = Vector2(80, 35)
	bribe_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	bribe_button.pressed.connect(_on_bribe_pressed)
	button_container.add_child(bribe_button)

	# NEGOTIATE button
	negotiate_button = Button.new()
	negotiate_button.text = "NEGOTIATE"
	negotiate_button.custom_minimum_size = Vector2(95, 35)
	negotiate_button.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	negotiate_button.pressed.connect(_on_negotiate_pressed)
	button_container.add_child(negotiate_button)

	# INTIMIDATE button
	intimidate_button = Button.new()
	intimidate_button.text = "INTIMIDATE"
	intimidate_button.custom_minimum_size = Vector2(95, 35)
	intimidate_button.add_theme_color_override("font_color", Color(0.8, 0.3, 0.8))
	intimidate_button.pressed.connect(_on_intimidate_pressed)
	button_container.add_child(intimidate_button)


## Open dialogue for a humanoid enemy encounter
## enemy: The primary enemy being engaged
## group: All enemies in the group (for group negotiations)
func open(enemy: EnemyBase, group: Array[EnemyBase] = []) -> void:
	if dialogue_active:
		return

	target_enemy = enemy
	target_group = group if not group.is_empty() else [enemy]

	# Calculate bribe cost based on group size and enemy strength
	_calculate_bribe_cost()

	# Update UI
	_update_ui()

	# Show dialogue
	visible = true
	dialogue_active = true

	# Pause game and show cursor
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if DEBUG:
		print("[HumanoidDialogue] Opened for %s (group of %d)" % [
			enemy.enemy_data.display_name if enemy.enemy_data else "Enemy",
			target_group.size()
		])


func _calculate_bribe_cost() -> void:
	bribe_cost = BRIBE_BASE_COST

	for enemy in target_group:
		bribe_cost += BRIBE_COST_PER_ENEMY
		if enemy.enemy_data:
			# Approximate "level" from max HP
			var level_approx := enemy.enemy_data.max_hp / 10
			bribe_cost += level_approx * BRIBE_COST_PER_LEVEL

	# Speech skill reduces bribe cost
	if GameManager.player_data:
		var speech := GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		var discount := speech * 0.03  # 3% discount per Speech point
		bribe_cost = int(bribe_cost * (1.0 - discount))

	bribe_cost = maxi(25, bribe_cost)  # Minimum 25 gold


func _update_ui() -> void:
	# Update title based on enemy
	var enemy_name := "Hostile"
	if target_enemy and target_enemy.enemy_data:
		enemy_name = target_enemy.enemy_data.display_name

	if target_group.size() > 1:
		title_label.text = "%s and %d others" % [enemy_name, target_group.size() - 1]
	else:
		title_label.text = enemy_name

	# Update description
	description_label.text = "They block your path. How do you respond?"

	# Update bribe button with cost
	bribe_button.text = "BRIBE (%dg)" % bribe_cost
	bribe_button.disabled = InventoryManager.gold < bribe_cost
	if bribe_button.disabled:
		bribe_button.tooltip_text = "Not enough gold"
	else:
		bribe_button.tooltip_text = "Pay %d gold to make them leave" % bribe_cost

	# Update negotiate tooltip with skill info
	if GameManager.player_data:
		var speech := GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		var negotiation := GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)
		negotiate_button.tooltip_text = "Speech %d + Negotiation %d vs their Will" % [speech, negotiation]

		var grit := GameManager.player_data.get_effective_stat(Enums.Stat.GRIT)
		var intimidation := GameManager.player_data.get_skill(Enums.Skill.INTIMIDATION)
		intimidate_button.tooltip_text = "Grit %d + Intimidation %d vs their Will + Bravery" % [grit, intimidation]

	# Hide result label
	result_label.visible = false

	# Show all buttons
	button_container.visible = true


func _on_fight_pressed() -> void:
	_close_with_result(DialogueResult.FIGHT)


func _on_bribe_pressed() -> void:
	if InventoryManager.gold < bribe_cost:
		return

	# Pay the bribe
	InventoryManager.remove_gold(bribe_cost)

	# Bribe always succeeds if you can afford it
	_show_result("They take your gold and leave.", Color(0.3, 1.0, 0.3))

	# Make all enemies in group disengage
	for enemy in target_group:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.is_intimidated = true  # Mark as "dealt with"
			enemy.intimidation_cooldown = 60.0  # Won't re-aggro for a while
			enemy._change_state(EnemyBase.AIState.DISENGAGE)

	await get_tree().create_timer(1.5).timeout
	_close_with_result(DialogueResult.BRIBE_SUCCESS)


func _on_negotiate_pressed() -> void:
	# Roll: Player Speech + Negotiation + d10 vs Enemy Will + d10
	var player_speech := 5
	var player_negotiation := 0
	if GameManager.player_data:
		player_speech = GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		player_negotiation = GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)

	var enemy_will := 5
	if target_enemy and target_enemy.enemy_data:
		enemy_will = target_enemy.enemy_data.will

	var player_roll := randi_range(1, 10)
	var enemy_roll := randi_range(1, 10)

	var player_total := player_speech + player_negotiation + player_roll
	var enemy_total := enemy_will + enemy_roll

	if DEBUG:
		print("[HumanoidDialogue] Negotiate: Player(%d+%d+%d=%d) vs Enemy(%d+%d=%d)" % [
			player_speech, player_negotiation, player_roll, player_total,
			enemy_will, enemy_roll, enemy_total
		])

	if player_total > enemy_total:
		_show_result("You convince them to stand down.", Color(0.3, 1.0, 0.3))

		# Make all enemies in group disengage
		for enemy in target_group:
			if is_instance_valid(enemy) and not enemy.is_dead():
				enemy.is_intimidated = true
				enemy.intimidation_cooldown = 60.0
				enemy._change_state(EnemyBase.AIState.DISENGAGE)

		await get_tree().create_timer(1.5).timeout
		_close_with_result(DialogueResult.NEGOTIATE_SUCCESS)
	else:
		_show_result("They refuse to listen!", Color(1.0, 0.3, 0.3))
		await get_tree().create_timer(1.5).timeout
		_close_with_result(DialogueResult.NEGOTIATE_FAIL)


func _on_intimidate_pressed() -> void:
	# Roll: Player Grit + Intimidation + d10 vs Enemy Will + Bravery + d10
	var player_grit := 5
	var player_intimidation := 0
	if GameManager.player_data:
		player_grit = GameManager.player_data.get_effective_stat(Enums.Stat.GRIT)
		player_intimidation = GameManager.player_data.get_skill(Enums.Skill.INTIMIDATION)

	var enemy_will := 5
	var enemy_bravery := 3
	if target_enemy and target_enemy.enemy_data:
		enemy_will = target_enemy.enemy_data.will
		enemy_bravery = target_enemy.enemy_data.bravery

	var player_roll := randi_range(1, 10)
	var enemy_roll := randi_range(1, 10)

	var player_total := player_grit + player_intimidation + player_roll
	var enemy_total := enemy_will + enemy_bravery + enemy_roll

	if DEBUG:
		print("[HumanoidDialogue] Intimidate: Player(%d+%d+%d=%d) vs Enemy(%d+%d+%d=%d)" % [
			player_grit, player_intimidation, player_roll, player_total,
			enemy_will, enemy_bravery, enemy_roll, enemy_total
		])

	if player_total > enemy_total:
		_show_result("They cower and flee!", Color(0.8, 0.3, 1.0))

		# Make all enemies in group disengage
		for enemy in target_group:
			if is_instance_valid(enemy) and not enemy.is_dead():
				enemy.is_intimidated = true
				enemy.intimidation_cooldown = 60.0
				enemy._change_state(EnemyBase.AIState.DISENGAGE)

		await get_tree().create_timer(1.5).timeout
		_close_with_result(DialogueResult.INTIMIDATE_SUCCESS)
	else:
		_show_result("They laugh at your threats!", Color(1.0, 0.3, 0.3))
		await get_tree().create_timer(1.5).timeout
		_close_with_result(DialogueResult.INTIMIDATE_FAIL)


func _show_result(text: String, color: Color) -> void:
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	result_label.visible = true
	button_container.visible = false


func _close_with_result(result: DialogueResult) -> void:
	dialogue_active = false
	visible = false

	# Unpause and capture mouse
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if DEBUG:
		var result_names := ["FIGHT", "BRIBE_SUCCESS", "BRIBE_FAIL", "NEGOTIATE_SUCCESS",
							 "NEGOTIATE_FAIL", "INTIMIDATE_SUCCESS", "INTIMIDATE_FAIL", "CANCELLED"]
		print("[HumanoidDialogue] Closed with result: %s" % result_names[result])

	dialogue_closed.emit(result)

	# Clean up
	target_enemy = null
	target_group.clear()


## Check if an enemy can be reasoned with (fight/bribe/negotiate/intimidate)
## Returns true only if allows_dialogue is explicitly enabled for this enemy
static func is_humanoid_enemy(enemy: EnemyBase) -> bool:
	if not enemy or not enemy.enemy_data:
		return false

	# Only enemies with allows_dialogue = true can be negotiated with
	# This is reserved for special encounters (named NPCs, quest targets, etc.)
	return enemy.enemy_data.allows_dialogue


## Check if this enemy/group has already been "dealt with" (bribed, negotiated, etc.)
static func was_already_dealt_with(enemy: EnemyBase) -> bool:
	if not enemy:
		return false
	return enemy.is_intimidated or enemy.intimidation_cooldown > 0
