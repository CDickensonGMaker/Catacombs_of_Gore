# Catacombs of Gore - World Lore Bible

A living document consolidating all world lore, geography, NPCs, quests, and factions for the game.

---

## Table of Contents

1. [World Overview](#world-overview)
2. [Geography](#geography)
3. [Calendar System](#calendar-system)
4. [Adventure Part 1 - Locations](#adventure-part-1---locations)
5. [Main Quest](#main-quest)
6. [Side Quests](#side-quests)
7. [NPCs](#npcs)
8. [Enemies & Creatures](#enemies--creatures)
9. [Factions](#factions)
10. [Items & Artifacts](#items--artifacts)
11. [Future Content](#future-content)

---

## World Overview

The game takes place in the **Holy State of Cigis**, a medieval fantasy realm with dwarven mountain holds, coastal port cities, ancient ruins, and dark secrets lurking beneath the surface.

### Key Regions
- **Holy State of Cigis** - Main region where Adventure Part 1 takes place
- **Protectorate** - Western coastal region
- **United Republic** - Southeastern region

### World State at Game Start
- The main mountain pass toward Duncaster is blocked by a rockslide
- Rotherhine (Dwarf Hold) is under goblin siege - the Keerzhar Bridge is contested
- Southern towns are starving due to blocked trade routes
- Ghost pirates haunt the western waters, blocking sea trade
- A vampire cult is secretly taking over Whaeler's Drake

---

## Geography

### World Map Layout (North to South)

```
                 ╔════════════════════════════════════╗
                 ║         FALKENHAFEN (Capital)      ║
                 ║         - Destination for main quest
                 ║         - Grond Stoneheart awaits  ║
                 ║              ↑                     ║
                 ║         Mountain Pass              ║
                 ║              ↑ (hooks NE)          ║
                 ║      WHAELER'S ABYSS               ║
                 ║      - Cliffside town on abyss     ║
                 ║      - Rickety bridges             ║
                 ║      - Vampire cult (secret)       ║
                 ║      - Missing dwarves held here   ║
                 ║              ↑ east then NE        ║
    ═════════════╬═══════ KEERZHAR BRIDGE ═══════════ ║
    Southern     ║         ROTHERHINE                 ║
    Mountains    ║         (Karaz-Dor Dwarf Hold)     ║
                 ║         - 5 levels deep            ║
                 ║         - Under goblin siege       ║
                 ║         - Day 28 of invasion       ║
                 ╠════════════════════════════════════╣
                 ║                                    ║
                 ║      ~75 MILES OF WILDERNESS~      ║
                 ║   - Villages and hamlets           ║
                 ║   - Dungeons and caves             ║
                 ║   - Bandit camps                   ║
                 ║   - POIs to discover               ║
                 ║                                    ║
                 ╠════════════════════════════════════╣
                 ║         WILLOW DALE                ║
                 ║         - Abandoned watchtower     ║
                 ║         - Undead infestation       ║
                 ║         - Trapped apprentice       ║
                 ╠════════════════════════════════════╣
                 ║         DALHURST                   ║
                 ║         - Major port city          ║
                 ║         - 18 warships, 2600 troops ║
                 ║         - Commerce hub for capital ║
    ≋≋ Ghost ≋≋  ║              ↑                     ║
    ≋ Pirates ≋  ║      ELDER MOOR WILDERNESS        ║
    ≋≋≋≋≋≋≋≋≋≋≋  ║              ↑                     ║
                 ║         ELDER MOOR (START)         ║
                 ║         - Logging/hunting village  ║
                 ║         - 100 miles inland         ║
                 ║         - Population: 600          ║
                 ╚════════════════════════════════════╝
```

### Distance Reference
- Elder Moor to coast: ~100 miles west
- Elder Moor to Dalhurst: Short journey north/northwest
- Dalhurst to Rotherhine: ~75 miles south
- Rotherhine to Whaeler's Drake: South across bridge, then east

### Two Routes to Falkenhafen

| Route | Path | Challenges | Rewards |
|-------|------|------------|---------|
| **Land (South)** | Elder Moor → Dalhurst → Rotherhine → Bridge → Whaeler's Drake → Mountain Pass → Falkenhafen | Goblin siege, vampire cult | Restore land trade, dwarf allies, rescue hostages |
| **Sea (West)** | Elder Moor → Dalhurst → Boat → Coastal landing → Falkenhafen | Ghost pirates | Restore sea trade, coastal towns grateful |

Both routes are valid. Players choose their adventure.

---

## Calendar System

The world uses a unique calendar:

| Season | Duration | Real-World Equivalent |
|--------|----------|----------------------|
| **Jarrow** | 45 days | Winter → Spring (Jan-Apr) |
| **Midden** | 45 days | Spring → Summer (May-Aug) |
| **Weitherin** | 45 days | Summer → Fall/Winter (Sep-Dec) |

**Total Year: 135 days**

---

## Adventure Part 1 - Locations

### 1. Elder Moor (Starting Village)

**Type:** Village (Tier 2)
**Population:** 600
**Zone ID:** `village_elder_moor`

**Description:**
Nestled within the lush forest of Kreigstan, Elder Moor sits about 100 miles east of the coast. This hunting and lumber mining hamlet was founded in the last 30 years by ambitious merchants eager to capitalize on the overgrowth from the Wild Forests. Sustained by the sounds of axes against timber, the village thrives on the logging and hunting trade, providing a steady flow of resources to Dalhurst.

**Challenges:**
- Occasional disputes with local goblins
- Tree Folk encounters in the surrounding wilderness

**Key Features:**
- Fast Travel Shrine (starting shrine)
- Inn (The player's first rest point)
- Lumber company headquarters
- General store

**Key NPCs:**
- Thrain Ironbeard (Dwarf Guild Master, quest giver)
- Shopkeeper (TBD)
- 3-4 additional villagers (TBD)

---

### 2. Elder Moor Wilderness

**Type:** Wilderness/Open World
**Zone ID:** `wilderness_elder_moor`

**Description:**
The forest surrounding Elder Moor, part of the Kreigstan wilds. Dense trees, logging paths, and dangers lurking in the shadows.

**Potential POIs:**
- Logging camps
- Goblin caves
- Hunter's blinds
- Ancient tree shrine
- Bandit hideout
- Ruined watchtower

---

### 3. Dalhurst (Port City)

**Type:** City (Tier 4)
**Population:** Large (thousands)
**Zone ID:** `city_dalhurst`

**Description:**
Nestled along the rugged coastline, where the mighty waves of the Great Azure embrace the land, stands the vibrant port city of Dalhurst. The skyline is dominated not just by the towering masts of merchant vessels but also by the majestic warships that stand sentinel in the harbor.

As the largest commercial port for the esteemed Capital City, Emmenburg, Dalhurst pulsates with an energy born from the convergence of seafaring endeavors and military might.

**Military Presence:**
- 18 warships in harbor
- 2,600 troops garrison

**Key Districts:**
- Harbor/Docks
- Market District
- Tavern Row
- Merchant Quarter
- Military Barracks

**Key Locations:**
- **The Gilded Grog Tavern** - Lively establishment, bounty board location. Run by Gruff Stonemug.
- **Dalhurst Shipwright Guild** - Ship repairs. Led by Elara Ironwood.
- **Lady Nightshade's Curiosities** - Magic shop run by mysterious elf woman.
- **Harbormaster's Office** - Run by Gareth Stronghelm.

**Key NPCs:**
- Gruff Stonemug (Barkeep, The Gilded Grog)
- Elara Ironwood (Shipwright Guild Leader)
- Lady Nightshade (Magic Shop Owner, Elf)
- Captain Alan Stormrider (Merchant ship captain, often drunk by docks)
- Gareth Stronghelm (Harbormaster)

**Services:**
- Multiple inns
- Ship passage/purchase
- Bounty board
- Full merchant variety
- Stables

---

### 4. Willow Dale (Dungeon - Abandoned Watchtower)

**Type:** Dungeon/Ruins
**Zone ID:** `dungeon_willow_dale`

**Description:**
North of Dalhurst lies the abandoned Willow Dale Watchtower, once a magical observatory, now a cursed site due to a failed experiment by the ancient wizard Elhazar 100 years ago.

**Backstory:**
Elara Elrendor, a young warlock apprentice, ventured here seeking forbidden knowledge. She accidentally activated the Shadow Stone, reanimating the buried dead from the outlying cemetery. Now both she and Elhazar's spirit are trapped in a magical stasis in the basement.

**Dungeon Structure:**
1. **Ground Floor** - Entrance Hall, Guard Room (skeleton guards), Library
2. **First Floor** - Living Quarters (ghosts), Laboratory
3. **Second Floor** - Wizard's Study, Trap Room
4. **Rooftop** - Observation Deck, powerful undead guardian
5. **Basement Level 1** - Stasis Chamber entrance, experiments
6. **Basement Level 2** - Hall of Shadows (shadow wraiths)
7. **Basement Level 3** - Elhazar's Laboratory, Crystal Stasis

**Crystal Shard Puzzle:**
6 shards must be found to free Elara from the stasis:

| Shard | Location | DV |
|-------|----------|-----|
| Aethr | Buried with old wizard in grave outside | 10 |
| Chronly | Top of tower, behind boxes | 13 |
| Lumar | Jammed in a skeleton's eye socket | 14 |
| Bornis | Basement experiment table | 12 |
| Synvar | Locked chest (DV 15 to pick), with 100 gold | 0 |
| Veilith | Around a basement skeleton's neck | 15 |

**Enemies:**
- Skeletons (various)
- Zombies
- Shadow Wraiths
- Small Iron Golem
- Elhazar's Spirit (boss, can be hostile or neutral)

**Key NPCs:**
- Elara Elrendor (trapped apprentice warlock)
- Elhazar (ancient wizard spirit)

**Rewards:**
- Gold scattered throughout (1d6 x 100 per room)
- Magical items (scrolls, potions)
- Elhazar's Grimoire (necromancy spells)
- Elhazar's Staff (controls crystal stasis)
- Possible: Flamebrand Shortsword

---

### 5. Rotherhine / Karaz-Dor (Dwarf Mountain Hold)

**Type:** City (Tier 4) - Dwarven Hold
**Zone ID:** `city_rotherhine`

**Description:**
A crucial dwarven stronghold embedded deep within a mountain range, known for its strategic location and rich resources. Currently UNDER SIEGE by goblins.

**Current State (Day 28 of Invasion):**
- Goblins control inner chambers
- Survivors pushed outside
- Lord Balon Ironbeard killed on Day 25
- His body captured by goblins
- Succession crisis brewing
- Keerzhar Bridge nearly fell, now reinforced

**Structure (5 Levels):**

| Level | Name | Contents |
|-------|------|----------|
| 1st | Royalty & High Nobility | Great Hall, Royal Chambers, Council Room, Temple of Moradin |
| 2nd | Entrance & Fortifications | Entrance Hall, Guard Barracks, Armory, Keerzhar Bridge |
| 3rd | Markets & Common Housing | Market Square, Residential Quarters, Tavern, Guild Halls |
| 4th | Industry & Craftsmanship | Smithies, Workshop, Warehouse, Alchemy Lab |
| 5th | Mines & Lower Depths | Mining tunnels, Support Structures, Hidden Chambers, Shadowstone Chamber |

**Keerzhar Bridge:**
Massive bridge spanning a deep chasm, crucial for defense and trade. Connects northern and southern mountain passes. Currently the front line against goblins.

**Timeline of Invasion:**
- Day 1: Dwarves go missing from deep mines
- Day 3: Weakened support structures discovered
- Day 5: Goblin invasion begins
- Day 7: Goblins overrun first mine level
- Day 10: Dwarves fortify upper levels
- Day 12: Siege engines breach outer defenses
- Day 15: Bridge nearly falls
- Day 18: Engineers reinforce bridge
- Day 20: Goblin warlord Grukthak spotted
- Day 22: Goblins breach the bridge
- Day 25: Lord Balon killed, body captured
- Day 27: Survivors pushed outside
- **Day 28: PLAYERS ARRIVE**
- Day 35: Grukthak plans to eat Balon's body (deadline!)

**Key NPCs:**
- Prospector Gralmir (Balon's blood brother, quest giver)
- Tormek GrimmForgehands (Blacksmith, trapped in lower levels)
- Balon Ironbeard (DEAD - body must be recovered)
- Balon's Wife (pregnant with heir)

**Key Enemies:**
- Goblin forces
- Grukthak (Goblin Chieftain, boss)

**Political Conflict:**
Two factions disagree on succession:
1. **Legitimacy Faction** - Secure Balon's wife as heir (she's pregnant). Requires Necklace of the Fathers.
2. **Rite Faction** - Ancient dwarven rite of power succession (knife fight). Requires Shadowstone Blades.

---

### 6. Whaeler's Drake

**Type:** Town (Tier 3) - Cliffside Settlement
**Zone ID:** `town_whaelers_abyss`

**Description:**
A town built on the side of a massive abyss/cliff, connected by rickety bridges spanning the void. Located south of Keerzhar Bridge, then east. The path eventually hooks northeast into the mountain pass toward Falkenhafen.

**Current State:**
- Secret vampire cult taking over
- Missing dwarf survey/architect team held hostage
- Residents unaware or complicit

**Features:**
- Cliffside buildings
- Rickety rope/wood bridges
- Vertical layout
- Hidden cult headquarters

**Key NPCs:**
- Missing Dwarf Architects (hostages, need rescue)
- Vampire Cult Leader (TBD)
- Town residents (some cult members)

---

### 7. Falkenhafen (Capital City - Destination)

**Type:** Capital (Tier 5)
**Zone ID:** `capital_falkenhafen`

**Description:**
The main capital city and destination for the cart delivery. Grond Stoneheart awaits the delivery from Thrain Ironbeard.

**Key NPCs:**
- Grond Stoneheart (Dwarf, recipient of cart delivery)

*[More details TBD - Part 2+ content]*

---

## Main Quest

### Guild Dispatch

**Quest Giver:** Thrain Ironbeard (Elder Moor)

**Setup:**
The usual mountain route toward Duncaster is blocked by a rockslide. Thrain needs the party to deliver a cart of lumber and goods to his comrade Grond Stoneheart in Falkenhafen via an alternate southern route.

**Objectives:**

1. **Supply Delivery** (Main)
   Deliver the cart to Grond Stoneheart in Falkenhafen.
   *Reward: 4,000 Gold, 25,000 XP*

2. **Search for the Prospectors** (Optional)
   Find the missing architect/survey crew sent to Whaeler's Drake.
   *Reward: 25,000 XP*

**Route Instructions from Thrain:**
> "Head south toward the old Dwarven Mining Hall Rotherhine. Ask for Balon, my distant cousin. He'll put you up good for the night. Then east once through their mountain pass. Loop through Whaeler's Drake and then back north and you'll find the mountain pass that leads to King's Watch."

**Starting Resources:**
- 50 gold for expenses
- Sealed letter to Grond Stoneheart (proof of Ironbeard House)
- Cart with goods (must not break seal before delivery)

---

## Side Quests

### Dalhurst Bounty Board

#### 1. The Disappearing Cargo
*The Merchant Guild seeks adventurers to investigate missing cargo shipments along the northern trade route. Suspected bandit activity.*

- **Reward:** 150 gold
- **XP:** 250 per party member

#### 2. Feral Menace in the Marshlands
*Feral creatures in nearby marshlands disrupting trade caravans. Eliminate the threat.*

- **Reward:** 200 gold
- **XP:** 300 per party member

#### 3. Rescue in Willowdale
*Warlock Guild seeking return of lost apprentice Elara Elrendor who ventured to the ruins.*

- **Reward:** 300 gold
- **XP:** 400 per party member

---

### Rotherhine Quests

#### Reclaim the Throne
**Quest Giver:** Prospector Gralmir

**Objectives:**
1. Investigate Balon's death
2. Recover the Necklace of the Fathers (heirloom)
3. Rescue Balon's body before Grukthak consumes it (Day 35 deadline!)
4. Protect Balon's pregnant wife
5. Resolve succession crisis (choose faction)

**Complications:**
- Goblin ambushes
- Political intrigue between factions

#### The Shadowstone Blade
**Quest Giver:** Tormek GrimmForgehands (trapped blacksmith)

**Objectives:**
1. Reach lower levels through goblin-infested areas
2. Find Tormek
3. Gather rare forging materials
4. Protect the forge during crafting
5. Retrieve the completed Shadowstone Blade

**Notes:**
- If players choose the rite of succession, they need Tormek to craft Shadowblade Daggers
- Tormek has his own goals beyond helping the party

---

## NPCs

### Major NPCs

#### Thrain Ironbeard
- **Role:** Dwarf Guild Master, Quest Giver
- **Location:** Elder Moor
- **Description:** Grizzled dwarf, mix of wisdom and toughness
- **Relationship:** Balon Ironbeard is his distant cousin

#### Balon Ironbeard (DECEASED)
- **Role:** Lord of Rotherhine
- **Status:** Killed Day 25 of goblin invasion
- **Body Status:** Captured by goblins, Grukthak plans to consume it
- **Family:** Pregnant wife (heir to throne)

#### Prospector Gralmir
- **Role:** Quest Giver, Balon's blood brother
- **Location:** Rotherhine (outside, with survivors)
- **Motivation:** Fears for throne legitimacy, prefers engineering to fighting

#### Tormek GrimmForgehands
- **Role:** Dwarven Blacksmith
- **Location:** Trapped in Rotherhine lower levels
- **Stats:** HP 60, Grit 11, Armor 21
- **Skills:** Engineering 15, Endurance 10, Melee 15
- **Can Craft:** Shadowstone weapons, enchanted items

#### Elara Elrendor
- **Role:** Apprentice Warlock (trapped)
- **Location:** Willow Dale basement, crystal stasis
- **Backstory:** Accidentally activated Shadow Stone while trying to free Elhazar

#### Elhazar
- **Role:** Ancient Wizard Spirit
- **Location:** Willow Dale basement
- **Disposition:** Neutral (can turn hostile if disrespected)
- **Stats (if hostile):** HP 50, Armor 15, Arcane Blast 2d8, Necrotic Grasp 1d10+4

### Dalhurst NPCs

| NPC | Role | Location |
|-----|------|----------|
| Gruff Stonemug | Barkeep | The Gilded Grog Tavern |
| Elara Ironwood | Shipwright Guild Leader | Shipwright Guild |
| Lady Nightshade | Magic Shop Owner (Elf) | Lady Nightshade's Curiosities |
| Captain Alan Stormrider | Merchant Captain | Docks (often drunk) |
| Gareth Stronghelm | Harbormaster | Harbormaster's Office |

---

## Enemies & Creatures

### Shadow Wraith
- **HP:** 35
- **Armor:** 12 (Ethereal Shroud, resists non-magical physical)
- **Horror Check:** 14+
- **Movement:** 30 ft, can hover
- **Spawn:** Groups of 1d4
- **Attacks:**
  - Soul Drain: 1d6 necrotic, heals caster
  - Necrotic Bolt: 2d6 necrotic, range 30/60
- **Immunities:** Poison, Sleep, Charm, Exhaustion, Mind-affecting
- **Vulnerabilities:** Celestial magic, bright light (2d8 damage)
- **Special:** Incorporeal Movement, Shadow Stealth

### Small Iron Golem
- **HP:** 63
- **Armor:** 18 (Natural)
- **Horror Check:** 16+
- **Movement:** 20 ft
- **Attack:** Iron Fists 3d8+2
- **Immunities:** Poison, Sleep, Charm, Mind-affecting
- **Vulnerabilities:** Rust effects, Lightning

### Goblin Chieftain Grukthak (Boss)
- **HP:** 42
- **Armor:** 21 (Leather & Chain)
- **Horror Check:** 14+ (in groups of 3+)
- **Movement:** 9
- **Stats:** Grit 12, Agility 13, Vitality 12, Will 7
- **Weapon:** Emperor Alric's Longsword +3 (3d6+3 damage)
- **To Hit:** Melee +19, Ranged +17
- **Skills:** Leadership 11, Endurance 12
- **Personality:** Cunning, terrified of magic (refuses to use it)
- **Goal:** Find Shadowstone to empower goblin forces, conquer Aberdeen
- **Immediate Goal:** Consume Balon's flesh in dark ritual

---

## Factions

### Ironbeard Lumber Company
- **Base:** Elder Moor
- **Leader:** Thrain Ironbeard
- **Business:** Logging, lumber trade to Dalhurst
- **Allied With:** Rotherhine dwarves

### Rotherhine Dwarves
- **Base:** Karaz-Dor (Rotherhine)
- **Current Leader:** Disputed (Balon dead)
- **Status:** Under siege, fractured by succession crisis

### Goblin Horde
- **Leader:** Grukthak
- **Base:** Occupying Rotherhine lower levels
- **Goal:** Obtain Shadowstone, conquer region
- **Shamans:** Know true power of Shadowstone (Grukthak doesn't)

### Vampire Cult (Secret)
- **Base:** Whaeler's Drake
- **Status:** Secretly taking over the town
- **Hostages:** Missing dwarf survey team

### Ghost Pirates
- **Location:** Western waters
- **Effect:** Blocking sea trade routes
- **Opportunity:** Defeating them opens alternate path to Falkenhafen

---

## Items & Artifacts

### Necklace of the Fathers
- **Type:** Heirloom
- **Description:** Tribal necklace whittled from bones of the first great beast that fed the dwarf tribes centuries ago
- **Purpose:** Required to legitimize heir to Rotherhine throne

### Shadowstone
- **Type:** Artifact
- **Location:** Deep in Rotherhine mines
- **Power:** Amplifies dark magic
- **Danger:** Grukthak seeks it to empower his army

### Shadowstone Blade / Shadowblade Daggers
- **Type:** Weapon
- **Crafter:** Tormek GrimmForgehands
- **Purpose:** Required for ancient rite of power succession

### Emperor Alric's Longsword +3
- **Type:** Legendary Weapon
- **Current Owner:** Grukthak
- **Stats:** +3 to hit, 3d6+3 damage
- **Description:** Blessed by ancient enchantments, glows with radiant aura

### Elhazar's Staff
- **Type:** Magical Staff
- **Location:** Willow Dale
- **Power:** Controls crystal stasis apparatus

### Elhazar's Grimoire
- **Type:** Spellbook
- **Location:** Willow Dale
- **Contents:** Powerful necromancy spells and rituals

---

## Adventure Part 2 - Locations

### 5. Aberdeen (Trade Town - Starving)

**Type:** Town (Tier 3)
**Zone ID:** `town_aberdeen`

**Description:**
A once-thriving trade town now reduced to a shattered fraction of its former population. The last few months have seen no trade or growth. Famine and lack of material income has driven folks to their graves or worse - moving away.

**Current State:**
- Population decimated
- Famine conditions
- No incoming trade
- Desperate residents

**Problem:**
Trade from Larton has stopped. Larton's fishing wagons used to be the lifeblood of every working person in Aberdeen.

**Key NPCs:**
- Mayor of Aberdeen (quest giver, asking party to investigate why trade stopped)

**Quest: Investigate Trade Stoppage**
The Mayor asks the party to find out why trade from Larton has ceased.

---

### 6. Larton (Abandoned Port Town)

**Type:** Town (Tier 3) - Mostly Abandoned
**Zone ID:** `town_larton`

**Description:**
A large port town that has suffered even worse than Aberdeen. The Ghost Captain has been destroying all ships traveling up and down the coast, completely cutting off the fishing trade.

**Current State:**
- Largely abandoned/vacant
- Bandits and beggars have moved into unoccupied portions
- Few guards remain, mostly hiding indoors
- Mayor hasn't been seen in quite some time

**Problem:**
The Ghost Captain and his spectral pirates are destroying all coastal shipping, causing the town's collapse.

**Key NPCs:**
- Larton Guards (demoralized, staying inside)
- Ghost Captain (enemy, at sea)
- Enchanted Pirates (enemy crew)
- Missing Mayor (whereabouts unknown)

**Enemies:**
- Ghost Captain
- Enchanted/Spectral Pirates
- Bandits
- Beggars (potentially hostile)

---

### 7. East Hollow (Fallen Town)

**Type:** Town (Tier 3) - Conquered
**Zone ID:** `town_east_hollow`

**Description:**
A town that has been completely taken over by Human/Tregar hybrids. The scene is horrific - the former residents now hang from the walls by their entrails.

**Current State:**
- Conquered by Tregar hybrids
- Former residents massacred
- 50% chance Tregar envoy has already arrived and meeting is underway when party arrives

**Nearby POI: The Border Wars Graveyard**
The last of the great border disputes happened around 100 years ago. The tormentous large charnel pit that is the aftermath from that battle still exists.

- Hundreds of thousands of corpses still in armor
- Weapons scattered about
- Home to undead and grave diggers
- Grave diggers look to profit from recovered gems/equipment
- Restless undead spirits roam, reanimated by unspeakable magic

**Enemies:**
- Human/Tregar Hybrids
- Tregar Envoy
- Undead (at graveyard)

---

### 8. Whaeler's Drake / Whalersdrake (Canyon Town)

**Type:** Town (Tier 3) - Cliffside
**Zone ID:** `town_whaelers_drake`

**Note:** This is the same location referred to as "Whaeler's Drake" in Part 1 notes.

**Description:**
A town built into the edges of a Grand Canyon-type situation. Buildings are constructed into the cliff faces themselves, with a large bridge connecting the two sides of the canyon.

**Current State:**
- Vampire cult rapidly taking hold
- Missing dwarf prospectors located here
- Charismatic cult leader recruiting followers

**The Missing Dwarves (from Main Quest):**
- Some are drunk in the tavern
- One has been captured by the cult
- They completed their bridge integrity check (passed)
- Were waiting for friend with sprained ankle before returning
- Drunk ones assume captured one fell off the cliffs

**Cult Activity Timeline:**
| Day | Event |
|-----|-------|
| 1 | Party starts adventure |
| 5 | Cult Leader appears in town |
| 10 | Cult begins recruiting in secret |
| 15 | Ritual sacrifices in hidden locations |
| 20 | Cult influence spreads among townsfolk |
| 25 | Cultists sabotage town defenses |
| 30 | Cultists openly display symbols |
| 35 | Cult intimidates/eliminates resistance |
| 40 | Cult power solidifies |
| 45 | Town leaders disappear or join cult |
| 50 | Cult controls town government |
| 55 | Strict rules and curfews imposed |
| 60 | Cult fully controls Whalersdrake |

**Cult's Goal:**
Sacrifice the captured dwarf to unearth an ancient vampire from a crypt hidden to the northeast in the mountains on the east side of the canyon.

**Quest: Canyon of Shadows**

1. **Introduction** - Arrive in Whalersdrake, learn about missing dwarf prospector
2. **Investigation** - Explore town, find drunk dwarves in tavern, learn of cult
3. **Cult Activity** - Discover cult plans to sacrifice dwarf to awaken vampire
4. **Rescue Mission** - Confront cult, navigate cliffs and bridges, rescue dwarf
5. **Crypt Exploration** - Journey to hidden crypt in mountains, face undead guardians
6. **Final Confrontation** - Battle cult leader during awakening ritual, defeat vampire's minions
7. **Resolution** - Return as heroes, town celebrates, but other threats loom

**Key Locations:**
- Canyon cliffs with buildings
- Large central bridge
- Tavern (drunk dwarves)
- Cult hideout
- Hidden vampire crypt (NE in mountains)

---

## Adventure Part 2 - Updated World Map

```
                    NORTH
                      ↑
    ╔═══════════════════════════════════════════════════╗
    ║                 FALKENHAFEN                       ║
    ║                      ↑                            ║
    ║              Mountain Pass                        ║
    ║                      ↑                            ║
    ║    [Vampire Crypt] ← WHAELER'S DRAKE             ║
    ║    (hidden NE)       (Canyon Town, Cult)          ║
    ║                      ↑                            ║
    ║              KEERZHAR BRIDGE                      ║
    ║                      ↑                            ║
    ║              ROTHERHINE (Siege)                   ║
    ╠═══════════════════════════════════════════════════╣
    ║                                                   ║
    ║   ABERDEEN ←──trade cut──→ LARTON               ║
    ║   (starving)              (ghost pirates)        ║
    ║                                                   ║
    ║        BORDER WARS GRAVEYARD                     ║
    ║              (undead)                             ║
    ║                  ↓                                ║
    ║           EAST HOLLOW                            ║
    ║           (Tregar hybrids)                       ║
    ║                                                   ║
    ╠═══════════════════════════════════════════════════╣
    ║              WILLOW DALE                          ║
    ║                  ↓                                ║
    ║              DALHURST                             ║
    ║                  ↓                                ║
    ║           ELDER MOOR (START)                     ║
    ╚═══════════════════════════════════════════════════╝
         WEST                              EAST
    (Ghost Pirates                    (Holy State
     at sea)                           of Cigis)
```

---

## New Factions (Part 2)

### Whaeler's Drake Vampire Cult
- **Base:** Whaeler's Drake, hidden crypt in NE mountains
- **Leader:** Charismatic cult leader (name TBD)
- **Goal:** Awaken ancient vampire
- **Method:** Sacrifice captives (including dwarf prospector)
- **Timeline:** 60 days to full control of town

### Tregar Hybrids
- **Base:** East Hollow (conquered)
- **Nature:** Human/Tregar hybrid creatures
- **Disposition:** Hostile, massacred town residents
- **Activity:** Meeting with Tregar envoy

### Ghost Pirates
- **Leader:** Ghost Captain
- **Base:** Coastal waters near Larton
- **Effect:** Destroying all ships, cutting off trade
- **Victims:** Larton, Aberdeen (indirectly)

---

## New Enemies (Part 2)

### Ghost Captain
- **Type:** Undead/Spectral
- **Location:** Coastal waters
- **Crew:** Enchanted Pirates
- **Threat:** Destroys all ships on coast

### Enchanted Pirates
- **Type:** Undead/Spectral
- **Serve:** Ghost Captain
- **Stats:** TBD

### Tregar Hybrids
- **Type:** Humanoid hybrid
- **Location:** East Hollow
- **Disposition:** Extremely hostile
- **Notable:** Display victims' bodies on walls

### Border Wars Undead
- **Type:** Various undead
- **Location:** Border Wars Graveyard
- **Origin:** 100-year-old battlefield
- **Numbers:** Hundreds of thousands of potential corpses

---

## Future Content

### Adventure Part 3
*[To be documented]*

### Ghost Pirate Questline
- Sea route alternative
- Spectral enemies
- Naval/coastal content

### The Dark Tower (Ethereal Dark Castle)
- 5 floors of dungeon
- Shadow-themed enemies
- Dark Overlord boss (HP 120)
- Located in shadow parallel plane

---

## POI Target List

**Goal: 75-100 Points of Interest**

### Confirmed Locations (Main Story)
1. Elder Moor (Village)
2. Elder Moor Wilderness
3. Dalhurst (City)
4. The Gilded Grog Tavern
5. Shipwright Guild
6. Lady Nightshade's Curiosities
7. Willow Dale Watchtower
8. Rotherhine / Karaz-Dor
9. Keerzhar Bridge
10. Whaeler's Drake
11. Falkenhafen (Capital)

### Planned POI Categories

| Category | Target Count | Examples |
|----------|--------------|----------|
| Settlements | 10-15 | Hamlets, villages along the 75-mile stretch |
| Dungeons/Caves | 15-20 | Goblin caves, crypts, abandoned mines |
| Camps | 10-15 | Bandit camps, hunter camps, goblin outposts |
| Ruins | 10-15 | Old towers, collapsed forts, shrines |
| Landmarks | 10-15 | Standing stones, waterfalls, ancient trees |
| Resource Sites | 5-10 | Ore veins, herb gardens, fishing spots |
| Hidden/Secret | 5-10 | Unmarked caves, treasure caches |

---

## Development Notes

### Zone ID Naming Convention
- `village_[name]` - Villages
- `hamlet_[name]` - Hamlets
- `town_[name]` - Towns
- `city_[name]` - Cities
- `capital_[name]` - Capitals
- `dungeon_[name]` - Dungeons
- `wilderness_[name]` - Open world areas
- `poi_[name]` - Generic points of interest

### Current Codebase Mapping
| Lore Location | Current Code | Needs Rename |
|---------------|--------------|--------------|
| Elder Moor | `test_level` | YES → `village_elder_moor` |
| Elder Moor Wilderness | `open_world` | YES → `wilderness_elder_moor` |
| Riverside Village | `riverside_village` | REPURPOSE or REMOVE |

---

*Last Updated: [Auto-generated during development]*
*This is a living document - add new lore as it's shared.*
