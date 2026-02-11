# Catacombs of Gore

A PS1-style open world action RPG built in Godot 4.5, inspired by classic dark fantasy games.

## Game Overview

**Catacombs of Gore** is a retro-styled action RPG that combines the exploration of Elder Scrolls games with the brutal combat of Souls-likes, wrapped in a nostalgic PS1 visual aesthetic.

### Key Features

- **PS1 Visual Style**: Low-poly models, billboard sprites, vertex jitter, affine texture mapping
- **Open World Exploration**: Hex-based world map with procedural and hand-crafted content
- **TTRPG-Inspired Combat**: Dice-based damage calculations, critical hits, skill checks
- **Deep NPC Conversations**: Topic-based dialogue system with reputation effects
- **Procedural Dungeons**: Generated dungeon layouts with room templates
- **Quest System**: Main storylines and procedural bounties
- **Crime & Consequence**: Guards, bounties, faction reputation

## Technical Details

- **Engine**: Godot 4.5
- **Language**: GDScript (strict typing)
- **Rendering**: Forward+ with custom PS1 shaders
- **Resolution**: 640x480 (window scaled to 1280x960)

## Project Structure

```
CatacombsOfGore/
├── assets/           # Sprites, shaders, textures
├── data/             # Game data resources (.tres files)
│   ├── armor/        # Armor definitions
│   ├── enemies/      # Enemy data
│   ├── items/        # Item definitions
│   ├── quests/       # Quest data (JSON)
│   ├── spells/       # Magic spells
│   └── weapons/      # Weapon definitions
├── docs/             # Design documentation
├── scenes/           # Scene files (.tscn)
│   ├── combat/       # Combat-related scenes
│   ├── levels/       # Level scenes
│   ├── player/       # Player scenes
│   └── ui/           # UI scenes
└── scripts/          # GDScript files
    ├── autoload/     # Singleton managers
    ├── combat/       # Combat systems
    ├── data/         # Data structures
    ├── dialogue/     # Dialogue resources
    ├── npcs/         # NPC scripts
    ├── player/       # Player scripts
    ├── ui/           # UI scripts
    └── world/        # World/level scripts
```

## Core Systems

### Combat
- Real-time melee and ranged combat
- Hitbox/hurtbox collision system
- Status effects and damage types
- Equipment affects stats and abilities

### World
- Hex-based overworld navigation
- Wilderness encounters
- Towns with services (shops, temples, guilds)
- Procedural dungeon generation

### NPCs
- Billboard sprites with 8-directional facing
- Topic-based conversation system
- Memory of past interactions
- Guards with crime response

### Progression
- Level-based character advancement
- Multiple skills (combat, magic, social)
- Equipment crafting and upgrading
- Faction reputation

## Inspirations

- **Skyrim / Elder Scrolls** - Open world, guilds, dialogue
- **Dark Souls / Elden Ring** - Combat feel, difficulty
- **Fallout: New Vegas** - Faction reputation, skill checks
- **King's Field** - PS1 first-person dungeon crawling
- **Tenchu** - Stealth mechanics
- **Final Fantasy 7/8/9** - Story structure

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Camera |
| LMB | Light Attack |
| RMB | Heavy Attack |
| Q | Block |
| Space | Jump |
| Shift | Sprint |
| Ctrl | Dodge |
| E | Interact |
| F | Lock-on |
| Tab | Menu |
| Esc | Pause |
| 1-0 | Hotbar |

## Development Status

**Currently in Development**

The game is being actively developed. Current focus areas:
- NPC visual consistency
- Quest system refinement
- World map population
- Combat balancing

## License

All rights reserved. This code is shared for educational purposes.

## Credits

Developed using **Godot Engine 4.5**
AI-assisted development with **Claude (Anthropic)**
