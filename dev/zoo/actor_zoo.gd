## actor_zoo.gd - Visual QA tool for all NPC and enemy sprites
## Displays every actor in a grid using BillboardSprite for pixel-identical preview
extends Node3D

## Grid configuration
const GRID_COLUMNS := 6
const GRID_SPACING := 6.0
const ENEMY_NPC_GAP_ROWS := 2

## Camera configuration
const CAMERA_SPEED := 10.0
const ZOOM_SPEED := 2.0
const ZOOM_MIN := 5.0
const ZOOM_MAX := 50.0
const ORBIT_SENSITIVITY := 0.003

## Patch file path
const PATCH_FILE := "user://zoo_patches.json"

## Node references
var camera: Camera3D
var ground_plane: MeshInstance3D
var grid_container: Node3D
var ui: CanvasLayer
var top_bar: HBoxContainer
var tools_panel: Control

## State
var all_cards: Array[ZooCard] = []
var selected_cards: Array[ZooCard] = []
var visible_cards: Array[ZooCard] = []
var modified_cards: Dictionary = {}  # id -> ZooCard
var patches: Dictionary = {}  # id -> patch dict

## Filter state
var current_filter: String = "all"  # "all", "enemy", "npc"
var search_text: String = ""

## Camera state
var camera_target: Vector3 = Vector3.ZERO
var camera_distance: float = 20.0
var camera_orbit_angle: float = 0.0
var camera_pitch: float = -0.5  # Looking down
var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

## Label visibility
var show_names: bool = true
var show_ids: bool = false
var show_states: bool = false
var show_baselines: bool = false

## Keyboard selection
var selection_index: int = 0


func _ready() -> void:
	# Ensure mouse is visible and not captured (dev tool needs mouse interaction)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_load_patches()
	_create_camera()
	_create_ground()
	_create_grid_container()
	_create_ui()
	_build_grid()
	_update_camera_position()


func _process(delta: float) -> void:
	_handle_camera_input(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse click for selection via raycast
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click_selection(mb.position)

	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_F:
				_toggle_name_labels()
			KEY_I:
				_toggle_id_labels()
			KEY_T:
				_toggle_state_labels()
			KEY_B:
				_toggle_baselines()
			KEY_ESCAPE:
				_deselect_all()
			KEY_HOME:
				_reset_camera()
			KEY_TAB:
				# Tab to cycle through cards (Shift+Tab for reverse)
				if key.shift_pressed:
					_select_previous_card()
				else:
					_select_next_card()
			KEY_ENTER, KEY_KP_ENTER:
				# Enter to select card under cursor index
				_select_card_by_index(selection_index)
			KEY_1:
				_set_filter("all")
			KEY_2:
				_set_filter("enemy")
			KEY_3:
				_set_filter("npc")
			KEY_4:
				_set_filter("named")
			KEY_5:
				_set_filter("hostage")
			KEY_F1:
				_set_all_cards_state(BillboardSprite.AnimState.IDLE)
			KEY_F2:
				_set_all_cards_state(BillboardSprite.AnimState.WALK)
			KEY_F3:
				_set_all_cards_state(BillboardSprite.AnimState.ATTACK)
			KEY_F4:
				_set_all_cards_state(BillboardSprite.AnimState.HURT)
			KEY_F5:
				_set_all_cards_state(BillboardSprite.AnimState.DEATH)
			KEY_UP:
				_nudge_offset_y(0.01 if not key.shift_pressed else 0.04)
			KEY_DOWN:
				_nudge_offset_y(-0.01 if not key.shift_pressed else -0.04)
			KEY_EQUAL, KEY_KP_ADD:  # + key
				_nudge_pixel_size(0.001 if not key.shift_pressed else 0.005)
			KEY_MINUS, KEY_KP_SUBTRACT:  # - key
				_nudge_pixel_size(-0.001 if not key.shift_pressed else -0.005)
			KEY_S:
				if key.ctrl_pressed:
					_save_patches()
					get_viewport().set_input_as_handled()

	# Handle mouse for orbiting
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = mb.pressed
			last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(camera_distance - ZOOM_SPEED, ZOOM_MIN)
			_update_camera_position()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(camera_distance + ZOOM_SPEED, ZOOM_MAX)
			_update_camera_position()

	if event is InputEventMouseMotion and is_orbiting:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		camera_orbit_angle -= motion.relative.x * ORBIT_SENSITIVITY
		camera_pitch = clampf(camera_pitch - motion.relative.y * ORBIT_SENSITIVITY, -1.4, -0.1)
		_update_camera_position()


## ============================================================================
## SETUP
## ============================================================================

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)


