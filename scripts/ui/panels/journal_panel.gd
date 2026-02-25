## journal_panel.gd - Comprehensive 6-tab journal UI panel
## Tabs: Quests, Notes, Factions, Codex, Bestiary, Statistics
class_name JournalPanel
extends Control

## Currently selected tab
enum Tab { QUESTS, NOTES, FACTIONS, CODEX, BESTIARY, STATISTICS }

## Quest sub-category
enum QuestCategory { MAIN, SECONDARY }

## UI colors (PS1 gothic aesthetic)
const COL_BG := Color(0.08, 0.08, 0.1)
const COL_PANEL := Color(0.12, 0.12, 0.15)
const COL_BORDER := Color(0.3, 0.25, 0.2)
const COL_TEXT := Color(0.9, 0.85, 0.75)
const COL_DIM := Color(0.5, 0.5, 0.5)
const COL_GOLD := Color(0.8, 0.6, 0.2)
const COL_SELECT := Color(0.25, 0.2, 0.15)
const COL_GREEN := Color(0.3, 0.8, 0.3)
const COL_RED := Color(0.8, 0.3, 0.3)
const COL_TEAL := Color(0.3, 0.7, 0.7)

## State
var current_tab: Tab = Tab.QUESTS
var quest_category: QuestCategory = QuestCategory.MAIN

## UI node references
var tab_buttons: Array[Button] = []
var content_container: Control
var current_content: Control = null

## Tab-specific data
var displayed_quests: Array = []
var selected_quest_index: int = -1
var displayed_notes: Array = []
var selected_note_index: int = -1
var displayed_factions: Array = []
var displayed_bestiary: Array = []
var selected_bestiary_index: int = -1


func _ready() -> void:
	_build_ui()
	_switch_to_tab(Tab.QUESTS)
	_connect_signals()


func _connect_signals() -> void:
	# Quest signals
	if QuestManager:
		if QuestManager.has_signal("quest_started"):
			QuestManager.quest_started.connect(func(_id: String): _refresh_current_tab())
		if QuestManager.has_signal("quest_completed"):
			QuestManager.quest_completed.connect(func(_id: String): _refresh_current_tab())
		if QuestManager.has_signal("quest_updated"):
			QuestManager.quest_updated.connect(func(_id: String, _obj_id: String): _refresh_current_tab())

	# Journal signals
	if JournalManager:
		if JournalManager.has_signal("note_added"):
			JournalManager.note_added.connect(func(_note: Dictionary): _refresh_current_tab())
		if JournalManager.has_signal("bestiary_updated"):
			JournalManager.bestiary_updated.connect(func(_id: String, _entry: Dictionary): _refresh_current_tab())

	# Faction signals
	if FactionManager:
		if FactionManager.has_signal("reputation_changed"):
			FactionManager.reputation_changed.connect(func(_id: String, _old: int, _new: int): _refresh_current_tab())


## Build the main UI layout
func _build_ui() -> void:
	custom_minimum_size = Vector2(600, 400)

	# Background panel
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COL_BG
	bg_style.border_width_bottom = 2
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_color = COL_BORDER
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	bg.add_child(main_vbox)

	# Tab bar
	_build_tab_bar(main_vbox)

	# Content area
	content_container = Control.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_container)


