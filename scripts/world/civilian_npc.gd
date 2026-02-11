## civilian_npc.gd - Wandering civilian NPCs for towns
## Non-hostile NPCs that wander around and add life to the world
class_name CivilianNPC
extends CharacterBody3D

## Dialogue data for this NPC (optional - for scripted dialogue trees)
@export var dialogue_data: DialogueData

## Knowledge profile for topic-based conversations (optional - if null, uses default)
@export var knowledge_profile: NPCKnowledgeProfile

## Stable NPC ID for quest tracking (e.g., "barmaid_elder_moor")
@export var npc_id: String = ""

## Visual representation
var billboard: BillboardSprite
var collision_shape: CollisionShape3D
var wander: WanderBehavior
var interaction_area: Area3D

## Sprite configuration
## Target height for humanoids in units (roughly 1.8m)
const TARGET_HEIGHT := 2.46

## Per-sprite pixel sizes calculated from: pixel_size = TARGET_HEIGHT / frame_height
## These values normalize all sprites to the same in-game height
const PIXEL_SIZE_MAN := 0.0384       # 64px frame height
const PIXEL_SIZE_LADY_RED := 0.0182  # 135px frame height
const PIXEL_SIZE_WIZARD := 0.0189    # 130px frame height
const PIXEL_SIZE_BARMAID_BLONDE := 0.0189  # 130px frame height
const PIXEL_SIZE_BARMAID_BRUNETTE := 0.0234  # 105px frame height
## Dwarf sprites are shorter and stockier - roughly 75% of human height
const DWARF_TARGET_HEIGHT := 1.85  # Dwarves are shorter
const PIXEL_SIZE_DWARF := 0.029    # 64px frame height, shorter stature

var sprite_texture: Texture2D
var sprite_h_frames: int = 8  # Default for most civilian sprites
var sprite_v_frames: int = 3  # Default for most civilian sprites
var sprite_pixel_size: float = PIXEL_SIZE_MAN  # Default to man size
var sprite_offset_y: float = 0.0  # Vertical offset adjustment

## Color tint for variety
var tint_color: Color = Color.WHITE

## NPC name (for potential dialogue)
var npc_name: String = "Villager"

## Color variations for female NPCs (dress tints)
const DRESS_COLORS := [
	Color(1.0, 1.0, 1.0),      # Original red
	Color(0.7, 0.85, 1.0),     # Blue tint
	Color(0.85, 1.0, 0.7),     # Green tint
	Color(1.0, 0.9, 0.7),      # Yellow/gold tint
	Color(1.0, 0.75, 0.9),     # Pink tint
	Color(0.8, 0.7, 1.0),      # Purple tint
	Color(0.9, 0.9, 0.9),      # White/grey tint
	Color(1.0, 0.85, 0.75),    # Peach tint
]

## Color variations for male NPCs (clothing tints)
const MALE_COLORS := [
	Color(1.0, 1.0, 1.0),      # Original brown/tan
	Color(0.85, 0.9, 1.0),     # Cooler blue-grey
	Color(1.0, 0.95, 0.85),    # Warmer tan
	Color(0.9, 0.85, 0.8),     # Dusty brown
	Color(0.95, 0.9, 0.95),    # Faded purple-grey
	Color(0.85, 0.95, 0.85),   # Sage green tint
	Color(1.0, 0.9, 0.85),     # Rust/orange tint
	Color(0.8, 0.8, 0.85),     # Dark grey
]

## Color variations for wizard/mage robes
const WIZARD_COLORS := [
	Color(1.0, 1.0, 1.0),      # Original black/gold
	Color(0.7, 0.8, 1.0),      # Blue robes
	Color(0.6, 0.4, 0.5),      # Dark maroon
	Color(0.5, 0.7, 0.5),      # Forest green
	Color(0.8, 0.7, 1.0),      # Purple/violet
	Color(0.6, 0.5, 0.4),      # Brown robes
	Color(1.0, 0.9, 0.8),      # Cream/white
	Color(0.5, 0.5, 0.6),      # Dark grey
]

