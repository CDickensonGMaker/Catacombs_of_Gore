## prison.gd - Prison system for handling jailed players
## Universal prison that can be placed in any town
## Handles jailing, time-skip release, escape attempts, and item confiscation
class_name Prison
extends StaticBody3D

## Signals
signal player_jailed(player: Node3D)
signal player_released(player: Node3D)
signal player_escaped(player: Node3D)
signal escape_attempted(success: bool)

## Prison configuration
@export var prison_name: String = "Town Jail"
@export var region_id: String = "elder_moor"

## Lock difficulty for escape lockpicking
@export var cell_lock_dc: int = 18  # Hard to pick - it's a prison

## Bribe costs (base multiplier on bounty)
@export var bribe_multiplier: float = 0.5  # Bribe costs 50% of bounty

## Prison cell spawn position (inside the cell)
var cell_spawn_point: Vector3 = Vector3.ZERO

## Release spawn position (outside the jail)
var release_spawn_point: Vector3 = Vector3.ZERO

## Prison geometry nodes
var cell_mesh: Node3D
var cell_door: Node3D
var bars_mesh: MeshInstance3D
var guard_post: Node3D

## Interaction area
var interaction_area: Area3D

## PS1-style materials
var wall_material: StandardMaterial3D
var bars_material: StandardMaterial3D
var floor_material: StandardMaterial3D

## State
var is_player_inside: bool = false
var current_prisoner: Node3D = null

## Guard reference (for bribing)
var jail_guard: Node3D = null

## Lockpick break chance formula (same as doors)
func _get_lockpick_break_chance(lockpicking_skill: int) -> float:
	return maxf(0.10, 0.50 - (lockpicking_skill * 0.04))


func _ready() -> void:
	add_to_group("prisons")
	add_to_group("interactable")

	# Setup collision
	collision_layer = 1  # World layer
	collision_mask = 0

	# Calculate spawn points based on position
	cell_spawn_point = position + Vector3(0, 0, 0)
	release_spawn_point = position + Vector3(5, 0, 0)  # Outside the cell

	# Build the prison structure
	_build_prison()
	_create_interaction_area()

	# Connect to CrimeManager signals
	CrimeManager.player_released.connect(_on_crime_manager_released)


## Build the prison structure
func _build_prison() -> void:
	# Materials
	_create_materials()

	# Cell root
	cell_mesh = Node3D.new()
	cell_mesh.name = "CellStructure"
	add_child(cell_mesh)

	# Floor
	_create_floor()

	# Walls (back and sides)
	_create_walls()

	# Barred front
	_create_bars()

	# Door (barred)
	_create_cell_door()

	# Guard post/area
	_create_guard_post()


## Create PS1-style materials
func _create_materials() -> void:
	# Stone wall material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.3, 0.28, 0.25)  # Dark stone
	wall_material.roughness = 0.95

	# Try to load stone texture
	var stone_tex: Texture2D = load("res://Sprite folders grab bag/stonefloor.png")
	if stone_tex:
		wall_material.albedo_texture = stone_tex
		wall_material.uv1_scale = Vector3(2, 2, 1)
		wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Metal bars material
	bars_material = StandardMaterial3D.new()
	bars_material.albedo_color = Color(0.2, 0.2, 0.22)  # Dark iron
	bars_material.metallic = 0.7
	bars_material.roughness = 0.5

	# Prison floor material
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.25, 0.23, 0.2)  # Dirty stone
	floor_material.roughness = 0.98


## Create floor
func _create_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(4, 0.2, 4)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = floor_material
	floor_mesh.position = Vector3(0, 0.1, 0)
	cell_mesh.add_child(floor_mesh)

	# Add floor collision
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(4, 0.2, 4)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, 0.1, 0)
	add_child(floor_col)