func _create_ground() -> void:
	ground_plane = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = mat

	ground_plane.mesh = plane
	add_child(ground_plane)


func _create_grid_container() -> void:
	grid_container = Node3D.new()
	grid_container.name = "GridContainer"
	add_child(grid_container)


func _create_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# Create main UI container - MUST ignore mouse so 3D viewport receives clicks
	var main_container := VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 0)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(main_container)

	# Top bar
	_create_top_bar(main_container)

	# Content area with tools panel on the right
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(content)

	# Spacer for 3D viewport area - MUST ignore mouse
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

	# Tools panel
	_create_tools_panel(content)


func _create_top_bar(parent: Control) -> void:
	var bar_bg := PanelContainer.new()
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar_bg)

	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	bar_bg.add_child(top_bar)

	# Filter buttons
	var btn_all := Button.new()
	btn_all.text = "All (3)"
	btn_all.pressed.connect(_set_filter.bind("all"))
	top_bar.add_child(btn_all)

	var btn_enemies := Button.new()
	btn_enemies.text = "Enemies (2)"
	btn_enemies.pressed.connect(_set_filter.bind("enemy"))
	top_bar.add_child(btn_enemies)

	var btn_npcs := Button.new()
	btn_npcs.text = "NPCs (1)"
	btn_npcs.pressed.connect(_set_filter.bind("npc"))
	top_bar.add_child(btn_npcs)

	var btn_named := Button.new()
	btn_named.text = "Named (4)"
	btn_named.pressed.connect(_set_filter.bind("named"))
	top_bar.add_child(btn_named)

	var btn_hostages := Button.new()
	btn_hostages.text = "Hostages (5)"
	btn_hostages.pressed.connect(_set_filter.bind("hostage"))
	top_bar.add_child(btn_hostages)

	# Search field
	var search := LineEdit.new()
	search.placeholder_text = "Search..."
	search.custom_minimum_size.x = 150
	search.text_changed.connect(_on_search_changed)
	top_bar.add_child(search)

	# Separator
	var sep := VSeparator.new()
	top_bar.add_child(sep)

	# Global state buttons
	var lbl_global := Label.new()
	lbl_global.text = "All cards:"
	top_bar.add_child(lbl_global)

	var state_names: Array[String] = ["IDLE", "WALK", "ATK", "HURT", "DEATH"]
	for i in range(5):
		var btn := Button.new()
		btn.text = state_names[i]
		btn.pressed.connect(_set_all_cards_state.bind(i as BillboardSprite.AnimState))
		top_bar.add_child(btn)