## Dwarf name prefixes and suffixes for procedural name generation
const DWARF_MALE_NAMES := [
	"Thorin", "Balin", "Dwalin", "Gimli", "Gloin", "Oin", "Bifur", "Bofur",
	"Bombur", "Dori", "Nori", "Ori", "Fili", "Kili", "Durin", "Thrain",
	"Borin", "Grimjaw", "Stonefoot", "Ironbeard", "Goldhand", "Hammerfall"
]

const DWARF_FEMALE_NAMES := [
	"Disa", "Gilda", "Thorina", "Brunhild", "Helga", "Ingrid", "Freya",
	"Sigrid", "Astrid", "Ragna", "Hilda", "Gudrun", "Embla", "Thyra"
]

func _ready() -> void:
	add_to_group("civilians")
	add_to_group("npcs")
	add_to_group("interactable")

	# Setup collision
	collision_layer = 1
	collision_mask = 1

	_create_visual()
	_create_collision()
	_create_interaction_area()
	_setup_wandering()

	# Register with WorldData for tracking
	_register_with_world_data()


## Register this NPC with WorldData for tracking
func _register_with_world_data() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	var hex: Vector2i = WorldData.world_to_axial(global_position)
	var zone_id: String = ""

	# Try to get zone_id from parent scene
	var parent: Node = get_parent()
	while parent:
		if "zone_id" in parent:
			zone_id = parent.zone_id
			break
		parent = parent.get_parent()

	# Default zone if not found
	if zone_id.is_empty():
		zone_id = "town_unknown"

	WorldData.register_npc(effective_id, hex, zone_id, "civilian")


func _exit_tree() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	WorldData.unregister_npc(effective_id)


func _create_visual() -> void:
	if not sprite_texture:
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = sprite_texture
	billboard.h_frames = sprite_h_frames
	billboard.v_frames = sprite_v_frames
	billboard.pixel_size = sprite_pixel_size
	billboard.idle_frames = sprite_h_frames
	billboard.walk_frames = sprite_h_frames
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
	billboard.name = "Billboard"
	billboard.offset_y = sprite_offset_y  # Configurable per NPC type
	add_child(billboard)

	# Apply color tint
	call_deferred("_apply_tint")


func _apply_tint() -> void:
	if billboard and billboard.sprite:
		billboard.sprite.modulate = tint_color


func _create_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.8, 0)
	add_child(collision_shape)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	area_shape.shape = capsule
	area_shape.position = Vector3(0, 0.9, 0)
	interaction_area.add_child(area_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Priority 1: Use scripted dialogue if available
	if dialogue_data:
		DialogueManager.start_dialogue(dialogue_data, npc_name)
		return

	# Priority 2: Use topic-based conversation system
	var profile := knowledge_profile
	if not profile:
		# Create default civilian profile if none assigned
		profile = _get_default_profile()

	if profile:
		ConversationSystem.start_conversation(self, profile)


## Get the default knowledge profile for this NPC type
func _get_default_profile() -> NPCKnowledgeProfile:
	# Try to load default civilian profile
	var default_path := "res://data/npc_profiles/civilian_default.tres"
	if ResourceLoader.exists(default_path):
		return load(default_path) as NPCKnowledgeProfile

	# Create a basic one on the fly
	return NPCKnowledgeProfile.generic_villager()


## Get unique NPC ID for conversation system
func get_npc_id() -> String:
	return name if name else "civilian_" + str(get_instance_id())


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Talk to " + npc_name


func _setup_wandering() -> void:
	wander = WanderBehavior.new()
	wander.wander_radius = 8.0
	wander.move_speed = 1.5
	wander.min_wait_time = 2.0
	wander.max_wait_time = 6.0
	add_child(wander)

	# Connect signals for animation
	wander.started_moving.connect(_on_started_moving)
	wander.stopped_moving.connect(_on_stopped_moving)


func _on_started_moving() -> void:
	if billboard:
		billboard.set_state(BillboardSprite.AnimState.WALK)


func _on_stopped_moving() -> void:
	if billboard:
		billboard.set_state(BillboardSprite.AnimState.IDLE)


func _process(_delta: float) -> void:
	# Update billboard facing direction
	if billboard and wander:
		billboard.facing_direction = wander.get_facing_direction()


## Validate a spawn position is not inside an object
static func validate_spawn_position(parent: Node, pos: Vector3, check_radius: float = 0.5) -> Vector3:
	# Get a Node3D to access the world space state for collision checking
	var world_node := parent.get_tree().get_first_node_in_group("player")
	if not world_node:
		# Try to get world from parent
		if parent is Node3D:
			var world := (parent as Node3D).get_world_3d()
			if world:
				var direct_state := world.direct_space_state
				if direct_state:
					return _find_valid_position(direct_state, pos, check_radius)
		return pos

	# Use player's world to get space state
	if world_node is Node3D:
		var world := (world_node as Node3D).get_world_3d()
		if world:
			var direct_state := world.direct_space_state
			if direct_state:
				return _find_valid_position(direct_state, pos, check_radius)

	return pos


## Find a valid spawn position near the desired position
static func _find_valid_position(space_state: PhysicsDirectSpaceState3D, pos: Vector3, radius: float) -> Vector3:
	# Check if original position is clear
	if _is_position_clear(space_state, pos, radius):
		return pos

	# Try offsets around the original position
	var offsets: Array[Vector3] = [
		Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0),
		Vector3(0, 0, 1.5), Vector3(0, 0, -1.5),
		Vector3(1.0, 0, 1.0), Vector3(-1.0, 0, 1.0),
		Vector3(1.0, 0, -1.0), Vector3(-1.0, 0, -1.0),
		Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0),
		Vector3(0, 0, 2.0), Vector3(0, 0, -2.0),
	]

	for offset: Vector3 in offsets:
		var test_pos: Vector3 = pos + offset
		if _is_position_clear(space_state, test_pos, radius):
			return test_pos

	# If no valid position found, return original (will be handled by stuck detection)
	return pos


