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
| After modifying UI code | `ui-consistency-checker` |
| After enemy/item stat changes | `balance-reviewer` |
| After dungeon generation changes | `dungeon-validator` |
| After quest system changes | `quest-validator` |
| After combat system changes | `combat-flow-tester` |
| After adding persistent data | `save-system-auditor` |
| Before declaring task complete | `scene-auditor` + relevant domain agent |
| When user reports bugs | `performance-profiler` + relevant agent |

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

**Rule of thumb:** When working with Dictionary, untyped Array, comparisons, or conditional expressions, ALWAYS add explicit type annotations. This is especially critical in static functions, loop variables, and boolean expressions. **NEVER use `:=` for comparisons or conditional assignments - always use explicit `: Type =` syntax.**

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

### Agent: asset-validator
**Purpose:** Validates game assets (sprites, textures, audio) and their references in code.
**When to use:** After adding new sprites, before committing art changes, when sprites display incorrectly.
**Checks:**
- Sprite sheet dimensions match h_frames × v_frames in code
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

### Agent: balance-reviewer
**Purpose:** Reviews game balance - stats, damage, spawn rates, economy.
**When to use:** After adding enemies, items, or adjusting combat values.
**Checks:**
- Enemy HP vs player damage = reasonable TTK (time to kill)
- Player HP vs enemy damage = survivability
- Item costs vs rewards
- Spawn rates vs difficulty curve
- Loot table weights

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

### Agent: save-system-auditor
**Purpose:** Validates save/load system integrity.
**When to use:** After adding new persistent data, when saves seem corrupted.
**Checks:**
- All zone_ids are unique
- Persistent IDs don't collide
- Save data schema matches load expectations
- Migration paths exist for schema changes

### Agent: dungeon-validator
**Purpose:** Validates procedural dungeon generation.
**When to use:** After dungeon changes, when players fall through floors.
**Checks:**
- All doors connect bidirectionally
- Corridors cover all door gaps
- No unreachable rooms
- Spawn limits respected
- Boss room always reachable

### Agent: ui-consistency-checker
**Purpose:** Ensures UI elements follow consistent patterns.
**When to use:** After UI changes, when menus look broken.
**Checks:**
- All tabs use same sizing/anchoring pattern
- Font sizes are consistent
- Color scheme matches theme
- Input handling is consistent
- Accessibility considerations

### Agent: combat-flow-tester
**Purpose:** Reviews combat system integrity.
**When to use:** After combat changes, when attacks don't connect.
**Checks:**
- Hitbox/hurtbox alignment
- Damage calculation flow
- Status effect stacking rules
- Cooldown/timing consistency
- Death handling and cleanup

### Agent: quest-validator
**Purpose:** Validates quest system integrity.
**When to use:** After adding quests, when objectives don't complete.
**Checks:**
- All quest IDs are unique
- Objectives are achievable
- Rewards exist and are valid
- Quest givers have proper dialogue
- State transitions are valid

### Agent: performance-profiler
**Purpose:** Identifies performance bottlenecks.
**When to use:** When game stutters, after adding many entities.
**Checks:**
- Entity counts vs budgets
- Process/physics_process complexity
- Signal spam detection
- Memory leak patterns
- Draw call estimates

---

## AGENT COORDINATION

When working on complex features, agents should be used in sequence:

1. **Pre-implementation:** `gdscript-linter` on existing code
2. **Asset work:** `asset-validator` after adding sprites/sounds
3. **Feature complete:** `scene-auditor` + domain-specific agent
4. **Pre-commit:** `performance-profiler` for budget checks

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
3. Player accepts → Quest created in QuestManager → Appears in journal
4. Player kills targets (QuestManager tracks automatically)
5. Player returns to NPC → Turn in bounty → Rewards given

**Standards:**
- All quest objectives must have valid targets
- Response_ids must be unique within pools
- Creature IDs in WorldLexicon must match enemy .tres files
- Disposition ranges don't create unreachable content
- Required_knowledge tags are valid

