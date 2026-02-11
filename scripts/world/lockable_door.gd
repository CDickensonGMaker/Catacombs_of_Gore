## lockable_door.gd - Lockpickable door for houses (theft/robbery system)
## Uses same lockpicking rules as chests: Agility + d10 + Lockpicking skill vs DC
class_name LockableDoor
extends StaticBody3D

const DEBUG := true

## Signals
signal lockpick_success
signal lockpick_failed
signal lockpick_broke

## Visual representation
var door_mesh: MeshInstance3D
var frame_mesh: MeshInstance3D
var interaction_area: Area3D
var lock_indicator: MeshInstance3D

## Door configuration
@export var door_name: String = "Door"
@export var is_locked: bool = true
@export var lock_difficulty: int = 12  # DC for lockpicking check

## House interior loot (spawned when first opened)
var has_been_searched: bool = false
var house_loot: Array[Dictionary] = []

## PS1-style materials
var door_material: StandardMaterial3D
var frame_material: StandardMaterial3D

## Lockpick bonus constant (same as chest)
const LOCKPICK_BONUS: float = 1.5

## Lockpick break chance formula: max(10%, 50% - (lockpicking_skill * 4%))
func _get_lockpick_break_chance(lockpicking_skill: int) -> float:
	return maxf(0.10, 0.50 - (lockpicking_skill * 0.04))


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("doors")

	# Setup collision
	collision_layer = 1  # World layer
	collision_mask = 0   # Don't collide with anything

	_create_door_mesh()
	_create_interaction_area()

	# Generate house loot
	_generate_house_loot()


func _create_door_mesh() -> void:
	## Create a simple wooden door with frame

	# Door material (dark wood)
	door_material = StandardMaterial3D.new()
	door_material.albedo_color = Color(0.35, 0.25, 0.15)
	door_material.roughness = 0.85

	# Frame material (slightly lighter wood)
	frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.4, 0.3, 0.2)
	frame_material.roughness = 0.8

	# Door frame
	frame_mesh = MeshInstance3D.new()
	frame_mesh.name = "FrameMesh"
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(0.15, 2.2, 1.2)
	frame_mesh.mesh = frame_box
	frame_mesh.material_override = frame_material
	frame_mesh.position = Vector3(0, 1.1, 0)
	add_child(frame_mesh)

	# Door panel
	door_mesh = MeshInstance3D.new()
	door_mesh.name = "DoorMesh"
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.1, 2.0, 1.0)
	door_mesh.mesh = door_box
	door_mesh.material_override = door_material
	door_mesh.position = Vector3(0.05, 1.0, 0)
	add_child(door_mesh)

	# Lock indicator
	if is_locked:
		_add_lock_indicator()


func _add_lock_indicator() -> void:
	## Visual indicator that door is locked
	lock_indicator = MeshInstance3D.new()
	lock_indicator.name = "LockIndicator"
	var lock_box := BoxMesh.new()
	lock_box.size = Vector3(0.08, 0.12, 0.08)
	lock_indicator.mesh = lock_box

	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.7, 0.6, 0.2)  # Gold/brass
	lock_mat.metallic = 0.8
	lock_indicator.material_override = lock_mat
	lock_indicator.position = Vector3(0.12, 1.0, 0.35)  # On front of door
	add_child(lock_indicator)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2.5, 1.5)
	area_shape.shape = box
	area_shape.position = Vector3(0, 1.25, 0)
	interaction_area.add_child(area_shape)


func _generate_house_loot() -> void:
	## Generate random loot for this house
	## Small chance of valuable items, mostly mundane stuff

	var loot_count := randi_range(1, 4)

	# Possible house loot items (only items that exist in database)
	var common_items := [
		{"item_id": "bread", "weight": 30},
		{"item_id": "cheese", "weight": 25},
		{"item_id": "ale", "weight": 20},
		{"item_id": "cooked_meat", "weight": 15},
		{"item_id": "leather_strip", "weight": 10},
	]

	var uncommon_items := [
		{"item_id": "health_potion", "weight": 25},
		{"item_id": "lockpick", "weight": 20},
		{"item_id": "repair_kit", "weight": 15},
		{"item_id": "mana_potion", "weight": 10},
		{"item_id": "_gold", "weight": 30},  # Special gold handling
	]

	for i in range(loot_count):
		var roll := randf()
		var items: Array
		if roll < 0.7:
			items = common_items
		else:
			items = uncommon_items

		# Weighted random selection
		var total_weight := 0
		for item in items:
			total_weight += item.weight

		var weight_roll := randi() % total_weight
		var cumulative := 0
		for item in items:
			cumulative += item.weight
			if weight_roll < cumulative:
				var quantity := 1
				if item.item_id == "_gold":
					quantity = randi_range(5, 25)
				elif item.item_id == "lockpick":
					quantity = randi_range(1, 2)
				house_loot.append({
					"item_id": item.item_id,
					"quantity": quantity,
					"quality": Enums.ItemQuality.AVERAGE
				})
				break


