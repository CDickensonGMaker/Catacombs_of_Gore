# Catacombs of Gore - Agent Instructions

## PROACTIVE AGENT ENGAGEMENT (MANDATORY)

**CRITICAL:** Agents MUST be employed AUTOMATICALLY. Do NOT wait for user to ask.
**The user has explicitly requested agents run without prompting.**

After EVERY code edit, silently deploy relevant validators in background.
Aggregate findings and report only significant issues.

| Trigger | Agent(s) to Run |
|---------|-----------------|
| After writing/editing GDScript | `gdscript-linter` |
| After adding sprites or textures | `asset-validator` |
| After enemy/item stat changes | `balance-reviewer` |
| After quest system changes | `dialogue-quest-master` |
| After adding/modifying WorldGrid locations | `scene-auditor` |
| After adding new levels/regions | `scene-auditor` |
| Before declaring task complete | `scene-auditor` + relevant domain agent |

**Run agents in parallel when possible.** Multiple agents can analyze simultaneously.

---

## MANDATORY WORKFLOW: Research → Code → Verify

Before making ANY code changes, follow this process:

### 1. RESEARCH (KNW Phase)
- Read ALL relevant files completely before proposing changes
- Understand existing patterns and conventions in the codebase
- Identify ALL files that will need modification
- List dependencies and potential side effects
- Do NOT proceed until you fully understand the problem

### 2. CODE (Implementation Phase)
- Make changes methodically, one system at a time
- Complete each feature FULLY before moving to the next
- Follow existing code patterns (naming, structure, style)
- Add audio event hooks even if no sounds yet (e.g., "enemy_hit", "item_pickup")
- Never leave placeholder/stub code without explicit user approval

### 3. VERIFY (Audit Phase)
- After implementation, audit all connections
- Check for: unused parameters, orphan files, missing signals
- Verify the feature works with existing systems
- Run through the user flow mentally to catch edge cases
- Report what was done and what to test

## RULES
- Do NOT add features beyond what was requested
- Do NOT move on until current task is complete
- If uncertain, ASK before implementing
- Prefer editing existing files over creating new ones
- Always check if similar patterns exist before creating new ones

## QUEST DESIGN RULES
**Every quest giver MUST have a corresponding quest receiver.**
- If a quest requires turning in to an NPC, that NPC MUST exist and be spawned in the target zone
- Before creating a quest, verify:
  1. `giver_npc_id` exists and is spawned in `giver_region`
  2. `turn_in_target` NPC exists and is spawned in `turn_in_zone`
  3. All `target` NPCs in objectives exist in their respective zones
- When adding a quest giver to a zone, also verify/add the receiver
- Quest JSON fields that require spawned NPCs:
  - `giver_npc_id` + `giver_region`
  - `turn_in_target` + `turn_in_zone` (if `turn_in_type` is "npc_specific")
  - `objectives[].target` (if objective type is "talk")

## ITEM DESIGN PHILOSOPHY
Every item MUST serve a gameplay purpose. No "junk" items without function.
- **Consumables:** Must provide meaningful effects (healing, buffs, cures)
- **Food/Drink:** Each should have a unique benefit (ale = courage buff, cheese = stamina regen, meat = HP regen, bread = cheap heal)
- **Materials:** Must be used for crafting, repair, or quests (stone blocks = construction/repair, ores = smithing)
- **Tools:** Must enable gameplay actions (lockpicks = open locked containers, repair kits = fix gear)
- **Equipment:** Must have stat effects and durability considerations
- When creating new items, document their purpose in the description

## PERFORMANCE BUDGETS
- Max active enemies per zone: 20
- Max dropped items per zone: 50
- Max active projectiles: 30
- Projectile pool size: 50

## INVENTORY & ENCUMBRANCE SYSTEM

**No hard limit on inventory slots.** Players can always pick up items.

**Encumbrance penalties apply when overweight:**
- 50% movement speed reduction
- Cannot sprint
- Cannot jump
- Cannot dodge

**Carry weight formula:**
```
max_carry_weight = 50 + (Grit * 10)
```

**When picking up items:** If player becomes overencumbered, show notification "You are overencumbered!"

**Do NOT add slot limits or "inventory full" messages.** Use encumbrance as the only limiter.

## LOOTABLE CORPSE SYSTEM (Fallout-style)

**Enemies do NOT auto-drop loot.** When an enemy dies:
1. XP is awarded automatically (only auto-granted reward)
2. A `LootableCorpse` spawns at death position
3. Player must interact with corpse to search it and take items

**Loot Tiers (based on enemy level 1-100):**
| Level Range | Tier | Quality Distribution |
|-------------|------|---------------------|
| 1-10 | BASIC | Mostly Poor/Below Average |
| 11-25 | COMMON | Below Average to Average |
| 26-50 | UNCOMMON | Average with chance for Fine |
| 51-75 | RARE | Good quality common |
| 76-90 | EPIC | Above Average common |
| 91-100 | LEGENDARY | High quality guaranteed |

**EnemyData level field:**
```gdscript
@export var level: int = 1  ## Enemy level (1-100) - determines loot tier
```

**Humanoid enemies** (bandits, cultists, goblins, Tengers) carry:
- Weapons appropriate to their tier
- Armor (chance increases with tier)
- Gold (scales with level)
- Food, potions, utility items

