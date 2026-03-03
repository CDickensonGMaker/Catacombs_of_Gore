## zoo_registry.gd - Complete catalog of all enemy and NPC sprites in the game
## Scraped from: EncounterManager, WildernessRoom, CivilianNPC, EnemyBase, level scripts
class_name ZooRegistry
extends RefCounted

## Actor entry structure:
## {
##   "id": String,              # Unique identifier
##   "name": String,            # Display name
##   "category": String,        # "enemy" or "npc"
##   "subcategory": String,     # More specific grouping
##   "sprite_path": String,     # Main sprite texture path
##   "h_frames": int,           # Horizontal frames in sprite sheet
##   "v_frames": int,           # Vertical frames in sprite sheet
##   "pixel_size": float,       # World-space pixel size
##   "offset_y": float,         # Vertical offset adjustment
##   "idle_frames": int,        # Frames for idle animation
##   "walk_frames": int,        # Frames for walk animation
##   "idle_fps": float,         # Idle animation speed
##   "walk_fps": float,         # Walk animation speed
##   "attack_sprite_path": String,  # Separate attack texture (optional)
##   "attack_h_frames": int,
##   "attack_v_frames": int,
##   "attack_frames": int,
##   "death_sprite_path": String,   # Separate death texture (optional)
##   "death_h_frames": int,
##   "death_v_frames": int,
##   "death_frames": int,
##   "notes": String,           # Any special notes about this actor
## }

## Default pixel sizes from CivilianNPC
const PIXEL_SIZE_HUMANOID := 0.0256  # Standard 96px frame, 2.46m target
const PIXEL_SIZE_DWARF := 0.0193     # Shorter dwarves
const PIXEL_SIZE_ENEMY := 0.03       # Default enemy size

## ============================================================================
## ENEMY REGISTRY
## ============================================================================