func _create_tools_panel(parent: Control) -> void:
	var panel_container := PanelContainer.new()
	panel_container.custom_minimum_size.x = 280
	parent.add_child(panel_container)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	tools_panel = vbox

	# Actor Info section
	var info_header := Label.new()
	info_header.text = "=== Actor Info ==="
	vbox.add_child(info_header)

	var lbl_name := Label.new()
	lbl_name.name = "LblName"
	lbl_name.text = "Select an actor"
	vbox.add_child(lbl_name)

	var lbl_id := Label.new()
	lbl_id.name = "LblId"
	lbl_id.text = ""
	lbl_id.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(lbl_id)

	var lbl_sprite := Label.new()
	lbl_sprite.name = "LblSprite"
	lbl_sprite.text = ""
	lbl_sprite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sprite.custom_minimum_size.x = 250
	lbl_sprite.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(lbl_sprite)

	var lbl_frame_size := Label.new()
	lbl_frame_size.name = "LblFrameSize"
	lbl_frame_size.text = ""
	vbox.add_child(lbl_frame_size)

	# Animation State section
	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var anim_header := Label.new()
	anim_header.text = "=== Preview State ==="
	vbox.add_child(anim_header)

	var state_buttons := HBoxContainer.new()
	state_buttons.name = "StateButtons"
	vbox.add_child(state_buttons)

	var state_names: Array[String] = ["IDLE", "WALK", "ATK", "HURT", "DEATH"]
	for i in range(5):
		var btn := Button.new()
		btn.name = "BtnState%d" % i
		btn.text = state_names[i]
		btn.pressed.connect(_on_state_button_pressed.bind(i))
		state_buttons.add_child(btn)

	# Animation info
	var anim_info := VBoxContainer.new()
	anim_info.name = "AnimInfo"
	vbox.add_child(anim_info)

	for state_name: String in ["IDLE", "WALK", "ATK", "HURT", "DEATH"]:
		var lbl := Label.new()
		lbl.name = "LblAnim" + state_name
		lbl.text = ""
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		anim_info.add_child(lbl)

	# Edit Fields section
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var edit_header := Label.new()
	edit_header.text = "=== Edit Values ==="
	vbox.add_child(edit_header)

	_add_spin_field(vbox, "pixel_size", "Pixel Size:", 0.001, 0.005, 0.1, 0.001)
	_add_spin_field(vbox, "offset_y", "Offset Y:", -2.0, -2.0, 2.0, 0.01)
	_add_spin_field(vbox, "h_frames", "H Frames:", 1, 1, 16, 1)
	_add_spin_field(vbox, "v_frames", "V Frames:", 1, 1, 16, 1)

	# Nudge buttons
	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	var nudge_header := Label.new()
	nudge_header.text = "Nudge offset_y:"
	vbox.add_child(nudge_header)

	var nudge_row := HBoxContainer.new()
	vbox.add_child(nudge_row)

	for amount: float in [-0.08, -0.04, -0.02, -0.01, 0.01, 0.02, 0.04, 0.08]:
		var btn := Button.new()
		btn.text = "%+.2f" % amount
		btn.custom_minimum_size.x = 30
		btn.pressed.connect(_nudge_offset_y.bind(amount))
		nudge_row.add_child(btn)

	# Toggles section
	var sep4 := HSeparator.new()
	vbox.add_child(sep4)

	var toggle_header := Label.new()
	toggle_header.text = "=== Toggles ==="
	vbox.add_child(toggle_header)

	_add_toggle(vbox, "Name labels (F)", show_names, _toggle_name_labels)
	_add_toggle(vbox, "ID labels (I)", show_ids, _toggle_id_labels)
	_add_toggle(vbox, "State labels (T)", show_states, _toggle_state_labels)
	_add_toggle(vbox, "Baseline (B)", show_baselines, _toggle_baselines)

	# Batch section
	var sep5 := HSeparator.new()
	vbox.add_child(sep5)

	var batch_label := Label.new()
	batch_label.name = "LblBatch"
	batch_label.text = "Selected: 0"
	vbox.add_child(batch_label)

	# Save button
	var sep6 := HSeparator.new()
	vbox.add_child(sep6)

	var save_btn := Button.new()
	save_btn.text = "Save Patches (Ctrl+S)"
	save_btn.pressed.connect(_save_patches)
	vbox.add_child(save_btn)

	# Status label
	var status_label := Label.new()
	status_label.name = "LblStatus"
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	vbox.add_child(status_label)