## Build the tab bar with 6 tabs
func _build_tab_bar(parent: Control) -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.custom_minimum_size.y = 32
	tab_bar.add_theme_constant_override("separation", 2)
	parent.add_child(tab_bar)

	var tab_names: Array[String] = ["Quests", "Notes", "Factions", "Codex", "Bestiary", "Stats"]

	for i: int in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(80, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_tab_pressed.bind(i))

		# Style
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = COL_PANEL
		normal_style.border_width_bottom = 2
		normal_style.border_color = COL_BORDER
		btn.add_theme_stylebox_override("normal", normal_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = COL_SELECT
		pressed_style.border_width_bottom = 2
		pressed_style.border_color = COL_GOLD
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.add_theme_color_override("font_color", COL_TEXT)
		btn.add_theme_color_override("font_pressed_color", COL_GOLD)

		tab_bar.add_child(btn)
		tab_buttons.append(btn)


func _on_tab_pressed(tab_index: int) -> void:
	_switch_to_tab(tab_index as Tab)


func _switch_to_tab(tab: Tab) -> void:
	current_tab = tab

	# Update tab button states
	for i: int in range(tab_buttons.size()):
		tab_buttons[i].button_pressed = (i == int(tab))

	# Clear and rebuild content
	if current_content:
		current_content.queue_free()
		current_content = null

	match tab:
		Tab.QUESTS:
			current_content = _build_quests_content()
		Tab.NOTES:
			current_content = _build_notes_content()
		Tab.FACTIONS:
			current_content = _build_factions_content()
		Tab.CODEX:
			current_content = _build_codex_content()
		Tab.BESTIARY:
			current_content = _build_bestiary_content()
		Tab.STATISTICS:
			current_content = _build_statistics_content()

	if current_content:
		content_container.add_child(current_content)


func _refresh_current_tab() -> void:
	_switch_to_tab(current_tab)


# =============================================================================
# QUESTS TAB
# =============================================================================

func _build_quests_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

	# Sub-tabs: Main / Secondary
	var sub_tabs := HBoxContainer.new()
	sub_tabs.custom_minimum_size.y = 28
	container.add_child(sub_tabs)

	var main_btn := Button.new()
	main_btn.text = "Main Quests"
	main_btn.toggle_mode = true
	main_btn.button_pressed = (quest_category == QuestCategory.MAIN)
	main_btn.pressed.connect(func(): _set_quest_category(QuestCategory.MAIN))
	main_btn.add_theme_color_override("font_color", COL_GOLD)
	sub_tabs.add_child(main_btn)

	var secondary_btn := Button.new()
	secondary_btn.text = "Side Quests"
	secondary_btn.toggle_mode = true
	secondary_btn.button_pressed = (quest_category == QuestCategory.SECONDARY)
	secondary_btn.pressed.connect(func(): _set_quest_category(QuestCategory.SECONDARY))
	secondary_btn.add_theme_color_override("font_color", COL_TEAL)
	sub_tabs.add_child(secondary_btn)

	# Content split
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(split)

	# Quest list
	var list_panel := _create_panel()
	list_panel.custom_minimum_size.x = 200
	split.add_child(list_panel)

	var list_vbox := VBoxContainer.new()
	list_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_panel.add_child(list_vbox)

	var quest_list := ItemList.new()
	quest_list.name = "QuestList"
	quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_list.add_theme_color_override("font_color", COL_TEXT)
	quest_list.add_theme_color_override("font_selected_color", COL_GOLD)
	quest_list.item_selected.connect(_on_quest_selected)
	quest_list.item_activated.connect(_on_quest_double_clicked)  # Double-click to track
	list_vbox.add_child(quest_list)

	# Track button
	var track_btn := Button.new()
	track_btn.name = "TrackButton"
	track_btn.text = "Track Quest"
	track_btn.custom_minimum_size.y = 28
	track_btn.add_theme_color_override("font_color", COL_GOLD)
	track_btn.pressed.connect(_on_track_quest_pressed)
	list_vbox.add_child(track_btn)

	# Quest details
	var detail_panel := _create_panel()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	detail_panel.add_child(detail_vbox)

	var title_label := Label.new()
	title_label.name = "QuestTitle"
	title_label.text = "Select a Quest"
	title_label.add_theme_color_override("font_color", COL_GOLD)
	title_label.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(title_label)

	var desc_label := RichTextLabel.new()
	desc_label.name = "QuestDesc"
	desc_label.custom_minimum_size.y = 60
	desc_label.bbcode_enabled = true
	desc_label.scroll_active = true
	desc_label.add_theme_color_override("default_color", COL_TEXT)
	detail_vbox.add_child(desc_label)

	var obj_label := Label.new()
	obj_label.text = "Objectives:"
	obj_label.add_theme_color_override("font_color", COL_DIM)
	detail_vbox.add_child(obj_label)

	var obj_list := ItemList.new()
	obj_list.name = "ObjectivesList"
	obj_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	obj_list.add_theme_color_override("font_color", COL_TEXT)
	detail_vbox.add_child(obj_list)

	# Populate quest list
	_populate_quest_list(quest_list)

	return container


func _set_quest_category(category: QuestCategory) -> void:
	quest_category = category
	_refresh_current_tab()


func _populate_quest_list(quest_list: ItemList) -> void:
	displayed_quests.clear()
	quest_list.clear()

	var quests: Array = []
	var tracked_id: String = ""
	if QuestManager:
		tracked_id = QuestManager.get_tracked_quest_id() if QuestManager.has_method("get_tracked_quest_id") else ""
		var active: Array = QuestManager.get_active_quests() if QuestManager.has_method("get_active_quests") else []
		var completed: Array = QuestManager.get_completed_quests() if QuestManager.has_method("get_completed_quests") else []

		for quest in active:
			var is_main: bool = quest.is_main_quest if "is_main_quest" in quest else false
			if quest_category == QuestCategory.MAIN and is_main:
				quests.append(quest)
			elif quest_category == QuestCategory.SECONDARY and not is_main:
				quests.append(quest)

		# Add completed quests at bottom (dimmed)
		for quest in completed:
			var is_main: bool = quest.is_main_quest if "is_main_quest" in quest else false
			if quest_category == QuestCategory.MAIN and is_main:
				quests.append(quest)
			elif quest_category == QuestCategory.SECONDARY and not is_main:
				quests.append(quest)

	for quest in quests:
		displayed_quests.append(quest)
		var title: String = quest.title if "title" in quest else "Unknown"
		var quest_id: String = quest.id if "id" in quest else ""
		var state = quest.state if "state" in quest else Enums.QuestState.ACTIVE

		# Show tracked indicator
		if quest_id == tracked_id and state == Enums.QuestState.ACTIVE:
			title = "> " + title  # Arrow indicates tracked quest

		if state == Enums.QuestState.COMPLETED:
			title = "[DONE] " + title
		elif state == Enums.QuestState.FAILED:
			title = "[FAIL] " + title

		var idx: int = quest_list.add_item(title)

		# Highlight tracked quest with gold color
		if quest_id == tracked_id and state == Enums.QuestState.ACTIVE:
			quest_list.set_item_custom_fg_color(idx, COL_GOLD)

	if displayed_quests.is_empty():
		quest_list.add_item("No quests in this category")


func _on_quest_selected(index: int) -> void:
	selected_quest_index = index
	if index < 0 or index >= displayed_quests.size():
		return

	var quest = displayed_quests[index]
	var title_label: Label = content_container.find_child("QuestTitle", true, false)
	var desc_label: RichTextLabel = content_container.find_child("QuestDesc", true, false)
	var obj_list: ItemList = content_container.find_child("ObjectivesList", true, false)
	var track_btn: Button = content_container.find_child("TrackButton", true, false)

	if title_label:
		title_label.text = quest.title if "title" in quest else "Unknown"

	if desc_label:
		desc_label.text = quest.description if "description" in quest else ""

	if obj_list:
		obj_list.clear()
		var objectives: Array = quest.objectives if "objectives" in quest else []
		for obj in objectives:
			var text: String = obj.description if "description" in obj else "???"
			var done: bool = obj.is_completed if "is_completed" in obj else false
			var current: int = obj.current_count if "current_count" in obj else 0
			var required: int = obj.required_count if "required_count" in obj else 1

			if required > 1:
				text += " (%d/%d)" % [current, required]
			text = ("[X] " if done else "[ ] ") + text
			obj_list.add_item(text)

	# Update track button text based on quest state
	if track_btn:
		var state = quest.state if "state" in quest else Enums.QuestState.ACTIVE
		var quest_id: String = quest.id if "id" in quest else ""
		var tracked_id: String = QuestManager.get_tracked_quest_id() if QuestManager else ""

		if state != Enums.QuestState.ACTIVE:
			track_btn.text = "Quest Complete"
			track_btn.disabled = true
		elif quest_id == tracked_id:
			track_btn.text = "Currently Tracking"
			track_btn.disabled = true
		else:
			track_btn.text = "Track Quest"
			track_btn.disabled = false


## Double-click on a quest to track it
func _on_quest_double_clicked(index: int) -> void:
	_track_quest_at_index(index)


## Track button pressed
func _on_track_quest_pressed() -> void:
	_track_quest_at_index(selected_quest_index)


## Track the quest at the given index
func _track_quest_at_index(index: int) -> void:
	if index < 0 or index >= displayed_quests.size():
		return

	var quest = displayed_quests[index]
	var quest_id: String = quest.id if "id" in quest else ""
	var state = quest.state if "state" in quest else Enums.QuestState.ACTIVE

	# Only track active quests
	if state != Enums.QuestState.ACTIVE:
		return

	if QuestManager and not quest_id.is_empty():
		QuestManager.set_tracked_quest(quest_id)
		_refresh_current_tab()  # Refresh to show new tracked quest


# =============================================================================
# NOTES TAB
# =============================================================================

func _build_notes_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

	var header := Label.new()
	header.text = "Journal Notes"
	header.add_theme_color_override("font_color", COL_GOLD)
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var notes_vbox := VBoxContainer.new()
	notes_vbox.name = "NotesContainer"
	notes_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(notes_vbox)

	# Populate notes
	_populate_notes(notes_vbox)

	return container


func _populate_notes(container: VBoxContainer) -> void:
	displayed_notes.clear()

	var notes: Array = []
	if JournalManager:
		notes = JournalManager.get_notes()

	if notes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No notes recorded yet.\nNotes are added automatically from important dialogue\nor manually copied during conversations."
		empty_label.add_theme_color_override("font_color", COL_DIM)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		container.add_child(empty_label)
		return

	for note: Dictionary in notes:
		displayed_notes.append(note)
		var note_panel := _create_note_entry(note)
		container.add_child(note_panel)


func _create_note_entry(note: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_width_left = 3
	style.border_color = COL_GOLD if note.get("is_auto", false) else COL_TEAL
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Header: Day - Source
	var header := Label.new()
	var day: int = note.get("game_day", 1)
	var source: String = note.get("source_npc", "Unknown")
	var location: String = note.get("source_location", "")
	var header_text: String = "[Day %d" % day
	if not location.is_empty():
		header_text += " - %s" % location
	header_text += "] %s" % source
	header.text = header_text
	header.add_theme_color_override("font_color", COL_DIM)
	header.add_theme_font_size_override("font_size", 12)
	vbox.add_child(header)

	# Note text
	var text_label := Label.new()
	text_label.text = '"%s"' % note.get("text", "")
	text_label.add_theme_color_override("font_color", COL_TEXT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(text_label)

	return panel


# =============================================================================
# FACTIONS TAB
# =============================================================================

func _build_factions_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

	var header := Label.new()
	header.text = "Faction Standings"
	header.add_theme_color_override("font_color", COL_GOLD)
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var factions_vbox := VBoxContainer.new()
	factions_vbox.name = "FactionsContainer"
	factions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(factions_vbox)

	_populate_factions(factions_vbox)

	return container


func _populate_factions(container: VBoxContainer) -> void:
	displayed_factions.clear()

	if not FactionManager:
		var empty_label := Label.new()
		empty_label.text = "No faction data available."
		empty_label.add_theme_color_override("font_color", COL_DIM)
		container.add_child(empty_label)
		return

	# Get known factions (ones player has interacted with)
	var known_factions: Array = []
	if FactionManager.has_method("get_known_factions"):
		known_factions = FactionManager.get_known_factions()
	elif "player_reputations" in FactionManager:
		for faction_id: String in FactionManager.player_reputations.keys():
			known_factions.append(faction_id)

	if known_factions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "You haven't interacted with any factions yet."
		empty_label.add_theme_color_override("font_color", COL_DIM)
		container.add_child(empty_label)
		return

	for faction_id: String in known_factions:
		displayed_factions.append(faction_id)
		var faction_entry := _create_faction_entry(faction_id)
		container.add_child(faction_entry)


func _create_faction_entry(faction_id: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.border_width_bottom = 1
	style.border_color = COL_BORDER
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Faction name
	var faction_name: String = faction_id.capitalize().replace("_", " ")
	if FactionManager and FactionManager.has_method("get_faction_name"):
		faction_name = FactionManager.get_faction_name(faction_id)

	var name_label := Label.new()
	name_label.text = faction_name
	name_label.add_theme_color_override("font_color", COL_GOLD)
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Reputation bar
	var rep_hbox := HBoxContainer.new()
	vbox.add_child(rep_hbox)

	var rep_value: int = 0
	if FactionManager and "player_reputations" in FactionManager:
		rep_value = FactionManager.player_reputations.get(faction_id, 0)

	var rep_label := Label.new()
	rep_label.text = "Reputation: %d" % rep_value
	rep_label.custom_minimum_size.x = 120
	rep_label.add_theme_color_override("font_color", COL_TEXT)
	rep_hbox.add_child(rep_label)

	# Progress bar
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 16)
	bar.min_value = -100
	bar.max_value = 100
	bar.value = rep_value
	bar.show_percentage = false

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = COL_PANEL.lightened(0.1)
	bar.add_theme_stylebox_override("background", bar_style)

	var fill_style := StyleBoxFlat.new()
	if rep_value >= 50:
		fill_style.bg_color = COL_GREEN
	elif rep_value >= 0:
		fill_style.bg_color = COL_TEAL
	elif rep_value >= -50:
		fill_style.bg_color = COL_GOLD
	else:
		fill_style.bg_color = COL_RED
	bar.add_theme_stylebox_override("fill", fill_style)

	rep_hbox.add_child(bar)

	# Status label
	var status_label := Label.new()
	var status: String = _get_reputation_status(rep_value)
	status_label.text = status
	status_label.add_theme_color_override("font_color", _get_status_color(rep_value))
	rep_hbox.add_child(status_label)

	return panel


func _get_reputation_status(rep: int) -> String:
	if rep >= 75:
		return "Beloved"
	elif rep >= 50:
		return "Honored"
	elif rep >= 25:
		return "Friendly"
	elif rep >= 0:
		return "Neutral"
	elif rep >= -25:
		return "Unfriendly"
	elif rep >= -50:
		return "Hostile"
	else:
		return "Enemy"


func _get_status_color(rep: int) -> Color:
	if rep >= 50:
		return COL_GREEN
	elif rep >= 0:
		return COL_TEXT
	elif rep >= -50:
		return COL_GOLD
	else:
		return COL_RED


# =============================================================================
# CODEX TAB
# =============================================================================

## Currently selected codex category
var codex_category: String = "recipes"
## Displayed codex entries for current category
var codex_entries: Array = []
## Selected codex entry index
var selected_codex_index: int = -1

func _build_codex_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

	var header := Label.new()
	header.text = "Codex - Recipes & Knowledge"
	header.add_theme_color_override("font_color", COL_GOLD)
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(split)

	# Category list
	var cat_panel := _create_panel()
	cat_panel.custom_minimum_size.x = 120
	split.add_child(cat_panel)

	var cat_vbox := VBoxContainer.new()
	cat_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cat_panel.add_child(cat_vbox)

	var cat_list := ItemList.new()
	cat_list.name = "CodexCategories"
	cat_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_list.add_theme_color_override("font_color", COL_TEXT)
	cat_list.add_theme_color_override("font_selected_color", COL_GOLD)
	cat_list.item_selected.connect(_on_codex_category_selected)
	cat_vbox.add_child(cat_list)

	# Entry list + details
	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right_split)

	var entry_panel := _create_panel()
	entry_panel.custom_minimum_size.x = 150
	right_split.add_child(entry_panel)

	var entry_list := ItemList.new()
	entry_list.name = "CodexEntries"
	entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_color_override("font_color", COL_TEXT)
	entry_list.add_theme_color_override("font_selected_color", COL_GOLD)
	entry_list.item_selected.connect(_on_codex_entry_selected)
	entry_panel.add_child(entry_list)

	var detail_panel := _create_panel()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(detail_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)

	var detail_label := RichTextLabel.new()
	detail_label.name = "CodexDetail"
	detail_label.fit_content = true
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.bbcode_enabled = true
	detail_label.add_theme_color_override("default_color", COL_TEXT)
	detail_scroll.add_child(detail_label)

	# Populate categories - Recipes first, then Lore categories
	var categories: Array[String] = ["Recipes"]
	# Add lore categories
	for lore_cat: String in CodexManager.LORE_CATEGORIES:
		categories.append(lore_cat.capitalize())

	for cat: String in categories:
		cat_list.add_item(cat)

	# Select first category by default
	if cat_list.item_count > 0:
		cat_list.select(0)
		_on_codex_category_selected(0)

	return container


func _on_codex_category_selected(idx: int) -> void:
	var cat_names: Array[String] = ["recipes"]
	for lore_cat: String in CodexManager.LORE_CATEGORIES:
		cat_names.append(lore_cat)

	if idx < 0 or idx >= cat_names.size():
		return

	codex_category = cat_names[idx]
	selected_codex_index = -1
	_refresh_codex_entries()


func _refresh_codex_entries() -> void:
	codex_entries.clear()

	var entry_list: ItemList = content_container.find_child("CodexEntries", true, false)
	var detail_label: RichTextLabel = content_container.find_child("CodexDetail", true, false)
	if not entry_list or not detail_label:
		return

	entry_list.clear()
	detail_label.text = "Select an entry to view details."

	if codex_category == "recipes":
		# Get all discovered recipes
		for recipe_cat: String in CodexManager.discovered_recipes.keys():
			for recipe_id: String in CodexManager.discovered_recipes[recipe_cat]:
				var recipe: Dictionary = CodexManager.get_recipe(recipe_id)
				if not recipe.is_empty():
					codex_entries.append({"type": "recipe", "id": recipe_id, "data": recipe})
					var name: String = recipe.get("name", recipe_id)
					entry_list.add_item(name)
	else:
		# Get discovered lore for this category
		var lore_ids: Array = CodexManager.get_discovered_lore(codex_category)
		for lore_id: String in lore_ids:
			var lore: Dictionary = CodexManager.get_lore(lore_id)
			if not lore.is_empty():
				codex_entries.append({"type": "lore", "id": lore_id, "data": lore})
				var title: String = lore.get("title", lore_id)
				entry_list.add_item(title)

	if codex_entries.is_empty():
		detail_label.text = "[i]No entries discovered in this category yet.[/i]\n\nExplore the world, talk to NPCs, and read books to discover new knowledge."


func _on_codex_entry_selected(idx: int) -> void:
	if idx < 0 or idx >= codex_entries.size():
		return

	selected_codex_index = idx
	var entry: Dictionary = codex_entries[idx]
	var data: Dictionary = entry.get("data", {})

	var detail_label: RichTextLabel = content_container.find_child("CodexDetail", true, false)
	if not detail_label:
		return

	var text: String = ""

	if entry.type == "recipe":
		text = "[b][color=#cc9933]%s[/color][/b]\n\n" % data.get("name", "Unknown Recipe")
		text += "%s\n\n" % data.get("description", "")

		# Ingredients
		var ingredients: Array = data.get("ingredients", [])
		if not ingredients.is_empty():
			text += "[b]Ingredients:[/b]\n"
			for ing: Dictionary in ingredients:
				var ing_name: String = ing.get("item_id", "unknown").replace("_", " ").capitalize()
				var qty: int = ing.get("quantity", 1)
				text += "  - %s x%d\n" % [ing_name, qty]

		# Result
		var result: Dictionary = data.get("result", {})
		if not result.is_empty():
			var result_name: String = result.get("item_id", "unknown").replace("_", " ").capitalize()
			var result_qty: int = result.get("quantity", 1)
			text += "\n[b]Creates:[/b] %s x%d\n" % [result_name, result_qty]

		# Skill requirement
		var skill_req: int = data.get("skill_required", 0)
		if skill_req > 0:
			text += "\n[b]Skill Required:[/b] %d" % skill_req

	else:  # Lore entry
		text = "[b][color=#cc9933]%s[/color][/b]\n\n" % data.get("title", "Unknown")
		text += data.get("text", "No information available.")

	detail_label.text = text


# =============================================================================
# BESTIARY TAB
# =============================================================================

func _build_bestiary_content() -> Control:
	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

	var header := Label.new()
	header.text = "Bestiary - Creatures Encountered"
	header.add_theme_color_override("font_color", COL_GOLD)
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(split)

	# Creature list
	var list_panel := _create_panel()
	list_panel.custom_minimum_size.x = 180
	split.add_child(list_panel)

	var creature_list := ItemList.new()
	creature_list.name = "BestiaryList"
	creature_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	creature_list.add_theme_color_override("font_color", COL_TEXT)
	creature_list.add_theme_color_override("font_selected_color", COL_GOLD)
	creature_list.item_selected.connect(_on_bestiary_selected)
	list_panel.add_child(creature_list)

	# Creature details
	var detail_panel := _create_panel()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	detail_panel.add_child(detail_vbox)

	var name_label := Label.new()
	name_label.name = "CreatureName"
	name_label.text = "Select a Creature"
	name_label.add_theme_color_override("font_color", COL_GOLD)
	name_label.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(name_label)

	var type_label := Label.new()
	type_label.name = "CreatureType"
	type_label.add_theme_color_override("font_color", COL_DIM)
	detail_vbox.add_child(type_label)

	var stats_label := Label.new()
	stats_label.name = "CreatureStats"
	stats_label.add_theme_color_override("font_color", COL_TEXT)
	detail_vbox.add_child(stats_label)

	var lore_label := RichTextLabel.new()
	lore_label.name = "CreatureLore"
	lore_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lore_label.bbcode_enabled = true
	lore_label.add_theme_color_override("default_color", COL_TEXT)
	detail_vbox.add_child(lore_label)

	# Populate bestiary
	_populate_bestiary(creature_list)

	return container


func _populate_bestiary(creature_list: ItemList) -> void:
	displayed_bestiary.clear()
	creature_list.clear()

	if not JournalManager:
		creature_list.add_item("No bestiary data available")
		return

	var entries: Array = JournalManager.get_all_bestiary_entries()
	if entries.is_empty():
		creature_list.add_item("No creatures encountered yet")
		return

	for entry: Dictionary in entries:
		displayed_bestiary.append(entry)
		var name: String = entry.get("creature_name", "Unknown")
		var kills: int = entry.get("kill_count", 0)
		creature_list.add_item("%s (%d)" % [name, kills])


func _on_bestiary_selected(index: int) -> void:
	selected_bestiary_index = index
	if index < 0 or index >= displayed_bestiary.size():
		return

	var entry: Dictionary = displayed_bestiary[index]
	var reveal_level: int = 1
	if JournalManager:
		reveal_level = JournalManager.get_reveal_level(entry.get("creature_id", ""))

	var name_label: Label = content_container.find_child("CreatureName", true, false)
	var type_label: Label = content_container.find_child("CreatureType", true, false)
	var stats_label: Label = content_container.find_child("CreatureStats", true, false)
	var lore_label: RichTextLabel = content_container.find_child("CreatureLore", true, false)

	if name_label:
		name_label.text = entry.get("creature_name", "Unknown")

	if type_label:
		type_label.text = "Type: %s" % entry.get("creature_type", "Unknown")

	if stats_label:
		var kills: int = entry.get("kill_count", 0)
		var location: String = entry.get("first_encounter_location", "Unknown")
		stats_label.text = "First Encountered: %s\nKilled: %d" % [location, kills]

	if lore_label:
		var lore: String = ""
		if reveal_level >= 2:
			lore = entry.get("lore_description", "")
		else:
			lore = "[i]Kill more to learn about this creature...[/i]"

		if reveal_level >= 3:
			var weaknesses: Array = entry.get("weaknesses", [])
			var resistances: Array = entry.get("resistances", [])
			if not weaknesses.is_empty():
				lore += "\n\n[color=#80cc80]Weaknesses:[/color] " + ", ".join(weaknesses)
			if not resistances.is_empty():
				lore += "\n[color=#cc8080]Resistances:[/color] " + ", ".join(resistances)

		lore_label.text = lore


# =============================================================================
# STATISTICS TAB
# =============================================================================

func _build_statistics_content() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	scroll.add_child(container)

	# Play time header
	var time_label := Label.new()
	var play_time: String = "00:00:00"
	if StatsTracker:
		play_time = StatsTracker.get_play_time_formatted()
	time_label.text = "Play Time: %s" % play_time
	time_label.add_theme_color_override("font_color", COL_GOLD)
	time_label.add_theme_font_size_override("font_size", 16)
	container.add_child(time_label)

	# Stat categories
	_add_stat_section(container, "Combat", [
		["Enemies Killed", "enemies_killed"],
		["Deaths", "deaths"],
		["Damage Dealt", "damage_dealt"],
		["Damage Taken", "damage_taken"],
		["Toughest Enemy", "toughest_enemy"],
	])

	_add_stat_section(container, "Exploration", [
		["Locations Discovered", "locations_discovered"],
		["Cells Explored", "cells_explored"],
		["Dungeons Cleared", "dungeons_cleared"],
		["Chests Opened", "chests_opened"],
	])

	_add_stat_section(container, "Social", [
		["Main Quests Completed", "quests_completed_main"],
		["Side Quests Completed", "quests_completed_secondary"],
		["Quests Failed", "quests_failed"],
		["NPCs Met", "npcs_talked_to"],
		["Factions Joined", "factions_joined"],
	])

	_add_stat_section(container, "Crime", [
		["Items Stolen", "items_stolen"],
		["Murders", "murders"],
		["Times Arrested", "times_arrested"],
		["Bounty Paid", "bounty_paid"],
	])

	_add_stat_section(container, "Economy", [
		["Gold Earned", "gold_earned"],
		["Gold Spent", "gold_spent"],
		["Items Crafted", "items_crafted"],
		["Potions Consumed", "potions_consumed"],
	])

	return scroll


func _add_stat_section(parent: Control, title: String, stats: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	parent.add_child(section)

	var header := Label.new()
	header.text = title
	header.add_theme_color_override("font_color", COL_GOLD)
	header.add_theme_font_size_override("font_size", 14)
	section.add_child(header)

	for stat_pair in stats:
		var label: String = stat_pair[0]
		var key: String = stat_pair[1]
		var value: Variant = 0
		if StatsTracker:
			value = StatsTracker.get_stat(key)

		var row := HBoxContainer.new()
		section.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = label + ":"
		name_lbl.custom_minimum_size.x = 180
		name_lbl.add_theme_color_override("font_color", COL_TEXT)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(value)
		val_lbl.add_theme_color_override("font_color", COL_TEAL)
		row.add_child(val_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	parent.add_child(spacer)


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _create_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Called when panel becomes visible
func refresh() -> void:
	_refresh_current_tab()
