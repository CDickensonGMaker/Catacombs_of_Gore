## bounty_board.gd - Interactable board in town that offers random procedural bounties
## Big Game Hunting - Minimum 500 gold for any bounty, with extreme tier bosses
class_name BountyBoard
extends StaticBody3D

signal bounty_accepted(bounty: Bounty)
signal bounty_completed(bounty: Bounty)
signal bounties_refreshed

## Bounty data structure
class Bounty:
	var id: String
	var title: String
	var description: String
	var tier: String  # "standard", "dangerous", "deadly", "extreme"
	var objective_type: String  # "kill", "collect", "explore", "clear"
	var target: String  # enemy_id, item_id, location_id
	var target_display_name: String  # Human-readable target name
	var required_count: int
	var current_count: int = 0
	var gold_reward: int
	var xp_reward: int
	var is_boss: bool = false
	var is_complete: bool = false
	var is_active: bool = false
	var bonus_loot: String = ""  # Guaranteed loot for deadly+ tiers

	func get_progress_text() -> String:
		return "%d / %d" % [current_count, required_count]

	func get_tier_color() -> Color:
		match tier:
			"standard": return Color(0.3, 0.8, 0.3)  # Green
			"dangerous": return Color(0.9, 0.8, 0.2)  # Yellow
			"deadly": return Color(0.9, 0.3, 0.3)  # Red
			"extreme": return Color(0.8, 0.2, 0.9)  # Purple
		return Color.WHITE

	func get_tier_display() -> String:
		match tier:
			"standard": return "Standard"
			"dangerous": return "Dangerous"
			"deadly": return "Deadly"
			"extreme": return "EXTREME"
		return tier.capitalize()

## Board configuration
@export var board_name: String = "Bounty Board"
@export var max_available_bounties: int = 5
@export var min_available_bounties: int = 3

## Visual components
var mesh_instance: MeshInstance3D
var interaction_area: Area3D

## Bounty tracking
var available_bounties: Array[Bounty] = []
var active_bounties: Array[Bounty] = []
var completed_bounty_ids: Array[String] = []  # Prevent repeats until refresh

## Bounty templates loaded from data file
var bounty_templates: Dictionary = {}

## UI reference
var bounty_ui: Control = null

## Unique ID counter for bounties
var _bounty_id_counter: int = 0

## Bonus loot pools
var dangerous_loot: Array[String] = ["iron_ore", "leather", "healing_herb"]
var deadly_loot: Array[String] = ["iron_sword", "iron_armor", "silver_ore", "enchanted_ring"]
var extreme_loot: Array[String] = ["steel_sword", "enchanted_amulet", "legendary_weapon", "rare_gem"]

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("bounty_boards")

	# Only create visuals/areas if not already present (supports scene instancing)
	if not get_node_or_null("MeshInstance"):
		_create_visual()
	else:
		mesh_instance = get_node_or_null("MeshInstance")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	if not get_node_or_null("Collision"):
		_create_collision()

	_load_bounty_templates()
	_generate_bounties()

	# Connect to enemy kills
	CombatManager.entity_killed.connect(_on_entity_killed)

	# Connect to item collection
	InventoryManager.item_added.connect(_on_item_added)

## Create the visual representation (wooden notice board)
func _create_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance"

	# Board backing
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(2.0, 2.5, 0.2)
	mesh_instance.mesh = board_mesh
	mesh_instance.position.y = 1.5

	# Wood material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.28, 0.18)  # Dark wood
	mat.roughness = 0.9
	mesh_instance.material_override = mat

	add_child(mesh_instance)

	# Add wanted posters texture on the front of the board
	var poster_tex: Texture2D = load("res://Sprite folders grab bag/bountyboard_asset.png")
	if poster_tex:
		var poster_sprite := Sprite3D.new()
		poster_sprite.name = "BountyPosters"
		poster_sprite.texture = poster_tex
		poster_sprite.pixel_size = 0.006  # Scale to fit the board nicely
		poster_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		poster_sprite.position = Vector3(0, 0, 0.11)  # Slightly in front of board face
		poster_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style
		mesh_instance.add_child(poster_sprite)

	# Add posts on sides
	_add_post(Vector3(-0.9, 0.75, 0))
	_add_post(Vector3(0.9, 0.75, 0))