## Check if a position is clear of obstacles
static func _is_position_clear(space_state: PhysicsDirectSpaceState3D, pos: Vector3, radius: float) -> bool:
	# Create a sphere shape query
	var shape := SphereShape3D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), pos + Vector3(0, 0.8, 0))  # Check at chest height
	query.collision_mask = 1  # World layer only

	var results := space_state.intersect_shape(query, 1)
	return results.is_empty()


## Static factory method for spawning civilians
static func spawn_civilian(parent: Node, pos: Vector3, sprite_path: String,
		h_frames: int = 7, v_frames: int = 8, random_color: bool = true,
		pixel_size: float = PIXEL_SIZE_MAN) -> CivilianNPC:  # Default to man size
	var npc := CivilianNPC.new()

	# Validate spawn position to avoid spawning inside objects
	var validated_pos := validate_spawn_position(parent, pos)
	npc.position = validated_pos

	# Load sprite
	var tex := load(sprite_path) as Texture2D
	if tex:
		npc.sprite_texture = tex
		npc.sprite_h_frames = h_frames
		npc.sprite_v_frames = v_frames

	npc.sprite_pixel_size = pixel_size

	# Apply random color tint
	if random_color:
		npc.tint_color = DRESS_COLORS[randi() % DRESS_COLORS.size()]

	parent.add_child(npc)
	return npc


## Spawn a woman NPC specifically (uses lady in red sprite with color variations)
## zone_id: Optional zone for unique name generation
static func spawn_woman(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/new lady in red.png",
		8,  # 8 columns
		1,  # 1 row
		false,  # Don't use default colors
		PIXEL_SIZE_LADY_RED  # Normalized for 135px frame height
	)
	npc.tint_color = DRESS_COLORS[randi() % DRESS_COLORS.size()]
	_assign_unique_name(npc, zone_id, true)
	return npc


## Spawn a man NPC specifically
## zone_id: Optional zone for unique name generation
static func spawn_man(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/man_civilian.png",
		8,  # 8 columns
		2,  # 2 rows
		false,   # Don't use default colors
		PIXEL_SIZE_MAN  # Reference size (64px frame height)
	)
	npc.tint_color = MALE_COLORS[randi() % MALE_COLORS.size()]
	_assign_unique_name(npc, zone_id, false)
	return npc