static var ENEMIES: Array[Dictionary] = [
	# -------------------------------------------------------------------------
	# TIER 1 - Basic enemies
	# -------------------------------------------------------------------------
	{
		"id": "wolf",
		"name": "Wolf",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/wolf_moving.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Basic forest predator - single frame"
	},
	{
		"id": "giant_spider",
		"name": "Giant Spider",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/spider.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame sprite"
	},
	{
		"id": "human_bandit",
		"name": "Bandit",
		"category": "enemy",
		"subcategory": "humanoid",
		"sprite_path": "res://assets/sprites/enemies/human_bandit.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Standard bandit enemy"
	},
	{
		"id": "giant_rat",
		"name": "Giant Rat",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/rat_moving_forward.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 8.0,
		"notes": "Has directional variants (away, right)"
	},
	{
		"id": "bat",
		"name": "Bat",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/bat.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 4.0, "walk_fps": 8.0,
		"notes": "Flying enemy - fly_height 2.5"
	},

	# -------------------------------------------------------------------------
	# TIER 2 - Mid-level enemies
	# -------------------------------------------------------------------------
	{
		"id": "dire_wolf",
		"name": "Dire Wolf",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/wolf_moving.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.04,  # Larger than normal wolf
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Same sprite as wolf - larger size"
	},
	{
		"id": "goblin_soldier",
		"name": "Goblin Soldier",
		"category": "enemy",
		"subcategory": "goblin",
		"sprite_path": "res://assets/sprites/enemies/goblins/goblin_sword.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame sprite"
	},
	{
		"id": "bandit_captain",
		"name": "Bandit Captain",
		"category": "enemy",
		"subcategory": "humanoid",
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.035,  # Slightly larger
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame sprite"
	},
	{
		"id": "goblin_archer",
		"name": "Goblin Archer",
		"category": "enemy",
		"subcategory": "goblin",
		"sprite_path": "res://assets/sprites/goblin_archer_Fixed.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame - crossbow goblin"
	},
	{
		"id": "goblin_mage",
		"name": "Goblin Mage",
		"category": "enemy",
		"subcategory": "goblin",
		"sprite_path": "res://assets/sprites/enemies/goblins/goblin_fireball.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame - casting fireball"
	},
	{
		"id": "goblin_warboss",
		"name": "Goblin Warboss",
		"category": "enemy",
		"subcategory": "goblin",
		"sprite_path": "res://assets/sprites/enemies/goblins/goblin_warboss_walking.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": 0.04,  # Larger boss
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"death_sprite_path": "res://assets/sprites/enemies/goblins/goblin_warboss_dying.png",
		"death_h_frames": 4, "death_v_frames": 1,
		"death_frames": 4,
		"notes": "Boss enemy - has separate walk/death textures"
	},

	# -------------------------------------------------------------------------
	# TIER 3 - Dangerous enemies
	# -------------------------------------------------------------------------
	{
		"id": "ogre",
		"name": "Ogre",
		"category": "enemy",
		"subcategory": "monster",
		"sprite_path": "res://assets/sprites/enemies/ogre_monster.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.05,  # Large creature
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame sprite"
	},
	{
		"id": "basilisk",
		"name": "Basilisk",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/basilisk.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": 0.04,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"notes": "Petrification attack"
	},

	# -------------------------------------------------------------------------
	# UNDEAD enemies
	# -------------------------------------------------------------------------
	{
		"id": "skeleton",
		"name": "Skeleton",
		"category": "enemy",
		"subcategory": "undead",
		"sprite_path": "res://assets/sprites/enemies/undead/skeleton_walking.png",
		"h_frames": 8, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 8, "walk_frames": 8,
		"idle_fps": 3.0, "walk_fps": 8.0,
		"attack_sprite_path": "res://assets/sprites/enemies/undead/skeleton_attacking.png",
		"attack_h_frames": 6, "attack_v_frames": 1,
		"attack_frames": 6,
		"notes": "Has separate attack texture"
	},
	{
		"id": "zombie",
		"name": "Zombie",
		"category": "enemy",
		"subcategory": "undead",
		"sprite_path": "res://assets/sprites/enemies/undead/swampy_undead.png",
		"h_frames": 4, "v_frames": 4,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 2.0, "walk_fps": 4.0,
		"notes": "Slow shambling undead"
	},
	{
		"id": "vampire_lord",
		"name": "Vampire Lord",
		"category": "enemy",
		"subcategory": "undead",
		"sprite_path": "res://assets/sprites/enemies/undead/vampirelord_walking.png",
		"h_frames": 5, "v_frames": 1,
		"pixel_size": 0.04,
		"offset_y": 0.0,
		"idle_frames": 5, "walk_frames": 5,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"attack_sprite_path": "res://assets/sprites/enemies/undead/vampirelord_pointing.png",
		"attack_h_frames": 5, "attack_v_frames": 1,
		"attack_frames": 5,
		"death_sprite_path": "res://assets/sprites/enemies/undead/vampirelord_dying.png",
		"death_h_frames": 5, "death_v_frames": 1,
		"death_frames": 5,
		"notes": "Boss enemy - has separate walk/attack/death textures"
	},
	{
		"id": "skeleton_shade",
		"name": "Soul Shade",
		"category": "enemy",
		"subcategory": "undead",
		"sprite_path": "res://assets/sprites/enemies/undead/skeleton_shade_walking.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": 0.035,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"attack_sprite_path": "res://assets/sprites/enemies/undead/skeleton_shade_attacking.png",
		"attack_h_frames": 4, "attack_v_frames": 1,
		"attack_frames": 4,
		"death_sprite_path": "res://assets/sprites/enemies/undead/skeleton_shade_dying.png",
		"death_h_frames": 4, "death_v_frames": 1,
		"death_frames": 4,
		"notes": "Tortured spirit bound to skeletal remains - magical enemy with Soul Drain and Chain Lash attacks"
	},

	# -------------------------------------------------------------------------
	# HUMANOID enemies
	# -------------------------------------------------------------------------
	{
		"id": "cultist",
		"name": "Cultist",
		"category": "enemy",
		"subcategory": "humanoid",
		"sprite_path": "res://assets/sprites/enemies/humanoid/cultist_red.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_ENEMY,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"notes": "From cultist_temple.gd"
	},
	{
		"id": "orc",
		"name": "Orc",
		"category": "enemy",
		"subcategory": "humanoid",
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.04,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame - uses bandit sprite"
	},

	# -------------------------------------------------------------------------
	# LARGE CREATURES (back row display)
	# -------------------------------------------------------------------------
	{
		"id": "troll",
		"name": "Bridge Troll",
		"category": "enemy",
		"subcategory": "monster",
		"sprite_path": "res://assets/sprites/enemies/beasts/troll.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.05,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame sprite"
	},
	{
		"id": "wyvern",
		"name": "Wyvern",
		"category": "enemy",
		"subcategory": "beast",
		"sprite_path": "res://assets/sprites/enemies/beasts/wyvern.png",
		"h_frames": 6, "v_frames": 1,
		"pixel_size": 0.05,
		"offset_y": 0.0,
		"idle_frames": 6, "walk_frames": 6,
		"idle_fps": 4.0, "walk_fps": 8.0,
		"notes": "Flying enemy - fly_height 4.0"
	},
	{
		"id": "tree_ent",
		"name": "Ancient Treant",
		"category": "enemy",
		"subcategory": "monster",
		"sprite_path": "res://assets/sprites/enemies/treeent_massive.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": 0.06,  # Very large
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 2.0, "walk_fps": 4.0,
		"notes": "Forest biome only - massive tree creature"
	},
	{
		"id": "abomination",
		"name": "Abomination",
		"category": "enemy",
		"subcategory": "monster",
		"sprite_path": "res://assets/sprites/abomination_idle.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": 0.06,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 4.0,
		"attack_sprite_path": "res://assets/sprites/abomination_attack.png",
		"attack_h_frames": 4, "attack_v_frames": 1,
		"attack_frames": 4,
		"notes": "Horror enemy - has separate idle/attack textures"
	},
	{
		"id": "dark_general",
		"name": "Dark General",
		"category": "enemy",
		"subcategory": "boss",
		"sprite_path": "res://assets/sprites/enemies/dark_general_idle.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": 0.006,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"attack_sprite_path": "res://assets/sprites/enemies/dark_general_attack.png",
		"attack_h_frames": 4, "attack_v_frames": 1,
		"attack_frames": 4,
		"death_sprite_path": "res://assets/sprites/enemies/dark_general_death.png",
		"death_h_frames": 4, "death_v_frames": 1,
		"death_frames": 4,
		"notes": "Level 35 boss - spiked black armor, massive blade"
	},

	# -------------------------------------------------------------------------
	# SPECIAL ENCOUNTERS - Scripted assassin/bounty targets
	# -------------------------------------------------------------------------
	{
		"id": "ratfang_snotcheeze",
		"name": "Ratfang Snotcheeze",
		"category": "enemy",
		"subcategory": "assassin",
		"sprite_path": "res://assets/sprites/enemies/ratgan_idle.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.025,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"attack_sprite_path": "res://assets/sprites/enemies/ratgan_walking.png",
		"attack_h_frames": 4, "attack_v_frames": 1,
		"attack_frames": 4,
		"notes": "Level 18-22 rat assassin - scripted encounter with pre-battle dialogue"
	},
]