func _add_post(pos: Vector3) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.15, 1.5, 0.15)
	post.mesh = post_mesh
	post.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.15)
	post.material_override = mat

	mesh_instance.add_child(post)

## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 3.0, 1.5)
	collision.shape = shape
	collision.position.y = 1.5
	interaction_area.add_child(collision)

	add_child(interaction_area)

## Create collision shape
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.5, 0.3)
	collision.shape = shape
	collision.position.y = 1.5
	add_child(collision)

## Load bounty templates from data file
func _load_bounty_templates() -> void:
	var file_path := "res://data/bounty_templates.json"
	if not FileAccess.file_exists(file_path):
		push_warning("[BountyBoard] bounty_templates.json not found, using defaults")
		_create_default_templates()
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string := file.get_as_text()
		var json: Variant = JSON.parse_string(json_string)
		if json is Dictionary:
			bounty_templates = json
		else:
			push_warning("[BountyBoard] Failed to parse bounty_templates.json")
			_create_default_templates()
	else:
		_create_default_templates()

## Create default bounty templates if file not found
func _create_default_templates() -> void:
	bounty_templates = {
		"kill": {
			"standard": [
				{"target": "goblin", "display": "Goblins", "count_min": 5, "count_max": 10},
			],
			"dangerous": [
				{"target": "goblin_soldier", "display": "Goblin Soldiers", "count_min": 6, "count_max": 10},
			],
			"deadly": [
				{"target": "ogre", "display": "Ogres", "count_min": 2, "count_max": 3},
			],
			"extreme": [
				{"target": "goblin_warboss", "display": "the Goblin Warboss", "count_min": 1, "count_max": 1, "is_boss": true},
			]
		}
	}

## Generate available bounties
func _generate_bounties() -> void:
	available_bounties.clear()

	var num_to_generate := randi_range(min_available_bounties, max_available_bounties)

	for i in range(num_to_generate):
		var bounty := _generate_random_bounty()
		if bounty:
			available_bounties.append(bounty)

	bounties_refreshed.emit()

## Generate a single random bounty
func _generate_random_bounty() -> Bounty:
	# Pick tier with weighted probability
	# Standard: 40%, Dangerous: 35%, Deadly: 20%, Extreme: 5%
	var tier_roll := randf()
	var tier: String
	if tier_roll < 0.40:
		tier = "standard"
	elif tier_roll < 0.75:
		tier = "dangerous"
	elif tier_roll < 0.95:
		tier = "deadly"
	else:
		tier = "extreme"

	# Pick type with weighted probability
	var type_roll := randf()
	var obj_type: String
	if type_roll < 0.65:
		obj_type = "kill"
	elif type_roll < 0.85:
		obj_type = "collect"
	elif type_roll < 0.95:
		obj_type = "explore"
	else:
		obj_type = "clear"

	# Get templates for this type and tier
	if not bounty_templates.has(obj_type):
		obj_type = "kill"  # Fallback
	if not bounty_templates[obj_type].has(tier):
		# Try fallback tiers
		if bounty_templates[obj_type].has("standard"):
			tier = "standard"
		elif bounty_templates[obj_type].has("dangerous"):
			tier = "dangerous"
		else:
			return null

	var templates: Array = bounty_templates[obj_type][tier]
	if templates.is_empty():
		return null

	var template: Dictionary = templates[randi() % templates.size()]

	# Create bounty
	var bounty := Bounty.new()
	_bounty_id_counter += 1
	bounty.id = "bounty_%d_%d" % [Time.get_ticks_msec(), _bounty_id_counter]
	bounty.tier = tier
	bounty.objective_type = obj_type
	bounty.target = template.get("target", "")
	bounty.target_display_name = template.get("display", bounty.target)
	bounty.is_boss = template.get("is_boss", false)

	# Set required count
	if obj_type == "clear":
		bounty.required_count = template.get("enemy_count", 10)
	else:
		bounty.required_count = randi_range(template.get("count_min", 1), template.get("count_max", 3))

	# Generate title and description
	_generate_bounty_text(bounty, obj_type)

	# Calculate rewards - Big Game Hunting values
	_calculate_bounty_rewards(bounty, tier)

	# Assign bonus loot for deadly+ tiers
	_assign_bonus_loot(bounty, tier)

	# Skip if recently completed (prevent exact duplicates)
	var template_key := "%s_%s_%s" % [obj_type, bounty.target, tier]
	if template_key in completed_bounty_ids:
		return null

	return bounty