## Spawn a barmaid NPC (randomly picks between variants)
## zone_id: Optional zone for unique name generation
static func spawn_barmaid(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_barmaid_blonde(parent, pos, zone_id)
	else:
		return spawn_barmaid_brunette(parent, pos, zone_id)


## Spawn blonde barmaid (blue dress)
## zone_id: Optional zone for unique name generation
static func spawn_barmaid_blonde(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/4x4barmaid_civilian.png",
		4,
		2,
		false,   # Don't use default colors
		PIXEL_SIZE_BARMAID_BLONDE  # Normalized for 130px frame height
	)
	npc.tint_color = Color.WHITE  # Keep original colors (blue dress)
	_assign_unique_name(npc, zone_id, true, "Barmaid")
	return npc


## Spawn brunette barmaid (brown dress)
## zone_id: Optional zone for unique name generation
static func spawn_barmaid_brunette(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/3x3barmaid_civilian.png",
		3,
		1,
		false,   # Don't use default colors
		PIXEL_SIZE_BARMAID_BRUNETTE  # Normalized for 105px frame height
	)
	npc.tint_color = Color.WHITE  # Keep original colors (brown dress)
	_assign_unique_name(npc, zone_id, true, "Barmaid")
	return npc


## Spawn a wizard/mage NPC
## zone_id: Optional zone for unique name generation
static func spawn_wizard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/wizard_mage.png",
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_WIZARD  # Normalized for 130px frame height
	)
	npc.tint_color = WIZARD_COLORS[randi() % WIZARD_COLORS.size()]
	_assign_unique_name(npc, zone_id, false, "Mage")
	return npc


## Spawn a lady in red NPC
## zone_id: Optional zone for unique name generation
static func spawn_lady_in_red(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/new lady in red.png",
		8,  # 8 columns
		1,  # 1 row
		false,   # Don't use default colors
		PIXEL_SIZE_LADY_RED  # Normalized for 135px frame height
	)
	npc.tint_color = Color.WHITE  # Keep original colors
	_assign_unique_name(npc, zone_id, true)
	return npc


## Spawn a random civilian (man, woman, barmaid, wizard, or lady in red)
## zone_id: Optional zone for unique name generation
static func spawn_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.30:
		return spawn_woman(parent, pos, zone_id)
	elif roll < 0.60:
		return spawn_man(parent, pos, zone_id)
	elif roll < 0.75:
		return spawn_barmaid(parent, pos, zone_id)  # 15% chance for barmaid
	elif roll < 0.90:
		return spawn_lady_in_red(parent, pos, zone_id)  # 15% chance for lady in red
	else:
		return spawn_wizard(parent, pos, zone_id)   # 10% chance for wizard


## Helper to assign a unique name and npc_id to an NPC
## zone_id: Zone for unique name tracking (empty = use random name without tracking)
## is_female: Whether to use female names
## title: Optional title to append (e.g., "Barmaid" -> "Elara the Barmaid")
static func _assign_unique_name(npc: CivilianNPC, zone_id: String, is_female: bool, title: String = "") -> void:
	var first_name: String
	if zone_id.is_empty():
		# No zone tracking - use random name
		first_name = WorldLexicon.get_random_name(is_female)
	else:
		# Zone tracking - get unique name
		first_name = WorldLexicon.get_unique_name_for_zone(zone_id, is_female)
		if first_name.is_empty():
			# Fallback if all names exhausted
			first_name = WorldLexicon.get_random_name(is_female)

	# Set npc_id to first name only (for quest tracking)
	# Extract just the first name if surname was included
	var base_name: String = first_name.split(" ")[0]
	npc.npc_id = base_name.to_lower() + "_" + zone_id if not zone_id.is_empty() else base_name.to_lower()

	# Set display name with optional title
	if title.is_empty():
		npc.npc_name = first_name
	else:
		npc.npc_name = first_name + " the " + title


## ============================================================================
## DWARF NPC SPAWNING METHODS
## ============================================================================

## Spawn a dwarf guard/warrior NPC (uses blue armored sprite - dwarf_2.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_guard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/dwarf_2.png",
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original blue/purple armor colors
	_assign_dwarf_name(npc, zone_id, false, "Guard")
	return npc


