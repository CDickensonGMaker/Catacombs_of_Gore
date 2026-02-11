## quest_manager.gd - Manages quest states and objectives
extends Node

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal objective_completed(quest_id: String, objective_id: String)
signal tracked_quest_changed(quest_id: String)

## Quest data structure
class Quest:
	var id: String
	var title: String
	var description: String
	var state: Enums.QuestState = Enums.QuestState.UNAVAILABLE
	var is_main_quest: bool = false  # Main story quests get gold markers, side quests get teal
	var objectives: Array[Objective] = []
	var rewards: Dictionary = {}  # {gold, xp, items: [{id, quantity}]}
	var prerequisites: Array[String] = []  # Quest IDs that must be completed

	# Quest source and giver tracking
	var quest_source: Enums.QuestSource = Enums.QuestSource.STORY
	var giver_npc_id: String = ""  # NPC who gave this quest
	var giver_npc_type: String = ""  # Type of NPC (e.g., "guard", "merchant")
	var giver_region: String = ""  # Region where quest was given

	# Turn-in configuration (NEW - unified turn-in system)
	var turn_in_type: Enums.TurnInType = Enums.TurnInType.NPC_SPECIFIC
	var turn_in_target: String = ""  # NPC ID, NPC type, or object ID depending on turn_in_type
	var turn_in_region: String = ""  # Region where turn-in is accepted
	var turn_in_zone: String = ""  # Zone ID for compass navigation

	# Quest chains and triggers
	var next_quest: String = ""  # Auto-start this quest on completion
	var trigger_item: String = ""  # Item that triggers this quest when picked up

class Objective:
	var id: String
	var description: String
	var type: String  # "kill", "collect", "talk", "reach", "interact"
	var target: String  # Enemy ID, item ID, NPC ID, location ID
	var required_count: int = 1
	var current_count: int = 0
	var is_completed: bool = false
	var is_optional: bool = false


## Navigation data for compass/minimap
class QuestNavigation:
	var quest_id: String = ""
	var quest_title: String = ""
	var is_main_quest: bool = false
	var is_ready_for_turnin: bool = false
	var destination_type: String = ""  # "objective", "turn_in", "zone_exit"
	var destination_position: Vector3 = Vector3.ZERO
	var destination_zone: String = ""  # Empty if in current zone
	var destination_name: String = ""


## Active quests
var quests: Dictionary = {}  # quest_id -> Quest

## Quest database (loaded from data files)
var quest_database: Dictionary = {}

## Currently tracked quest (shown on compass)
var tracked_quest_id: String = ""

## Objective locations cache: quest_id -> {objective_id -> {hex: Vector2i, zone_id: String, world_pos: Vector3}}
## Caches resolved locations for quest objectives for efficient navigation
var objective_locations: Dictionary = {}

func _ready() -> void:
	_load_quest_database()
	# Defer signal connection to ensure other managers are ready
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	# Connect to CombatManager for kill tracking (backup for spell kills)
	if CombatManager and CombatManager.has_signal("entity_killed"):
		CombatManager.entity_killed.connect(_on_entity_killed)

	# Connect to InventoryManager for trigger_item quests
	if InventoryManager and InventoryManager.has_signal("item_added"):
		InventoryManager.item_added.connect(_on_item_added)

## Handle entity killed event from combat manager (backup for spell kills via CombatManager)
func _on_entity_killed(entity: Node, _killer: Node) -> void:
	if entity.has_method("get_enemy_data"):
		var enemy_data = entity.get_enemy_data()
		if enemy_data and enemy_data.id:
			on_enemy_killed(enemy_data.id)


## Handle item added to inventory - check for quest trigger items
func _on_item_added(item_id: String, _quantity: int) -> void:
	# Check if any quest is triggered by picking up this item
	for quest_id in quest_database:
		var template: Quest = quest_database[quest_id]
		if template.trigger_item == item_id:
			# Don't trigger if quest is already active or completed
			if quests.has(quest_id):
				continue

			# Start the quest
			if start_quest(quest_id):
				print("[QuestManager] Triggered quest '%s' from item: %s" % [quest_id, item_id])

				# Show notification
				var hud := get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("show_notification"):
					var quest: Quest = quests.get(quest_id)
					if quest:
						hud.show_notification("Quest Started: " + quest.title)