func _add_spin_field(parent: Control, field_name: String, label_text: String, default: float, min_val: float, max_val: float, step: float) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)

	var spin := SpinBox.new()
	spin.name = "Spin_" + field_name
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = default
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spin_changed.bind(field_name))
	hbox.add_child(spin)


func _add_toggle(parent: Control, label_text: String, default: bool, callback: Callable) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = default
	check.toggled.connect(func(_pressed: bool) -> void: callback.call())
	parent.add_child(check)


## ============================================================================
## GRID BUILDING
## ============================================================================

func _build_grid() -> void:
	# Clear existing cards
	for card: ZooCard in all_cards:
		card.queue_free()
	all_cards.clear()

	var actors: Array[Dictionary] = ZooRegistry.get_all_actors()

	# Separate enemies and NPCs
	var enemies: Array[Dictionary] = []
	var npcs: Array[Dictionary] = []
	for actor: Dictionary in actors:
		if actor.get("category", "") == "enemy":
			enemies.append(actor)
		else:
			npcs.append(actor)

	var row := 0
	var col := 0

	# Add enemies first
	for actor: Dictionary in enemies:
		var card := _create_card(actor, col, row)
		all_cards.append(card)
		col += 1
		if col >= GRID_COLUMNS:
			col = 0
			row += 1

	# Gap between enemies and NPCs
	if col > 0:
		row += 1
	row += ENEMY_NPC_GAP_ROWS

	col = 0

	# Add NPCs
	for actor: Dictionary in npcs:
		var card := _create_card(actor, col, row)
		all_cards.append(card)
		col += 1
		if col >= GRID_COLUMNS:
			col = 0
			row += 1

	# Apply filters
	_apply_filter()

	# Center camera on grid
	var total_rows := row + 1
	camera_target = Vector3(
		(GRID_COLUMNS - 1) * GRID_SPACING * 0.5,
		0,
		total_rows * GRID_SPACING * 0.5
	)
	_update_camera_position()


func _create_card(actor: Dictionary, col: int, row: int) -> ZooCard:
	var card := ZooCard.new()
	card.position = Vector3(col * GRID_SPACING, 0, row * GRID_SPACING)

	# Apply any saved patches
	var actor_id: String = actor.get("id", "")
	if patches.has(actor_id):
		var patch: Dictionary = patches[actor_id]
		for key: String in patch:
			actor[key] = patch[key]

	card.setup(actor)
	card.selected.connect(_on_card_selected)

	# Apply label visibility
	card.show_name_label(show_names)
	card.show_id_label(show_ids)
	card.show_state_label(show_states)
	card.show_baseline(show_baselines)

	grid_container.add_child(card)
	return card


## ============================================================================
## FILTERING
## ============================================================================

func _set_filter(filter: String) -> void:
	current_filter = filter
	_apply_filter()


func _on_search_changed(text: String) -> void:
	search_text = text.to_lower()
	_apply_filter()


func _apply_filter() -> void:
	visible_cards.clear()

	for card: ZooCard in all_cards:
		var actor: Dictionary = card.actor_data
		var category: String = actor.get("category", "")
		var actor_name: String = actor.get("name", "").to_lower()
		var actor_id: String = actor.get("id", "").to_lower()

		# Category filter
		var passes_category := false
		match current_filter:
			"all":
				passes_category = true
			"enemy":
				passes_category = (category == "enemy")
			"npc":
				passes_category = (category == "npc")
			"named":
				passes_category = (category == "named")
			"hostage":
				passes_category = (category == "hostage")

		# Search filter
		var passes_search := search_text.is_empty() or actor_name.contains(search_text) or actor_id.contains(search_text)

		var visible := passes_category and passes_search
		card.visible = visible
		if visible:
			visible_cards.append(card)


## ============================================================================
## SELECTION
## ============================================================================

