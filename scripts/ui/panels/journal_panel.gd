## journal_panel.gd - Quest journal display panel
class_name JournalPanel
extends Control

## Quest category buttons
@export var active_quests_button: Button
@export var completed_quests_button: Button

## Quest display
@export var quest_list: ItemList
@export var quest_title_label: Label
@export var quest_description_label: RichTextLabel
@export var objectives_list: ItemList

## State
enum QuestCategory { ACTIVE, COMPLETED }
var current_category: QuestCategory = QuestCategory.ACTIVE
var displayed_quests: Array = []
var selected_quest_id: String = ""

func _ready() -> void:
	_connect_buttons()
	refresh()

func _connect_buttons() -> void:
	if active_quests_button:
		active_quests_button.pressed.connect(func(): _set_category(QuestCategory.ACTIVE))
	if completed_quests_button:
		completed_quests_button.pressed.connect(func(): _set_category(QuestCategory.COMPLETED))

	if quest_list:
		quest_list.item_selected.connect(_on_quest_selected)

func _set_category(category: QuestCategory) -> void:
	current_category = category

	if active_quests_button:
		active_quests_button.button_pressed = (category == QuestCategory.ACTIVE)
	if completed_quests_button:
		completed_quests_button.button_pressed = (category == QuestCategory.COMPLETED)

	_refresh_quest_list()

func refresh() -> void:
	_set_category(current_category)

func _refresh_quest_list() -> void:
	if not quest_list:
		return

	quest_list.clear()
	displayed_quests.clear()
	selected_quest_id = ""

	# Get quests from QuestManager
	var quests: Array = []
	if current_category == QuestCategory.ACTIVE:
		quests = QuestManager.get_active_quests() if QuestManager.has_method("get_active_quests") else []
	else:
		quests = QuestManager.get_completed_quests() if QuestManager.has_method("get_completed_quests") else []

	for quest in quests:
		displayed_quests.append(quest)
		var quest_name: String = quest.title if "title" in quest else "Unknown Quest"
		quest_list.add_item(quest_name)

	# Show placeholder if no quests
	if displayed_quests.is_empty():
		if current_category == QuestCategory.ACTIVE:
			quest_list.add_item("No active quests")
		else:
			quest_list.add_item("No completed quests")

	_clear_quest_details()

func _on_quest_selected(index: int) -> void:
	if index < 0 or index >= displayed_quests.size():
		_clear_quest_details()
		return

	var quest = displayed_quests[index]
	selected_quest_id = quest.get("id", "")
	_display_quest_details(quest)

func _display_quest_details(quest) -> void:
	if quest_title_label:
		quest_title_label.text = quest.title if "title" in quest else "Unknown Quest"

	if quest_description_label:
		quest_description_label.text = quest.description if "description" in quest else "No description available."

	if objectives_list:
		objectives_list.clear()

		var objectives: Array = quest.objectives if "objectives" in quest else []
		for objective in objectives:
			var obj_text: String = objective.description if "description" in objective else "???"
			var completed: bool = objective.is_completed if "is_completed" in objective else false
			var current: int = objective.current_count if "current_count" in objective else 0
			var target: int = objective.required_count if "required_count" in objective else 1

			if target > 1:
				obj_text += " (%d/%d)" % [current, target]

			if completed:
				obj_text = "[X] " + obj_text
			else:
				obj_text = "[ ] " + obj_text

			objectives_list.add_item(obj_text)

		if objectives.is_empty():
			objectives_list.add_item("No objectives")

func _clear_quest_details() -> void:
	if quest_title_label:
		quest_title_label.text = "Select a Quest"
	if quest_description_label:
		quest_description_label.text = ""
	if objectives_list:
		objectives_list.clear()