## Generate bounty title and description text
func _generate_bounty_text(bounty: Bounty, obj_type: String) -> void:
	var skull_icon := " [BOSS]" if bounty.is_boss else ""

	match obj_type:
		"kill":
			if bounty.is_boss:
				bounty.title = "Hunt %s%s" % [bounty.target_display_name, skull_icon]
				bounty.description = "A dangerous creature threatens the land. Track down and slay %s. This is no ordinary quarry - prepare well." % bounty.target_display_name
			else:
				bounty.title = "Slay %d %s" % [bounty.required_count, bounty.target_display_name]
				bounty.description = "The local populace needs protection. Eliminate %d %s from the area." % [bounty.required_count, bounty.target_display_name.to_lower()]

		"collect":
			bounty.title = "Collect %d %s" % [bounty.required_count, bounty.target_display_name]
			bounty.description = "Supplies are needed urgently. Gather %d %s and return them." % [bounty.required_count, bounty.target_display_name.to_lower()]

		"explore":
			bounty.title = "Scout %s" % bounty.target_display_name
			bounty.description = "Information is needed about %s. Explore the area and report back." % bounty.target_display_name.to_lower()

		"clear":
			bounty.title = "Clear %s%s" % [bounty.target_display_name, skull_icon]
			bounty.description = "A dangerous location must be cleared of all threats. Kill at least %d enemies within %s." % [bounty.required_count, bounty.target_display_name]

## Calculate bounty rewards based on tier
func _calculate_bounty_rewards(bounty: Bounty, tier: String) -> void:
	# Big Game Hunting reward structure - minimum 500 gold
	match tier:
		"standard":
			# 500-1,000 gold, 300-500 XP
			bounty.gold_reward = randi_range(500, 1000)
			bounty.xp_reward = randi_range(300, 500)

		"dangerous":
			# 1,000-2,500 gold, 500-1,000 XP
			bounty.gold_reward = randi_range(1000, 2500)
			bounty.xp_reward = randi_range(500, 1000)

		"deadly":
			# 2,500-4,000 gold, 1,000-2,000 XP
			bounty.gold_reward = randi_range(2500, 4000)
			bounty.xp_reward = randi_range(1000, 2000)

		"extreme":
			# 4,000-6,000 gold, 2,000-3,500 XP
			bounty.gold_reward = randi_range(4000, 6000)
			bounty.xp_reward = randi_range(2000, 3500)

		_:
			bounty.gold_reward = 500
			bounty.xp_reward = 300

	# Add bonus for count (smaller bonus now that base is higher)
	bounty.gold_reward += bounty.required_count * 25
	bounty.xp_reward += bounty.required_count * 20

## Assign guaranteed bonus loot for higher tier bounties
func _assign_bonus_loot(bounty: Bounty, tier: String) -> void:
	match tier:
		"dangerous":
			if not dangerous_loot.is_empty():
				bounty.bonus_loot = dangerous_loot[randi() % dangerous_loot.size()]
		"deadly":
			if not deadly_loot.is_empty():
				bounty.bonus_loot = deadly_loot[randi() % deadly_loot.size()]
		"extreme":
			if not extreme_loot.is_empty():
				bounty.bonus_loot = extreme_loot[randi() % extreme_loot.size()]

## Interaction interface
func interact(_interactor: Node) -> void:
	_open_bounty_ui()

func get_interaction_prompt() -> String:
	var active_count := active_bounties.size()
	if active_count > 0:
		return "View %s (%d active)" % [board_name, active_count]
	return "View " + board_name

