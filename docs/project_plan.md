# Catacombs of Gore - Project Plan

## Project Overview
PS1-styled open world adventure RPG built in Godot 4.5. Inspired by Skyrim, Fallout New Vegas, Elden Ring, Dark Souls, Vampire the Masquerade Bloodlines, Tenchu, Final Fantasy 7/8/9, and Metal Gear Solid.

---

## COMPLETED WORK

### Session 1: World Building Foundation

#### Fast Travel System
- [x] Created `FastTravelShrine` class (`scripts/world/fast_travel_shrine.gd`)
- [x] Applied shrine texture from `Sprite folders grab bag/shrinetexture.png`
- [x] Added shrines to test_level and riverside_village
- [x] Shrines auto-discover zones via MapTracker

#### Documentation
- [x] Created `docs/town_development_guide.md` - Settlement tier system (Hamlet → Capital)
- [x] Created `docs/world_lore.md` - 500+ line master lore bible with all locations, NPCs, quests

#### World Map System
- [x] Updated `scripts/ui/world_map.gd` with 16 real locations
- [x] Proper map positions and connections based on lore

#### Zone Renaming (Lore Accuracy)
- [x] `test_level.gd` → ZONE_ID "elder_moor" (Starting Village)
- [x] `open_world.gd` → ZONE_ID "elder_moor_wilderness"
- [x] `riverside_village.gd` → ZONE_ID "rotherhine" (Dwarf Trading Post)

#### New Location Scenes Created (14 total)
- [x] `dalhurst.gd/tscn` - Port city with harbor, warships, merchants, bounty board
- [x] `willow_dale.gd/tscn` - Undead dungeon with cemetery, tower structure
- [x] `duncaster.gd/tscn` - Mountain town with ROCKSLIDE blocking main route
- [x] `falkenhaften.gd/tscn` - Capital city with grand plaza, Grond Stoneheart NPC
- [x] `kings_watch.gd/tscn` - Mountain fortress with barracks
- [x] `pola_perron.gd/tscn` - Peaceful mountain village
- [x] `whaelers_drake.gd/tscn` - Canyon cliffside town with cult hints, rickety bridges
- [x] `larton.gd/tscn` - Abandoned port with ghost ship, bandits
- [x] `aberdeen.gd/tscn` - Starving trade town, Mayor quest giver
- [x] `east_hollow.gd/tscn` - Conquered town with defiled shrine, hostile enemies
- [x] `border_wars_graveyard.gd/tscn` - Massive undead battlefield dungeon
- [x] `vampire_crypt.gd/tscn` - Hidden cult dungeon with ancient vampire

#### Bug Fixes
- [x] Fixed type inference errors (array indexing returning Variant)
- [x] Fixed quest_ids type error in dungeon_room.gd (Array vs Array[String])
- [x] Removed test dungeon portals from Elder Moor (not canon)
- [x] Updated wilderness portals to lore-accurate connections

#### Additional Work (User)
- [x] Added new assets (sprites, textures, etc.)
- [x] Improved random dungeon generator

---

## PENDING WORK - PRIORITY ORDER

### Phase 1: UI Systems Fix (Foundation)

#### 1.1 Local Map Overhaul
**Status:** NOT STARTED
**Priority:** HIGH - Needed before adding more POIs

**Current Issues:**
- Map tracks explored cells but doesn't show key features
- No merchant/store markers
- No inn markers
- No zone exit markers
- No quest item markers

**Tasks:**
- [ ] Add new marker types to MapTracker:
  - `"merchant"` - Gold coin icon
  - `"inn"` - Bed icon
  - `"exit"` - Door/arrow icon
  - `"quest_item"` - Star icon
- [ ] Update `minimap.gd` `_draw_markers()` to render new types
- [ ] Update `zone_map.gd` `_draw_markers()` to render new types
- [ ] Modify `Merchant.spawn_merchant()` to register with MapTracker
- [ ] Modify `ZoneDoor` to register as map marker (not just compass POI)
- [ ] Create inn registration system (innkeeper NPCs or inn doors)

**Files to Modify:**
- `scripts/autoload/map_tracker.gd`
- `scripts/ui/minimap.gd`
- `scripts/ui/zone_map.gd`
- `scripts/world/merchant.gd`
- `scripts/world/zone_door.gd`

