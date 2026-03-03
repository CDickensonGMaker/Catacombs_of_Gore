## torch_light.gd - Manages torch light emission and durability depletion
## Attach to: Player (as child node)
class_name TorchLight
extends Node3D

const DEBUG := false

## Light configuration
@export var light_energy: float = 2.5  ## Brightness of the torch (increased 67%)
@export var light_range: float = 22.0  ## Range in world units (increased 47%)
@export var light_color: Color = Color(1.0, 0.85, 0.6)  ## Warm orange/yellow
@export var flicker_enabled: bool = true  ## Enable realistic flickering
@export var flicker_speed: float = 8.0  ## How fast the flicker oscillates
@export var flicker_intensity: float = 0.15  ## How much the light varies (0-1)

## Durability (9 minutes = 540 seconds)
const TORCH_MAX_DURABILITY := 540
const DURABILITY_DRAIN_PER_SECOND := 1.0

## Runtime state
var torch_light: OmniLight3D = null
var is_torch_equipped: bool = false
var durability_drain_accumulator: float = 0.0
var flicker_time: float = 0.0
var base_energy: float = 0.0

## Reference to player
var player: Node3D = null


func _ready() -> void:
	# Get player reference (parent)
	player = get_parent() as Node3D

	# Connect to equipment changes
	if InventoryManager:
		InventoryManager.equipment_changed.connect(_on_equipment_changed)
		# Check if torch is already equipped (e.g., after scene load)
		_check_current_equipment()

	if DEBUG:
		print("[TorchLight] Initialized")


func _process(delta: float) -> void:
	if not is_torch_equipped or not torch_light:
		return

	# Don't process if paused or in menu
	if GameManager and (GameManager.is_in_menu or GameManager.is_paused):
		return

	# Flicker effect
	if flicker_enabled:
		flicker_time += delta * flicker_speed
		var flicker := 1.0 + sin(flicker_time) * flicker_intensity * 0.5
		flicker += randf_range(-flicker_intensity * 0.3, flicker_intensity * 0.3)
		torch_light.light_energy = base_energy * flicker

	# Deplete durability
	_deplete_durability(delta)


## Check current equipment state (for initialization/scene load)
func _check_current_equipment() -> void:
	if not InventoryManager or not InventoryManager.equipment:
		return

	var off_hand: Dictionary = InventoryManager.equipment.get("off_hand", {})
	if off_hand.is_empty():
		_hide_torch_light()
		return

	var item_id: String = off_hand.get("item_id", "")
	if item_id == "torch":
		_show_torch_light()
	else:
		_hide_torch_light()


## Handle equipment changes
func _on_equipment_changed(slot: String, _old_item: Dictionary, new_item: Dictionary) -> void:
	if slot != "off_hand":
		return

	if new_item.is_empty():
		_hide_torch_light()
		return

	var item_id: String = new_item.get("item_id", "")
	if item_id == "torch":
		_show_torch_light()
	else:
		_hide_torch_light()


## Create and show the torch light
func _show_torch_light() -> void:
	if is_torch_equipped:
		return  # Already showing

	is_torch_equipped = true
	durability_drain_accumulator = 0.0

	# Create light if it doesn't exist
	if not torch_light:
		torch_light = OmniLight3D.new()
		torch_light.name = "TorchOmniLight"
		add_child(torch_light)

	# Configure light
	torch_light.light_color = light_color
	torch_light.light_energy = light_energy
	torch_light.omni_range = light_range
	torch_light.omni_attenuation = 1.5  # Smooth falloff
	torch_light.shadow_enabled = true
	torch_light.visible = true

	# Position slightly in front and above player
	torch_light.position = Vector3(0.3, 1.5, -0.3)

	base_energy = light_energy
	flicker_time = 0.0

	if DEBUG:
		print("[TorchLight] Torch equipped - light enabled")


## Hide the torch light
func _hide_torch_light() -> void:
	if not is_torch_equipped:
		return  # Already hidden

	is_torch_equipped = false

	if torch_light:
		torch_light.visible = false

	if DEBUG:
		print("[TorchLight] Torch unequipped - light disabled")


## Deplete torch durability over time
func _deplete_durability(delta: float) -> void:
	durability_drain_accumulator += delta * DURABILITY_DRAIN_PER_SECOND

	# Only update when we've accumulated at least 1 durability point
	if durability_drain_accumulator < 1.0:
		return

	var drain_amount := int(durability_drain_accumulator)
	durability_drain_accumulator -= float(drain_amount)

	# Validate InventoryManager exists
	if not InventoryManager or not InventoryManager.equipment:
		return

	# Get current torch durability from equipment
	var off_hand: Dictionary = InventoryManager.equipment.get("off_hand", {})
	if off_hand.is_empty() or off_hand.get("item_id", "") != "torch":
		return

	var current_durability: int = off_hand.get("durability", TORCH_MAX_DURABILITY)
	current_durability -= drain_amount

	# Update durability in equipment
	off_hand["durability"] = max(0, current_durability)

	if DEBUG and current_durability % 60 == 0:  # Log every minute
		var minutes_left := current_durability / 60
		print("[TorchLight] Torch durability: %d seconds (%d minutes remaining)" % [current_durability, minutes_left])

	# Check if torch burned out
	if current_durability <= 0:
		_torch_burned_out()


## Handle torch burning out
func _torch_burned_out() -> void:
	if DEBUG:
		print("[TorchLight] Torch burned out!")

	# Hide the light
	_hide_torch_light()

	# Remove torch from equipment (it's consumed)
	InventoryManager.equipment["off_hand"] = {}
	InventoryManager.equipment_changed.emit("off_hand", {"item_id": "torch"}, {})

	# Notify player via HUD
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Your torch has burned out!")

	# Play sound effect if available
	if AudioManager:
		AudioManager.play_sfx("torch_extinguish")


## Get remaining torch time in seconds
func get_remaining_time() -> int:
	if not is_torch_equipped:
		return 0

	if not InventoryManager or not InventoryManager.equipment:
		return 0

	var off_hand: Dictionary = InventoryManager.equipment.get("off_hand", {})
	if off_hand.is_empty():
		return 0

	return off_hand.get("durability", 0)


## Get remaining torch time as formatted string (M:SS)
func get_remaining_time_string() -> String:
	var seconds := get_remaining_time()
	var minutes := seconds / 60
	var secs := seconds % 60
	return "%d:%02d" % [minutes, secs]