## Open bounty board UI
func _open_bounty_ui() -> void:
	if bounty_ui:
		return

	# Pause game
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Load and instantiate UI
	var ui_script := preload("res://scripts/ui/bounty_board_ui.gd")
	bounty_ui = Control.new()
	bounty_ui.set_script(ui_script)
	bounty_ui.name = "BountyBoardUI"
	bounty_ui.set("bounty_board", self)

	var canvas := CanvasLayer.new()
	canvas.name = "BountyBoardCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(bounty_ui)

	if bounty_ui.has_signal("ui_closed"):
		bounty_ui.ui_closed.connect(_on_bounty_ui_closed.bind(canvas))

## Close bounty UI
func _on_bounty_ui_closed(canvas: CanvasLayer) -> void:
	GameManager.exit_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()
	bounty_ui = null

## Accept a bounty
func accept_bounty(bounty: Bounty) -> bool:
	if bounty.is_active:
		return false

	# Remove from available, add to active
	var idx := available_bounties.find(bounty)
	if idx >= 0:
		available_bounties.remove_at(idx)

	bounty.is_active = true

	# Check existing inventory for collect bounties
	if bounty.objective_type == "collect":
		var current := InventoryManager.get_item_count(bounty.target)
		bounty.current_count = mini(current, bounty.required_count)
		if bounty.current_count >= bounty.required_count:
			bounty.is_complete = true

	active_bounties.append(bounty)
	bounty_accepted.emit(bounty)

	AudioManager.play_ui_confirm()
	return true

## Turn in a completed bounty
func turn_in_bounty(bounty: Bounty) -> bool:
	if not bounty.is_complete:
		return false

	# Give rewards
	InventoryManager.add_gold(bounty.gold_reward)
	if GameManager.player_data:
		var xp := int(bounty.xp_reward * GameManager.player_data.get_xp_multiplier())
		GameManager.player_data.add_ip(xp)

	# For collect bounties, remove items from inventory
	if bounty.objective_type == "collect":
		InventoryManager.remove_item(bounty.target, bounty.required_count)

	# Give bonus loot for deadly+ tiers
	if not bounty.bonus_loot.is_empty():
		InventoryManager.add_item(bounty.bonus_loot, 1)

	# Remove from active
	var idx := active_bounties.find(bounty)
	if idx >= 0:
		active_bounties.remove_at(idx)

	# Track to prevent immediate repeat
	var template_key := "%s_%s_%s" % [bounty.objective_type, bounty.target, bounty.tier]
	if template_key not in completed_bounty_ids:
		completed_bounty_ids.append(template_key)

	bounty_completed.emit(bounty)
	AudioManager.play_ui_confirm()

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var msg := "Bounty Complete! +%d Gold, +%d XP" % [bounty.gold_reward, bounty.xp_reward]
		if not bounty.bonus_loot.is_empty():
			var item_name := InventoryManager.get_item_name(bounty.bonus_loot)
			msg += " + %s" % item_name
		hud.show_notification(msg)

	return true

## Abandon a bounty (lose progress)
func abandon_bounty(bounty: Bounty) -> void:
	var idx := active_bounties.find(bounty)
	if idx >= 0:
		active_bounties.remove_at(idx)

## Refresh bounties (called on rest or other triggers)
func refresh_bounties() -> void:
	# Clear completed tracking to allow repeats
	completed_bounty_ids.clear()

	# Keep active bounties, regenerate available
	_generate_bounties()

## Update bounty progress from enemy kill
func _on_entity_killed(entity: Node, _killer: Node) -> void:
	if entity.has_method("get_enemy_data"):
		var enemy_data: Variant = entity.get_enemy_data()
		if enemy_data and "id" in enemy_data:
			_update_kill_progress(enemy_data.id)