## Create walls
func _create_walls() -> void:
	var wall_height := 3.0
	var wall_thickness := 0.3

	# Back wall
	var back_wall := MeshInstance3D.new()
	back_wall.name = "BackWall"
	var back_box := BoxMesh.new()
	back_box.size = Vector3(4, wall_height, wall_thickness)
	back_wall.mesh = back_box
	back_wall.material_override = wall_material
	back_wall.position = Vector3(0, wall_height / 2, -2 + wall_thickness / 2)
	cell_mesh.add_child(back_wall)

	# Back wall collision
	var back_col := CollisionShape3D.new()
	var back_shape := BoxShape3D.new()
	back_shape.size = Vector3(4, wall_height, wall_thickness)
	back_col.shape = back_shape
	back_col.position = Vector3(0, wall_height / 2, -2 + wall_thickness / 2)
	add_child(back_col)

	# Side walls
	for side in [-1, 1]:
		var side_wall := MeshInstance3D.new()
		side_wall.name = "SideWall_%d" % side
		var side_box := BoxMesh.new()
		side_box.size = Vector3(wall_thickness, wall_height, 4)
		side_wall.mesh = side_box
		side_wall.material_override = wall_material
		side_wall.position = Vector3(side * (2 - wall_thickness / 2), wall_height / 2, 0)
		cell_mesh.add_child(side_wall)

		# Side wall collision
		var side_col := CollisionShape3D.new()
		var side_shape := BoxShape3D.new()
		side_shape.size = Vector3(wall_thickness, wall_height, 4)
		side_col.shape = side_shape
		side_col.position = Vector3(side * (2 - wall_thickness / 2), wall_height / 2, 0)
		add_child(side_col)

	# Ceiling
	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"
	var ceiling_box := BoxMesh.new()
	ceiling_box.size = Vector3(4, 0.3, 4)
	ceiling.mesh = ceiling_box
	ceiling.material_override = wall_material
	ceiling.position = Vector3(0, wall_height + 0.15, 0)
	cell_mesh.add_child(ceiling)


## Create metal bars on front of cell
func _create_bars() -> void:
	bars_mesh = MeshInstance3D.new()
	bars_mesh.name = "Bars"

	# Create a simple bar pattern
	var bar_group := Node3D.new()
	bar_group.name = "BarGroup"

	var bar_spacing := 0.3
	var bar_count := 12  # Number of vertical bars
	var bar_radius := 0.03
	var bar_height := 3.0

	for i in range(bar_count):
		var bar := MeshInstance3D.new()
		bar.name = "Bar_%d" % i
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = bar_radius
		cylinder.bottom_radius = bar_radius
		cylinder.height = bar_height
		bar.mesh = cylinder
		bar.material_override = bars_material

		var x_pos: float = -1.8 + i * bar_spacing
		bar.position = Vector3(x_pos, bar_height / 2, 2)
		bar_group.add_child(bar)

	# Horizontal bars
	for y in [0.5, 1.5, 2.5]:
		var h_bar := MeshInstance3D.new()
		h_bar.name = "HBar_%.1f" % y
		var h_box := BoxMesh.new()
		h_box.size = Vector3(3.6, bar_radius * 2, bar_radius * 2)
		h_bar.mesh = h_box
		h_bar.material_override = bars_material
		h_bar.position = Vector3(0, y, 2)
		bar_group.add_child(h_bar)

	cell_mesh.add_child(bar_group)

	# Bars collision (solid wall - can't pass through)
	var bars_col := CollisionShape3D.new()
	var bars_shape := BoxShape3D.new()
	bars_shape.size = Vector3(4, 3, 0.15)
	bars_col.shape = bars_shape
	bars_col.position = Vector3(0, 1.5, 2)
	add_child(bars_col)