## ============================================================================
## NPC REGISTRY
## ============================================================================

static var NPCS: Array[Dictionary] = [
	# -------------------------------------------------------------------------
	# CIVILIANS - Animated
	# -------------------------------------------------------------------------
	{
		"id": "woman_civilian",
		"name": "Civilian Woman",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/lady_in_red.png",
		"h_frames": 8, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 8, "walk_frames": 8,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"notes": "Main female civilian sprite"
	},
	{
		"id": "man_civilian",
		"name": "Civilian Man",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/man_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame male"
	},
	{
		"id": "barmaid_blonde",
		"name": "Barmaid (Blonde)",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/barmaid_4x4.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Blue dress barmaid"
	},
	{
		"id": "barmaid_brunette",
		"name": "Barmaid (Brunette)",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/barmaid_3x3.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Brown dress barmaid"
	},
	{
		"id": "wizard_mage",
		"name": "Wizard",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/wizard_mage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Robed mage NPC"
	},
	{
		"id": "guy_green_vest",
		"name": "Guy (Green Vest)",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/guy_civilian1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame male"
	},
	{
		"id": "pink_lady",
		"name": "Pink Lady",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/pinklady.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Single frame female"
	},
	{
		"id": "seductress",
		"name": "Seductress",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/seductress_civilian_Front.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Has front/back directional sprites"
	},
	{
		"id": "seductress2",
		"name": "Blue Dress Lady",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/seductress2_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Alternate seductress"
	},
	{
		"id": "female_noble",
		"name": "Female Noble",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/female_noble1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Wealthy female"
	},
	{
		"id": "male_noble",
		"name": "Male Noble",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/man_noble1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Wealthy male"
	},
	{
		"id": "female_hunter",
		"name": "Female Hunter",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/female_hunter.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Ranger type"
	},
	{
		"id": "guard_civilian",
		"name": "Guard (Dwarf-Style)",
		"category": "npc",
		"subcategory": "guard",
		"sprite_path": "res://assets/sprites/npcs/civilians/guard_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Stocky armored dwarf-style guard - used by GuardNPC"
	},
	{
		"id": "guard2_civilian",
		"name": "Guard (Roman-Style)",
		"category": "npc",
		"subcategory": "guard",
		"sprite_path": "res://assets/sprites/npcs/civilians/guard2_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Roman soldier with spear and shield - used by GuardNPC"
	},
	{
		"id": "wizard_wild",
		"name": "Wild Wizard",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/wizard_wild.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Hermit mage"
	},
	{
		"id": "wizard_civilian",
		"name": "Wizard (Town)",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/wizard_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Town mage"
	},
	{
		"id": "bard_civilian",
		"name": "Bard",
		"category": "npc",
		"subcategory": "civilian",
		"sprite_path": "res://assets/sprites/npcs/civilians/bard_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Musician NPC"
	},

	# -------------------------------------------------------------------------
	# MERCHANTS
	# -------------------------------------------------------------------------
	{
		"id": "magic_shop_worker",
		"name": "Magic Shop Worker",
		"category": "npc",
		"subcategory": "merchant",
		"sprite_path": "res://assets/sprites/npcs/merchants/magic_shop_worker.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Enchantress type"
	},
	{
		"id": "merchant_civilian",
		"name": "Merchant",
		"category": "npc",
		"subcategory": "merchant",
		"sprite_path": "res://assets/sprites/npcs/merchants/merchant_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "General store keeper"
	},
	{
		"id": "innkeeper_male",
		"name": "Innkeeper (Male)",
		"category": "npc",
		"subcategory": "merchant",
		"sprite_path": "res://assets/sprites/npcs/merchants/Innkeeper_man.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Stationary - behind counter"
	},
	{
		"id": "innkeeper_female",
		"name": "Innkeeper (Female)",
		"category": "npc",
		"subcategory": "merchant",
		"sprite_path": "res://assets/sprites/npcs/merchants/Innkeeper_woman.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Stationary - behind counter"
	},
	{
		"id": "blacksmith",
		"name": "Blacksmith",
		"category": "npc",
		"subcategory": "merchant",
		"sprite_path": "res://assets/sprites/npcs/merchants/blacksmith.png",
		"h_frames": 5, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 5, "walk_frames": 5,
		"idle_fps": 4.0, "walk_fps": 6.0,
		"notes": "Blacksmith at anvil - weapons/armor merchant"
	},

	# -------------------------------------------------------------------------
	# DWARVES
	# -------------------------------------------------------------------------
	{
		"id": "dwarf_civilian",
		"name": "Dwarf Civilian",
		"category": "npc",
		"subcategory": "dwarf",
		"sprite_path": "res://assets/sprites/npcs/dwarves/dwarf_1.png",
		"h_frames": 5, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 5, "walk_frames": 5,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"notes": "Generic dwarf civilian"
	},
	{
		"id": "dwarf_guard",
		"name": "Dwarf Guard",
		"category": "npc",
		"subcategory": "dwarf",
		"sprite_path": "res://assets/sprites/npcs/dwarves/dwarf_2.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Blue/purple armor"
	},
	{
		"id": "dwarf_warrior",
		"name": "Dwarf Warrior",
		"category": "npc",
		"subcategory": "dwarf",
		"sprite_path": "res://assets/sprites/npcs/dwarves/dwarf_3.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Red/maroon armor"
	},
	{
		"id": "dwarf_forge_master",
		"name": "Dwarf Forge Master",
		"category": "npc",
		"subcategory": "dwarf",
		"sprite_path": "res://assets/sprites/npcs/dwarves/dwarf_molten1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Molten/forge themed"
	},
	{
		"id": "dwarf_forge_worker",
		"name": "Dwarf Smith",
		"category": "npc",
		"subcategory": "dwarf",
		"sprite_path": "res://assets/sprites/npcs/dwarves/dwarf_molten2.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Molten/forge themed"
	},
	{
		"id": "dwarf_forge_guard",
		"name": "Dwarf Forge Guard",
		"category": "npc",
		"subcategory": "dwarf",
		"sprite_path": "res://assets/sprites/npcs/dwarves/dwarf_molten3.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Molten/forge themed"
	},

	# -------------------------------------------------------------------------
	# COMBAT NPCs
	# -------------------------------------------------------------------------
	{
		"id": "female_gladiator",
		"name": "Female Gladiator",
		"category": "npc",
		"subcategory": "combat",
		"sprite_path": "res://assets/sprites/npcs/combat/female_gladiator1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Arena fighter"
	},
	{
		"id": "male_gladiator",
		"name": "Male Gladiator",
		"category": "npc",
		"subcategory": "combat",
		"sprite_path": "res://assets/sprites/npcs/combat/male_gladiator1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Arena fighter"
	},
	{
		"id": "thief",
		"name": "Thief",
		"category": "npc",
		"subcategory": "combat",
		"sprite_path": "res://assets/sprites/npcs/combat/thief.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "From ThiefNPC"
	},
	{
		"id": "bandit_npc",
		"name": "Bandit (NPC)",
		"category": "npc",
		"subcategory": "combat",
		"sprite_path": "res://assets/sprites/npcs/combat/bandit_3.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Reformed bandit in towns"
	},

	# -------------------------------------------------------------------------
	# TEMPLE
	# -------------------------------------------------------------------------
	{
		"id": "monk_tan",
		"name": "Monk (Tan)",
		"category": "npc",
		"subcategory": "temple",
		"sprite_path": "res://assets/sprites/npcs/temple/monk_1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Temple monk"
	},
	{
		"id": "monk_brown",
		"name": "Monk (Brown)",
		"category": "npc",
		"subcategory": "temple",
		"sprite_path": "res://assets/sprites/npcs/temple/monk_2.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Temple monk"
	},
	{
		"id": "monk_purple",
		"name": "Monk (Purple)",
		"category": "npc",
		"subcategory": "temple",
		"sprite_path": "res://assets/sprites/npcs/temple/monk_3_purple.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Priest - mystical"
	},
]