## Update kill bounty progress
func _update_kill_progress(enemy_id: String) -> void:
	for bounty in active_bounties:
		if bounty.is_complete:
			continue
		if bounty.objective_type != "kill" and bounty.objective_type != "clear":
			continue

		# Check if this enemy matches the target
		var matches := false
		if bounty.target == enemy_id:
			matches = true
		# Also check category match (e.g., "goblin" matches "goblin_soldier")
		elif enemy_id.begins_with(bounty.target):
			matches = true
		# For clear objectives, check enemy type from template
		elif bounty.objective_type == "clear":
			# Clear objectives match any enemy in the target location
			matches = true

		if matches:
			bounty.current_count += 1
			if bounty.current_count >= bounty.required_count:
				bounty.is_complete = true
				_show_bounty_progress_notification(bounty, true)
			else:
				_show_bounty_progress_notification(bounty, false)

## Update collect bounty progress
func _on_item_added(item_id: String, quantity: int) -> void:
	for bounty in active_bounties:
		if bounty.is_complete:
			continue
		if bounty.objective_type != "collect":
			continue
		if bounty.target != item_id:
			continue

		bounty.current_count = mini(bounty.current_count + quantity, bounty.required_count)
		if bounty.current_count >= bounty.required_count:
			bounty.is_complete = true
			_show_bounty_progress_notification(bounty, true)
		else:
			_show_bounty_progress_notification(bounty, false)

## Show progress notification
func _show_bounty_progress_notification(bounty: Bounty, is_complete: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		if is_complete:
			hud.show_notification("Bounty Ready: %s" % bounty.title)
		else:
			hud.show_notification("%s: %s" % [bounty.title, bounty.get_progress_text()])

## Get bounties that are ready for turn-in
func get_ready_bounties() -> Array[Bounty]:
	var ready: Array[Bounty] = []
	for bounty in active_bounties:
		if bounty.is_complete:
			ready.append(bounty)
	return ready

## Serialize for saving
func to_dict() -> Dictionary:
	var active_data: Array = []
	for bounty in active_bounties:
		active_data.append({
			"id": bounty.id,
			"title": bounty.title,
			"description": bounty.description,
			"tier": bounty.tier,
			"objective_type": bounty.objective_type,
			"target": bounty.target,
			"target_display_name": bounty.target_display_name,
			"required_count": bounty.required_count,
			"current_count": bounty.current_count,
			"gold_reward": bounty.gold_reward,
			"xp_reward": bounty.xp_reward,
			"is_boss": bounty.is_boss,
			"is_complete": bounty.is_complete,
			"is_active": bounty.is_active,
			"bonus_loot": bounty.bonus_loot
		})

	return {
		"active_bounties": active_data,
		"completed_bounty_ids": completed_bounty_ids.duplicate()
	}

## Deserialize from save
func from_dict(data: Dictionary) -> void:
	active_bounties.clear()
	completed_bounty_ids.clear()

	var active_data: Array = data.get("active_bounties", [])
	for bd: Variant in active_data:
		if bd is Dictionary:
			var bounty := Bounty.new()
			bounty.id = bd.get("id", "")
			bounty.title = bd.get("title", "")
			bounty.description = bd.get("description", "")
			bounty.tier = bd.get("tier", "standard")
			bounty.objective_type = bd.get("objective_type", "kill")
			bounty.target = bd.get("target", "")
			bounty.target_display_name = bd.get("target_display_name", "")
			bounty.required_count = bd.get("required_count", 1)
			bounty.current_count = bd.get("current_count", 0)
			bounty.gold_reward = bd.get("gold_reward", 500)
			bounty.xp_reward = bd.get("xp_reward", 300)
			bounty.is_boss = bd.get("is_boss", false)
			bounty.is_complete = bd.get("is_complete", false)
			bounty.is_active = bd.get("is_active", true)
			bounty.bonus_loot = bd.get("bonus_loot", "")
			active_bounties.append(bounty)

	var completed: Array = data.get("completed_bounty_ids", [])
	for c: Variant in completed:
		completed_bounty_ids.append(str(c))

	# Regenerate available bounties
	_generate_bounties()

## Static factory method
static func spawn_bounty_board(parent: Node, pos: Vector3, board_name_param: String = "Bounty Board") -> BountyBoard:
	var board := BountyBoard.new()
	board.board_name = board_name_param
	board.position = pos
	parent.add_child(board)
	return board
