## dice_roll_ui.gd - Displays dice roll results with transparency
## Shows roll breakdown: base stat + skill + modifiers vs DC
class_name DiceRollUI
extends Control

signal roll_complete(success: bool)

# Dark gothic colors
const COL_BG = Color(0.05, 0.05, 0.08, 0.9)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.8, 0.6, 0.2)
const COL_GREEN = Color(0.3, 0.8, 0.3)
const COL_RED = Color(0.8, 0.3, 0.3)
const COL_CRIT = Color(1.0, 0.9, 0.3)

# Display modes
enum DisplayMode { PASSIVE, ACTIVE }

# UI elements
var panel: PanelContainer
var title_label: Label
var roll_label: Label  # Shows the d10 result
var breakdown_container: VBoxContainer
var result_label: Label
var dc_label: Label

# Animation
var display_timer: float = 0.0
var display_duration: float = 2.0  # Passive rolls
var active_duration: float = 4.0  # Active rolls (lockpicking, etc.)
var is_displaying: bool = false
var current_mode: DisplayMode = DisplayMode.PASSIVE

# Roll queue for passive rolls
var roll_queue: Array[Dictionary] = []
var processing_queue: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_build_ui()

func _process(delta: float) -> void:
	if is_displaying:
		display_timer -= delta
		if display_timer <= 0:
			_hide_roll()
			_process_queue()

func _build_ui() -> void:
	# Anchor to top-right for passive, center for active
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -280
	offset_right = -20
	offset_top = 100
	offset_bottom = 280

	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var style = StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.border_color = COL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Title (e.g., "LOCKPICK CHECK")
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COL_GOLD)
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	# d10 Roll display
	var roll_hbox = HBoxContainer.new()
	roll_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(roll_hbox)

	var die_label = Label.new()
	die_label.text = "d10:"
	die_label.add_theme_color_override("font_color", COL_DIM)
	roll_hbox.add_child(die_label)

	roll_label = Label.new()
	roll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_label.add_theme_font_size_override("font_size", 24)
	roll_label.custom_minimum_size.x = 40
	roll_hbox.add_child(roll_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Breakdown container
	breakdown_container = VBoxContainer.new()
	breakdown_container.add_theme_constant_override("separation", 2)
	vbox.add_child(breakdown_container)

	# Separator before result
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	vbox.add_child(sep2)

	# DC and result row
	var result_hbox = HBoxContainer.new()
	result_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(result_hbox)

	dc_label = Label.new()
	dc_label.add_theme_color_override("font_color", COL_DIM)
	result_hbox.add_child(dc_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 18)
	result_hbox.add_child(result_label)

## Show a dice roll result
## roll_data format:
## {
##   title: "LOCKPICK CHECK",
##   d10_roll: 7,  # The actual d10 result (0-9 for display, 10 internally for crit)
##   is_crit: bool,
##   modifiers: [
##     {name: "Agility", value: 5},
##     {name: "Lockpicking", value: 3},
##     {name: "Lock Difficulty", value: -2}
##   ],
##   total: 13,
##   dc: 12,
##   success: true,
##   mode: DisplayMode.PASSIVE or ACTIVE
## }
func show_roll(roll_data: Dictionary) -> void:
	var mode: DisplayMode = roll_data.get("mode", DisplayMode.PASSIVE)

	if mode == DisplayMode.PASSIVE:
		# Queue passive rolls
		roll_queue.append(roll_data)
		if not processing_queue:
			_process_queue()
	else:
		# Active rolls display immediately and interrupt queue
		_display_roll(roll_data)

func _process_queue() -> void:
	if roll_queue.is_empty():
		processing_queue = false
		return

	processing_queue = true
	var roll_data: Dictionary = roll_queue.pop_front()
	_display_roll(roll_data)

func _display_roll(roll_data: Dictionary) -> void:
	current_mode = roll_data.get("mode", DisplayMode.PASSIVE)

	# Position based on mode
	if current_mode == DisplayMode.ACTIVE:
		# Center for active rolls
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -130
		offset_right = 130
		offset_top = -100
		offset_bottom = 100
		display_timer = active_duration
	else:
		# Top-right for passive
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -280
		offset_right = -20
		offset_top = 100
		offset_bottom = 280
		display_timer = display_duration

	# Title
	title_label.text = roll_data.get("title", "ROLL")

	# d10 display - show 0 for crits (authentic d10 style)
	var d10_roll: int = roll_data.get("d10_roll", 1)
	var is_crit: bool = roll_data.get("is_crit", false)

	if is_crit:
		roll_label.text = "0!"  # Crit display
		roll_label.add_theme_color_override("font_color", COL_CRIT)
	else:
		# d10 shows 0-9, internally 1-10
		var display_val: int = d10_roll if d10_roll < 10 else 0
		roll_label.text = str(display_val)
		roll_label.add_theme_color_override("font_color", COL_TEXT)

	# Clear and rebuild breakdown
	for child in breakdown_container.get_children():
		child.queue_free()

	var modifiers: Array = roll_data.get("modifiers", [])
	for mod in modifiers:
		var mod_row = _create_modifier_row(mod.name, mod.value)
		breakdown_container.add_child(mod_row)

	# DC and result
	var dc: int = roll_data.get("dc", 0)
	var total: int = roll_data.get("total", 0)
	var success: bool = roll_data.get("success", false)

	dc_label.text = "vs DC %d" % dc

	if success:
		result_label.text = "SUCCESS (%d)" % total
		result_label.add_theme_color_override("font_color", COL_GREEN)
	else:
		result_label.text = "FAIL (%d)" % total
		result_label.add_theme_color_override("font_color", COL_RED)

	visible = true
	is_displaying = true
	roll_complete.emit(success)

func _create_modifier_row(mod_name: String, value: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = mod_name + ":"
	name_lbl.custom_minimum_size.x = 100
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(name_lbl)

	var val_lbl = Label.new()
	if value >= 0:
		val_lbl.text = "+%d" % value
		val_lbl.add_theme_color_override("font_color", COL_GREEN)
	else:
		val_lbl.text = str(value)
		val_lbl.add_theme_color_override("font_color", COL_RED)
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	return row

func _hide_roll() -> void:
	visible = false
	is_displaying = false

## Instant hide for scene changes
func force_hide() -> void:
	_hide_roll()
	roll_queue.clear()
	processing_queue = false