## ============================================================================
## NAMED CHARACTERS (Quest Givers & Important NPCs)
## ============================================================================

static var NAMED_CHARACTERS: Array[Dictionary] = [
	# -------------------------------------------------------------------------
	# ELDER MOOR - Starting Area
	# -------------------------------------------------------------------------
	{
		"id": "tharin_ironbeard",
		"name": "Tharin Ironbeard",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/tharin_ironbeard.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_DWARF,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Elder Moor - Keepers contact, starts main quest"
	},
	{
		"id": "martha_cook",
		"name": "Martha Cook",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/martha_cook.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"notes": "Elder Moor - Tutorial cooking quest"
	},
	{
		"id": "grom_the_smith",
		"name": "Grom the Smith",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/merchants/blacksmith.png",
		"h_frames": 5, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 5, "walk_frames": 5,
		"idle_fps": 4.0, "walk_fps": 6.0,
		"notes": "Elder Moor - Tutorial crafting quest"
	},
	{
		"id": "sage_brennan",
		"name": "Sage Brennan",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/civilians/wizard_mage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Elder Moor - Tutorial alchemy quest"
	},
	{
		"id": "varn_the_scarred",
		"name": "Varn the Scarred",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/combat/male_gladiator1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Elder Moor - Arena contact"
	},

	# -------------------------------------------------------------------------
	# DALHURST - Western Trade Hub
	# -------------------------------------------------------------------------
	{
		"id": "aldric_vane",
		"name": "Aldric Vane",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/aldric_vane.png",
		"h_frames": 4, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 4, "walk_frames": 4,
		"idle_fps": 3.0, "walk_fps": 6.0,
		"notes": "Dalhurst - Keepers secret society contact"
	},
	{
		"id": "guildmaster_vorn",
		"name": "Guildmaster Vorn",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/merchants/merchant_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Dalhurst - Adventurer's Guild leader"
	},
	{
		"id": "wizard_dalhurst",
		"name": "Wizard of Dalhurst",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/civilians/wizard_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Dalhurst - Magic shop & quests"
	},
	{
		"id": "harbor_captain",
		"name": "Harbor Captain",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/civilians/guard_civilian.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Dalhurst - Harbor/docks quest giver"
	},
	{
		"id": "priest_gaela",
		"name": "Priestess Gaela",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/temple/monk_1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Dalhurst - Priest of The Harvest"
	},
	{
		"id": "priest_chronos",
		"name": "Priest Chronos",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/temple/monk_2.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Dalhurst - Priest of Time"
	},
	{
		"id": "priest_morthane",
		"name": "Priest Morthane",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/temple/monk_3_purple.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Dalhurst - Priest of Death & Rebirth"
	},

	# -------------------------------------------------------------------------
	# THORNFIELD - Eastern Town
	# -------------------------------------------------------------------------
	{
		"id": "elder_vorn_thornfield",
		"name": "Elder Vorn",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/thornfield_leader.png",
		"h_frames": 5, "v_frames": 1,
		"pixel_size": 0.0384,
		"offset_y": 0.0,
		"idle_frames": 5, "walk_frames": 5,
		"idle_fps": 2.0, "walk_fps": 4.0,
		"notes": "Thornfield - Town elder, quest receiver for Tharin's message"
	},
	{
		"id": "thornfield_leader",
		"name": "Lord Edric",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/village_leader.png",
		"h_frames": 2, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 2, "walk_frames": 2,
		"idle_fps": 2.0, "walk_fps": 4.0,
		"notes": "Thornfield - Town leader (deprecated - use elder_vorn_thornfield)"
	},
	{
		"id": "marek_hunter",
		"name": "Marek the Hunter",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/civilians/female_hunter.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Thornfield - Bounty hunting quests"
	},
	{
		"id": "thornfield_wizard",
		"name": "Thornfield Wizard",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/civilians/wizard_wild.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Thornfield - Apprentice rescue quest giver"
	},

	# -------------------------------------------------------------------------
	# MILLBROOK - Southern Lake Town
	# -------------------------------------------------------------------------
	{
		"id": "millbrook_elder",
		"name": "Millbrook Elder",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/village_leader.png",
		"h_frames": 2, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 2, "walk_frames": 2,
		"idle_fps": 2.0, "walk_fps": 4.0,
		"notes": "Millbrook - Town elder"
	},
	{
		"id": "millbrook_healer",
		"name": "Millbrook Healer",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/civilians/pinklady.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Millbrook - Healer NPC"
	},

	# -------------------------------------------------------------------------
	# BLOODSAND ARENA
	# -------------------------------------------------------------------------
	{
		"id": "gormund_pitmaster",
		"name": "Gormund the Pitmaster",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/combat/male_gladiator1.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.04,  # Larger imposing figure
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Bloodsand Arena - Arena master"
	},

	# -------------------------------------------------------------------------
	# SAGES & WISE MEN
	# -------------------------------------------------------------------------
	{
		"id": "old_man_sage",
		"name": "Old Man Sage",
		"category": "named",
		"subcategory": "quest_giver",
		"sprite_path": "res://assets/sprites/npcs/named/old_man_sage.png",
		"h_frames": 2, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 2, "walk_frames": 2,
		"idle_fps": 2.0, "walk_fps": 4.0,
		"notes": "Wise old sage with potions"
	},

	# -------------------------------------------------------------------------
	# EASTER EGGS & SPECIAL
	# -------------------------------------------------------------------------
	{
		"id": "spock_stranger",
		"name": "Pointed-Eared Stranger",
		"category": "named",
		"subcategory": "easter_egg",
		"sprite_path": "res://assets/sprites/npcs/named/spock.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.025,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Easter egg - rare spawn, requires player level 10+, far wilderness"
	},
	{
		"id": "conan_barbarian",
		"name": "Muscular Barbarian",
		"category": "named",
		"subcategory": "easter_egg",
		"sprite_path": "res://assets/sprites/npcs/named/conan_easter_egg.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Easter egg - Cimmerian warrior"
	},
]

