## chest.gd - Container that can hold items and optionally be locked
## Lockpicking follows tabletop rules: Agility + d10 + Lockpicking skill + lockpick bonus vs DC
class_name Chest
extends StaticBody3D

const DEBUG := true

## Signals
signal opened
signal lockpick_success
signal lockpick_failed
signal lockpick_broke

## Visual representation
var mesh_root: Node3D
var body_mesh: MeshInstance3D
var lid_mesh: MeshInstance3D
var interaction_area: Area3D

## Chest configuration
@export var chest_name: String = "Chest"
@export var chest_id: String = ""  # Unique ID for persistence (leave empty for non-persistent)
@export var is_persistent: bool = false  # If true, contents are saved/loaded
@export var is_locked: bool = false
@export var lock_difficulty: int = 10  # DC for lockpicking check
@export var is_trapped: bool = false  # Future use
@export var trap_damage: int = 0  # Future use

## Contents: Array of {item_id: String, quantity: int, quality: Enums.ItemQuality}
var contents: Array[Dictionary] = []

## Has this chest been opened before?
var has_been_opened: bool = false

## Reference to open UI canvas (for cleanup on disappear)
var _active_ui_canvas: CanvasLayer = null

## PS1-style materials
var chest_material: StandardMaterial3D
var metal_material: StandardMaterial3D

## Lockpick bonus constant (15% = 1.5 on a d10 scale)
const LOCKPICK_BONUS: float = 1.5

## Lockpick break chance formula: max(10%, 50% - (lockpicking_skill * 4%))
func _get_lockpick_break_chance(lockpicking_skill: int) -> float:
	return maxf(0.10, 0.50 - (lockpicking_skill * 0.04))


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("chests")

	# Setup collision for player interaction detection
	collision_layer = 1  # World layer for physics
	collision_mask = 0   # Don't collide with anything

	# Check if mesh already exists (from .tscn scene) before creating
	mesh_root = get_node_or_null("MeshRoot")
	if not mesh_root:
		_create_chest_mesh()
	else:
		# Get references to existing meshes
		body_mesh = mesh_root.get_node_or_null("BodyMesh")
		lid_mesh = mesh_root.get_node_or_null("LidMesh")
		# Add lock indicator if locked
		if is_locked:
			_add_lock_indicator()

	_create_interaction_area()

	# Load persistent chest contents if applicable
	if is_persistent and not chest_id.is_empty():
		_load_persistent_contents()


func _create_chest_mesh() -> void:
	## Create a simple chest mesh (wooden box with metal trim)

	# Wood material (brown)
	chest_material = StandardMaterial3D.new()
	chest_material.albedo_color = Color(0.45, 0.3, 0.15)
	chest_material.roughness = 0.9

	# Metal material for trim
	metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.3, 0.3, 0.35)
	metal_material.roughness = 0.5
	metal_material.metallic = 0.6

	# Root for the mesh
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# Main body (box)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.5, 0.5)
	body_mesh.mesh = box
	body_mesh.material_override = chest_material
	body_mesh.position = Vector3(0, 0.25, 0)
	mesh_root.add_child(body_mesh)

	# Lid (slightly raised if unlocked/opened)
	lid_mesh = MeshInstance3D.new()
	lid_mesh.name = "LidMesh"
	var lid := BoxMesh.new()
	lid.size = Vector3(0.85, 0.1, 0.55)
	lid_mesh.mesh = lid
	lid_mesh.material_override = metal_material
	lid_mesh.position = Vector3(0, 0.55, 0)
	mesh_root.add_child(lid_mesh)

	# Add lock indicator if locked
	if is_locked:
		_add_lock_indicator()