**Creature enemies** (beasts, undead, demons) drop:
- Material drops (pelts, fangs, claws)
- No gold (creatures don't carry money)
- Drop quantity increases with tier

**Corpse Lifecycle:**
- Despawns after 5 minutes if never searched
- Despawns after 30 seconds if emptied
- Visual: gore mesh with blood pool

**Files:**
- `scripts/world/lootable_corpse.gd` - Corpse class with loot generation
- `scripts/ui/corpse_loot_ui.gd` - Search interface (dark/gore themed)

## AUDIO EVENT NAMING CONVENTION
Use these standardized event names:
- `player_hit`, `player_attack`, `player_death`
- `enemy_hit`, `enemy_death`, `enemy_attack`
- `item_pickup`, `item_drop`, `item_use`
- `menu_open`, `menu_close`, `menu_select`
- `projectile_fire`, `projectile_hit`
- `footstep_stone`, `footstep_wood`, `footstep_grass`

## SAVE DATA ZONES
Each scene must have a unique `zone_id` for save data tracking.
Format: `area_subarea` (e.g., `dungeon_crypt_01`, `town_marketplace`)

---

## GDSCRIPT COMMON PITFALLS (AVOID THESE)

### CRITICAL: Reserved Keywords in Godot 4

**NEVER use these as variable or parameter names - they are reserved keywords:**
- `trait` - Use `trait_name` or `personality_trait` instead
- `await` - Reserved for async
- `signal` - Use `sig` or `signal_name`
- `class` - Use `cls` or `class_ref`
- `extends` - Reserved
- `enum` - Use `enum_value` or `enum_type`

```gdscript
# BAD - Will cause parser errors
func has_trait(trait: String) -> bool:
    return trait in traits

# GOOD - Use alternative name
func has_trait(trait_name: String) -> bool:
    return trait_name in traits
```

**ALWAYS use explicit type annotations in these cases:**

### 1. Dictionary Variables from Arrays
```gdscript
# BAD - Type inference fails
var items := [{"id": "sword", "damage": 10}]
var selected := items[0]  # ERROR: Cannot infer type

# GOOD - Explicit types
var items: Array[Dictionary] = [{"id": "sword", "damage": 10}]
var selected: Dictionary = items[0]
```

### 2. Variables Assigned from Dictionary Access
```gdscript
# BAD - Dictionary values are Variant
var data := {"name": "Bob", "level": 5}
var name := data["name"]  # Type is Variant, not String

# GOOD - Cast or declare type
var name: String = data["name"]
var level: int = data["level"]
```

### 3. Loop Variables from Untyped Collections
```gdscript
# BAD
for item in some_array:
    var id := item["id"]  # May fail if item type unknown

# GOOD
for item: Dictionary in some_array:
    var id: String = item["id"]
```

### 4. Return Values from get() Methods
```gdscript
# BAD - get() returns Variant
var value := dict.get("key", 0)

# GOOD
var value: int = dict.get("key", 0)
```

### 5. Expressions Using Loop Variables from Arrays
```gdscript
# BAD - Loop variable type unknown, expression result can't be inferred
var offsets := [Vector3(1, 0, 0), Vector3(-1, 0, 0)]
for offset in offsets:
    var new_pos := pos + offset  # ERROR: Cannot infer type

# GOOD - Type the array AND the loop variable AND the result
var offsets: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0)]
for offset: Vector3 in offsets:
    var new_pos: Vector3 = pos + offset
```

### 6. Static Function Variables from Untyped Sources
```gdscript
# BAD - Static functions are stricter about type inference
static func find_position(positions: Array) -> Vector3:
    for pos in positions:
        var adjusted := pos + Vector3(0, 1, 0)  # ERROR in static context

# GOOD - Be explicit in static functions
static func find_position(positions: Array[Vector3]) -> Vector3:
    for pos: Vector3 in positions:
        var adjusted: Vector3 = pos + Vector3(0, 1, 0)
```

### 7. Boolean Comparisons and Expressions
```gdscript
# BAD - Comparison result type cannot be inferred
var tracked_id := QuestManager.get_tracked_quest_id()
for quest in active_quests:
    var is_tracked := (quest.id == tracked_id)  # ERROR: Cannot infer type

# GOOD - Explicitly type boolean variables
var tracked_id: String = QuestManager.get_tracked_quest_id()
for quest in active_quests:
    var is_tracked: bool = (quest.id == tracked_id)
```

### 8. Ternary-style Expressions
```gdscript
# BAD - Ternary result type unclear
var color := COL_GOLD if is_main else COL_TEXT  # May fail inference

# GOOD - Explicit type for conditional assignments
var color: Color = COL_GOLD if is_main else COL_TEXT
```

### 9. Node vs Node3D (global_position)
```gdscript
# BAD - Node does NOT have global_position!
class_name MyEncounter
extends Node  # Wrong base class!

func spawn_enemy() -> void:
    var pos := global_position  # ERROR: Identifier "global_position" not declared

# GOOD - Use Node3D for anything with position
class_name MyEncounter
extends Node3D  # Correct!

func spawn_enemy() -> void:
    var pos := global_position  # Works!
```

**Rule:** If your script needs `position`, `global_position`, `transform`, or `global_transform`, it MUST extend `Node3D` (or a subclass like `CharacterBody3D`).

### 10. Static Function Signature Override Mismatch
```gdscript
# Parent class (civilian_npc.gd):
static func spawn_dwarf_guard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
    pass

# BAD - Child class with DIFFERENT signature causes parse error!
class_name GuardNPC
extends CivilianNPC

static func spawn_dwarf_guard(parent: Node, pos: Vector3, patrol: Array[Vector3] = []) -> GuardNPC:
    pass  # ERROR: The function signature doesn't match the parent

# GOOD - Use a DIFFERENT function name to avoid conflict
static func spawn_guard_dwarf(parent: Node, pos: Vector3, patrol: Array[Vector3] = []) -> GuardNPC:
    pass  # Works! Different name, no override conflict
```

**Rule:** Static functions in child classes with the same name as parent MUST have the exact same signature. If you need different parameters, use a different function name.

**Rule of thumb:** When working with Dictionary, untyped Array, comparisons, or conditional expressions, ALWAYS add explicit type annotations. This is especially critical in static functions, loop variables, and boolean expressions. **NEVER use `:=` for comparisons or conditional assignments - always use explicit `: Type =` syntax.**

---

## AUTOLOAD API FUNCTION REFERENCE

**CRITICAL:** Always verify function names exist before using them. These are the CORRECT function names for common operations.

### InventoryManager Functions
```gdscript
# Item queries
InventoryManager.get_item_name(item_id: String) -> String      # Get display name
InventoryManager.get_item_description(item_id: String) -> String
InventoryManager.get_item_data(item_id: String) -> Resource    # Get ItemData resource
InventoryManager.get_item_count(item_id: String) -> int        # Count in inventory
InventoryManager.get_item_value(item_id: String, quality) -> int

# Inventory operations
InventoryManager.add_item(item_id: String, quantity: int = 1) -> bool
InventoryManager.remove_item(item_id: String, quantity: int = 1) -> bool
InventoryManager.has_item(item_id: String, quantity: int = 1) -> bool
InventoryManager.add_gold(amount: int) -> void
InventoryManager.remove_gold(amount: int) -> bool
```

### Common Mistakes
```gdscript
# WRONG - These functions DO NOT exist:
InventoryManager.get_item_display_name(item_id)  # Use get_item_name()
InventoryManager.give_item(item_id)              # Use add_item()
InventoryManager.take_item(item_id)              # Use remove_item()

# CORRECT versions:
var name: String = InventoryManager.get_item_name(item_id)
var success: bool = InventoryManager.add_item(item_id, quantity)
var removed: bool = InventoryManager.remove_item(item_id, quantity)
```

### GameManager Functions
```gdscript
# Player data access
GameManager.player_data.level          # Player level (int)
GameManager.player_data.gold           # Player gold (int)
GameManager.player_data.add_ip(amount) # Add improvement points (XP)
GameManager.player_data.take_damage(amount)
GameManager.player_data.get_effective_stat(Enums.Stat.STAT_NAME) -> int
GameManager.player_data.get_skill(Enums.Skill.SKILL_NAME) -> int
```

### CraftingRecipe Properties
**CRITICAL:** CraftingRecipe uses `materials`, NOT `ingredients`!

```gdscript
# CraftingRecipe resource properties (scripts/data/crafting_recipe.gd)
recipe.recipe_id: String              # Unique ID
recipe.display_name: String           # Display name
recipe.description: String            # Description text
recipe.category: String               # "Weapon", "Armor", "Consumable", "Tool", "Material", "Food"
recipe.materials: Dictionary          # {item_id: quantity} - NOT "ingredients"!
recipe.gold_cost: int                 # Gold required
recipe.required_engineering: int      # Engineering skill required
recipe.required_arcana: int           # Arcana skill required
recipe.output_item_id: String         # Item produced
recipe.output_quantity: int           # How many items produced
recipe.base_quality: Enums.ItemQuality
recipe.can_crit: bool                 # Can get quality bonus on crit

# Methods
recipe.can_craft() -> bool            # Has materials and gold?
recipe.meets_requirements() -> bool   # Has required skills?
recipe.craft() -> Dictionary          # Execute craft, returns {success, item_id, quantity, quality}
```

**Common Mistakes:**
```gdscript
# WRONG - "ingredients" does NOT exist!
recipe.ingredients.size()  # ERROR!

# CORRECT - use "materials"
recipe.materials.size()
```

---

## BILLBOARDSPRITE API

When creating NPCs using BillboardSprite, follow these rules to avoid common errors:

### 1. Modulate: Access the Child Sprite
The BillboardSprite is a Node3D container. The actual Sprite3D is a child named `sprite`.

```gdscript
# WRONG - BillboardSprite (Node3D) has no modulate property
billboard.modulate = Color(0.9, 0.75, 0.65)

# RIGHT - Access the child Sprite3D
billboard.sprite.modulate = Color(0.9, 0.75, 0.65)
```

### 2. Sprite Created in _ready()
The internal `sprite` child is created when BillboardSprite enters the scene tree. You must call `add_child()` BEFORE accessing `billboard.sprite`.

```gdscript
# WRONG - sprite doesn't exist yet
billboard.sprite.modulate = Color.RED
add_child(billboard)

# RIGHT - add first, then access sprite
add_child(billboard)
if billboard.sprite:
    billboard.sprite.modulate = Color.RED
```

### 3. Walking State Method
The method is `set_walking()`, NOT `set_moving()`.

```gdscript
# WRONG
billboard.set_moving(true)

# RIGHT
billboard.set_walking(true)
billboard.set_walking(false)
```

### 4. Available Methods
| Method | Description |
|--------|-------------|
| `set_walking(bool)` | Toggle walk/idle animation |
| `set_state(AnimState)` | Set state: IDLE, WALK, ATTACK, HURT, DEATH |
| `play_death()` | Play death animation (one-shot) |
| `play_hurt()` | Play hurt flash + animation |
| `play_attack()` | Play attack animation (one-shot) |
| `set_facing_direction(Vector3)` | For 8-directional sprites |
| `setup(config: Dictionary)` | Reconfigure and recreate sprite |

### 5. Quick Reference
```gdscript
# Creating a billboard NPC
var billboard = BillboardSprite.new()
billboard.sprite_sheet = preload("res://path/to/sprite.png")
billboard.h_frames = 5
billboard.v_frames = 1
billboard.pixel_size = 0.0384  # Standard humanoid size
billboard.idle_frames = 5
billboard.walk_frames = 5
billboard.idle_fps = 3.0
billboard.walk_fps = 6.0
add_child(billboard)

# After adding, you can access the sprite
if billboard.sprite:
    billboard.sprite.modulate = Color(0.9, 0.8, 0.7)
```

---

## ENEMYBASE SPAWN API

When spawning enemies in hand-crafted levels, use the static factory method:

```gdscript
# Full signature
static func spawn_billboard_enemy(
    parent: Node,
    pos: Vector3,
    enemy_data_path: String,      # Path to .tres file, NOT EnemyData object!
    sprite_texture: Texture2D,     # Loaded texture, NOT path string!
    h_frames: int = 4,
    v_frames: int = 4
) -> EnemyBase
```

### Correct Usage
```gdscript
# CORRECT - pass path string and loaded texture
var enemy_data_path := "res://data/enemies/human_bandit.tres"
var sprite_texture: Texture2D = load("res://assets/sprites/enemies/human_bandit.png")

var enemy = EnemyBase.spawn_billboard_enemy(
    self,
    marker.global_position,
    enemy_data_path,      # String path
    sprite_texture,       # Texture2D object
    3,                    # h_frames
    4                     # v_frames
)
```

### Common Mistakes
```gdscript
# WRONG - passing EnemyData object instead of path string
var enemy_data: EnemyData = load(enemy_data_path)
EnemyBase.spawn_billboard_enemy(self, pos, enemy_data, ...)  # ERROR!

# WRONG - passing sprite path string instead of Texture2D
EnemyBase.spawn_billboard_enemy(self, pos, path, "res://sprite.png", ...)  # ERROR!
```

### Hand-Crafted Level Enemy Spawning Pattern
```gdscript
func _spawn_enemy_at_marker(marker: Node3D) -> void:
    var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/human_bandit.tres")
    var sprite_path: String = marker.get_meta("sprite_path", "res://assets/sprites/enemies/human_bandit.png")
    var h_frames: int = marker.get_meta("h_frames", 3)
    var v_frames: int = marker.get_meta("v_frames", 4)

    var sprite_texture: Texture2D = load(sprite_path)
    if not sprite_texture:
        push_error("Failed to load sprite: %s" % sprite_path)
        return

    var enemy = EnemyBase.spawn_billboard_enemy(
        self,
        marker.global_position,
        enemy_data_path,
        sprite_texture,
        h_frames,
        v_frames
    )

    if enemy:
        enemy.add_to_group("enemies")
```

### Enemy Dialogue System (FIGHT/BRIBE/NEGOTIATE/INTIMIDATE)

The humanoid dialogue system allows pacifist resolution for certain enemies. **This is disabled by default** and must be explicitly enabled per-enemy for special encounters.

**EnemyData flag:**
```gdscript
@export var allows_dialogue: bool = false  ## If true, shows FIGHT/BRIBE/NEGOTIATE/INTIMIDATE options
```

**When to enable `allows_dialogue = true`:**
- Named bandit leaders or quest-related NPCs
- Enemies you want players to potentially spare
- Boss encounters with negotiation options
- Special story moments

**Regular enemies (human_bandit, etc.) should keep `allows_dialogue = false`** - players must fight them. Reserve the dialogue options for meaningful encounters.

---

## DUNGEONROOM API

When working with procedurally generated rooms:

```gdscript
# DungeonRoom properties (NOT methods!)
var room: DungeonRoom = generator.rooms[0]

room.room_center      # Vector3 - center position of the room (USE THIS)
room.room_index       # int - index in generator.rooms array
room.template         # RoomTemplate - the template used to create this room
room.connected_rooms  # Dictionary[Vector3, DungeonRoom] - connections by direction
room.is_explored      # bool - has player entered this room
room.is_cleared       # bool - are all enemies dead
```

### Common Mistake
```gdscript
# WRONG - get_center() does not exist!
spawn.global_position = entrance_room.get_center() + Vector3(0, 0.5, 0)  # ERROR!

# CORRECT - use room_center property
spawn.global_position = entrance_room.room_center + Vector3(0, 0.5, 0)
```

---

## ZONEDOOR API

When spawning doors in dungeons or levels, use the static factory method:

```gdscript
# Full signature with all 6 parameters
static func spawn_door(
    parent: Node,
    pos: Vector3,
    target: String,
    spawn_id: String = "default",
    door_name_param: String = "Door",
    show_frame_param: bool = true
) -> ZoneDoor
```

### Example Usage
```gdscript
# Spawning a door with all options
var door := ZoneDoor.spawn_door(
    doors_container,           # Parent node
    marker.global_position,    # Position
    target_scene,              # Target scene path (or SceneManager.RETURN_TO_WILDERNESS)
    "from_level_1",            # Spawn point ID in target scene
    "Cave Entrance",           # Display name for interaction prompt
    true                       # Show door frame geometry
)
door.rotation = marker.rotation  # Apply rotation after spawning
```

### Special Target Values
- `SceneManager.RETURN_TO_WILDERNESS` - Returns player to wilderness grid system
- Regular scene path like `"res://scenes/levels/bandit_hideout_level_2.tscn"`

### Door Properties (set after spawning if needed)
| Property | Type | Description |
|----------|------|-------------|
| `is_locked` | bool | Whether door requires unlocking |
| `lock_difficulty` | int | Lockpicking skill required (0 = no skill check) |
| `return_to_previous` | bool | If true, returns to previous scene instead of target |

---

## HAND-CRAFTED LEVEL STRUCTURE

When creating hand-crafted levels (dungeons, zones, etc.), use this standardized node naming convention in .tscn files:

### Required Node Names
| Node Name | Purpose | Children |
|-----------|---------|----------|
| `SpawnPoints` | Player spawn locations | Marker3D with `spawn_id` metadata |
| `EnemySpawns` | Enemy spawn markers | Marker3D with enemy metadata |
| `DoorPositions` | Door spawn markers | Marker3D with door metadata |
| `ChestPositions` | Chest spawn markers | Marker3D with chest metadata |

**CRITICAL:** Scripts must use these EXACT names. Do NOT use alternatives like:
- `Enemies` (wrong) → Use `EnemySpawns`
- `Doors` (wrong) → Use `DoorPositions`
- `Chests` (wrong) → Use `ChestPositions`

### Marker Metadata Reference

**SpawnPoints markers:**
```
metadata/spawn_id = "default"  # or "from_exterior", "from_level_2", etc.
```

**EnemySpawns markers:**
```
metadata/enemy_data = "res://data/enemies/human_bandit.tres"
metadata/sprite_path = "res://assets/sprites/enemies/human_bandit.png"
metadata/h_frames = 3
metadata/v_frames = 4
metadata/patrol_radius = 5.0  # Optional
metadata/aggro_range = 10.0   # Optional
```

**DoorPositions markers:**
```
metadata/target_scene = "res://scenes/levels/bandit_hideout_level_2.tscn"
metadata/spawn_id = "from_level_1"
metadata/door_label = "Cave Entrance"
metadata/show_frame = true
```

**ChestPositions markers:**
```
metadata/chest_id = "bandit_chest_01"
metadata/loot_table = "common"  # or "rare", "boss", etc.
metadata/is_locked = false
metadata/lock_difficulty = 0
```

### Standard Level Script Structure
```gdscript
var spawn_points: Node3D
var enemy_spawns: Node3D
var door_positions: Node3D
var chest_positions: Node3D

func _ready() -> void:
    # Use get_node_or_null - nodes may not exist in every scene
    spawn_points = get_node_or_null("SpawnPoints")
    enemy_spawns = get_node_or_null("EnemySpawns")
    door_positions = get_node_or_null("DoorPositions")
    chest_positions = get_node_or_null("ChestPositions")

    _setup_spawn_points()
    _setup_enemies()
    _setup_doors()
    _setup_chests()
```

### Common Mistake
```gdscript
# WRONG - @onready fails if node doesn't exist
@onready var enemies: Node3D = $Enemies  # Crash if no Enemies node!

# CORRECT - get_node_or_null in _ready()
var enemies: Node3D

func _ready():
    enemies = get_node_or_null("EnemySpawns")
    if enemies:
        # process enemies
```

---

## GLB/BLENDER MODEL COLLISION

**CRITICAL:** Do NOT use `create_trimesh_collision()` on entire GLB models. This creates collision for ALL geometry including archways, railings, and decorative elements that players should walk through.

### The Problem
```gdscript
# BAD - Creates collision on EVERYTHING including passable areas
func _generate_terrain_collision() -> void:
    var terrain := get_node_or_null("Terrain")
    if terrain:
        _add_collision_to_meshes(terrain)  # Blocks doorways, archways, etc!
```

### The Solution

**Option 1: Use ground plane collision only**
```gdscript
# GOOD - Simple ground plane + barriers
func _ready() -> void:
    _setup_ground_plane()  # Floor collision
    _setup_arena_barrier()  # Perimeter walls
    # Do NOT call _generate_terrain_collision()
```

**Option 2: Use GLBCollisionProcessor with naming conventions**
```gdscript
# Use smart collision based on mesh names
var terrain := get_node_or_null("Terrain")
if terrain:
    GLBCollisionProcessor.process_node(terrain)
```

### Blender Naming Conventions

Tell artists to use these suffixes in Blender object names:

**Gets collision (solid objects):**
| Suffix | Use Case |
|--------|----------|
| `_floor`, `_ground` | Floor surfaces |
| `_wall`, `_walls` | Solid walls |
| `_pillar`, `_column` | Pillars/columns |
| `_stairs`, `_steps` | Stairways |
| `_solid`, `_block` | Generic solid objects |

**No collision (passable/decorative):**
| Suffix | Use Case |
|--------|----------|
| `_arch`, `_archway` | Archways (walk through) |
| `_frame`, `_doorframe` | Door/window frames |
| `_railing`, `_rail` | Railings (visual only) |
| `_decor`, `_prop` | Decorative props |
| `_trim`, `_molding` | Trim details |

### Slash Command

Use `/fix-mesh-collision <script-path>` to automatically fix collision issues in a level script.

---

## CHEST SPAWN API

When spawning chests in levels, use the static factory method (no .tscn file needed):

```gdscript
# Full signature
static func spawn_chest(
    parent: Node,
    pos: Vector3,
    p_chest_name: String = "Chest",
    p_locked: bool = false,
    p_lock_dc: int = 10,
    p_persistent: bool = false,
    p_chest_id: String = ""
) -> Chest
```

### Example Usage
```gdscript
# Spawn a locked chest with loot
var chest := Chest.spawn_chest(
    self,                    # Parent node
    marker.global_position,  # Position
    "Bandit Chest",          # Display name
    true,                    # Is locked
    15,                      # Lock DC
    false,                   # Not persistent (disappears when empty)
    "bandit_chest_01"        # Unique ID
)
chest.rotation = marker.rotation
chest.setup_with_loot(LootTables.LootTier.COMMON)
```

### LootTables.LootTier Values
| Tier | Description |
|------|-------------|
| `JUNK` | Common trash, low value |
| `COMMON` | Basic gear and supplies |
| `UNCOMMON` | Better quality items |
| `RARE` | Good finds |
| `EPIC` | Exceptional items |
| `LEGENDARY` | Best items in the game |

### ChestPositions Marker Metadata
```
metadata/chest_id = "bandit_chest_01"
metadata/chest_name = "Bandit Chest"
metadata/is_locked = true
metadata/lock_difficulty = 15
metadata/is_persistent = false
metadata/loot_tier = "common"  # junk, common, uncommon, rare, epic, legendary
```

---

## SPECIALIZED AGENTS

The following agents work together to streamline development. Use them proactively.

### Agent: gdscript-linter
**Purpose:** Catches common GDScript issues before runtime.
**When to use:** After writing new code, before testing.
**Checks:**
- Type safety (missing type hints on exports)
- Null safety (potential null access)
- Signal naming conventions
- Function too long (>50 lines)
- Dead code detection
- Proper cleanup in _exit_tree

### Agent: asset-validator
**Purpose:** Validates game assets (sprites, textures, audio) and their references in code.
**When to use:** After adding new sprites, before committing art changes, when sprites display incorrectly.
**Checks:**
- Sprite sheet dimensions match h_frames x v_frames in code
- All referenced asset paths exist
- Image dimensions are power-of-2 friendly for PS1 aesthetic
- No orphan assets (files not referenced anywhere)

### Agent: scene-auditor
**Purpose:** Scans scene files and scripts for integrity issues.
**When to use:** After major refactors, when signals aren't firing, when nodes seem disconnected.
**Checks:**
- All signal connections are valid
- No orphan nodes (nodes with no purpose)
- All preload/load paths resolve
- Scene inheritance is correct
- No circular dependencies
- WorldGrid location_ids match scene files

### Agent: balance-reviewer
**Purpose:** Reviews game balance - stats, damage, spawn rates, economy.
**When to use:** After adding enemies, items, or adjusting combat values.
**Checks:**
- Enemy HP vs player damage = reasonable TTK (time to kill)
- Player HP vs enemy damage = survivability
- Item costs vs rewards
- Spawn rates vs difficulty curve
- Loot table weights
- Danger levels vs enemy difficulty

### Agent: dialogue-quest-master
**Purpose:** Specialist for creating dialogue, quests, bounties, and conversation-to-quest pipelines.
**When to use:** Creating NPCs, writing dialogue trees, adding quests, creating bounty content.

**Expertise:**
- DialogueData/DialogueNode/DialogueChoice structures
- ConversationSystem topic-based responses
- Quest/Objective definitions in JSON
- BountyManager bounty generation and turn-in
- WorldLexicon region/creature/settlement data
- NPC knowledge profiles and archetypes
- Disposition-gated content
- Skill checks in dialogue

**Key Systems:**
- `BountyManager` - Autoload managing bounty quests via QuestManager
- `WorldLexicon` - Static data for regions, creatures, settlements, NPC names
- `ConversationSystem` - Topic-based conversations with QUESTS topic for bounties
- Action type 8 = SET_FLAG (sets dialogue flags for quest hooks)

**Bounty System Flow:**
1. Player talks to NPC, selects "Looking for work" (QUESTS topic)
2. BountyManager generates bounty based on region
3. Player accepts -> Quest created in QuestManager -> Appears in journal
4. Player kills targets (QuestManager tracks automatically)
5. Player returns to NPC -> Turn in bounty -> Rewards given

**Standards:**
- All quest objectives must have valid targets
- Response_ids must be unique within pools
- Creature IDs in WorldLexicon must match enemy .tres files
- Disposition ranges don't create unreachable content
- Required_knowledge tags are valid

### Agent: town-builder
**Purpose:** Specialist for creating towns, cities, capitals, and medieval buildings in PS1 style.
**When to use:** Building settlements, creating architecture, designing town layouts, generating buildings.

**Art Style: PS1 Medieval Architecture**

All buildings must follow these constraints:

**Geometry:**
- Extremely low poly (8-30 faces per building max)
- No smooth curves - everything is hard edges and flat planes
- Roofs are simple 2-4 face slopes, no overhangs modeled (use texture)
- Windows and doors are texture-only, never modeled geometry
- Timber framing is part of the texture, not extra meshes

**Textures:**
- Max 128x128 or 64x64 per texture
- No filtering (use nearest-neighbor / pixel filtering)
- Affine texture mapping (no perspective correction)
- Muted earthy palette: browns, tans, slate grays, dusty greens
- Hand-painted look with visible low-res detail

**Vertex Snapping:**
- All vertices snap to a grid (simulates PS1 vertex jitter)
- Wobble increases with camera distance

**Building Types:**
- Taverns, blacksmiths, merchant stalls, chapels, guard towers
- Half-timbered Tudor style with stone foundations
- Open-front market stalls with simple awning geometry (2 triangles)

**IMPORTANT - Roof Placement:**
- When placing sloped/wedge roofs using CSGPolygon3D or rotated CSGBox3D, roofs often end up UPSIDE DOWN
- Always rotate roofs 180 degrees on the X-axis to flip them right-side up
- Example: `transform = Transform3D(1, 0, 0, 0, -1, 0, 0, 0, -1, x, y, z)` flips the roof
- Test roof orientation visually - the peak should point UP, not down into the building

**Settlement Tiers:**
| Tier | Type | Building Count | Services |
|------|------|----------------|----------|
| 1 | Hamlet | 3-5 | Inn or general store only |
| 2 | Village | 6-10 | Inn, general store, blacksmith, temple |
| 3 | Town | 11-20 | Add magic shop, guild halls, multiple merchants |
| 4 | City | 21-40 | Full services, specialized shops, walls |
| 5 | Capital | 40+ | Castle, multiple districts, grand architecture |

**Standards:**
- All geometry uses CSGBox3D or low-poly MeshInstance3D
- Textures set to TEXTURE_FILTER_NEAREST
- Buildings organized in scene hierarchy (Terrain, Buildings, NPCs, Doors, SpawnPoints)
- Each building is a Node3D container with child geometry
- NPC spawn markers placed inside/near relevant buildings

---

## AGENT COORDINATION

When working on complex features, agents should be used in sequence:

1. **Pre-implementation:** `gdscript-linter` on existing code
2. **Asset work:** `asset-validator` after adding sprites/sounds
3. **Feature complete:** `scene-auditor` + domain-specific agent
4. **World changes:** Verify WorldGrid locations match scene files

### Quick Reference Commands
- "lint code" -> gdscript-linter
- "validate assets" -> asset-validator
- "audit scene" -> scene-auditor
- "check balance" -> balance-reviewer
- "create dialogue" -> dialogue-quest-master
- "add bounties" -> dialogue-quest-master
- "build town" -> town-builder
- "create building" -> town-builder
- "design settlement" -> town-builder

---

## WORLD ARCHITECTURE (Daggerfall-Style Cell Streaming)

The game uses a Daggerfall-inspired cell streaming system for seamless open world exploration. The player walks continuously across cell boundaries without teleportation or loading screens.

### Core Systems Overview

| System | File | Purpose |
|--------|------|---------|
| **CellStreamer** | `scripts/autoload/cell_streamer.gd` | Loads/unloads cells around player |
| **PlayerGPS** | `scripts/autoload/player_gps.gd` | Tracks player position and discovery |
| **WorldGrid** | `scripts/data/world_grid.gd` | Single source of truth for world data |
| **CellEdge** | `scripts/world/cell_edge.gd` | Boundary walls for impassable terrain |
| **PaintedWorldMap** | `scripts/ui/painted_world_map.gd` | OpenMW-style world map UI |
| **MapFogOfWar** | `scripts/map/map_fog_of_war.gd` | Exploration fog reveal system |

---

### CellStreamer (Autoload)

The heart of the world streaming system. Loads cells in a ring around the player and unloads distant ones.

**Key Constants:**
```gdscript
const LOAD_RADIUS := 1       # Load cells within 1 cell of player
const UNLOAD_RADIUS := 2     # Unload cells beyond 2 cells
const CELL_SIZE := 100.0     # World units per cell (matches WorldGrid)
const ORIGIN_SHIFT_THRESHOLD := 500.0  # Floating origin shift distance
```

**Key Properties:**
```gdscript
var loaded_cells: Dictionary = {}     # Vector2i -> Node3D
var active_cell: Vector2i             # Current player cell
var world_offset: Vector3             # Cumulative floating origin offset
var streaming_enabled: bool           # Is streaming active?
```

**Public API:**
| Method | Description |
|--------|-------------|
| `start_streaming(coords: Vector2i)` | Begin streaming from a cell |
| `stop_streaming()` | Stop streaming and unload all cells |
| `pause_streaming()` | Pause without unloading (for menus) |
| `resume_streaming()` | Resume streaming |
| `get_active_cell() -> Vector2i` | Get current player cell |
| `is_cell_loaded(coords: Vector2i) -> bool` | Check if cell is loaded |
| `teleport_to_cell(coords: Vector2i, spawn_pos: Vector3)` | Fast travel to cell |
| `register_main_scene_cell(coords: Vector2i, node: Node3D)` | Register the main scene (never unloaded) |

**Floating Origin:**
The system automatically shifts all loaded content when the player moves too far from the world origin to prevent floating-point precision issues.

**Usage in Hand-Crafted Levels:**
```gdscript
func _ready() -> void:
    # Register this level as the main scene cell
    var my_coords := Vector2i.ZERO  # Elder Moor is at (0, 0)
    CellStreamer.register_main_scene_cell(my_coords, self)
    CellStreamer.start_streaming(my_coords)
```

---

### PlayerGPS (Autoload)

Single source of truth for player location and exploration state. Replaces the old WorldManager + MapTracker systems.

**Key Signals:**
```gdscript
signal cell_changed(old_cell: Vector2i, new_cell: Vector2i)
signal location_discovered(location_id: String, location_name: String)
signal region_changed(old_region: String, new_region: String)
signal cell_revealed(coords: Vector2i)
```

**Key Properties:**
```gdscript
var current_cell: Vector2i            # Current player cell (Elder Moor-relative)
var current_region: String            # Current region name
var current_location_id: String       # Current location ID (empty if wilderness)
var discovered_cells: Dictionary      # Vector2i -> timestamp
var discovered_locations: Dictionary  # location_id -> info dict
var total_cells_traveled: int         # Statistics
```

**Public API:**
| Method | Description |
|--------|-------------|
| `update_cell(new_cell: Vector2i)` | Called by CellStreamer when player crosses boundary |
| `discover_cell(coords: Vector2i)` | Mark cell as discovered |
| `is_discovered(coords: Vector2i) -> bool` | Check if cell discovered |
| `discover_location(location_id: String)` | Discover location by ID (for shrines) |
| `get_discovered_locations() -> Array[Dictionary]` | Get all discovered locations |
| `get_distance_to(location_id: String) -> int` | Grid distance to location |
| `set_position(coords: Vector2i)` | Set position directly (saves/fast travel) |

---

### WorldGrid (Static Data)

Contains all world grid data with Elder Moor at coordinate (0, 0). This is the canonical source for terrain, locations, and regions.

**Coordinate System:**
- **Elder Moor = (0, 0)** - All coordinates are relative to Elder Moor
- **X increases East**, **Y increases South** (screen-space mapping)
- Grid bounds: (-12, -8) to (7, 11) relative to Elder Moor
- Cell size: 100 world units

**Grid to World Conversion:**
```
Grid X → World X (direct: Grid X * 100 = World X)
Grid Y → World Z (direct: Grid Y * 100 = World Z)
```
- Grid Y positive = South = World Z positive (+Z is South in Godot)
- Grid Y negative = North = World Z negative (-Z is North in Godot)
- Example: Thornfield at Grid (3, -2) = World (300, 0, -200) = East + North

**Terrain Types:**
```gdscript
enum Terrain { BLOCKED, HIGHLANDS, FOREST, WATER, COAST, SWAMP, ROAD, POI, DESERT }
```

**Location Types:**
```gdscript
enum LocationType { NONE, VILLAGE, TOWN, CITY, CAPITAL, DUNGEON, LANDMARK, BRIDGE, OUTPOST, BLOCKED }
```

**CellInfo Structure:**
```gdscript
class CellInfo:
    var terrain: Terrain
    var biome: Biome
    var location_type: LocationType
    var location_id: String       # Unique identifier (e.g., "dalhurst")
    var location_name: String     # Display name (e.g., "Dalhurst")
    var region_name: String       # Region (e.g., "The Greenwood")
    var passable: bool
    var discovered: bool
    var is_road: bool
    var scene_path: String        # Hand-crafted scene path (empty = procedural)
    var danger_level: int         # 1-10 based on distance from Elder Moor
```

**Public API:**
| Method | Description |
|--------|-------------|
| `initialize()` | Build grid from GRID_DATA |
| `get_cell(coords: Vector2i) -> CellInfo` | Get cell info |
| `is_passable(coords: Vector2i) -> bool` | Check if cell is walkable |
| `is_road(coords: Vector2i) -> bool` | Check if cell is a road |
| `is_in_bounds(coords: Vector2i) -> bool` | Check if coords are valid |
| `cell_to_world(coords: Vector2i) -> Vector3` | Convert grid to 3D position |
| `world_to_cell(world_pos: Vector3) -> Vector2i` | Convert 3D position to grid |
| `get_location_coords(location_id: String) -> Vector2i` | Get coords by location ID |
| `find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]` | BFS pathfinding |
| `grid_distance(from: Vector2i, to: Vector2i) -> int` | Manhattan distance |

**Defined Locations:**
| Location ID | Name | Coords | Type |
|-------------|------|--------|------|
| `elder_moor` | Elder Moor | (0, 0) | Landmark (Start) |
| `dalhurst` | Dalhurst | (-8, -2) | Town |
| `crossroads` | Crossroads | (-5, -2) | Landmark |
| `thornfield` | Thornfield | (3, -2) | Town |
| `millbrook` | Millbrook | (-7, 4) | Town |
| `willow_dale` | Willow Dale Ruins | (-5, -5) | Dungeon |
| `bandit_hideout` | Bandit Hideout | (1, -4) | Dungeon |
| `kazer_dun_entrance` | Kazer-Dun Entrance | (-5, 9) | Dungeon |

---

### CellEdge (Boundary Walls)

Static utility class for creating invisible collision walls at cell edges where adjacent cells are impassable.

**Usage:**
```gdscript
# Create boundary walls for a cell
CellEdge.create_boundary_walls(cell_node, coords, 100.0)

# Create visible debug walls
CellEdge.create_visible_boundaries(cell_node, coords, 100.0)

# Check if direction is blocked
if CellEdge.is_direction_blocked(coords, CellEdge.Direction.NORTH):
    # North edge has impassable terrain
```

---

### PaintedWorldMap (UI)

OpenMW-inspired world map with a hand-painted texture overlay, fog of war, and fast travel.

**Features:**
- Pan and zoom with mouse
- Fog of war reveals as player explores
- Click towns to fast travel (discovered only)
- Player marker with pulsing glow
- Tooltip showing cell info

**Integration:**
```gdscript
# The map reads from PlayerGPS for player position
# and WorldGrid for cell/location data
var player_cell: Vector2i = PlayerGPS.current_cell
var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(player_cell)
```

---

### MapFogOfWar

Grayscale image-based fog of war system. White = visible, black = hidden.

**Constants:**
```gdscript
const REVEAL_RADIUS_CELLS := 2  # Cells around player to reveal
const REVEAL_FEATHER := 0.3     # Edge softness
```

**Public API:**
| Method | Description |
|--------|-------------|
| `reveal_hex(cell: Vector2i)` | Reveal area around cell |
| `is_explored(hex: Vector2i) -> bool` | Check if cell explored |
| `bulk_reveal(hexes: Array)` | Reveal multiple cells |
| `reset()` | Clear all exploration |
| `reveal_all()` | Reveal entire map (dev mode) |
| `to_dict() -> Dictionary` | Save state |
| `from_dict(data: Dictionary)` | Load state |

---

### Region-Based Level Structure

Hand-crafted levels follow a consistent pattern with region scripts.

**Standard Region Script:**
```gdscript
extends Node3D

const ZONE_ID := "region_name"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
    # Register with PlayerGPS
    if PlayerGPS:
        PlayerGPS.set_position(Vector2i.ZERO)  # Set correct coords

    _setup_navigation()
    _setup_day_night_cycle()
    _setup_spawn_point_metadata()
    _spawn_enemies()
    _setup_cell_streaming()  # For main regions like Elder Moor

func _setup_cell_streaming() -> void:
    if CellStreamer:
        CellStreamer.register_main_scene_cell(Vector2i.ZERO, self)
        CellStreamer.start_streaming(Vector2i.ZERO)
```

---

## WORLD DESIGN & LORE

### The Three Gods
The world's religious pantheon consists of three deities:
1. **Time (Chronos)** - God of time, fate, and inevitability
2. **The Harvest (Gaela)** - Goddess of growth, agriculture, and prosperity
3. **Death & Rebirth (Morthane)** - God/Goddess of the cycle, endings and new beginnings (one deity, two aspects)

The Temple of Three Gods exists in Elder Moor with priests for each deity who can bestow blessings.

### Persistent World Locations
These locations exist in EVERY playthrough and are the anchors for quests and story.
All coordinates are Elder Moor-relative (Elder Moor = 0, 0).

| Location | Type | Coords | Notes |
|----------|------|--------|-------|
| **Elder Moor** | Starting Town | (0, 0) | Logging camp, player starts here |
| **Dalhurst** | Major Town | (-8, -2) | Western trade hub |
| **Crossroads** | Landmark | (-5, -2) | Road intersection |
| **Thornfield** | Town | (3, -2) | Eastern town |
| **Millbrook** | Town | (-7, 4) | Southern lakeside town |
| **Kazan-Dun** | Dwarf Hold | (-5, 9) | Southern dwarf stronghold |
| **Willow Dale** | Dungeon | (-5, -5) | Ruins in the foothills |
| **Bandit Hideout** | Dungeon | (1, -4) | Bandit cave |

### Regions
| Region Name | Location | Terrain |
|-------------|----------|---------|
| Western Shore | West coast (cols 0-2) | Coastal, water |
| Elder Moor | Central (around 0, 0) | Forest, plains |
| Eastern Highlands | East (cols 14+) | Rocky, highlands |
| Southern Forest | South (rows 14+) | Dense forest |
| Iron Mountains | North/edges | Impassable peaks |
| The Greenwood | Central default | Mixed forest |

### World Geography Notes
**IMPORTANT terrain rules for level design:**

- **Western Edge = Water**: The entire western edge of the map (columns 0-1) is open water (impassable). Column 2 is coastline.
- **Dalhurst Harbor**: Dalhurst's harbor faces WEST toward the water. Ships dock on the western side of town.
- **Eastern Edge = Mountains**: The eastern edge has impassable mountain terrain (blocked cells).
- **Northern Edge = Mountains**: The northern boundary is also impassable mountains.
- **Southern Edge = Mixed**: Southern edge has forest leading to Kazer-Dun, with some blocked mountain cells.

**Hand-crafted level orientation:**
- When a town borders water (like Dalhurst), the harbor/docks should face the water direction
- Check WorldData GRID_DATA to determine which edges of a cell have water/mountains
- Water cells ("W") and blocked cells ("B") are impassable - don't place walkable content there

### Sea Travel & Encounters
Planned boat travel system for crossing the lake to the Elven City:
- **Pirates** - Human bandits on the water
- **Ghost Pirates** - Undead ship crews, more dangerous
- **Sea Monsters** - Large creatures (serpents, krakens) for high-level encounters
- Boat travel is not instant - player may encounter multiple events per crossing

---

## NPC DESIGN STANDARDS

### Visual Standards
- **All humanoid NPCs use 2D billboard sprites** (Sprite3D with billboard mode), NOT 3D meshes
- **Exception:** Goblin NPCs may use 3D mesh
- **Standard humanoid height:** `pixel_size = 0.0384` for consistent scale
- **Directional sprites:** Guards and combat NPCs should have front/back/attack sprite sheets

### NPC Interaction Philosophy
- **ALL NPCs should be interactable** - even generic civilians
- **Guards:** Limited to DIRECTIONS and GOODBYE topics only. Handle arrests and combat.
- **Named NPCs:** Mix of scripted dialogue trees AND topic-based conversation
- **Generic NPCs:** Topic-based conversation with archetype responses

### Conversation System Architecture
Three-tier response selection:
1. **Unique responses** - Specific to this NPC
2. **Archetype responses** - Based on NPC type (merchant, guard, civilian, priest)
3. **Generic responses** - Fallback for any NPC

Topics: LOCAL_NEWS, RUMORS, PERSONAL, DIRECTIONS, TRADE, WEATHER, QUESTS, GOODBYE

### NPC Memory System
- NPCs remember what they've told the player (stored in DialogueManager.dialogue_flags)
- Key format: `"npc_id:response_id"`
- Player UI shows reminder of information NPCs have shared

---

## PLANNED FEATURES / FUTURE DEVELOPMENT

### Procedural Town Generator
Similar to the dungeon generator, create a system that procedurally generates towns/settlements based on:
- **Location:** Geographic position affects town type (coastal = fishing, mountain = mining, forest = lumber)
- **Population Size:** Determines the number and types of services available:
  - Hamlet (< 50): Maybe just an inn or general store
  - Village (50-200): Inn, general store, blacksmith
  - Town (200-500): Add magic shop, temple, guild halls
  - City (500+): Full services, multiple merchants per type, specialized shops
- **Merchant Types by Population:**
  - General Store: Always present
  - Blacksmith: Village+
  - Inn/Tavern: Always present
  - Magic Shop: Town+
  - Temple/Healer: Village+
  - Guild Halls: Town+
  - Specialized Crafters: City only
- **Layout:** Generate building placement, roads, walls based on population
- **Universal Storage:** Town Storage chests use shared ID "town_storage_main" for cross-world access

### Notes
- Riverside Village is placeholder - will be generated with this system when implemented
- Each generated town should have a unique zone_id for save system
- Consider faction alignment affecting available services

### Dynamic Quest System (Multi-Path Completion)

**Vision:** Quests should be solvable in multiple ways with real consequences.

**Example Scenario - "Deal with Bandit Camp" Quest:**
| Path | Method | Consequence |
|------|--------|-------------|
| 1 | Kill all bandits (combat) | Standard reputation gain |
| 2 | Intimidate leader to leave (skill check) | Peaceful resolution, different rep |
| 3 | Bribe leader to leave (gold + persuasion) | Costs gold, bandits may return |
| 4 | Take over operation (kill/intimidate leader) | Become bandit boss, ongoing mechanics |
| 5 | Pre-completion (already killed bandits) | Auto-complete when quest offered |

**Current State (~20% of Vision):**

What EXISTS:
- Linear quests (kill X, collect Y, talk to Z)
- Quest chains (`next_quest` field auto-starts next)
- Optional objectives (`is_optional: true`)
- Prerequisites (gate quests behind other quests)
- Skill checks in dialogue (DiceManager + branching nodes)
- Persuasion system (ADMIRE/INTIMIDATE/BRIBE/TAUNT)
- Humanoid dialogue for combat NPCs (FIGHT/BRIBE/NEGOTIATE/INTIMIDATE)
- Faction reputation (-100 to +100, cascading)

What's MISSING:
- Multiple completion paths (quests are single-path only)
- OR objectives (can't do "kill OR intimidate")
- Dialogue → quest completion (skill checks don't complete objectives)
- Pre-completion detection (no world state checks)
- Method-based rewards (same reward regardless of approach)
- Reputation from quests (JSON field exists but not parsed)
- Branching quest paths (JSON structure exists, code doesn't execute)

**Gap Analysis:**

Quest System (`quest_manager.gd`):
- Only parses basic fields, not `branching_quests` or `turn_in_options`
- `_check_quest_completion()` just checks "are ALL objectives done?"
- No tracking of HOW objectives were completed
- No world state pre-checks

Dialogue ↔ Quest Integration:
- Dialogue can START quests via action
- Dialogue CANNOT complete quest objectives
- No `DialogueAction` type for "mark objective complete via method X"
- Skill checks branch dialogue, but don't affect quest state

World State Tracking:
- No system to track: "bandits at location X are dead"
- No pre-completion checks when quest is offered
- No auto-complete for already-met conditions

**Implementation Roadmap:**

**Phase 1: Foundation**
1. Extend Objective class - Add `completion_method` field to track HOW
2. Parse branching fields - Read `branching_quests`, `turn_in_options` from JSON
3. Add `complete_objective_via_method()` - New function for method-aware completion

**Phase 2: Dialogue Integration**
1. New DialogueAction type - `COMPLETE_QUEST_OBJECTIVE`
2. Wire skill checks to quests - Success/fail routes to different quest branches
3. Conversation → Quest bridge - Intimidating bandit leader completes "deal with bandits"

**Phase 3: World State**
1. Create WorldState autoload - Track flags like `bandits_camp_x_cleared`
2. Pre-completion checks - When quest offered, check if already done
3. Auto-complete system - Skip objectives that world state shows are met

**Phase 4: Consequences**
1. Parse reputation_changes - Already in some JSON, need to execute
2. Method-based rewards - Different rewards per completion path
3. NPC state changes - Bandit leader behavior changes if you're their boss

**Phase 5: Advanced**
1. Ongoing quest effects - Extortion payments as bandit leader
2. Dynamic NPC behavior - NPCs react to your choices
3. Faction consequences - Being bandit leader affects guard relations

---

## DIALOGUE SYSTEM ARCHITECTURE

### Core Resources (scripts/dialogue/)
- **DialogueData** - Container for full dialogue trees with nodes dictionary
- **DialogueNode** - Single node with speaker, text, choices, and branching
- **DialogueChoice** - Player response option with conditions and actions
- **DialogueCondition** - Requirements to show/enable a choice (quest state, items, flags, stats)
- **DialogueAction** - Effects when selecting choice (give/take items, set flags, skill checks)

### Condition Types
`NONE, QUEST_STATE, QUEST_COMPLETE, HAS_ITEM, HAS_GOLD, FLAG_SET, FLAG_NOT_SET, STAT_CHECK, SKILL_CHECK, TIME_OF_DAY, REPUTATION, RANDOM_CHANCE`

### Action Types
`NONE, GIVE_ITEM, TAKE_ITEM, GIVE_GOLD, TAKE_GOLD, START_QUEST, COMPLETE_QUEST, ADVANCE_QUEST, SET_FLAG, CLEAR_FLAG, SKILL_CHECK, MODIFY_REPUTATION, GIVE_XP, HEAL_PLAYER, TELEPORT, OPEN_SHOP, PLAY_SOUND, SET_NPC_STATE`

### Skill Checks in Dialogue
- Uses TTRPG-style dice rolling via DiceManager
- Visual feedback with delay before showing result
- Branching based on success/failure node IDs

---

## NPC SPRITE SPECIFICATIONS (CRITICAL)

### Standard Sprite Sheet Format
**All humanoid NPC sprites use 1x5 layout** (5 horizontal frames, 1 row)

```
┌─────┬─────┬─────┬─────┬─────┐
│ Fr1 │ Fr2 │ Fr3 │ Fr4 │ Fr5 │  ← 5 frames for animation cycle
└─────┴─────┴─────┴─────┴─────┘
```

**Required settings in code:**
```gdscript
sprite.hframes = 5
sprite.vframes = 1
```

### Recommended Image Dimensions

| NPC Type | Frame Size | Total Sheet Size | Notes |
|----------|-----------|------------------|-------|
| Standard Civilian | 32×64 px | 160×64 px | Human-sized NPCs |
| Guard (Front) | 32×64 px | 160×64 px | Front-facing sprite |
| Guard (Back) | 32×64 px | 160×64 px | Back-facing sprite |
| Guard (Attack) | 48×64 px | 240×64 px | Wider for weapon swing |
| Wizard/Mage | 32×48 px | 160×48 px | Smaller stature |
| Lady in Red | 32×48 px | 160×48 px | Smaller stature |
| Barmaid | 32×56 px | 160×56 px | Slightly shorter |
| Large NPC (Orc, etc) | 48×80 px | 240×80 px | Bigger characters |

### Pixel Size by NPC Type

| NPC Type | pixel_size | Visual Result |
|----------|-----------|---------------|
| Standard Civilian (Man) | 0.0518 | Reference size |
| Wizard / Lady in Red | 0.0134 | 65% smaller than base |
| Barmaid | 0.0326 | 15% smaller than base |
| Guard | 0.055 | Larger/imposing |
| Quest Giver | 0.0384 | Standard NPC height |

### Animation Frame Guidelines

For smooth idle/walk animations:
- **Frame 1:** Neutral pose
- **Frame 2:** Step right (or breathing in)
- **Frame 3:** Neutral pose
- **Frame 4:** Step left (or breathing out)
- **Frame 5:** Alternate/variation frame

**Animation Speeds:**
```gdscript
const IDLE_FPS := 3.0   # Slow breathing/idle
const WALK_FPS := 6.0   # Walking cycle
const ATTACK_FPS := 10.0  # Combat actions
```

### Sprite Vertical Offset Formula

To make sprite "stand" on ground (feet at node position):
```gdscript
# Calculate offset to put sprite bottom at node origin
var frame_height := texture.get_height()
sprite.offset = Vector2(0, frame_height / 2.0)
```

### Common Sprite Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| Sprite floating | Wrong offset calculation | Use `frame_height / 2.0` offset |
| All frames visible briefly | Frame not set before add_child | Set `sprite.frame = 0` BEFORE and AFTER add_child |
| Sprite too big/small | Wrong pixel_size | Check table above for correct values |
| Animation stuttering | Frame timer not delta-based | Use `_anim_timer += delta` pattern |
| Wrong frame count | hframes mismatch | Ensure hframes matches actual sprite sheet |

---

## COMMON RUNTIME CRASHES (AVOID THESE)

These bugs cause crashes in exported .exe builds. Reference this list when writing code.

### 1. "Trying to cast a freed object" (FIXED 2024)

**Cause:** Autoloads hold references to scene nodes. When scene changes or save/load happens, nodes are freed but autoload references persist. Casting the stale reference crashes.

**Bad Pattern:**
```gdscript
# In an autoload
var current_npc: Node = null  # This persists across scene changes!

func do_something():
    var npc = current_npc as QuestGiver  # CRASH if node was freed!
```

**Fix Pattern:**
```gdscript
# 1. Always check validity before casting
func do_something():
    if not is_instance_valid(current_npc):
        current_npc = null
        return
    var npc = current_npc as QuestGiver

# 2. Clear references on scene change
func _ready():
    SceneManager.scene_load_started.connect(_on_scene_load_started)

func _on_scene_load_started():
    _clear_node_references()

func _clear_node_references():
    current_npc = null
    # Clear all other node references
```

**Affected Autoloads (now fixed):**
- CombatManager: `player`, `_pending_humanoid_enemy`, `_pending_humanoid_group`, `active_enemies`
- ConversationSystem: `current_npc`
- PlayerGPS: `registered_npcs` dictionary
- TournamentManager: `current_wave_enemies`

---

### 2. Sprite hframes/vframes Mismatch

**Cause:** Code specifies wrong frame count for sprite sheet, causing visual corruption or crashes.

**Example:** Martha's sprite has 4 frames but code said `h_frames = 5`

**Fix:** Always verify sprite dimensions match code:
```gdscript
# Check actual sprite: 160x64 with 4 poses = 4 frames
sprite.hframes = 4  # NOT 5!
sprite.vframes = 1
```

---

### 3. Static Method Resolution on Non-Autoload Classes

**Cause:** Autoloads load early. If autoload calls `ClassName.static_method()` on a non-autoload class, the class may not be parsed yet.

**Bad Pattern:**
```gdscript
# In tournament_manager.gd (autoload)
func spawn():
    enemy = GladiatorNPC.spawn_gladiator(...)  # CRASH - GladiatorNPC not loaded yet!
```

**Fix Pattern:**
```gdscript
# Preload the script instead
const GladiatorNPCScript = preload("res://scripts/npcs/gladiator_npc.gd")

func spawn():
    enemy = GladiatorNPCScript.spawn_gladiator(...)  # Works!
```

---

### 4. Accessing Child Nodes Before add_child()

**Cause:** BillboardSprite creates its `sprite` child in `_ready()`. Accessing it before adding to tree crashes.

**Bad Pattern:**
```gdscript
var billboard = BillboardSprite.new()
billboard.sprite.modulate = Color.RED  # CRASH - sprite doesn't exist yet!
add_child(billboard)
```

**Fix Pattern:**
```gdscript
var billboard = BillboardSprite.new()
add_child(billboard)  # Now _ready() runs and creates sprite
if billboard.sprite:
    billboard.sprite.modulate = Color.RED
```

---

### 5. Dictionary/Array Type Inference in Static Functions

**Cause:** GDScript static functions are stricter about type inference. Using `:=` with dictionary access or comparisons fails.

**Bad Pattern:**
```gdscript
static func find_item(items: Array) -> Dictionary:
    for item in items:
        var id := item["id"]  # CRASH - cannot infer type
```

**Fix Pattern:**
```gdscript
static func find_item(items: Array[Dictionary]) -> Dictionary:
    for item: Dictionary in items:
        var id: String = item["id"]  # Explicit types work
```

---

## CURRENT PRIORITY: SHIPPABLE .EXE

**Goal:** Hard bug test and export a stable .exe for external playtesting and feedback.

### Pre-Release Checklist
- [ ] Full playthrough without crashes
- [ ] Save/Load works correctly
- [ ] All core systems functional (combat, dialogue, quests, inventory, crafting)
- [ ] No game-breaking bugs
- [ ] Reduce starting gold/XP to intended values (currently 10k gold, 100k XP for testing)
- [ ] Export to Windows .exe
- [ ] Test exported build

### Systems Status (All Complete)
| System | Status |
|--------|--------|
| Dialogue System | ✅ Fixed (mouse filters, escape key, save/load) |
| Magic System | ✅ Fixed (spell list filtering) |
| World Map | ✅ Complete (cell streaming, fog of war, fast travel) |
| NPC Visuals | ✅ Fixed (height, size, frame flicker) |
| Quest System | ✅ Working (linear quests, chains, prerequisites) |
| Combat | ✅ Working |
| Inventory/Crafting | ✅ Working |
| Save/Load | ✅ Working |
| Crime/Bounty | ✅ Working |

### Known Working Features
- Daggerfall-style cell streaming (seamless world traversal)
- OpenMW-style world map with fog of war
- Topic-based NPC conversation system
- Skill checks in dialogue
- Faction reputation system
- Lootable corpses with tier-based loot
- Hand-crafted + procedural dungeon generation

---

## POST-RELEASE / FUTURE FEATURES

These features are deferred until after initial playtest release:

### NPC & Cell Streaming Enhancements
- Traveling merchants spawning via CellStreamer
- Random encounters in wilderness
- NPC positions tracked for minimap/compass
- Guard patrols with cell-aware logic

### Stealth & Crouch System
- Crouch mechanic (Ctrl/C key)
- Detection based on Stealth skill and light level
- Backstab damage bonus
- Enemy awareness states (Unaware → Suspicious → Alert → Combat)

### Killable NPCs & Consequences
- All NPCs killable (no essential flags)
- Quest chains break permanently if giver dies
- Jail system with escapable cells

### Dynamic Quest System
- Multiple completion paths per quest (see PLANNED FEATURES section)
- OR objectives, method-based rewards
- World state tracking and pre-completion detection

### Boat Travel
- Sea travel across the lake to Elven City
- Pirates, ghost pirates, sea monster encounters

### Skill System Enhancements

**REMOVED SKILLS (consolidated):**
- ~~PERCEPTION~~ → merged into INTUITION (awareness/detection)
- ~~ACROBATICS~~ → merged into ENDURANCE (stamina/physical)

**INTUITION (consolidated):**
- Enemy radar on compass: Base 15 units + 5 per level
- Thief pickpocket defense
- Trap detection bonus
- Ambush detection

**ENDURANCE (consolidated):**
- Stamina pool and regen
- Fall damage reduction
- Jump height bonus

**Investigation:**
- TODO: Use for pressing NPCs for information in dialogue
- TODO: Finding hidden chests in wilderness cells
- TODO: Hook up `get_hidden_detection_bonus()` in character_data.gd

**Deception (HIGH RISK/REWARD):**
- Deception skill checks should have CONSEQUENCES for failure
- Higher rewards for successful deception checks
- TODO: Implement failure consequences (hostility, combat, reputation loss)
- TODO: Implement success rewards (extra gold, better info, exclusive options)

---

## SESSION NOTES

### Current Architecture (Post-Refactor)
The game now uses a Daggerfall-style cell streaming system:
- **CellStreamer** loads/unloads 100x100 unit cells around the player
- **PlayerGPS** is the single source of truth for player position
- **WorldGrid** contains all world data with Elder Moor at (0, 0)
- **PaintedWorldMap** shows an OpenMW-style world map with fog of war
- Player walks seamlessly across cell boundaries (no teleporting)

**DELETED SYSTEMS (do not reference):**
- WorldManager (replaced by PlayerGPS + WorldGrid)
- MapTracker (replaced by PlayerGPS)
- BackgroundManager (no longer needed)
- room_edge.gd (replaced by CellEdge)
- zone_edge.gd (deleted)
- wilderness_exit_handler.gd (deleted)
- tile_*_template files (deleted)

### Inspirations
Main sources of inspiration:
- **Daggerfall** - Cell streaming, open world structure
- **Skyrim** - Open world, guilds, conversation system
- **Fallout New Vegas** - Faction reputation, skill checks in dialogue
- **Elden Ring / Dark Souls** - Combat feel, difficulty
- **Vampire the Masquerade: Bloodlines** - Atmosphere, dialogue depth
- **Tenchu** - Stealth possibilities
- **Final Fantasy 7/8/9** - Story structure, party dynamics
- **Metal Gear Solid** - Narrative complexity

---

## KNOWN BUGS / ISSUES TO FIX

### Visual Issues
- [ ] **Elder Moor floor texture** - Should be fallen leaves, currently solid color
- [ ] **Thornfield floor texture** - Should be fallen leaves
- [x] **Human bandit sprite** - Fixed: changed h_frames from 3 to 4 (sprite has 4 horizontal frames)
- [ ] **Thornfield leader sprite** - Wrong asset being used, check NPC data

### Spawn/World Issues
- [ ] **Procedural content in hand-crafted zones** - Goblin artifacts and cursed totems spawning inside Elder Moor
  - Need to exclude hand-crafted scene coordinates from wilderness procedural generation
- [ ] **Fast travel spawn safety** - Can spawn on top of enemies/dangerous objects
  - Need spawn point safety checks
- [ ] **Autosave state accuracy** - Verify autosave captures correct game state

### Cell Streaming Issues
- [x] **Double scene loading** - Fixed: teleport_to_cell now preserves main scene registration
- [ ] **Scene doubling on save/load** - May still occur when loading into main scene area

---

## BUG TESTING CHECKLIST

Use this checklist for hard bug testing before export:

### Core Gameplay Loop
- [ ] New game starts correctly
- [ ] Player can move, attack, block, dodge
- [ ] Enemies spawn and have correct AI behavior
- [ ] Combat damage/death works both ways
- [ ] Lootable corpses spawn and can be searched
- [ ] XP awards correctly on kills

### UI & Menus
- [ ] All menus open/close properly (Escape, Tab, etc.)
- [ ] Inventory displays items correctly
- [ ] Equipment can be equipped/unequipped
- [ ] Crafting menu works
- [ ] Magic panel shows only learned spells
- [ ] Quest journal displays active/completed quests
- [ ] World map opens and shows player position

### Dialogue & NPCs
- [ ] NPCs can be interacted with
- [ ] Dialogue choices are clickable
- [ ] Skill checks in dialogue work
- [ ] Shops open and transactions work
- [ ] Quest givers can give/complete quests

### World & Navigation
- [ ] Cell streaming loads adjacent cells
- [ ] No crashes when crossing cell boundaries
- [ ] Doors/zone transitions work
- [ ] Fast travel functions correctly
- [ ] Fog of war reveals on exploration

### Save/Load
- [ ] Game can be saved
- [ ] Game can be loaded
- [ ] All state restored correctly (inventory, quests, position, flags)
- [ ] No crashes on save/load

### Export Testing
- [ ] Export to Windows .exe completes
- [ ] Exported build launches
- [ ] No missing resources or errors in exported build
- [ ] Performance acceptable in exported build