## ============================================================================
## HOSTAGES (Rescue Quest NPCs)
## ============================================================================

static var HOSTAGES: Array[Dictionary] = [
	{
		"id": "hostage_merchant_daughter",
		"name": "Merchant's Daughter",
		"category": "hostage",
		"subcategory": "rescue",
		"sprite_path": "res://assets/sprites/npcs/civilians/Hostages/red_dress_hostage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Rescue quest - merchant's kidnapped daughter"
	},
	{
		"id": "hostage_woodsman",
		"name": "Captured Woodsman",
		"category": "hostage",
		"subcategory": "rescue",
		"sprite_path": "res://assets/sprites/npcs/civilians/Hostages/woodsman_hostage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Rescue quest - captured logger/woodsman"
	},
	{
		"id": "hostage_little_girl",
		"name": "Missing Child",
		"category": "hostage",
		"subcategory": "rescue",
		"sprite_path": "res://assets/sprites/npcs/civilians/Hostages/littlegirl_hostage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": 0.02,  # Smaller child
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Rescue quest - kidnapped child from Millbrook"
	},
	{
		"id": "hostage_woman",
		"name": "Captive Woman",
		"category": "hostage",
		"subcategory": "rescue",
		"sprite_path": "res://assets/sprites/npcs/civilians/Hostages/green_dress_hostage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Rescue quest - generic female hostage"
	},
	{
		"id": "hostage_wizard_apprentice",
		"name": "Wizard's Apprentice",
		"category": "hostage",
		"subcategory": "rescue",
		"sprite_path": "res://assets/sprites/npcs/civilians/Hostages/old_man_or_wizard_hostage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Rescue quest - captured mage apprentice"
	},
	{
		"id": "hostage_soldier",
		"name": "Captured Soldier",
		"category": "hostage",
		"subcategory": "rescue",
		"sprite_path": "res://assets/sprites/npcs/civilians/Hostages/soldier_hostage.png",
		"h_frames": 1, "v_frames": 1,
		"pixel_size": PIXEL_SIZE_HUMANOID,
		"offset_y": 0.0,
		"idle_frames": 1, "walk_frames": 1,
		"idle_fps": 2.0, "walk_fps": 2.0,
		"notes": "Rescue quest - captured guard/soldier"
	},
]


## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

## Get all actors (enemies + NPCs + named characters + hostages)
static func get_all_actors() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(ENEMIES)
	all.append_array(NPCS)
	all.append_array(NAMED_CHARACTERS)
	all.append_array(HOSTAGES)
	return all


## Get actors filtered by category
static func get_actors_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor: Dictionary in get_all_actors():
		if actor.get("category", "") == category:
			result.append(actor)
	return result


## Get actor by ID
static func get_actor(id: String) -> Dictionary:
	for actor: Dictionary in get_all_actors():
		if actor.get("id", "") == id:
			return actor
	return {}


## Get all unique subcategories
static func get_subcategories() -> Array[String]:
	var subcats: Array[String] = []
	for actor: Dictionary in get_all_actors():
		var subcat: String = actor.get("subcategory", "")
		if not subcat.is_empty() and not subcats.has(subcat):
			subcats.append(subcat)
	subcats.sort()
	return subcats


## Check if sprite path exists
static func validate_sprite_path(path: String) -> bool:
	if path.is_empty():
		return false
	return ResourceLoader.exists(path)


## Get all actors with missing sprites
static func get_missing_sprite_actors() -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	for actor: Dictionary in get_all_actors():
		var path: String = actor.get("sprite_path", "")
		if not path.is_empty() and not validate_sprite_path(path):
			missing.append(actor)
	return missing