func _add_lock_indicator() -> void:
	## Visual indicator that chest is locked (small cube on front)
	# Check if already exists (from .tscn scene)
	if mesh_root and mesh_root.get_node_or_null("LockIndicator"):
		return

	var lock_mesh := MeshInstance3D.new()
	lock_mesh.name = "LockIndicator"
	var lock_box := BoxMesh.new()
	lock_box.size = Vector3(0.1, 0.15, 0.1)
	lock_mesh.mesh = lock_box

	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.7, 0.6, 0.2)  # Gold/brass color
	lock_mat.metallic = 0.8
	lock_mesh.material_override = lock_mat
	lock_mesh.position = Vector3(0, 0.3, 0.3)  # Front of chest
	mesh_root.add_child(lock_mesh)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.8, 0.7)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0.4, 0)
	interaction_area.add_child(area_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	if is_locked:
		_attempt_lockpick()
	else:
		_open_chest_ui()


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if is_locked:
		return "Pick Lock on %s (DC %d)" % [chest_name, lock_difficulty]
	return "Open " + chest_name


## Attempt to pick the lock
func _attempt_lockpick() -> void:
	var char_data := GameManager.player_data
	if not char_data:
		_show_notification("No character data!")
		return

	# Check if player has a lockpick
	var has_lockpick := _player_has_lockpick()

	if not has_lockpick:
		_show_notification("You need a lockpick!")
		return

	# Get lockpicking skill
	var lockpicking_skill: int = char_data.get_skill(Enums.Skill.LOCKPICKING)
	var agility: int = char_data.get_effective_stat(Enums.Stat.AGILITY)

	# Check if lockpick breaks BEFORE the attempt
	var break_chance := _get_lockpick_break_chance(lockpicking_skill)
	var lockpick_broke := randf() < break_chance

	# Consume the lockpick (always consumed on use)
	_consume_lockpick()

	if lockpick_broke:
		_show_notification("The lockpick broke!")
		self.lockpick_broke.emit()
		# AudioManager.play_lockpick_break()  # Hook for future audio
		return

	# Use DiceManager for transparent roll display
	var roll_result: Dictionary = DiceManager.lockpick_check(
		agility,
		lockpicking_skill,
		lock_difficulty,
		LOCKPICK_BONUS
	)

	if DEBUG:
		print("[Chest] Lockpick attempt: total=%d vs DC %d, success=%s" % [
			roll_result.total, lock_difficulty, roll_result.success
		])

	if roll_result.success:
		# Success!
		is_locked = false
		_remove_lock_indicator()

		# Award XP for successful DC check: XP = DC × 5, scaled by Knowledge multiplier
		var xp_reward: int = lock_difficulty * 5
		if GameManager.player_data:
			xp_reward = int(xp_reward * GameManager.player_data.get_xp_multiplier())
			GameManager.player_data.add_ip(xp_reward)
			_show_notification("Lock picked! (+%d XP)" % xp_reward)
		else:
			_show_notification("Lock picked!")

		lockpick_success.emit()
		# AudioManager.play_lockpick_success()  # Hook for future audio

		# Auto-open the chest after picking
		_open_chest_ui()
	else:
		# Failed
		_show_notification("Failed to pick the lock...")
		lockpick_failed.emit()
		# AudioManager.play_lockpick_fail()  # Hook for future audio


## Check if player has a lockpick in inventory
func _player_has_lockpick() -> bool:
	for slot in InventoryManager.inventory:
		if slot.item_id == "lockpick" and slot.quantity > 0:
			return true
	return false


## Consume one lockpick from inventory
func _consume_lockpick() -> void:
	InventoryManager.remove_item("lockpick", 1)


## Remove the visual lock indicator
func _remove_lock_indicator() -> void:
	var lock_indicator := mesh_root.get_node_or_null("LockIndicator")
	if lock_indicator:
		lock_indicator.queue_free()


## Open the chest UI
func _open_chest_ui() -> void:
	if not has_been_opened:
		has_been_opened = true
		opened.emit()

	# Load and instantiate chest UI
	var chest_ui_script := preload("res://scripts/ui/chest_ui.gd")
	var chest_ui := Control.new()
	chest_ui.set_script(chest_ui_script)
	chest_ui.name = "ChestUI"

	# Pass chest reference
	chest_ui.set("chest", self)

	# Add to CanvasLayer
	var canvas := CanvasLayer.new()
	canvas.name = "ChestUICanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(chest_ui)

	# Store reference for cleanup
	_active_ui_canvas = canvas

	# Connect close signal
	if chest_ui.has_signal("ui_closed"):
		chest_ui.ui_closed.connect(_on_chest_ui_closed.bind(canvas))

	# Enter menu mode
	GameManager.enter_menu()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Open the UI
	if chest_ui.has_method("open"):
		chest_ui.open()


func _on_chest_ui_closed(canvas: CanvasLayer) -> void:
	## Handle chest UI close
	GameManager.exit_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	_active_ui_canvas = null

	# AudioManager.play_ui_close()  # Hook for future audio


## Show a notification to the player
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Add an item to the chest
func add_item(item_id: String, quantity: int = 1, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> void:
	# Check if stackable and already exists
	for slot in contents:
		if slot.item_id == item_id and slot.quality == quality:
			slot.quantity += quantity
			_save_if_persistent()
			return

	# Add new slot
	contents.append({
		"item_id": item_id,
		"quantity": quantity,
		"quality": quality
	})
	_save_if_persistent()


## Remove an item from the chest
func remove_item(item_id: String, quantity: int = 1, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> bool:
	for i in range(contents.size()):
		var slot: Dictionary = contents[i]
		if slot.item_id == item_id and slot.quality == quality:
			if slot.quantity >= quantity:
				slot.quantity -= quantity
				if slot.quantity <= 0:
					contents.remove_at(i)
				_save_if_persistent()
				_check_if_should_disappear()
				return true
			return false
	return false


## Non-persistent chests disappear when emptied
func _check_if_should_disappear() -> void:
	if is_persistent:
		return  # Persistent chests never disappear
	if contents.is_empty() and has_been_opened:
		if DEBUG:
			print("[Chest] %s is empty and will disappear" % chest_name)

		# Close UI first if open (prevents game freeze)
		if _active_ui_canvas and is_instance_valid(_active_ui_canvas):
			# Manually handle UI close before freeing
			GameManager.exit_menu()
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_active_ui_canvas.queue_free()
			_active_ui_canvas = null

		# Delay slightly so UI cleanup can complete
		call_deferred("queue_free")


## Load contents from SaveManager if persistent
func _load_persistent_contents() -> void:
	if not is_persistent or chest_id.is_empty():
		return
	var saved: Array = SaveManager.load_chest_contents(chest_id)
	if not saved.is_empty():
		contents.clear()
		for item in saved:
			contents.append(item)
		if DEBUG:
			print("[Chest] Loaded %d items from persistent storage for %s" % [contents.size(), chest_id])


## Save contents to SaveManager if persistent
func _save_if_persistent() -> void:
	if not is_persistent or chest_id.is_empty():
		return
	var save_data: Array = []
	for slot in contents:
		save_data.append({
			"item_id": slot.item_id,
			"quantity": slot.quantity,
			"quality": slot.quality
		})
	SaveManager.save_chest_contents(chest_id, save_data)
	if DEBUG:
		print("[Chest] Saved %d items to persistent storage for %s" % [save_data.size(), chest_id])


## Setup chest with random loot based on tier
func setup_with_loot(tier: LootTables.LootTier, luck_modifier: int = 0) -> void:
	var loot: Array[Dictionary] = LootTables.generate_chest_loot(tier, luck_modifier)

	for item in loot:
		if item.item_id == "_gold":
			# Gold is handled separately by the UI or directly added to player
			InventoryManager.add_gold(item.quantity)
		else:
			add_item(item.item_id, item.quantity, item.quality)


## Static factory method for spawning chests
static func spawn_chest(parent: Node, pos: Vector3, p_chest_name: String = "Chest", p_locked: bool = false, p_lock_dc: int = 10, p_persistent: bool = false, p_chest_id: String = "") -> Chest:
	var instance := Chest.new()
	instance.position = pos
	instance.chest_name = p_chest_name
	instance.is_locked = p_locked
	instance.lock_difficulty = p_lock_dc
	instance.is_persistent = p_persistent
	instance.chest_id = p_chest_id

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.5, 0.5)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.25, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