func _load_quest_database() -> void:
	var quest_dir := "res://data/quests/"
	if not DirAccess.dir_exists_absolute(quest_dir):
		return

	var dir := DirAccess.open(quest_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file := FileAccess.open(quest_dir + file_name, FileAccess.READ)
			if file:
				var json: Variant = JSON.parse_string(file.get_as_text())
				if json is Dictionary:
					var quest := _parse_quest(json as Dictionary)
					quest_database[quest.id] = quest
		file_name = dir.get_next()

func _parse_quest(data: Dictionary) -> Quest:
	var quest := Quest.new()
	quest.id = data.get("id", "")
	quest.title = data.get("title", "Unknown Quest")
	quest.description = data.get("description", "")
	quest.is_main_quest = data.get("is_main_quest", false)  # Main story = gold, side = teal
	quest.rewards = data.get("rewards", {})

	# Quest source (defaults to STORY for JSON quests)
	var source_str: String = data.get("quest_source", "story")
	quest.quest_source = _parse_quest_source(source_str)

	# Quest giver info
	quest.giver_npc_id = data.get("giver_npc_id", "")
	quest.giver_npc_type = data.get("giver_npc_type", "")
	quest.giver_region = data.get("giver_region", "")

	# Turn-in configuration (NEW)
	var turnin_type_str: String = data.get("turn_in_type", "npc_specific")
	quest.turn_in_type = _parse_turn_in_type(turnin_type_str)
	quest.turn_in_target = data.get("turn_in_target", data.get("turn_in_npc_id", quest.giver_npc_id))  # Fallback to giver
	quest.turn_in_region = data.get("turn_in_region", quest.giver_region)  # Fallback to giver region
	quest.turn_in_zone = data.get("turn_in_zone", "")

	# Quest chains and triggers
	quest.next_quest = data.get("next_quest", "")
	quest.trigger_item = data.get("trigger_item", "")

	# Prerequisites
	var prereqs: Array = data.get("prerequisites", [])
	for prereq in prereqs:
		quest.prerequisites.append(str(prereq))

	# Objectives
	for obj_data in data.get("objectives", []):
		var obj := Objective.new()
		obj.id = obj_data.get("id", "")
		obj.description = obj_data.get("description", "")
		obj.type = obj_data.get("type", "")
		obj.target = obj_data.get("target", "")
		obj.required_count = obj_data.get("required_count", 1)
		obj.is_optional = obj_data.get("is_optional", false)
		quest.objectives.append(obj)

	return quest


## Parse quest source string to enum
func _parse_quest_source(source: String) -> Enums.QuestSource:
	match source.to_lower():
		"story": return Enums.QuestSource.STORY
		"npc_bounty": return Enums.QuestSource.NPC_BOUNTY
		"board_bounty": return Enums.QuestSource.BOARD_BOUNTY
		"world_object": return Enums.QuestSource.WORLD_OBJECT
		_: return Enums.QuestSource.STORY


## Parse turn-in type string to enum
func _parse_turn_in_type(turn_in: String) -> Enums.TurnInType:
	match turn_in.to_lower():
		"npc_specific": return Enums.TurnInType.NPC_SPECIFIC
		"npc_type_in_region": return Enums.TurnInType.NPC_TYPE_IN_REGION
		"world_object": return Enums.TurnInType.WORLD_OBJECT
		"auto_complete": return Enums.TurnInType.AUTO_COMPLETE
		_: return Enums.TurnInType.NPC_SPECIFIC

## Start a quest
func start_quest(quest_id: String) -> bool:
	if not quest_database.has(quest_id):
		push_warning("Quest not found: " + quest_id)
		return false

	if quests.has(quest_id):
		return false  # Already active or completed

	# Check prerequisites
	var template: Quest = quest_database[quest_id]
	for prereq in template.prerequisites:
		if not quests.has(prereq) or quests[prereq].state != Enums.QuestState.COMPLETED:
			return false

	# Create active quest from template
	var quest := Quest.new()
	quest.id = template.id
	quest.title = template.title
	quest.description = template.description
	quest.is_main_quest = template.is_main_quest
	quest.state = Enums.QuestState.ACTIVE
	quest.rewards = template.rewards.duplicate()
	quest.prerequisites = template.prerequisites.duplicate()

	# Copy quest source and giver info
	quest.quest_source = template.quest_source
	quest.giver_npc_id = template.giver_npc_id
	quest.giver_npc_type = template.giver_npc_type
	quest.giver_region = template.giver_region

	# Copy turn-in configuration (NEW)
	quest.turn_in_type = template.turn_in_type
	quest.turn_in_target = template.turn_in_target
	quest.turn_in_region = template.turn_in_region
	quest.turn_in_zone = template.turn_in_zone

	# Copy quest chains and triggers
	quest.next_quest = template.next_quest
	quest.trigger_item = template.trigger_item

	for obj in template.objectives:
		var new_obj := Objective.new()
		new_obj.id = obj.id
		new_obj.description = obj.description
		new_obj.type = obj.type
		new_obj.target = obj.target
		new_obj.required_count = obj.required_count
		new_obj.is_optional = obj.is_optional
		quest.objectives.append(new_obj)

	quests[quest_id] = quest
	print("[QuestManager] Quest STARTED: id='%s', title='%s', turn_in_type=%s, turn_in_target='%s', turn_in_zone='%s'" % [
		quest.id, quest.title, quest.turn_in_type, quest.turn_in_target, quest.turn_in_zone
	])
	quest_started.emit(quest_id)

	# Auto-track newly started quests (or if no quest is currently tracked)
	if tracked_quest_id.is_empty():
		set_tracked_quest(quest_id)

	# Check existing inventory for "collect" objectives (pre-collection support)
	_check_existing_inventory_for_quest(quest)

	# Cache objective locations for navigation
	_cache_objective_locations(quest_id)

	return true

# =============================================================================
# OBJECTIVE LOCATION CACHING (for navigation/compass)
# =============================================================================

## Cache objective locations when quest starts
## Resolves targets to hex coordinates for efficient navigation
func _cache_objective_locations(quest_id: String) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	var locations: Dictionary = {}

	for obj in quest.objectives:
		var location: Dictionary = _resolve_objective_location(obj)
		if not location.is_empty():
			locations[obj.id] = location
			print("[QuestManager] Cached location for objective '%s': hex=%s, zone=%s" % [
				obj.id, location.get("hex", Vector2i.ZERO), location.get("zone_id", "")
			])

	# Also cache turn-in location if applicable
	if quest.turn_in_type != Enums.TurnInType.AUTO_COMPLETE:
		var turnin_location: Dictionary = _resolve_turnin_location(quest)
		if not turnin_location.is_empty():
			locations["_turnin"] = turnin_location
			print("[QuestManager] Cached turn-in location: hex=%s, zone=%s" % [
				turnin_location.get("hex", Vector2i.ZERO), turnin_location.get("zone_id", "")
			])

	objective_locations[quest_id] = locations


## Resolve the location of an objective target
func _resolve_objective_location(obj: Objective) -> Dictionary:
	match obj.type:
		"kill":
			return _resolve_enemy_location(obj.target)
		"collect":
			return _resolve_item_location(obj.target)
		"talk":
			return _resolve_npc_location(obj.target)
		"reach":
			return _resolve_zone_location(obj.target)
		"interact":
			return _resolve_object_location(obj.target)
	return {}


## Resolve enemy spawn location (from WorldData registry or hex_map_data)
func _resolve_enemy_location(enemy_type: String) -> Dictionary:
	# First check WorldData enemy spawn registry
	var spawns: Array = WorldData.get_enemy_spawn_locations(enemy_type)
	if not spawns.is_empty():
		var spawn: Dictionary = spawns[0]
		return {
			"hex": spawn.get("hex", Vector2i.ZERO),
			"zone_id": spawn.get("zone_id", ""),
			"world_pos": WorldData.axial_to_world(spawn.get("hex", Vector2i.ZERO))
		}

	# Check biome regions in hex_map_data for dominant enemies
	var hex_map: Dictionary = _load_hex_map_data()
	if hex_map.has("biome_regions"):
		for region: Dictionary in hex_map["biome_regions"]:
			var enemies: Array = region.get("dominant_enemies", [])
			for enemy: String in enemies:
				if enemy == enemy_type or enemy_type.begins_with(enemy):
					# Return center of region as approximate location
					var bounds: Dictionary = region.get("hex_bounds", {})
					var center_q: int = (bounds.get("q_min", 0) + bounds.get("q_max", 0)) / 2
					var center_r: int = (bounds.get("r_min", 0) + bounds.get("r_max", 0)) / 2
					return {
						"hex": Vector2i(center_q, center_r),
						"zone_id": "",
						"world_pos": WorldData.axial_to_world(Vector2i(center_q, center_r)),
						"approximate": true
					}

	return {}


## Resolve item location (from world drops or containers)
func _resolve_item_location(item_id: String) -> Dictionary:
	# Items are typically found dynamically, so we check known drop sources
	# For now, return empty - items are usually collected from enemies or chests
	return {}


## Resolve NPC location (from WorldData registry)
func _resolve_npc_location(npc_id: String) -> Dictionary:
	# Check WorldData NPC registry
	var npc_data: Dictionary = WorldData.get_npc_location(npc_id)
	if not npc_data.is_empty():
		var hex: Vector2i = npc_data.get("hex", Vector2i.ZERO)
		return {
			"hex": hex,
			"zone_id": npc_data.get("zone_id", ""),
			"world_pos": WorldData.axial_to_world(hex)
		}

	# Check hex_map_data towns for NPC
	var hex_map: Dictionary = _load_hex_map_data()
	if hex_map.has("towns"):
		for town: Dictionary in hex_map["towns"]:
			# Check if NPC ID matches town ID (common pattern)
			if town.get("id", "") == npc_id or npc_id.begins_with(town.get("id", "")):
				var hex := Vector2i(town.get("q", 0), town.get("r", 0))
				return {
					"hex": hex,
					"zone_id": town.get("id", ""),
					"world_pos": WorldData.axial_to_world(hex)
				}

	return {}


## Resolve zone/location ID to hex coordinates
func _resolve_zone_location(zone_id: String) -> Dictionary:
	var hex_map: Dictionary = _load_hex_map_data()

	# Check towns
	if hex_map.has("towns"):
		for town: Dictionary in hex_map["towns"]:
			if town.get("id", "") == zone_id or town.get("hex_id", "") == zone_id:
				var hex := Vector2i(town.get("q", 0), town.get("r", 0))
				return {
					"hex": hex,
					"zone_id": town.get("id", ""),
					"world_pos": WorldData.axial_to_world(hex)
				}

	# Check POIs
	if hex_map.has("points_of_interest"):
		for poi: Dictionary in hex_map["points_of_interest"]:
			if poi.get("id", "") == zone_id:
				var hex := Vector2i(poi.get("q", 0), poi.get("r", 0))
				return {
					"hex": hex,
					"zone_id": poi.get("id", ""),
					"world_pos": WorldData.axial_to_world(hex)
				}

	# Check WorldData world_grid for location IDs
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == zone_id:
			return {
				"hex": coords,
				"zone_id": zone_id,
				"world_pos": WorldData.axial_to_world(coords)
			}

	return {}


## Resolve interactable object location
func _resolve_object_location(object_id: String) -> Dictionary:
	# Check for known object types
	# Bounty boards, doors, special interactables

	# For now, check WorldData for any registered location
	return _resolve_zone_location(object_id)


## Resolve turn-in location for a quest
func _resolve_turnin_location(quest: Quest) -> Dictionary:
	match quest.turn_in_type:
		Enums.TurnInType.NPC_SPECIFIC:
			return _resolve_npc_location(quest.turn_in_target)

		Enums.TurnInType.NPC_TYPE_IN_REGION:
			# Find any NPC of this type in the region
			var region: String = quest.turn_in_region if not quest.turn_in_region.is_empty() else quest.giver_region
			# Check if there's a zone hint
			if not quest.turn_in_zone.is_empty():
				return _resolve_zone_location(quest.turn_in_zone)
			# Otherwise return the region center (approximate)
			return {}

		Enums.TurnInType.WORLD_OBJECT:
			return _resolve_object_location(quest.turn_in_target)

		Enums.TurnInType.AUTO_COMPLETE:
			return {}  # No turn-in location needed

	return {}


## Load hex map data from JSON
func _load_hex_map_data() -> Dictionary:
	var file_path := "res://data/world/hex_map_data.json"
	if not FileAccess.file_exists(file_path):
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: Variant = JSON.parse_string(json_text)
	if json is Dictionary:
		return json as Dictionary

	return {}


## Get cached hex coordinates for an objective
## Returns Vector2i.ZERO if not cached or not found
func get_objective_hex(quest_id: String, objective_id: String) -> Vector2i:
	if not objective_locations.has(quest_id):
		return Vector2i.ZERO

	var quest_locs: Dictionary = objective_locations[quest_id]
	if not quest_locs.has(objective_id):
		return Vector2i.ZERO

	var loc: Dictionary = quest_locs[objective_id]
	return loc.get("hex", Vector2i.ZERO)


## Get cached zone ID for an objective
func get_objective_zone(quest_id: String, objective_id: String) -> String:
	if not objective_locations.has(quest_id):
		return ""

	var quest_locs: Dictionary = objective_locations[quest_id]
	if not quest_locs.has(objective_id):
		return ""

	var loc: Dictionary = quest_locs[objective_id]
	return loc.get("zone_id", "")


## Get cached world position for an objective
func get_objective_world_pos(quest_id: String, objective_id: String) -> Vector3:
	if not objective_locations.has(quest_id):
		return Vector3.ZERO

	var quest_locs: Dictionary = objective_locations[quest_id]
	if not quest_locs.has(objective_id):
		return Vector3.ZERO

	var loc: Dictionary = quest_locs[objective_id]
	return loc.get("world_pos", Vector3.ZERO)


## Get turn-in hex for a quest
func get_turnin_hex(quest_id: String) -> Vector2i:
	return get_objective_hex(quest_id, "_turnin")


## Get turn-in zone for a quest
func get_turnin_zone(quest_id: String) -> String:
	return get_objective_zone(quest_id, "_turnin")


## Clear cached locations for a quest (called when quest completes/fails)
func _clear_objective_locations(quest_id: String) -> void:
	objective_locations.erase(quest_id)


## Refresh cached locations (call if world state changes)
func refresh_objective_locations(quest_id: String) -> void:
	_clear_objective_locations(quest_id)
	_cache_objective_locations(quest_id)


## Check existing inventory for "collect" objectives when quest starts
## This allows pre-collected items to count toward quest progress
func _check_existing_inventory_for_quest(quest: Quest) -> void:
	for obj in quest.objectives:
		if obj.type == "collect" and not obj.is_completed:
			# Check if player already has items in inventory
			var current_count: int = InventoryManager.get_item_count(obj.target)
			if current_count > 0:
				var to_add: int = min(current_count, obj.required_count - obj.current_count)
				if to_add > 0:
					obj.current_count += to_add
					quest_updated.emit(quest.id, obj.id)

					if obj.current_count >= obj.required_count:
						obj.is_completed = true
						objective_completed.emit(quest.id, obj.id)

## Update quest progress for a specific type
func update_progress(objective_type: String, target: String, amount: int = 1) -> void:
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			if obj.type == objective_type and obj.target == target:
				obj.current_count += amount
				quest_updated.emit(quest_id, obj.id)

				if obj.current_count >= obj.required_count:
					obj.is_completed = true
					print("[QuestManager] Objective COMPLETED: quest='%s', objective='%s', type='%s', target='%s'" % [
						quest_id, obj.id, obj.type, obj.target
					])
					objective_completed.emit(quest_id, obj.id)

		# Check if quest is complete
		_check_quest_completion(quest_id)

## Track enemy kill
func on_enemy_killed(enemy_id: String) -> void:
	# Direct match (e.g., "goblin_soldier")
	update_progress("kill", enemy_id, 1)

	# Also check for category match (e.g., "goblin" matches "goblin_soldier")
	var parts := enemy_id.split("_")
	if parts.size() > 1:
		var category := parts[0]  # "goblin" from "goblin_soldier"
		update_progress("kill", category, 1)

	# Always update generic "enemies" target (matches any enemy)
	update_progress("kill", "enemies", 1)

## Track item collection
func on_item_collected(item_id: String, count: int = 1) -> void:
	update_progress("collect", item_id, count)

## Track NPC interaction
func on_npc_talked(npc_id: String) -> void:
	update_progress("talk", npc_id, 1)

## Track location reached
func on_location_reached(location_id: String) -> void:
	update_progress("reach", location_id, 1)

## Track object interaction
func on_interact(object_id: String) -> void:
	update_progress("interact", object_id, 1)

## Check if quest objectives are all complete
## AUTO_COMPLETE quests will complete automatically, others require turn-in
func _check_quest_completion(quest_id: String) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		return

	# Only auto-complete if turn_in_type is AUTO_COMPLETE
	if quest.turn_in_type != Enums.TurnInType.AUTO_COMPLETE:
		return

	# Check if all required objectives are complete
	if are_objectives_complete(quest_id):
		complete_quest(quest_id)

## Check if all required objectives are complete (for NPCs to check turn-in status)
func are_objectives_complete(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false

	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		if not obj.is_optional and not obj.is_completed:
			return false
	return true

## Complete a quest and give rewards
func complete_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		print("[QuestManager] complete_quest() FAILED: quest '%s' not found" % quest_id)
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		print("[QuestManager] complete_quest() FAILED: quest '%s' not active (state=%s)" % [quest_id, quest.state])
		return

	quest.state = Enums.QuestState.COMPLETED
	print("[QuestManager] Quest COMPLETED: id='%s', title='%s', next_quest='%s'" % [
		quest.id, quest.title, quest.next_quest
	])

	# Give rewards
	if quest.rewards.has("gold"):
		InventoryManager.add_gold(quest.rewards["gold"])

	if quest.rewards.has("xp"):
		GameManager.player_data.add_ip(quest.rewards["xp"])

	if quest.rewards.has("items"):
		for item in quest.rewards["items"]:
			InventoryManager.add_item(item["id"], item.get("quantity", 1))

	quest_completed.emit(quest_id)

	# Clear cached objective locations
	_clear_objective_locations(quest_id)

	# Handle quest chain - auto-start next quest if specified
	var next_quest_id: String = quest.next_quest
	if not next_quest_id.is_empty():
		# Defer to avoid issues with signal handling
		call_deferred("_start_chain_quest", next_quest_id)

	# If this was the tracked quest, switch to next quest in chain or another active quest
	if tracked_quest_id == quest_id:
		if not next_quest_id.is_empty() and quest_database.has(next_quest_id):
			# Will be tracked when chain quest starts
			pass
		else:
			var active := get_active_quests()
			if active.size() > 0:
				set_tracked_quest(active[0].id)
			else:
				set_tracked_quest("")


## Start a quest from a chain (deferred call)
func _start_chain_quest(quest_id: String) -> void:
	if start_quest(quest_id):
		# Auto-track the chain quest
		set_tracked_quest(quest_id)

## Fail a quest
func fail_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	quest.state = Enums.QuestState.FAILED

	# Clear cached objective locations
	_clear_objective_locations(quest_id)

	quest_failed.emit(quest_id)

## Get active quests
func get_active_quests() -> Array[Quest]:
	var active: Array[Quest] = []
	for quest_id in quests:
		if quests[quest_id].state == Enums.QuestState.ACTIVE:
			active.append(quests[quest_id])
	return active

## Get completed quests
func get_completed_quests() -> Array[Quest]:
	var completed: Array[Quest] = []
	for quest_id in quests:
		if quests[quest_id].state == Enums.QuestState.COMPLETED:
			completed.append(quests[quest_id])
	return completed

## Get quest by ID
func get_quest(quest_id: String) -> Quest:
	return quests.get(quest_id)

## Check if quest is currently active
func is_quest_active(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	return quests[quest_id].state == Enums.QuestState.ACTIVE

## Check if quest is completed
func is_quest_completed(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	return quests[quest_id].state == Enums.QuestState.COMPLETED

## Set the tracked quest (shown on compass)
func set_tracked_quest(quest_id: String) -> void:
	if quest_id == tracked_quest_id:
		return

	# Verify quest exists and is active
	if not quest_id.is_empty() and (not quests.has(quest_id) or quests[quest_id].state != Enums.QuestState.ACTIVE):
		return

	tracked_quest_id = quest_id
	tracked_quest_changed.emit(quest_id)


## Get the currently tracked quest
func get_tracked_quest() -> Quest:
	if tracked_quest_id.is_empty():
		return null
	return quests.get(tracked_quest_id)


## Get the tracked quest ID
func get_tracked_quest_id() -> String:
	return tracked_quest_id


## Get current progress for a specific objective
func get_objective_progress(quest_id: String, objective_id: String) -> int:
	if not quests.has(quest_id):
		return 0
	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		if obj.id == objective_id:
			return obj.current_count
	return 0


## Check if quest is available
func is_quest_available(quest_id: String) -> bool:
	if not quest_database.has(quest_id):
		return false
	if quests.has(quest_id):
		return false  # Already started

	var template: Quest = quest_database[quest_id]
	for prereq in template.prerequisites:
		if not quests.has(prereq) or quests[prereq].state != Enums.QuestState.COMPLETED:
			return false

	return true

## Get available quests (for quest givers)
func get_available_quests() -> Array[String]:
	var available: Array[String] = []
	for quest_id in quest_database:
		if is_quest_available(quest_id):
			available.append(quest_id)
	return available


## Set the quest giver NPC for a quest (used for dynamic quests like bounties)
func set_quest_giver(quest_id: String, npc_id: String) -> void:
	if quests.has(quest_id):
		quests[quest_id].giver_npc_id = npc_id


## Set the quest giver NPC type and region (for group turn-ins)
func set_quest_giver_info(quest_id: String, npc_id: String, npc_type: String, region: String) -> void:
	if quests.has(quest_id):
		quests[quest_id].giver_npc_id = npc_id
		quests[quest_id].giver_npc_type = npc_type
		quests[quest_id].giver_region = region


## Set turn-in configuration for a quest (for dynamic quests like bounties)
func set_turn_in_info(quest_id: String, turn_in_type: Enums.TurnInType, target: String, region: String = "", zone: String = "") -> void:
	if quests.has(quest_id):
		quests[quest_id].turn_in_type = turn_in_type
		quests[quest_id].turn_in_target = target
		quests[quest_id].turn_in_region = region
		quests[quest_id].turn_in_zone = zone


## Get the quest giver NPC ID for a quest
func get_quest_giver(quest_id: String) -> String:
	if quests.has(quest_id):
		return quests[quest_id].giver_npc_id
	return ""


# =============================================================================
# CENTRAL TURN-IN SYSTEM
# =============================================================================

## Check if an entity can accept turn-in for a specific quest
## Entity must have npc_id/object_id and npc_type/region_id properties as needed
func can_accept_turnin(entity: Node, quest_id: String) -> bool:
	var entity_npc_id: String = entity.get("npc_id") if "npc_id" in entity else ""
	var entity_npc_type: String = entity.get("npc_type") if "npc_type" in entity else ""
	var entity_region: String = entity.get("region_id") if "region_id" in entity else ""

	print("[QuestManager] can_accept_turnin() called: quest='%s', entity_npc_id='%s', entity_npc_type='%s', entity_region='%s'" % [
		quest_id, entity_npc_id, entity_npc_type, entity_region
	])

	if not quests.has(quest_id):
		print("[QuestManager] can_accept_turnin() -> FALSE (quest not found)")
		return false

	var quest: Quest = quests[quest_id]
	print("[QuestManager] Quest state: turn_in_type=%s, turn_in_target='%s', turn_in_region='%s'" % [
		quest.turn_in_type, quest.turn_in_target, quest.turn_in_region
	])

	# Quest must be active
	if quest.state != Enums.QuestState.ACTIVE:
		print("[QuestManager] can_accept_turnin() -> FALSE (quest not active, state=%s)" % quest.state)
		return false

	# Primary objectives must be complete
	if not _are_primary_objectives_complete(quest_id):
		print("[QuestManager] can_accept_turnin() -> FALSE (objectives not complete)")
		return false

	# Check based on turn-in type
	match quest.turn_in_type:
		Enums.TurnInType.NPC_SPECIFIC:
			# Entity must match exact NPC ID
			var matches: bool = entity_npc_id == quest.turn_in_target
			print("[QuestManager] NPC_SPECIFIC check: entity_npc_id='%s' == turn_in_target='%s' -> %s" % [
				entity_npc_id, quest.turn_in_target, matches
			])
			if matches:
				print("[QuestManager] can_accept_turnin() -> TRUE")
			else:
				print("[QuestManager] can_accept_turnin() -> FALSE (npc_id mismatch)")
			return matches

		Enums.TurnInType.NPC_TYPE_IN_REGION:
			# Entity must match NPC type and be in correct region
			# Also check giver_region if turn_in_region is empty (fallback)
			var required_region: String = quest.turn_in_region if not quest.turn_in_region.is_empty() else quest.giver_region
			var type_matches: bool = entity_npc_type == quest.turn_in_target
			var region_matches: bool = required_region.is_empty() or entity_region == required_region
			var matches: bool = type_matches and region_matches
			print("[QuestManager] NPC_TYPE_IN_REGION check: entity_type='%s' == target='%s' (%s), entity_region='%s' == required='%s' (%s) -> %s" % [
				entity_npc_type, quest.turn_in_target, type_matches,
				entity_region, required_region, region_matches,
				matches
			])
			if matches:
				print("[QuestManager] can_accept_turnin() -> TRUE")
			else:
				print("[QuestManager] can_accept_turnin() -> FALSE (type/region mismatch)")
			return matches

		Enums.TurnInType.WORLD_OBJECT:
			# Entity must match object ID
			var entity_object_id: String = entity.get("object_id") if "object_id" in entity else ""
			var matches: bool = entity_object_id == quest.turn_in_target
			print("[QuestManager] WORLD_OBJECT check: entity_object_id='%s' == target='%s' -> %s" % [
				entity_object_id, quest.turn_in_target, matches
			])
			return matches

		Enums.TurnInType.AUTO_COMPLETE:
			# Auto-complete quests don't need entity turn-in
			print("[QuestManager] can_accept_turnin() -> FALSE (auto-complete type)")
			return false

	print("[QuestManager] can_accept_turnin() -> FALSE (no match)")
	return false


## Attempt to turn in a quest to an entity
## Returns {success: bool, rewards: Dictionary, message: String}
func try_turnin(entity: Node, quest_id: String) -> Dictionary:
	var entity_npc_id: String = entity.get("npc_id") if "npc_id" in entity else ""
	print("[QuestManager] try_turnin() called: quest='%s', entity_npc_id='%s'" % [quest_id, entity_npc_id])

	if not can_accept_turnin(entity, quest_id):
		print("[QuestManager] try_turnin() -> FAILED (can_accept_turnin returned false)")
		return {
			"success": false,
			"rewards": {},
			"message": "Cannot turn in this quest here."
		}

	var quest: Quest = quests[quest_id]

	# Complete the quest and give rewards
	print("[QuestManager] try_turnin() -> SUCCESS, completing quest '%s'" % quest_id)
	complete_quest(quest_id)

	return {
		"success": true,
		"rewards": quest.rewards.duplicate(),
		"message": "Quest completed: " + quest.title
	}


## Get all quests that an entity can accept turn-in for
func get_turnin_quests_for_entity(entity: Node) -> Array[String]:
	var turnin_quests: Array[String] = []

	for quest_id in quests:
		if can_accept_turnin(entity, quest_id):
			turnin_quests.append(quest_id)

	return turnin_quests


## Get quests completable by an NPC of a specific type in a specific region
## Used for "any guard in this region can accept turn-in" feature
func get_completable_quests_for_npc_type(npc_type: String, region: String) -> Array[String]:
	var completable: Array[String] = []
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		# Quest must be active
		if quest.state != Enums.QuestState.ACTIVE:
			continue
		# Quest must have matching NPC type and region (or be in same region with matching type)
		if quest.giver_npc_type == npc_type and quest.giver_region == region:
			# Check if PRIMARY objectives are complete (ignore "talk" return objectives)
			# This allows guards to accept turn-in even if the "return_to_giver" talk objective
			# was meant for a different NPC
			if _are_primary_objectives_complete(quest_id):
				completable.append(quest_id)
	return completable


## Check if primary objectives (kill, collect, destroy, reach, interact) are complete
## Ignores "talk" objectives which are for specific NPC turn-ins
func _are_primary_objectives_complete(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false

	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		# Skip optional objectives
		if obj.is_optional:
			continue
		# Skip "talk" objectives - these are for specific NPC turn-ins, not guards
		if obj.type == "talk":
			continue
		# If any non-talk required objective is incomplete, return false
		if not obj.is_completed:
			return false
	return true


# =============================================================================
# NAVIGATION API - For Compass and Minimap
# =============================================================================

## Get navigation data for the currently tracked quest (for compass)
func get_tracked_quest_navigation() -> QuestNavigation:
	if tracked_quest_id.is_empty():
		return null

	var quest: Quest = quests.get(tracked_quest_id)
	if not quest or quest.state != Enums.QuestState.ACTIVE:
		return null

	return _build_quest_navigation(quest)


## Get navigation data for all active quests (for minimap)
func get_active_quests_with_positions() -> Array[QuestNavigation]:
	var nav_list: Array[QuestNavigation] = []

	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		var nav: QuestNavigation = _build_quest_navigation(quest)
		if nav:
			nav_list.append(nav)

	return nav_list


## Build navigation data for a quest
func _build_quest_navigation(quest: Quest) -> QuestNavigation:
	var nav := QuestNavigation.new()
	nav.quest_id = quest.id
	nav.quest_title = quest.title
	nav.is_main_quest = quest.is_main_quest

	# Check if ready for turn-in
	nav.is_ready_for_turnin = _are_primary_objectives_complete(quest.id)

	if nav.is_ready_for_turnin:
		# Point to turn-in location
		nav.destination_type = "turn_in"
		nav.destination_zone = quest.turn_in_zone
		_set_turnin_destination(nav, quest)
	else:
		# Point to next incomplete objective
		nav.destination_type = "objective"
		_set_objective_destination(nav, quest)

	return nav


## Set destination for turn-in based on turn_in_type
func _set_turnin_destination(nav: QuestNavigation, quest: Quest) -> void:
	var current_zone: String = _get_current_zone_id()

	match quest.turn_in_type:
		Enums.TurnInType.NPC_SPECIFIC:
			nav.destination_name = quest.turn_in_target
			# Find the specific NPC in the world
			var npc_pos: Vector3 = _find_npc_position(quest.turn_in_target)
			if npc_pos != Vector3.ZERO:
				nav.destination_position = npc_pos
			elif not quest.turn_in_zone.is_empty() and quest.turn_in_zone != current_zone:
				nav.destination_zone = quest.turn_in_zone

		Enums.TurnInType.NPC_TYPE_IN_REGION:
			nav.destination_name = quest.turn_in_target  # e.g., "guard", "merchant"
			# Find any NPC of this type in the current zone
			var npc_pos: Vector3 = _find_npc_type_position(quest.turn_in_target, quest.turn_in_region)
			if npc_pos != Vector3.ZERO:
				nav.destination_position = npc_pos
			elif not quest.turn_in_zone.is_empty() and quest.turn_in_zone != current_zone:
				nav.destination_zone = quest.turn_in_zone

		Enums.TurnInType.WORLD_OBJECT:
			nav.destination_name = quest.turn_in_target
			# Find the world object
			var obj_pos: Vector3 = _find_world_object_position(quest.turn_in_target)
			if obj_pos != Vector3.ZERO:
				nav.destination_position = obj_pos
			elif not quest.turn_in_zone.is_empty() and quest.turn_in_zone != current_zone:
				nav.destination_zone = quest.turn_in_zone

		Enums.TurnInType.AUTO_COMPLETE:
			# No destination needed - quest auto-completes
			pass


## Set destination for the next incomplete objective
func _set_objective_destination(nav: QuestNavigation, quest: Quest) -> void:
	for obj in quest.objectives:
		if obj.is_completed or obj.is_optional:
			continue

		nav.destination_name = obj.description

		match obj.type:
			"kill":
				# Find enemy spawn location
				var enemy_pos: Vector3 = _find_enemy_spawn_position(obj.target)
				if enemy_pos != Vector3.ZERO:
					nav.destination_position = enemy_pos
				else:
					# Check if there's a zone hint in objective description or quest data
					pass

			"collect":
				# Find item in world or drop location
				var item_pos: Vector3 = _find_item_position(obj.target)
				if item_pos != Vector3.ZERO:
					nav.destination_position = item_pos

			"talk":
				# Find NPC
				var npc_pos: Vector3 = _find_npc_position(obj.target)
				if npc_pos != Vector3.ZERO:
					nav.destination_position = npc_pos

			"reach":
				# Find location marker
				var loc_pos: Vector3 = _find_location_position(obj.target)
				if loc_pos != Vector3.ZERO:
					nav.destination_position = loc_pos

			"interact":
				# Find interactable object
				var obj_pos: Vector3 = _find_world_object_position(obj.target)
				if obj_pos != Vector3.ZERO:
					nav.destination_position = obj_pos

		# Only process first incomplete objective
		break


## Get current zone ID from GameManager or scene
func _get_current_zone_id() -> String:
	if GameManager and GameManager.has_method("get_current_zone_id"):
		return GameManager.get_current_zone_id()
	# Fallback to scene name
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene.name.to_lower()
	return ""


## Find position of a specific NPC by ID
func _find_npc_position(npc_id: String) -> Vector3:
	var npcs: Array[Node] = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		var node_npc_id: String = npc.get("npc_id") if "npc_id" in npc else ""
		if node_npc_id == npc_id and npc is Node3D:
			return (npc as Node3D).global_position
	return Vector3.ZERO


## Find position of any NPC of a specific type (optionally in a region)
func _find_npc_type_position(npc_type: String, region: String = "") -> Vector3:
	var npcs: Array[Node] = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		var node_type: String = npc.get("npc_type") if "npc_type" in npc else ""
		var node_region: String = npc.get("region_id") if "region_id" in npc else ""

		if node_type == npc_type:
			if region.is_empty() or node_region == region:
				if npc is Node3D:
					return (npc as Node3D).global_position
	return Vector3.ZERO


## Find position of a world object by ID
func _find_world_object_position(object_id: String) -> Vector3:
	# Check bounty boards
	var bounty_boards: Array[Node] = get_tree().get_nodes_in_group("bounty_boards")
	for board in bounty_boards:
		var board_id: String = board.get("object_id") if "object_id" in board else ""
		if board_id == object_id and board is Node3D:
			return (board as Node3D).global_position

	# Check interactables
	var interactables: Array[Node] = get_tree().get_nodes_in_group("interactables")
	for obj in interactables:
		var obj_id: String = obj.get("object_id") if "object_id" in obj else ""
		if obj.name.to_lower() == object_id or obj_id == object_id:
			if obj is Node3D:
				return (obj as Node3D).global_position

	return Vector3.ZERO


## Find position where enemies of a certain type spawn
func _find_enemy_spawn_position(enemy_id: String) -> Vector3:
	# First check if there's a live enemy of this type
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var enemy_data: Variant = null
		if enemy.has_method("get_enemy_data"):
			enemy_data = enemy.get_enemy_data()
		elif "enemy_data" in enemy:
			enemy_data = enemy.get("enemy_data")

		if enemy_data and enemy_data.get("id", "").begins_with(enemy_id):
			if enemy is Node3D:
				return (enemy as Node3D).global_position

	# Fall back to spawn points if no live enemy found
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("enemy_spawns")
	for spawn in spawn_points:
		var spawn_enemy: String = spawn.get("enemy_id") if "enemy_id" in spawn else ""
		if spawn_enemy.begins_with(enemy_id) and spawn is Node3D:
			return (spawn as Node3D).global_position

	return Vector3.ZERO


## Find position of an item in the world
func _find_item_position(item_id: String) -> Vector3:
	# Check dropped items
	var items: Array[Node] = get_tree().get_nodes_in_group("items")
	for item in items:
		var item_data_id: String = item.get("item_id") if "item_id" in item else ""
		if item_data_id == item_id and item is Node3D:
			return (item as Node3D).global_position

	# Check chests/containers that might have the item
	# (This is complex and would require container content checking)

	return Vector3.ZERO


## Find position of a location marker
func _find_location_position(location_id: String) -> Vector3:
	# Check for location markers in the scene
	var markers: Array[Node] = get_tree().get_nodes_in_group("location_markers")
	for marker in markers:
		var marker_id: String = marker.get("location_id") if "location_id" in marker else ""
		if marker_id == location_id or marker.name.to_lower() == location_id:
			if marker is Node3D:
				return (marker as Node3D).global_position

	# Also check exits/doors as locations
	var exits: Array[Node] = get_tree().get_nodes_in_group("exits")
	for exit in exits:
		var exit_id: String = exit.get("target_zone") if "target_zone" in exit else ""
		if exit_id == location_id and exit is Node3D:
			return (exit as Node3D).global_position

	return Vector3.ZERO


## Serialize for saving
func to_dict() -> Dictionary:
	var data := {
		"tracked_quest_id": tracked_quest_id,
		"quests": {}
	}
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		var quest_data := {
			"state": quest.state,
			# Quest source and giver
			"quest_source": quest.quest_source,
			"giver_npc_id": quest.giver_npc_id,
			"giver_npc_type": quest.giver_npc_type,
			"giver_region": quest.giver_region,
			# Turn-in configuration
			"turn_in_type": quest.turn_in_type,
			"turn_in_target": quest.turn_in_target,
			"turn_in_region": quest.turn_in_region,
			"turn_in_zone": quest.turn_in_zone,
			# Quest chains
			"next_quest": quest.next_quest,
			"objectives": []
		}
		for obj in quest.objectives:
			quest_data.objectives.append({
				"id": obj.id,
				"current_count": obj.current_count,
				"is_completed": obj.is_completed
			})
		data.quests[quest_id] = quest_data
	return data

## Deserialize from save
func from_dict(data: Dictionary) -> void:
	quests.clear()

	# Handle both old format (quest_id -> data) and new format ({tracked_quest_id, quests})
	var quests_data: Dictionary = data.get("quests", data)  # Fallback to old format
	tracked_quest_id = data.get("tracked_quest_id", "")

	for quest_id in quests_data:
		# Skip non-quest keys from new format
		if quest_id == "tracked_quest_id" or quest_id == "quests":
			continue

		if not quest_database.has(quest_id):
			continue

		var template: Quest = quest_database[quest_id]
		var quest := Quest.new()
		quest.id = template.id
		quest.title = template.title
		quest.description = template.description
		quest.state = quests_data[quest_id].get("state", Enums.QuestState.ACTIVE)
		quest.rewards = template.rewards.duplicate()
		quest.prerequisites = template.prerequisites.duplicate()
		# Restore quest source and giver info from save or fall back to template
		quest.quest_source = quests_data[quest_id].get("quest_source", template.quest_source)
		quest.giver_npc_id = quests_data[quest_id].get("giver_npc_id", template.giver_npc_id)
		quest.giver_npc_type = quests_data[quest_id].get("giver_npc_type", template.giver_npc_type)
		quest.giver_region = quests_data[quest_id].get("giver_region", template.giver_region)

		# Restore turn-in configuration
		quest.turn_in_type = quests_data[quest_id].get("turn_in_type", template.turn_in_type)
		quest.turn_in_target = quests_data[quest_id].get("turn_in_target", template.turn_in_target)
		quest.turn_in_region = quests_data[quest_id].get("turn_in_region", template.turn_in_region)
		quest.turn_in_zone = quests_data[quest_id].get("turn_in_zone", template.turn_in_zone)

		# Restore quest chain info
		quest.next_quest = quests_data[quest_id].get("next_quest", template.next_quest)

		var saved_objectives: Array = quests_data[quest_id].get("objectives", [])
		for i in range(template.objectives.size()):
			var obj := Objective.new()
			var t_obj: Objective = template.objectives[i]
			obj.id = t_obj.id
			obj.description = t_obj.description
			obj.type = t_obj.type
			obj.target = t_obj.target
			obj.required_count = t_obj.required_count
			obj.is_optional = t_obj.is_optional

			# Restore progress
			for saved in saved_objectives:
				if saved.id == obj.id:
					obj.current_count = saved.get("current_count", 0)
					obj.is_completed = saved.get("is_completed", false)
					break

			quest.objectives.append(obj)

		quests[quest_id] = quest

	# Validate tracked quest still exists and is active
	if not tracked_quest_id.is_empty():
		if not quests.has(tracked_quest_id) or quests[tracked_quest_id].state != Enums.QuestState.ACTIVE:
			# Track first active quest instead
			var active := get_active_quests()
			tracked_quest_id = active[0].id if active.size() > 0 else ""


## Reset quest state for a new game (called from death screen "New Game")
func reset_for_new_game() -> void:
	# Clear all active quests
	quests.clear()
	tracked_quest_id = ""

	# Clear objective location cache
	objective_locations.clear()