## Create cell door (barred)
func _create_cell_door() -> void:
	cell_door = Node3D.new()
	cell_door.name = "CellDoor"

	# Door frame
	var frame := MeshInstance3D.new()
	frame.name = "DoorFrame"
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(1.2, 2.5, 0.1)
	frame.mesh = frame_box
	frame.material_override = bars_material

	# Door bars
	var door_bars := Node3D.new()
	door_bars.name = "DoorBars"

	for i in range(4):
		var bar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.025
		cylinder.bottom_radius = 0.025
		cylinder.height = 2.3
		bar.mesh = cylinder
		bar.material_override = bars_material
		bar.position = Vector3(-0.4 + i * 0.25, 1.15, 0)
		door_bars.add_child(bar)

	cell_door.add_child(frame)
	cell_door.add_child(door_bars)
	cell_door.position = Vector3(1.7, 0, 2.1)  # Right side of front
	cell_mesh.add_child(cell_door)


## Create guard post outside cell
func _create_guard_post() -> void:
	guard_post = Node3D.new()
	guard_post.name = "GuardPost"

	# Simple desk
	var desk := MeshInstance3D.new()
	desk.name = "Desk"
	var desk_box := BoxMesh.new()
	desk_box.size = Vector3(1.5, 0.8, 0.8)
	desk.mesh = desk_box

	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.4, 0.3, 0.2)  # Wood
	desk_mat.roughness = 0.8
	desk.material_override = desk_mat
	desk.position = Vector3(3.5, 0.4, 0)

	guard_post.add_child(desk)
	add_child(guard_post)


## Create interaction area for cell door
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 1)
	area_shape.shape = box
	area_shape.position = Vector3(1.5, 1.5, 2)  # Near the door

	interaction_area.add_child(area_shape)
	add_child(interaction_area)


## Jail the player - called by guards
func jail_player(player: Node3D) -> void:
	if not player:
		return

	current_prisoner = player
	is_player_inside = true

	# Move player into cell
	player.global_position = global_position + cell_spawn_point + Vector3(0, 0.5, 0)

	# Disable player movement temporarily (handled by CrimeManager.is_jailed flag)

	print("[Prison] Player jailed in %s" % prison_name)
	player_jailed.emit(player)


## Release the player - called when sentence is served or bounty paid
func release_player() -> void:
	if not current_prisoner:
		return

	is_player_inside = false

	# Move player outside
	current_prisoner.global_position = global_position + release_spawn_point

	print("[Prison] Player released from %s" % prison_name)
	player_released.emit(current_prisoner)

	current_prisoner = null


## Handle CrimeManager release signal
func _on_crime_manager_released(released_region_id: String) -> void:
	if released_region_id == region_id and is_player_inside:
		release_player()


## Player interaction with cell door
func interact(_interactor: Node) -> void:
	if not CrimeManager.is_jailed:
		_show_notification("The cell is empty.")
		return

	# Show escape options
	_show_escape_options()


## Get interaction prompt
func get_interaction_prompt() -> String:
	if CrimeManager.is_jailed:
		return "Examine Cell Door (DC %d)" % cell_lock_dc
	return "Cell Door (Empty)"