## Called by player interaction system
func interact(_interactor: Node) -> void:
	if is_locked:
		_attempt_lockpick()
	elif not has_been_searched:
		_search_house()
	else:
		_show_notification("Already searched.")


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if is_locked:
		return "Pick Lock on %s (DC %d)" % [door_name, lock_difficulty]
	elif not has_been_searched:
		return "Search " + door_name
	return door_name + " (Empty)"


## Attempt to pick the lock
func _attempt_lockpick() -> void:
	var char_data := GameManager.player_data
	if not char_data:
		_show_notification("No character data!")
		return

	# Check if player has a lockpick
	if not _player_has_lockpick():
		_show_notification("You need a lockpick!")
		return

	# Get lockpicking skill
	var lockpicking_skill: int = char_data.get_skill(Enums.Skill.LOCKPICKING)
	var agility: int = char_data.get_effective_stat(Enums.Stat.AGILITY)

	# Check if lockpick breaks BEFORE the attempt
	var break_chance := _get_lockpick_break_chance(lockpicking_skill)
	var lockpick_broke := randf() < break_chance

	# Consume the lockpick
	_consume_lockpick()

	if lockpick_broke:
		_show_notification("The lockpick broke!")
		self.lockpick_broke.emit()
		return

	# Use DiceManager for transparent roll display
	var roll_result: Dictionary = DiceManager.lockpick_check(
		agility,
		lockpicking_skill,
		lock_difficulty,
		LOCKPICK_BONUS
	)

	if DEBUG:
		print("[Door] Lockpick attempt: total=%d vs DC %d, success=%s" % [
			roll_result.total, lock_difficulty, roll_result.success
		])

	if roll_result.success:
		# Success!
		is_locked = false
		_remove_lock_indicator()

		# Award XP
		var xp_reward: int = lock_difficulty * 5
		if GameManager.player_data:
			xp_reward = int(xp_reward * GameManager.player_data.get_xp_multiplier())
			GameManager.player_data.add_ip(xp_reward)
			_show_notification("Lock picked! (+%d XP)" % xp_reward)
		else:
			_show_notification("Lock picked!")

		lockpick_success.emit()

		# Auto-search after picking
		_search_house()
	else:
		_show_notification("Failed to pick the lock...")
		lockpick_failed.emit()


## Search the house for loot
func _search_house() -> void:
	if has_been_searched:
		_show_notification("Already searched.")
		return

	has_been_searched = true

	if house_loot.is_empty():
		_show_notification("Found nothing of value.")
		return

	# Give loot to player
	var loot_summary := []
	for item in house_loot:
		if item.item_id == "_gold":
			InventoryManager.add_gold(item.quantity)
			loot_summary.append("%d gold" % item.quantity)
		else:
			InventoryManager.add_item(item.item_id, item.quantity, item.quality)
			var item_name: String = InventoryManager.get_item_name(item.item_id)
			if not item_name.is_empty():
				loot_summary.append("%dx %s" % [item.quantity, item_name])

	if not loot_summary.is_empty():
		_show_notification("Found: " + ", ".join(loot_summary))

	if DEBUG:
		print("[Door] House searched, found %d items" % house_loot.size())


func _player_has_lockpick() -> bool:
	for slot in InventoryManager.inventory:
		if slot.item_id == "lockpick" and slot.quantity > 0:
			return true
	return false


func _consume_lockpick() -> void:
	InventoryManager.remove_item("lockpick", 1)


func _remove_lock_indicator() -> void:
	if lock_indicator:
		lock_indicator.queue_free()
		lock_indicator = null


func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Static factory method
static func spawn_door(parent: Node, pos: Vector3, p_door_name: String = "Door", p_lock_dc: int = 12) -> LockableDoor:
	var instance := LockableDoor.new()
	instance.position = pos
	instance.door_name = p_door_name
	instance.lock_difficulty = p_lock_dc
	instance.is_locked = true

	# Add collision shape
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.2, 1.2)
	col_shape.shape = box
	col_shape.position = Vector3(0, 1.1, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