**Validation checklist:**
- [ ] Quest JSON validates against quest structure
- [ ] Creature IDs exist in data/enemies/*.tres
- [ ] Disposition ranges don't create unreachable content
- [ ] Required_knowledge tags are valid

### Agent: town-builder
**Purpose:** Specialist for creating towns, cities, capitals, and medieval buildings in PS1 style.
**When to use:** Building settlements, creating architecture, designing town layouts, generating buildings.

**Art Style: PS1 Medieval Architecture**

All buildings must follow these constraints:

**Geometry:**
- Extremely low poly (8-30 faces per building max)
- No smooth curves — everything is hard edges and flat planes
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

**Expertise:**
- Procedural building generation using MeshInstance3D and SurfaceTool
- CSGBox3D prototyping for rapid building creation
- Scene templates for modular Tudor buildings
- PS1-style spatial shaders (vertex snapping, nearest-neighbor, no perspective correction)
- Town layout generation with organic medieval paths
- Settlement tier scaling (Village → Town → City → Capital)

**Key Capabilities:**
1. **Building Generator:** Create low-poly medieval buildings from simple box shapes for walls, wedge shapes for roofs, optional awnings. Face count under 30.
2. **Scene Templates:** Modular .tscn templates with swappable wall segments, roof types, ground-floor variations (shop front vs solid wall)
3. **PS1 Shaders:** Vertex snapping to grid, nearest-neighbor filtering, UV perspective removal, distance-based wobble
4. **Town Layout:** Place buildings along winding paths for organic medieval village feel, buildings face roads with slight random rotation/spacing

**Reference Material:** `C:\Users\caleb\CatacombsOfGore\reference\` folder contains style references

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

### Quick Reference Commands
- "validate assets" → asset-validator
- "audit scene" → scene-auditor
- "check balance" → balance-reviewer
- "lint code" → gdscript-linter
- "check saves" → save-system-auditor
- "validate dungeon" → dungeon-validator
- "check ui" → ui-consistency-checker
- "test combat" → combat-flow-tester
- "validate quests" → quest-validator
- "profile performance" → performance-profiler
- "create dialogue" → dialogue-quest-master
- "add bounties" → dialogue-quest-master
- "build town" → town-builder
- "create building" → town-builder
- "design settlement" → town-builder

---

## WORLD DESIGN & LORE

### The Three Gods
The world's religious pantheon consists of three deities:
1. **Time (Chronos)** - God of time, fate, and inevitability
2. **The Harvest (Gaela)** - Goddess of growth, agriculture, and prosperity
3. **Death & Rebirth (Morthane)** - God/Goddess of the cycle, endings and new beginnings (one deity, two aspects)

The Temple of Three Gods exists in Elder Moor with priests for each deity who can bestow blessings.

### Persistent World Locations
These locations exist in EVERY playthrough and are the anchors for quests and story:

| Location | Type | Hex Coords | Notes |
|----------|------|------------|-------|
| **Elder Moor** | Starting Town | (31, 12) | Swamp town, player starts here. Town-06. |
| **Dalhurst** | Major Town | TBD | Trade hub, one of the oldest settlements |
| **Kazan-Dun** | Dwarf Hold | South, Mountains | Dwarven stronghold inside mountain range |
| **Desert Camp** | Outpost | South, Desert | Nomadic/trading post. Town-11 terrain. |
| **Elven City** | Major City | Across Lake | Requires boat travel to reach |

### Hex World Map System
- World uses axial hex coordinates (q, r)
- Map data stored in `data/world/hex_map_data.json`
- Terrain types: plains, forest, hills, mountains, swamp, desert, water
- 11 towns, 5 POIs (ruins/watchtowers), rivers, and roads defined

### Procedural World Generation
The world should be procedurally generated with these rules:
- **Persistent locations** (Elder Moor, Dalhurst, Kazan-Dun, Desert Camp, Elven City) are FIXED
- **Other settlements** are randomly placed based on terrain logic
- **Ruins and POIs** are scattered procedurally but some key ones are fixed for quest anchors
- Each new character gets a unique world layout while keeping story-critical locations constant

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

## KNOWN ISSUES & TODO

### Dialogue System (FIXED)
**Issues resolved:**
1. ✅ **Escape key doesn't close dialogue** - Fixed by adding dialogue active check to HUD._is_menu_open()
2. ✅ **Dialogue choice buttons not clickable** - Fixed mouse_filter issues:
   - Changed root_control to MOUSE_FILTER_PASS (allows clicks through to children)
   - Changed overlay to MOUSE_FILTER_STOP (blocks clicks outside dialogue)
   - Added focus_mode and mouse_filter to buttons
3. ✅ **HUD opening pause menu during dialogue** - HUD now checks DialogueManager.is_dialogue_active and ConversationSystem.is_active
4. ✅ **Save/Load integration** - CrimeManager, DialogueManager, ConversationSystem now properly save/load

**Files modified:**
- `scripts/ui/dialogue_box.gd` - Fixed mouse filters and button focus
- `scripts/ui/conversation_ui.gd` - Same fixes
- `scripts/ui/hud.gd` - Added dialogue active checks to _is_menu_open()
- `scripts/data/save_data.gd` - Added CrimeSaveData, DialogueSaveData, ConversationSaveData classes
- `scripts/autoload/save_manager.gd` - Added collect/apply functions for crime, dialogue, conversation data

### Magic System
- **BUG:** MagicPanel shows ALL spells instead of only learned ones
- Need to filter `_populate_spell_list()` to check if player has learned each spell

### World Map
- Town names need to be mapped to hex IDs (Dalhurst, Rotherhine, etc.)
- Zone loading system needs implementation for hex-based travel
- Boat travel mechanics not yet implemented

### NPC Visual Issues (Needs Full Audit)
- Some NPCs floating above ground
- Some NPCs too big or too small
- Frame flicker on spawn for animated sprites
- Need consistent pixel_size across all NPC types

### Starting Experience
- Player starts with 10,000 gold and 100,000 XP for testing
- Starter equipment: fine longsword, hunting bow, 20 arrows
- **Remember to reduce these values before release**

---

## SESSION NOTES

### Current Session Focus (Rebuilding from Memory)
The game is being rebuilt based on memory after losing physical design notes. Key decisions being cemented:
- PS1 aesthetic with billboard sprites
- TTRPG-inspired stat/skill system
- Open world with procedural elements but fixed story anchors
- Deep NPC conversation system inspired by Elder Scrolls games
- Three-god pantheon for religious content
- Multiple factions (guilds, temples, towns)

### Inspirations
Main sources of inspiration:
- **Skyrim** - Open world, guilds, conversation system
- **Fallout New Vegas** - Faction reputation, skill checks in dialogue
- **Elden Ring / Dark Souls** - Combat feel, difficulty
- **Vampire the Masquerade: Bloodlines** - Atmosphere, dialogue depth
- **Tenchu** - Stealth possibilities
- **Final Fantasy 7/8/9** - Story structure, party dynamics
- **Metal Gear Solid** - Narrative complexity

---

## NEXT SESSION PLAN

### Priority 1: Fix Dialogue System ✅ COMPLETED
All dialogue issues have been fixed. Test to verify:
- Click on choice buttons - should respond to clicks
- Press ESC during dialogue - should close dialogue (not open pause menu)
- Talk to NPCs - dialogue/conversation UI should appear

### Priority 2: Fix NPC Visual Issues (CURRENT FOCUS)

1. **Audit all NPC sprites:**
   - Check each NPC class for correct pixel_size (see table in CLAUDE.md)
   - Verify sprite offset calculation uses `frame_height / 2.0`
   - Ensure frame is set to 0 before AND after add_child to prevent flicker

2. **Files to audit:**
   - `scripts/world/civilian_npc.gd`
   - `scripts/npcs/guard_npc.gd`
   - `scripts/npcs/quest_giver.gd`
   - `scripts/world/merchant.gd`
   - `scripts/world/innkeeper.gd`
   - Any other NPC scripts

3. **Standard sizes to enforce:**
   - Man civilian: pixel_size = 0.0518
   - Wizard/Lady in Red: pixel_size = 0.0134
   - Barmaid: pixel_size = 0.0326
   - Guard: pixel_size = 0.055

### Priority 3: Create New Sprite Assets

User prefers **1x5 sprite sheet format** for all NPCs:
- 5 horizontal frames, 1 row
- Recommended frame sizes:
  - Standard NPC: 32×64 pixels per frame (160×64 total)
  - Small NPC (wizard): 32×48 pixels per frame (160×48 total)
  - Large NPC (guard): 32×64 or 48×64 per frame

### Testing Checklist
**Dialogue System (should be fixed):**
- [ ] Talk to civilian NPC - dialogue box appears
- [ ] Click dialogue choice buttons - they respond
- [ ] Press ESC - dialogue closes (not pause menu)
- [ ] Talk to guard NPC - conversation UI appears
- [ ] Select topic via number keys - response shows
- [ ] Press ESC - conversation closes

**NPC Visual Issues (needs audit):**
- [ ] All NPCs at correct height (not floating)
- [ ] All NPCs at correct size (not too big/small)
- [ ] No frame flicker when NPCs spawn