## Show escape options dialogue
func _show_escape_options() -> void:
	var bounty: int = CrimeManager.get_bounty(region_id)
	var bribe_cost: int = int(bounty * bribe_multiplier)
	var jail_time: float = CrimeManager.jail_time_remaining
	var has_lockpick: bool = _player_has_lockpick()
	var player_gold: int = InventoryManager.gold

	# Create escape options dialogue
	var dialogue := DialogueData.new()
	dialogue.title = "Prison Cell"

	var root_node := DialogueNode.new()
	root_node.id = "escape_root"
	root_node.speaker = ""
	root_node.text = "You are locked in a prison cell. Time remaining: %.1f hours.\n\nWhat will you do?" % jail_time

	# Build choices based on what's available
	var choices: Array[DialogueChoice] = []

	# Wait option (always available)
	var wait_choice := DialogueChoice.new()
	wait_choice.text = "Wait out your sentence (%.1f hours)" % jail_time
	wait_choice.next_node_id = "wait"
	choices.append(wait_choice)

	# Lockpick option
	var lockpick_choice := DialogueChoice.new()
	if has_lockpick:
		lockpick_choice.text = "Try to pick the lock (DC %d)" % cell_lock_dc
	else:
		lockpick_choice.text = "Pick the lock (No lockpicks)"
	lockpick_choice.next_node_id = "lockpick"
	choices.append(lockpick_choice)

	# Bribe option
	var bribe_choice := DialogueChoice.new()
	if player_gold >= bribe_cost:
		bribe_choice.text = "Bribe the guard (%d gold)" % bribe_cost
	else:
		bribe_choice.text = "Bribe the guard (%d gold - Not enough)" % bribe_cost
	bribe_choice.next_node_id = "bribe"
	choices.append(bribe_choice)

	# Cancel
	var cancel_choice := DialogueChoice.new()
	cancel_choice.text = "Do nothing"
	cancel_choice.next_node_id = "cancel"
	choices.append(cancel_choice)

	root_node.choices = choices

	# Response nodes
	var wait_node := DialogueNode.new()
	wait_node.id = "wait"
	wait_node.speaker = ""
	wait_node.text = "You decide to wait out your sentence..."
	wait_node.is_end_node = true

	var lockpick_node := DialogueNode.new()
	lockpick_node.id = "lockpick"
	lockpick_node.speaker = ""
	lockpick_node.text = "You examine the lock..."
	lockpick_node.is_end_node = true

	var bribe_node := DialogueNode.new()
	bribe_node.id = "bribe"
	bribe_node.speaker = ""
	bribe_node.text = "You try to get the guard's attention..."
	bribe_node.is_end_node = true

	var cancel_node := DialogueNode.new()
	cancel_node.id = "cancel"
	cancel_node.speaker = ""
	cancel_node.text = "You step back from the door."
	cancel_node.is_end_node = true

	dialogue.nodes = [root_node, wait_node, lockpick_node, bribe_node, cancel_node]
	dialogue.start_node_id = "escape_root"

	# Connect signals
	if not DialogueManager.node_changed.is_connected(_on_escape_node_changed):
		DialogueManager.node_changed.connect(_on_escape_node_changed)
	if not DialogueManager.dialogue_ended.is_connected(_on_escape_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_escape_dialogue_ended)

	DialogueManager.start_dialogue(dialogue, "")


var _escape_choice: String = ""

func _on_escape_node_changed(node: DialogueNode) -> void:
	if node:
		_escape_choice = node.id


func _on_escape_dialogue_ended(_dialogue_data: DialogueData) -> void:
	# Disconnect signals
	if DialogueManager.node_changed.is_connected(_on_escape_node_changed):
		DialogueManager.node_changed.disconnect(_on_escape_node_changed)
	if DialogueManager.dialogue_ended.is_connected(_on_escape_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_escape_dialogue_ended)

	# Process choice
	match _escape_choice:
		"wait":
			_handle_wait()
		"lockpick":
			_handle_lockpick_attempt()
		"bribe":
			_handle_bribe_attempt()
		"cancel":
			pass  # Do nothing

	_escape_choice = ""


## Handle waiting out sentence (time skip)
func _handle_wait() -> void:
	# Skip remaining jail time
	CrimeManager.skip_jail_time()
	_show_notification("Time passes... You have served your sentence.")


