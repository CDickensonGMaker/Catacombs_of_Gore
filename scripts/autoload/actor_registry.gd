## actor_registry.gd - Unified sprite/actor configuration system
## Loads base actor data from ZooRegistry and merges any user patches from the Actor Zoo tool.
##
## IMPORTANT: When you fix sprite settings in the Actor Zoo (dev/zoo/), those changes
## are saved to user://zoo_patches.json. This autoload loads those patches automatically
## and applies them throughout the game, ensuring sprite fixes are consistently applied
## to all spawning systems (encounter_manager.gd, civilian_npc.gd, quest_giver.gd, etc.)
##
## Usage:
##   var config = ActorRegistry.get_actor_config("skeleton")
##   if config:
##       sprite_texture = load(config.sprite_path)
##       h_frames = config.h_frames
##       v_frames = config.v_frames
##       pixel_size = config.pixel_size
##
extends Node

## Signal emitted when patches are loaded or updated
signal patches_loaded(patch_count: int)

## Path to the zoo patches file (saved by Actor Zoo tool)
const ZOO_PATCHES_PATH := "user://zoo_patches.json"

## Cached actor configurations (base + patches merged)
var _actor_configs: Dictionary = {}

## Raw patches loaded from file
var _patches: Dictionary = {}

## Whether the registry has been initialized
var _initialized: bool = false


func _ready() -> void:
	_load_registry()


## Load the registry from ZooRegistry and apply any patches
func _load_registry() -> void:
	_actor_configs.clear()

	# Load base data from ZooRegistry
	_load_base_data()

	# Load and apply patches
	_load_patches()

	_initialized = true
	print("[ActorRegistry] Initialized with %d actors (%d patches applied)" % [
		_actor_configs.size(),
		_patches.size()
	])


## Load base actor data from ZooRegistry
func _load_base_data() -> void:
	# Load all actors from ZooRegistry arrays
	var all_actors: Array[Dictionary] = ZooRegistry.get_all_actors()

	for actor: Dictionary in all_actors:
		var actor_id: String = actor.get("id", "")
		if not actor_id.is_empty():
			_actor_configs[actor_id] = actor.duplicate()


## Load patches from the zoo patches file
func _load_patches() -> void:
	_patches.clear()

	if not FileAccess.file_exists(ZOO_PATCHES_PATH):
		# No patches file - that's fine, we just use base data
		return

	var file := FileAccess.open(ZOO_PATCHES_PATH, FileAccess.READ)
	if not file:
		push_warning("[ActorRegistry] Failed to open patches file: %s" % ZOO_PATCHES_PATH)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_warning("[ActorRegistry] Failed to parse patches JSON: %s" % json.get_error_message())
		return

	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("[ActorRegistry] Patches file root is not a Dictionary")
		return

	_patches = data as Dictionary

	# Apply patches to actor configs
	for actor_id: String in _patches.keys():
		var patch: Dictionary = _patches[actor_id]
		_apply_patch(actor_id, patch)

	patches_loaded.emit(_patches.size())

	if _patches.size() > 0:
		print("[ActorRegistry] Loaded %d patches from %s" % [_patches.size(), ZOO_PATCHES_PATH])


## Apply a patch to an actor's configuration
func _apply_patch(actor_id: String, patch: Dictionary) -> void:
	if not _actor_configs.has(actor_id):
		# Actor doesn't exist in base registry - this might be a new custom actor
		# Create a new entry with the patch data
		_actor_configs[actor_id] = patch.duplicate()
		_actor_configs[actor_id]["id"] = actor_id
		print("[ActorRegistry] Created new actor from patch: %s" % actor_id)
		return

	# Merge patch values into existing config
	var config: Dictionary = _actor_configs[actor_id]
	for key: String in patch.keys():
		config[key] = patch[key]


## Reload patches from file (useful if Actor Zoo saves new patches)
func reload_patches() -> void:
	_load_patches()


# =============================================================================
# PUBLIC API
# =============================================================================

## Get actor configuration by ID
## Returns empty Dictionary if actor not found
func get_actor_config(actor_id: String) -> Dictionary:
	if not _initialized:
		_load_registry()

	return _actor_configs.get(actor_id, {})