func _on_card_selected(card: ZooCard) -> void:
	var shift_held := Input.is_key_pressed(KEY_SHIFT)

	if not shift_held:
		# Single select - deselect all others
		for c: ZooCard in selected_cards:
			if c != card:
				c.deselect()
		selected_cards.clear()

	# Toggle selection
	if card.is_selected:
		card.deselect()
		selected_cards.erase(card)
	else:
		card.select()
		selected_cards.append(card)

	_update_tools_panel()


func _deselect_all() -> void:
	for card: ZooCard in selected_cards:
		card.deselect()
	selected_cards.clear()
	_update_tools_panel()


func _select_next_card() -> void:
	if visible_cards.is_empty():
		return
	selection_index = (selection_index + 1) % visible_cards.size()
	_select_card_by_index(selection_index)


func _select_previous_card() -> void:
	if visible_cards.is_empty():
		return
	selection_index = (selection_index - 1 + visible_cards.size()) % visible_cards.size()
	_select_card_by_index(selection_index)


func _handle_click_selection(mouse_pos: Vector2) -> void:
	# Cast a ray from the camera through the mouse position
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 100.0

	# Find closest card to the ray
	var closest_card: ZooCard = null
	var closest_dist: float = 999.0

	for card: ZooCard in visible_cards:
		# Simple distance check from card center to ray
		var card_pos: Vector3 = card.global_position + Vector3(0, 1.5, 0)  # Center of card
		var ray_dir: Vector3 = (to - from).normalized()

		# Project card position onto ray to find closest point
		var to_card: Vector3 = card_pos - from
		var t: float = to_card.dot(ray_dir)
		if t < 0:
			continue  # Behind camera

		var closest_point: Vector3 = from + ray_dir * t
		var dist: float = card_pos.distance_to(closest_point)

		# Check if within click radius (generous)
		if dist < 3.0 and dist < closest_dist:
			closest_dist = dist
			closest_card = card

	if closest_card:
		var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
		if not shift_held:
			# Single select - deselect all others
			for c: ZooCard in selected_cards:
				if c != closest_card:
					c.deselect()
			selected_cards.clear()

		# Toggle selection
		if closest_card.is_selected:
			closest_card.deselect()
			selected_cards.erase(closest_card)
		else:
			closest_card.select()
			selected_cards.append(closest_card)
			selection_index = visible_cards.find(closest_card)

		_update_tools_panel()


func _select_card_by_index(index: int) -> void:
	if visible_cards.is_empty():
		return
	index = clampi(index, 0, visible_cards.size() - 1)

	# Deselect all
	for card: ZooCard in selected_cards:
		card.deselect()
	selected_cards.clear()

	# Select the card at index
	var card: ZooCard = visible_cards[index]
	card.select()
	selected_cards.append(card)
	selection_index = index

	# Move camera to look at the selected card
	camera_target = card.global_position + Vector3(0, 1.5, 0)
	_update_camera_position()

	_update_tools_panel()


## ============================================================================
## TOOLS PANEL
## ============================================================================