#### 1.2 Compass Bounty Integration
**Status:** NOT STARTED
**Priority:** HIGH - Needed for bounty system usability

**Current Issues:**
- Compass shows quest objectives but NOT bounty targets
- No way to track bounty kills/collect locations

**Tasks:**
- [ ] Add bounty tracking to HUD compass system
- [ ] Query BountyBoard for active bounties
- [ ] Find bounty targets in current zone (enemies matching bounty.target)
- [ ] Display bounty markers with distinct color (red/orange)
- [ ] Show bounty collect item locations when applicable

**Files to Modify:**
- `scripts/ui/hud.gd` (compass section, lines 1134-1665)
- `scripts/world/bounty_board.gd` (expose active bounty data)

---

### Phase 2: Main Quest Introduction

#### 2.1 Thrain Ironbeard NPC
**Status:** PLANNED (design complete)
**Priority:** HIGH - Core story hook

**Overview:**
Dwarf guild master in Elder Moor who stops player when first trying to leave, gives main delivery quest.

**Tasks:**
- [ ] Create `MainQuestGiver` class or extend `QuestGiver`
- [ ] Create quest: `main_quest_ironbeard_delivery.json`
- [ ] Create quest item: `ironbeard_lockbox.tres`
- [ ] Add `is_quest_item` flag to ItemData (prevents drop/sell)
- [ ] Modify ZoneDoor to support blocking conditions
- [ ] Spawn Thrain in `test_level.gd` (Elder Moor)
- [ ] Implement dialogue tree with accept/decline flow
- [ ] Block town exit until quest accepted

**Quest Details:**
- **Quest Name:** "The Ironbeard Delivery"
- **Objective:** Deliver strongbox to Grond Stoneheart in Falkenhaften
- **Rewards:** 50 gold (upfront), 200 gold + 500 XP (on completion)
- **Side Hook:** Mentions missing dwarf surveyors at Whaeler's Abyss

**Files to Create:**
- `scripts/npcs/main_quest_giver.gd`
- `data/quests/main_quest_ironbeard_delivery.json`
- `data/items/ironbeard_lockbox.tres`

**Files to Modify:**
- `scripts/levels/test_level.gd`
- `scripts/world/zone_door.gd`
- `scripts/autoload/quest_manager.gd`

#### 2.2 Connected NPCs
**Status:** NOT STARTED
**Priority:** MEDIUM - Quest completion targets

- [ ] Grond Stoneheart in Falkenhaften (quest turn-in)
- [ ] Balon Ironbeard in Rotherhine (free lodging, dialogue)
- [ ] Missing surveyors content in Whaeler's Abyss (side quest)

---

### Phase 3: Wilderness Zone Expansion

#### 3.1 New Wilderness Zones (12 total)
**Status:** NOT STARTED
**Priority:** MEDIUM - World expansion

**Zone List:**

| # | Zone Name | Size | POIs | Connects |
|---|-----------|------|------|----------|
| 1 | Elder Moor Wilds | Medium | 5-6 | Elder Moor ↔ Crossroads |
| 2 | Crossroads Hub | Medium | 4-5 | Central junction point |
| 3 | Northern Road | Medium | 4-5 | Crossroads ↔ Dalhurst |
| 4 | Coastal Cliffs | Small | 3-4 | Dalhurst ↔ Willow Dale |
| 5 | Southern Highlands | Medium | 5-6 | Crossroads ↔ Rotherhine |
| 6 | Mountain Pass | Small | 3-4 | Duncaster ↔ Kings Watch (blocked to Falkenhaften) |
| 7 | Eastern Plains | Large | 6-8 | Crossroads ↔ Falkenhaften |
| 8 | King's Road | Medium | 5-6 | Rotherhine ↔ Falkenhaften |
| 9 | Moor Marsh | Medium | 4-5 | Southern Highlands ↔ Aberdeen |
| 10 | Whaeler's Descent | Medium | 4-5 | Aberdeen ↔ Whaeler's Drake |
| 11 | Ghost Coast | Small | 3-4 | Aberdeen ↔ Larton |
| 12 | Hollow Road | Small | 3-4 | Larton ↔ East Hollow |

**Total Wilderness POIs: ~55-65**