## Spawn a dwarf warrior/soldier NPC (uses red armored sprite - dwarf_3.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_warrior(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/dwarf_3.png",
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original red/maroon armor colors
	_assign_dwarf_name(npc, zone_id, false, "Warrior")
	return npc


## Spawn a random dwarf civilian (either guard or warrior type)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var sprite_path: String
	var title: String
	if randf() < 0.5:
		sprite_path = "res://Sprite folders grab bag/dwarf_2.png"
		title = ""  # Just a regular dwarf
	else:
		sprite_path = "res://Sprite folders grab bag/dwarf_3.png"
		title = ""

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE
	_assign_dwarf_name(npc, zone_id, randf() < 0.3)  # 30% chance female
	return npc


## Spawn a dwarf refugee (wounded, displaced - slightly muted colors)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_refugee(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var sprite_path: String = "res://Sprite folders grab bag/dwarf_3.png" if randf() < 0.5 else "res://Sprite folders grab bag/dwarf_2.png"

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	# Muted, dusty colors for refugees
	npc.tint_color = Color(0.85, 0.8, 0.75)
	_assign_dwarf_name(npc, zone_id, randf() < 0.4, "Refugee")  # 40% chance female
	return npc


## Spawn a wounded dwarf soldier (darkened/muted colors to show injury)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_wounded(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/dwarf_3.png",  # Red armor for soldiers
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	# Pale, injured look
	npc.tint_color = Color(0.75, 0.7, 0.7)
	_assign_dwarf_name(npc, zone_id, false, "Wounded Soldier")
	# Wounded soldiers don't wander
	if npc.wander:
		npc.wander.queue_free()
		npc.wander = null
	return npc


## Spawn a random dwarf for the hold (variety of types)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.35:
		return spawn_dwarf_guard(parent, pos, zone_id)  # 35% guards
	elif roll < 0.70:
		return spawn_dwarf_warrior(parent, pos, zone_id)  # 35% warriors
	else:
		return spawn_dwarf_civilian(parent, pos, zone_id)  # 30% civilians


## Helper to assign a dwarf name to an NPC
static func _assign_dwarf_name(npc: CivilianNPC, zone_id: String, is_female: bool, title: String = "") -> void:
	var first_name: String
	if is_female:
		first_name = DWARF_FEMALE_NAMES[randi() % DWARF_FEMALE_NAMES.size()]
	else:
		first_name = DWARF_MALE_NAMES[randi() % DWARF_MALE_NAMES.size()]

	# Set npc_id
	npc.npc_id = first_name.to_lower() + "_" + zone_id if not zone_id.is_empty() else first_name.to_lower()

	# Set display name with optional title
	if title.is_empty():
		npc.npc_name = first_name
	else:
		npc.npc_name = first_name + " the " + title


## ============================================================================
## MOLTEN/FORGE DWARF NPC SPAWNING METHODS
## For use in forge levels, foundries, and hot metalwork areas
## ============================================================================

## Spawn a molten forge master (uses dwarf_molten1.png - brightest/most ornate)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_master(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/dwarf_molten1.png",
		5,  # 5 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original molten orange/gold colors
	_assign_dwarf_name(npc, zone_id, false, "Forge Master")
	return npc


## Spawn a molten forge worker (uses dwarf_molten2.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_worker(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/dwarf_molten2.png",
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original molten colors
	_assign_dwarf_name(npc, zone_id, false, "Smith")
	return npc


## Spawn a molten forge guard (uses dwarf_molten3.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_guard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://Sprite folders grab bag/dwarf_molten3.png",
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original molten colors
	_assign_dwarf_name(npc, zone_id, false, "Forge Guard")
	return npc


## Spawn a random forge dwarf
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.15:
		return spawn_dwarf_forge_master(parent, pos, zone_id)  # 15% forge masters
	elif roll < 0.60:
		return spawn_dwarf_forge_worker(parent, pos, zone_id)  # 45% workers
	else:
		return spawn_dwarf_forge_guard(parent, pos, zone_id)   # 40% guards