func _update_tools_panel() -> void:
	if selected_cards.is_empty():
		_clear_tools_panel()
		return

	var card: ZooCard = selected_cards[-1]  # Use last selected
	var actor: Dictionary = card.actor_data
	var values: Dictionary = card.get_current_values()
	var anim_info: Dictionary = card.get_animation_info()

	# Update info labels
	var lbl_name: Label = tools_panel.get_node("LblName")
	var lbl_id: Label = tools_panel.get_node("LblId")
	var lbl_sprite: Label = tools_panel.get_node("LblSprite")
	var lbl_frame_size: Label = tools_panel.get_node("LblFrameSize")

	lbl_name.text = actor.get("name", "Unknown")
	lbl_id.text = "%s (%s)" % [actor.get("id", ""), actor.get("category", "")]
	lbl_sprite.text = actor.get("sprite_path", "N/A")

	# Calculate frame size
	var sprite_path: String = actor.get("sprite_path", "")
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		if tex:
			var h: int = actor.get("h_frames", 1)
			var v: int = actor.get("v_frames", 1)
			var fw: int = tex.get_width() / h
			var fh: int = tex.get_height() / v
			lbl_frame_size.text = "Frame: %dx%d px" % [fw, fh]

	# Update spinboxes (use find_child since they're nested in HBoxContainers)
	var spin_pixel: SpinBox = tools_panel.find_child("Spin_pixel_size", true, false) as SpinBox
	var spin_offset: SpinBox = tools_panel.find_child("Spin_offset_y", true, false) as SpinBox
	var spin_h: SpinBox = tools_panel.find_child("Spin_h_frames", true, false) as SpinBox
	var spin_v: SpinBox = tools_panel.find_child("Spin_v_frames", true, false) as SpinBox

	spin_pixel.set_value_no_signal(values.get("pixel_size", 0.03))
	spin_offset.set_value_no_signal(values.get("offset_y", 0.0))
	spin_h.set_value_no_signal(values.get("h_frames", 1))
	spin_v.set_value_no_signal(values.get("v_frames", 1))

	# Update animation info
	var state_names: Array[String] = ["IDLE", "WALK", "ATK", "HURT", "DEATH"]
	var state_keys: Array[String] = ["idle", "walk", "attack", "hurt", "death"]
	var anim_container: VBoxContainer = tools_panel.get_node("AnimInfo")

	for i in range(5):
		var lbl: Label = anim_container.get_node("LblAnim" + state_names[i])
		var info: Dictionary = anim_info.get(state_keys[i], {})
		var frames: int = info.get("frames", 0)
		var fps: float = info.get("fps", 0.0)
		var separate: bool = info.get("separate", false)

		var text := "%s: %df, %.1ffps" % [state_names[i], frames, fps]
		if separate:
			text += " [separate tex]"
		lbl.text = text

		# Gray out states with no frames
		if frames <= 1:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		else:
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Update batch count
	var lbl_batch: Label = tools_panel.get_node("LblBatch")
	lbl_batch.text = "Selected: %d" % selected_cards.size()


func _clear_tools_panel() -> void:
	var lbl_name: Label = tools_panel.get_node("LblName")
	var lbl_id: Label = tools_panel.get_node("LblId")
	var lbl_sprite: Label = tools_panel.get_node("LblSprite")
	var lbl_frame_size: Label = tools_panel.get_node("LblFrameSize")
	var lbl_batch: Label = tools_panel.get_node("LblBatch")

	lbl_name.text = "Select an actor"
	lbl_id.text = ""
	lbl_sprite.text = ""
	lbl_frame_size.text = ""
	lbl_batch.text = "Selected: 0"

	# Clear animation info
	var state_names: Array[String] = ["IDLE", "WALK", "ATK", "HURT", "DEATH"]
	var anim_container: VBoxContainer = tools_panel.get_node("AnimInfo")
	for state_name: String in state_names:
		var lbl: Label = anim_container.get_node("LblAnim" + state_name)
		lbl.text = ""


func _on_state_button_pressed(state_index: int) -> void:
	var state: BillboardSprite.AnimState = state_index as BillboardSprite.AnimState
	for card: ZooCard in selected_cards:
		card.set_preview_state(state)


func _on_spin_changed(value: float, field: String) -> void:
	for card: ZooCard in selected_cards:
		card.apply_edit(field, value)
		var actor_id: String = card.actor_data.get("id", "")
		modified_cards[actor_id] = card


## ============================================================================
## GLOBAL ACTIONS
## ============================================================================

func _set_all_cards_state(state: BillboardSprite.AnimState) -> void:
	for card: ZooCard in visible_cards:
		card.set_preview_state(state)