## Check if an actor exists in the registry
func has_actor(actor_id: String) -> bool:
	if not _initialized:
		_load_registry()

	return _actor_configs.has(actor_id)


## Get all actor IDs
func get_all_actor_ids() -> Array[String]:
	if not _initialized:
		_load_registry()

	var ids: Array[String] = []
	for key: String in _actor_configs.keys():
		ids.append(key)
	return ids


## Get actors filtered by category
func get_actors_by_category(category: String) -> Array[Dictionary]:
	if not _initialized:
		_load_registry()

	var result: Array[Dictionary] = []
	for actor_id: String in _actor_configs.keys():
		var config: Dictionary = _actor_configs[actor_id]
		if config.get("category", "") == category:
			result.append(config)
	return result


## Get actors filtered by subcategory
func get_actors_by_subcategory(subcategory: String) -> Array[Dictionary]:
	if not _initialized:
		_load_registry()

	var result: Array[Dictionary] = []
	for actor_id: String in _actor_configs.keys():
		var config: Dictionary = _actor_configs[actor_id]
		if config.get("subcategory", "") == subcategory:
			result.append(config)
	return result


## Get sprite configuration for spawning (convenience method)
## Returns a Dictionary with: sprite_path, h_frames, v_frames, pixel_size, offset_y
## Returns empty Dictionary if actor not found
func get_sprite_config(actor_id: String) -> Dictionary:
	var config: Dictionary = get_actor_config(actor_id)
	if config.is_empty():
		return {}

	return {
		"sprite_path": config.get("sprite_path", ""),
		"h_frames": config.get("h_frames", 1),
		"v_frames": config.get("v_frames", 1),
		"pixel_size": config.get("pixel_size", 0.03),
		"offset_y": config.get("offset_y", 0.0),
		"idle_frames": config.get("idle_frames", 1),
		"walk_frames": config.get("walk_frames", 1),
		"idle_fps": config.get("idle_fps", 2.0),
		"walk_fps": config.get("walk_fps", 6.0),
		"attack_sprite_path": config.get("attack_sprite_path", ""),
		"attack_h_frames": config.get("attack_h_frames", 1),
		"attack_v_frames": config.get("attack_v_frames", 1),
		"attack_frames": config.get("attack_frames", 1),
		"death_sprite_path": config.get("death_sprite_path", ""),
		"death_h_frames": config.get("death_h_frames", 1),
		"death_v_frames": config.get("death_v_frames", 1),
		"death_frames": config.get("death_frames", 1),
	}


## Check if a patch exists for an actor
func has_patch(actor_id: String) -> bool:
	return _patches.has(actor_id)


## Get the raw patch data for an actor (for debugging/display)
func get_patch(actor_id: String) -> Dictionary:
	return _patches.get(actor_id, {})


## Get all patches (for debugging/display)
func get_all_patches() -> Dictionary:
	return _patches.duplicate()


# =============================================================================
# SAVE/LOAD (for patches persistence across sessions)
# =============================================================================

## Save a patch for an actor (called by Actor Zoo)
func save_patch(actor_id: String, patch_data: Dictionary) -> bool:
	_patches[actor_id] = patch_data.duplicate()
	_apply_patch(actor_id, patch_data)
	return _save_patches_to_file()


## Remove a patch for an actor
func remove_patch(actor_id: String) -> bool:
	if not _patches.has(actor_id):
		return false

	_patches.erase(actor_id)

	# Reload base data for this actor
	var base_actor: Dictionary = ZooRegistry.get_actor(actor_id)
	if not base_actor.is_empty():
		_actor_configs[actor_id] = base_actor.duplicate()

	return _save_patches_to_file()


## Save all patches to file
func _save_patches_to_file() -> bool:
	var file := FileAccess.open(ZOO_PATCHES_PATH, FileAccess.WRITE)
	if not file:
		push_error("[ActorRegistry] Failed to save patches to: %s" % ZOO_PATCHES_PATH)
		return false

	var json_text: String = JSON.stringify(_patches, "\t")
	file.store_string(json_text)
	file.close()

	print("[ActorRegistry] Saved %d patches to %s" % [_patches.size(), ZOO_PATCHES_PATH])
	return true