**World Connection Map:**
```
                    [WILLOW DALE]
                         |
                   Coastal Cliffs (3-4)
                         |
    [DUNCASTER]----[DALHURST]
         |              |
  Mountain Pass      Northern Road
     (3-4)            (4-5)
         |              |
         X blocked [CROSSROADS]----Eastern Plains (6-8)----[FALKENHAFTEN]
         |            (4-5)                                      |
    [KINGS WATCH]       |                                   King's Road
                  Elder Moor Wilds                            (5-6)
                      (5-6)                                      |
                        |                                        |
                   [ELDER MOOR]                                  |
                                                                 |
                   Southern Highlands (5-6)-----------------[ROTHERHINE]
                         |
                    Moor Marsh (4-5)
                         |
                   [ABERDEEN]----Whaeler's Descent (4-5)----[WHAELER'S DRAKE]
                        |                                         |
                   Ghost Coast (3-4)                        Vampire Crypt
                        |
                    [LARTON]----Hollow Road (3-4)----[EAST HOLLOW]
                                                           |
                                                  Border Wars Graveyard
```

#### 3.2 POI Types for Wilderness
**Status:** NOT STARTED

**Loot/Discovery POIs:**
- [ ] Abandoned campsites (supplies, journals, lore)
- [ ] Hidden treasure caches (buried chests)
- [ ] Merchant corpses (trade goods, danger hints)
- [ ] Old battlefields (weapons, armor scraps)
- [ ] Hermit caves (mini-shops or lore NPCs)

**Combat POIs:**
- [ ] Bandit camps (enemies + loot)
- [ ] Goblin warrens (small dungeon entrances)
- [ ] Wolf/beast dens (animal enemies)
- [ ] Undead graves (night spawns, cursed areas)

**Exploration POIs:**
- [ ] Ancient ruins (lore tablets, puzzles)
- [ ] Scenic overlooks (map reveals?)
- [ ] Strange shrines (buffs, curses, or fast travel)
- [ ] Collapsed mines (blocked, future content hooks)

#### 3.3 POI Base Classes
**Status:** NOT STARTED

- [ ] Create `WildernessPOI` base class
- [ ] Create `LootCache` POI (chest with randomized loot)
- [ ] Create `EnemyCamp` POI (spawns enemies, has loot after clear)
- [ ] Create `AbandonedCamp` POI (supplies, journal entries)
- [ ] Create `AncientRuin` POI (lore discovery, possible puzzle)
- [ ] Create `HermitCave` POI (NPC merchant or quest giver)

---

### Phase 4: Leveling System Revision

#### 4.1 Level Up Changes
**Status:** NOT STARTED
**Priority:** LOW - Balance pass

**Current:** Unknown (needs audit)

**Proposed:**
- Normal level up: Choose ONE Skill OR ONE Stat
- Every 3rd level: Upgrade BOTH Skill AND Stat

**Tasks:**
- [ ] Audit current leveling system
- [ ] Implement new level up rules
- [ ] Update level up UI to reflect changes
- [ ] Balance skill/stat progression

---

### Phase 5: Skills Audit

#### 5.1 Skills Tied to Gameplay
**Status:** NOT STARTED
**Priority:** LOW - Polish pass

**Tasks:**
- [ ] Audit all skills and their gameplay effects
- [ ] Ensure each skill has meaningful impact
- [ ] Add missing skill checks where appropriate
- [ ] Balance skill requirements for content

---

## FUTURE CONSIDERATIONS

### Additional Content (Not Yet Planned)
- [ ] More dungeons (75-100 total POIs goal)
- [ ] Companion system
- [ ] Faction reputation
- [ ] Day/night cycle effects
- [ ] Weather system
- [ ] Crafting expansion
- [ ] Housing/base building

### Technical Debt
- [ ] Performance optimization for large wilderness zones
- [ ] Save/load testing with all new zones
- [ ] Quest system stress testing

---

## SESSION NOTES

### Session 1 Summary
- Built entire world structure from lore documents
- Created 14 new location scenes
- Fixed multiple GDScript type errors
- Established settlement tier system
- Planned main quest introduction

### Next Session Priority
1. Fix Local Map (show merchants, inns, exits)
2. Fix Compass (show bounty targets)
3. Implement Thrain Ironbeard NPC
4. Begin wilderness zone creation

---

*Last Updated: Session 1*