func _nudge_offset_y(amount: float) -> void:
	for card: ZooCard in selected_cards:
		var current: float = card.get_current_values().get("offset_y", 0.0)
		card.apply_edit("offset_y", current + amount)
		var actor_id: String = card.actor_data.get("id", "")
		modified_cards[actor_id] = card

	_update_tools_panel()


func _nudge_pixel_size(amount: float) -> void:
	for card: ZooCard in selected_cards:
		var current: float = card.get_current_values().get("pixel_size", 0.03)
		card.apply_edit("pixel_size", maxf(0.005, current + amount))
		var actor_id: String = card.actor_data.get("id", "")
		modified_cards[actor_id] = card

	_update_tools_panel()


## ============================================================================
## TOGGLES
## ============================================================================

func _toggle_name_labels() -> void:
	show_names = not show_names
	for card: ZooCard in all_cards:
		card.show_name_label(show_names)


func _toggle_id_labels() -> void:
	show_ids = not show_ids
	for card: ZooCard in all_cards:
		card.show_id_label(show_ids)


func _toggle_state_labels() -> void:
	show_states = not show_states
	for card: ZooCard in all_cards:
		card.show_state_label(show_states)


func _toggle_baselines() -> void:
	show_baselines = not show_baselines
	for card: ZooCard in all_cards:
		card.show_baseline(show_baselines)


## ============================================================================
## CAMERA
## ============================================================================

func _handle_camera_input(delta: float) -> void:
	# Don't move camera if Ctrl is held (for Ctrl+S save shortcut)
	if Input.is_key_pressed(KEY_CTRL):
		return

	var move := Vector3.ZERO

	# WASD for camera pan (arrow keys reserved for nudging)
	if Input.is_key_pressed(KEY_W):
		move.z -= 1
	if Input.is_key_pressed(KEY_S):
		move.z += 1
	if Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_key_pressed(KEY_D):
		move.x += 1

	if move.length_squared() > 0:
		move = move.normalized()
		# Rotate movement by camera yaw
		move = move.rotated(Vector3.UP, camera_orbit_angle)
		camera_target += move * CAMERA_SPEED * delta
		_update_camera_position()


func _update_camera_position() -> void:
	var offset := Vector3(
		sin(camera_orbit_angle) * cos(camera_pitch) * camera_distance,
		-sin(camera_pitch) * camera_distance,
		cos(camera_orbit_angle) * cos(camera_pitch) * camera_distance
	)

	camera.position = camera_target + offset
	camera.look_at(camera_target)


func _reset_camera() -> void:
	camera_distance = 20.0
	camera_orbit_angle = 0.0
	camera_pitch = -0.5
	_update_camera_position()


## ============================================================================
## PERSISTENCE
## ============================================================================

func _load_patches() -> void:
	if not FileAccess.file_exists(PATCH_FILE):
		return

	var file := FileAccess.open(PATCH_FILE, FileAccess.READ)
	if not file:
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_warning("[ActorZoo] Failed to parse patches: %s" % json.get_error_message())
		return

	patches = json.data as Dictionary
	print("[ActorZoo] Loaded %d patches from %s" % [patches.size(), PATCH_FILE])


func _save_patches() -> void:
	# Collect all modifications
	for actor_id: String in modified_cards:
		var card: ZooCard = modified_cards[actor_id]
		var patch: Dictionary = card.get_patch_data()
		if not patch.is_empty():
			patches[actor_id] = patch

	# Save to file
	var file := FileAccess.open(PATCH_FILE, FileAccess.WRITE)
	if not file:
		push_error("[ActorZoo] Failed to save patches")
		return

	file.store_string(JSON.stringify(patches, "\t"))
	file.close()

	print("[ActorZoo] Saved %d patches to %s" % [patches.size(), PATCH_FILE])

	# Show status
	var lbl_status: Label = tools_panel.get_node("LblStatus")
	lbl_status.text = "Saved!"

	# Clear status after delay
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		lbl_status.text = ""
	)