## Handle lockpick escape attempt
func _handle_lockpick_attempt() -> void:
	if not _player_has_lockpick():
		_show_notification("You need a lockpick!")
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	var lockpicking_skill: int = char_data.get_skill(Enums.Skill.LOCKPICKING)
	var agility: int = char_data.get_effective_stat(Enums.Stat.AGILITY)

	# Check lockpick break
	var break_chance := _get_lockpick_break_chance(lockpicking_skill)
	var lockpick_broke := randf() < break_chance

	# Consume lockpick
	_consume_lockpick()

	if lockpick_broke:
		_show_notification("The lockpick broke!")
		escape_attempted.emit(false)
		return

	# Lockpick check using DiceManager
	var roll_result: Dictionary = DiceManager.lockpick_check(
		agility,
		lockpicking_skill,
		cell_lock_dc,
		1.5  # Standard lockpick bonus
	)

	if roll_result.success:
		# Successful escape
		_show_notification("You picked the lock and escaped!")
		_escape_from_jail()
		escape_attempted.emit(true)
	else:
		_show_notification("Failed to pick the lock...")
		escape_attempted.emit(false)


## Handle bribe attempt
func _handle_bribe_attempt() -> void:
	var bounty: int = CrimeManager.get_bounty(region_id)
	var bribe_cost: int = int(bounty * bribe_multiplier)

	if InventoryManager.gold < bribe_cost:
		_show_notification("You don't have enough gold to bribe the guard.")
		return

	# Pay the bribe
	InventoryManager.remove_gold(bribe_cost)

	# Optional: Speech skill check for reduced bribe
	var char_data := GameManager.player_data
	if char_data:
		var speech: int = char_data.get_effective_stat(Enums.Stat.SPEECH)
		var negotiation: int = char_data.get_skill(Enums.Skill.NEGOTIATION)

		# High negotiation = chance to get some gold back
		var refund_chance: float = (negotiation * 0.05) + (speech * 0.02)
		if randf() < refund_chance:
			var refund: int = int(bribe_cost * 0.3)
			InventoryManager.add_gold(refund)
			_show_notification("The guard accepts your bribe. You negotiated %d gold back." % refund)
		else:
			_show_notification("The guard accepts your bribe and looks the other way...")
	else:
		_show_notification("The guard accepts your bribe and looks the other way...")

	# Escape without adding to bounty (bribe is a "clean" escape)
	_bribe_escape()


## Escape from jail (adds bounty)
func _escape_from_jail() -> void:
	CrimeManager.on_jail_escape(region_id)
	is_player_inside = false

	if current_prisoner:
		current_prisoner.global_position = global_position + release_spawn_point
		player_escaped.emit(current_prisoner)
		current_prisoner = null


## Escape via bribe (no bounty added)
func _bribe_escape() -> void:
	# Clear bounty and release (bribe counts as "legal" release)
	CrimeManager.clear_bounty(region_id)

	# Return confiscated items
	if CrimeManager.confiscated_items.has(region_id):
		var items: Array = CrimeManager.confiscated_items[region_id]
		for item in items:
			var item_id: String = item.get("item_id", "")
			var quality: Enums.ItemQuality = item.get("quality", Enums.ItemQuality.AVERAGE)
			if not item_id.is_empty():
				InventoryManager.add_item(item_id, 1, quality)
		CrimeManager.confiscated_items.erase(region_id)

	# Reset jail state
	CrimeManager.is_jailed = false
	CrimeManager.jail_region = ""
	CrimeManager.jail_time_remaining = 0.0

	is_player_inside = false
	if current_prisoner:
		current_prisoner.global_position = global_position + release_spawn_point
		player_released.emit(current_prisoner)
		current_prisoner = null


## Check if player has lockpick
func _player_has_lockpick() -> bool:
	for slot in InventoryManager.inventory:
		if slot.item_id == "lockpick" and slot.quantity > 0:
			return true
	return false


## Consume a lockpick
func _consume_lockpick() -> void:
	InventoryManager.remove_item("lockpick", 1)


## Show notification
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Static factory method for spawning prisons
static func spawn_prison(parent: Node, pos: Vector3, p_name: String = "Town Jail", p_region_id: String = "elder_moor") -> Prison:
	var prison := Prison.new()
	prison.position = pos
	prison.prison_name = p_name
	prison.region_id = p_region_id

	parent.add_child(prison)
	return prison
