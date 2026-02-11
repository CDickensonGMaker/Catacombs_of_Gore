# Town Development Guide

A reference document for developers creating settlements in Catacombs of Gore. This guide defines the structure, services, and features for each settlement tier.

---

## Settlement Tier Overview

| Tier | Name | Population | Description |
|------|------|------------|-------------|
| 1 | **Hamlet** | < 50 | Tiny, remote outpost with bare essentials. Safe haven for weary travelers. |
| 2 | **Village** | 50-200 | Small community with basic services. Generally safe, some nighttime dangers. |
| 3 | **Town** | 200-500 | Moderate settlement with varied services. Mixed safety - watch the back alleys. |
| 4 | **City** | 500-2000 | Large urban center with full services. Criminal elements present. |
| 5 | **Capital** | 2000+ | Major hub with everything plus unique features. Political intrigue and danger. |

---

## Core Rules

### Universal Requirements (ALL Settlements)
- **Fast Travel Shrine** - Always present, always accessible
- **Inn** - Required at every tier (door must be placed against a box-style building)
- **Innkeeper NPC** - Provides rest, rumors, and room rental

### Town Storage System
- Town Storage is **SHARED WORLDWIDE** when present
- Uses persistent ID: `town_storage_main`
- Available at Village tier and above
- Players can access their stored items from any settlement with storage

### Scaling Principles
- Merchants increase in **variety** (more types) AND **quality** (better stock) with settlement size
- Visual defenses scale with size (more guards, better walls)
- Larger settlements can contain hostile elements
- Small settlements (Hamlet) are guaranteed safe havens

---

## 1. Required Buildings/Features by Tier

| Feature | Hamlet | Village | Town | City | Capital |
|---------|:------:|:-------:|:----:|:----:|:-------:|
| Fast Travel Shrine | YES | YES | YES | YES | YES |
| Inn | YES (small) | YES | YES | YES (multiple) | YES (multiple) |
| Town Storage | - | YES | YES | YES | YES |
| Signature Landmark | Well/Signpost | Town Square | Fountain/Plaza | Statue/Monument | Grand Monument |
| Walls/Palisade | - | Partial | YES | YES (stone) | YES (fortified) |
| Guard Posts | - | 1 | 2-3 | 4-6 | 8+ |
| Stables | - | - | YES | YES | YES |
| Guild Halls | - | - | 1 | 2-3 | All guilds |
| Temple/Shrine | - | Shrine | Temple | Cathedral | Grand Cathedral |
| Barracks | - | - | - | YES | YES |
| Castle/Palace | - | - | - | - | YES |
| Arena/Colosseum | - | - | - | Optional | YES |
| Sewer Access | - | - | - | YES | YES |

### Building Count Guidelines

| Building Type | Hamlet | Village | Town | City | Capital |
|---------------|:------:|:-------:|:----:|:----:|:-------:|
| Residential | 2-4 | 8-15 | 20-40 | 50-100 | 150+ |
| Commercial | 1-2 | 3-5 | 8-12 | 20-30 | 50+ |
| Public/Civic | 1 | 2-3 | 4-6 | 8-12 | 20+ |
| Total Buildings | 4-7 | 15-25 | 35-60 | 80-150 | 200+ |

---

## 2. Merchant Availability by Tier

| Merchant Type | Hamlet | Village | Town | City | Capital | Stock Quality |
|---------------|:------:|:-------:|:----:|:----:|:-------:|---------------|
| General Store | YES | YES | YES | YES (x2) | YES (x3) | Basic supplies, common items |
| Blacksmith | - | YES | YES | YES (x2) | YES (x3) | Weapons, repairs |
| Armorer | - | - | YES | YES | YES (x2) | Armor, shields |
| Alchemist | - | - | YES | YES | YES (x2) | Potions, ingredients |
| Jeweler | - | - | - | YES | YES | Rings, amulets, gems |
| Enchanter | - | - | - | YES | YES | Magic items, enchantments |
| Exotic/Rare Dealer | - | - | - | - | YES | Unique items, artifacts |
| Black Market | - | - | Hidden | YES | YES | Illegal goods, stolen items |

### Merchant Stock Quality by Tier

| Tier | Item Quality Available | Price Modifier |
|------|------------------------|----------------|
| Hamlet | Common only | 1.2x (remote tax) |
| Village | Common, Uncommon (limited) | 1.0x |
| Town | Common, Uncommon, Rare (limited) | 1.0x |
| City | Common through Rare, Epic (limited) | 0.95x (competition) |
| Capital | All qualities, Legendary (very rare) | 0.9x (best prices) |

### Specialist Merchants (Unique to Tier)

**Village:**
- Traveling Merchant (random visits, rotating stock)

**Town:**
- Herbalist (plants, reagents)
- Scribe (scrolls, maps, books)

**City:**
- Fence (buys stolen goods, no questions)
- Exotic Pet Dealer (mounts, companions)
- Slave Market (if setting-appropriate)

**Capital:**
- Master Craftsmen (legendary quality commissions)
- Artifact Dealer (historical/magical items)
- Noble Outfitter (high-end cosmetics, prestige items)
- Faction Quartermasters (faction-specific gear)

---

## 3. NPC Types by Tier

| NPC Type | Hamlet | Village | Town | City | Capital |
|----------|:------:|:-------:|:----:|:----:|:-------:|
| Innkeeper | 1 | 1 | 1-2 | 2-4 | 4+ |
| Guards | 0 | 1-2 | 4-8 | 15-30 | 50+ |
| Quest Givers | 0-1 | 1-2 | 3-5 | 6-10 | 15+ |
| Trainers | 0 | 1 (basic) | 2-3 | 4-6 | All types |
| Guild Representatives | 0 | 0 | 1-2 | 3-5 | All guilds |
| Faction NPCs | 0 | 0-1 | 1-2 | 3-5 | 5+ per faction |
| Beggars/Street Folk | 0 | 0 | 1-3 | 5-10 | 15+ |
| Nobles/Officials | 0 | 0 | 0-1 | 2-5 | 10+ |
| Criers/Heralds | 0 | 0 | 1 | 2 | 4+ |
| Children | 0 | 2-4 | 5-10 | 15-30 | 50+ |

### Trainer Availability

| Trainer Type | Hamlet | Village | Town | City | Capital |
|--------------|:------:|:-------:|:----:|:----:|:-------:|
| Combat Basics | - | YES | YES | YES | YES |
| Advanced Combat | - | - | - | YES | YES |
| Magic Fundamentals | - | - | YES | YES | YES |
| Advanced Magic | - | - | - | - | YES |
| Stealth/Thievery | - | - | Hidden | YES | YES |
| Crafting | - | - | YES | YES | YES |
| Master Trainers | - | - | - | - | YES |

---

## 4. Landmark Progression

Each tier features a signature landmark that defines the settlement's center and character.

| Tier | Landmark | Description | Gameplay Function |
|------|----------|-------------|-------------------|
| **Hamlet** | Well or Signpost | Simple wooden well or weathered signpost | Gathering point, direction indicator |
| **Village** | Town Square | Open gathering area, possibly with a tree | Community events, announcements |
| **Town** | Fountain or Market Plaza | Stone fountain or dedicated market space | Trading hub, social center |
| **City** | Statue or Monument | Commemorative statue of hero/founder | Lore delivery, meeting point |
| **Capital** | Grand Monument/Palace View | Impressive central monument or palace facade | Political center, major quest hub |

### Additional Landmark Features by Tier

**Hamlet:**
- Campfire ring
- Notice board (bounties, rumors)

**Village:**
- Community garden
- Village elder's home (distinct from others)
- Small graveyard

**Town:**
- Town hall
- Gallows/stocks (justice)
- Merchant stalls (temporary)
- Clock tower or bell tower

**City:**
- Multiple plazas
- Public baths
- Theaters/entertainment
- Monuments to historical events
- District-defining landmarks

**Capital:**
- Royal palace/seat of power
- Grand cathedral
- Triumphal arches
- Colosseum/grand arena
- Academy/university
- Treasury
- Hall of records

---

## 5. Danger Levels

| Danger Type | Hamlet | Village | Town | City | Capital |
|-------------|:------:|:-------:|:----:|:----:|:-------:|
| **Safe Zone** | YES | Day only | Central only | Central only | Palace district |
| **Ambient Hostiles** | NO | Night only | Back alleys | Slums, sewers | Sewers, outskirts |
| **Faction Enemies** | NO | NO | Rare | Common | Very common |
| **Guard Response** | N/A | Slow | Moderate | Fast | Immediate |
| **Guard Strength** | N/A | Weak | Moderate | Strong | Elite |

### Hostile Types by Location

| Location | Possible Hostiles |
|----------|-------------------|
| Back alleys (Town+) | Muggers, pickpockets, drunk brawlers |
| Slums (City+) | Gang members, desperate thieves, cultists |
| Sewers (City+) | Rats, slimes, undead, cult hideouts |
| Docks (if coastal) | Pirates, smugglers, press gangs |
| Outskirts | Bandits, deserters, wild animals |

### Safe Zone Rules

**Guaranteed Safe:**
- Hamlet (entire settlement)
- Inn interiors (all tiers)
- Temple interiors
- Fast Travel Shrine immediate area

**Conditional Safety:**
- Village: Safe during day, possible wolf attacks at night
- Town: Central square safe, avoid alleys after dark
- City: Main streets patrolled, slums and sewers dangerous
- Capital: Palace district heavily guarded, lower districts vary

### Guard Response Table

| Tier | Response Time | Guard Count | Guard Level |
|------|---------------|-------------|-------------|
| Village | 30-60 sec | 1-2 | Level 3-5 |
| Town | 15-30 sec | 2-4 | Level 5-8 |
| City | 5-15 sec | 4-8 | Level 8-12 |
| Capital | Immediate | 6-12 | Level 12-20 |

---

## 6. Building Dimensions Guide

All dimensions in grid units (1 unit = 1 meter equivalent).

### Small Building (Single Room)
- **Footprint:** 4x4 to 6x6
- **Height:** 3-4 units
- **Interior:** Single room, 1 door
- **Use:** Residential hovels, guard posts, shrines
- **Furniture:** 2-4 items

```
+------+
|      |
|  []  |  4x4 Small
|   D  |
+------+
```

### Medium Building (Shop with Back Room)
- **Footprint:** 6x8 to 8x10
- **Height:** 4-5 units
- **Interior:** Main room + back room or upstairs
- **Use:** Shops, small inns, homes
- **Furniture:** 6-10 items

```
+----------+
| Back     |
|   []     |
+----  ----+
| Shop     |
|  []  []  |  6x8 Medium
|    D     |
+----------+
```

### Large Building (Multi-Story/Multi-Room)
- **Footprint:** 10x12 to 15x15
- **Height:** 6-10 units (2-3 floors)
- **Interior:** Multiple rooms per floor
- **Use:** Guild halls, large inns, manor houses
- **Furniture:** 15-30 items

```
+----------------+
| Room  | Room   |
|  []   |   []   |
+----   +   -----+
| Hall           |
|   []     []    |  10x12 Large
|      D         |
+----------------+
```

### Inn Sizes by Tier

| Tier | Inn Size | Rooms | Common Area | Staff |
|------|----------|-------|-------------|-------|
| Hamlet | Small (6x6) | 1 shared | Combined | 1 |
| Village | Medium (8x10) | 2-3 | Separate | 2-3 |
| Town | Large (12x12) | 4-6 | Large tavern | 4-6 |
| City | Very Large (15x15) | 8-12 | Grand hall | 8-12 |
| Capital | Mansion (20x20+) | 15-20 | Multiple halls | 15+ |

### Special Building Dimensions

| Building | Minimum Size | Recommended | Notes |
|----------|--------------|-------------|-------|
| Fast Travel Shrine | 3x3 | 4x4 | Open area around shrine |
| Temple | 10x15 | 15x20 | High ceilings (8+ units) |
| Guild Hall | 12x12 | 15x15 | Training area needed |
| Blacksmith | 8x8 | 10x10 | Forge area + shop |
| Stables | 8x12 | 12x15 | Multiple stalls |
| Arena | 30x30 | 50x50 | Seating + fighting pit |
| Palace | 40x60 | 60x80 | Multiple wings |

---

## 7. Quick Generation Checklist

### Hamlet Checklist
```
[ ] Fast Travel Shrine placed
[ ] Inn building (small, 6x6)
    [ ] Door against box building
    [ ] Innkeeper NPC inside
[ ] Landmark: Well or Signpost
[ ] 2-4 residential buildings
[ ] 1 General Store (if any commerce)
[ ] Notice board
[ ] Zone ID assigned: hamlet_[name]
[ ] Safe zone - no hostile spawns
```

### Village Checklist
```
[ ] Fast Travel Shrine placed
[ ] Inn building (medium, 8x10)
    [ ] Door against box building
    [ ] Innkeeper NPC inside
[ ] Town Storage chest (ID: town_storage_main)
[ ] Landmark: Town Square / Gathering Area
[ ] 8-15 residential buildings
[ ] Partial walls/palisade
[ ] 1 Guard post, 1-2 guards
[ ] Merchants:
    [ ] General Store
    [ ] Blacksmith
[ ] NPCs:
    [ ] 1-2 Quest Givers
    [ ] 1 Basic Trainer
    [ ] 2-4 ambient villagers
[ ] Small shrine or graveyard
[ ] Zone ID assigned: village_[name]
[ ] Night-only danger spawns (wolves, etc.)
```

### Town Checklist
```
[ ] Fast Travel Shrine placed
[ ] Inn building (large, 12x12)
    [ ] Door against box building
    [ ] Innkeeper NPC inside
[ ] Town Storage chest (ID: town_storage_main)
[ ] Landmark: Fountain or Market Plaza
[ ] 20-40 residential buildings
[ ] Complete walls with gates
[ ] 2-3 Guard posts, 4-8 guards
[ ] Merchants:
    [ ] General Store
    [ ] Blacksmith
    [ ] Armorer
    [ ] Alchemist
    [ ] Hidden Black Market access
[ ] NPCs:
    [ ] 3-5 Quest Givers
    [ ] 2-3 Trainers
    [ ] 1-2 Guild Representatives
    [ ] 1-2 Faction NPCs
    [ ] Town crier
[ ] Temple building
[ ] Stables
[ ] Town Hall
[ ] 1 Guild Hall
[ ] Zone ID assigned: town_[name]
[ ] Back alley danger zones marked
[ ] Guard patrol routes set
```

### City Checklist
```
[ ] Fast Travel Shrine placed (possibly multiple)
[ ] Multiple Inns (2-4)
    [ ] Each with door against box building
    [ ] Innkeeper NPC in each
[ ] Town Storage chest (ID: town_storage_main)
[ ] Landmark: Statue or Monument (central)
[ ] 50-100 residential buildings
[ ] Stone walls with multiple gates
[ ] 4-6 Guard posts, 15-30 guards
[ ] Barracks
[ ] Merchants:
    [ ] General Store (x2)
    [ ] Blacksmith (x2)
    [ ] Armorer
    [ ] Alchemist
    [ ] Jeweler
    [ ] Enchanter
    [ ] Black Market
    [ ] Fence
[ ] NPCs:
    [ ] 6-10 Quest Givers
    [ ] 4-6 Trainers (including advanced)
    [ ] 3-5 Guild Representatives
    [ ] 3-5 Faction NPCs per major faction
    [ ] Beggars, street performers
    [ ] Nobles
[ ] Cathedral/Large Temple
[ ] 2-3 Guild Halls
[ ] Sewer entrance (danger zone)
[ ] District system:
    [ ] Market district
    [ ] Residential district
    [ ] Slums (danger zone)
    [ ] Noble quarter
[ ] Zone ID assigned: city_[name]
[ ] Multiple danger zones marked
[ ] Guard patrol routes (frequent)
```

### Capital Checklist
```
[ ] Fast Travel Shrine placed (multiple locations)
[ ] Multiple Inns (4+, various qualities)
    [ ] Each with door against box building
    [ ] Innkeeper NPC in each
[ ] Town Storage chest (ID: town_storage_main)
[ ] Grand Landmark: Monument or Palace
[ ] 150+ residential buildings
[ ] Fortified walls, impressive gates
[ ] 8+ Guard posts, 50+ guards (elite)
[ ] Large Barracks
[ ] Merchants (ALL types):
    [ ] General Store (x3)
    [ ] Blacksmith (x3)
    [ ] Armorer (x2)
    [ ] Alchemist (x2)
    [ ] Jeweler
    [ ] Enchanter
    [ ] Exotic/Rare Dealer
    [ ] Black Market
    [ ] Master Craftsmen
    [ ] Artifact Dealer
    [ ] Faction Quartermasters
[ ] NPCs (ALL types):
    [ ] 15+ Quest Givers
    [ ] All Trainer types (including Masters)
    [ ] All Guild Representatives
    [ ] 5+ NPCs per major faction
    [ ] Nobles, officials, royalty
    [ ] Street life (beggars, performers, etc.)
[ ] Grand Cathedral
[ ] All Guild Halls
[ ] Palace/Seat of Power
[ ] Arena/Colosseum
[ ] Academy/University
[ ] Extensive Sewer system
[ ] Full District system:
    [ ] Palace district (safe)
    [ ] Noble quarter
    [ ] Market district
    [ ] Artisan district
    [ ] Temple district
    [ ] Slums (dangerous)
    [ ] Docks (if coastal)
[ ] Zone ID assigned: capital_[name]
[ ] Complex danger zone mapping
[ ] Elite guard patrol routes
[ ] Political intrigue hooks
```

---

## Zone ID Naming Convention

Format: `[tier]_[name]` or `[tier]_[region]_[name]`

Examples:
- `hamlet_crossroads`
- `village_millbrook`
- `town_riverside`
- `town_eastmarch_garrison`
- `city_ironhold`
- `capital_throneheim`

For sub-areas within settlements:
- `city_ironhold_slums`
- `city_ironhold_sewer_01`
- `capital_throneheim_palace`
- `capital_throneheim_arena`

---

## Additional Notes

### Inn Door Placement Rule
The inn door MUST be placed against a "box building" style structure. This means:
- Rectangular footprint
- Flat front facade
- Door at ground level, centered or offset
- No recessed entries or complex geometry

### Storage Persistence
All Town Storage chests use the ID `town_storage_main`. This means:
- Items stored in Village A appear in City B
- Storage is player-specific (each player has their own)
- Provides convenient item management across the world
- Consider this when balancing inventory/carry limits

### Faction Considerations
When placing faction NPCs, consider:
- Enemy factions may coexist in larger settlements
- Faction areas may be off-limits without reputation
- Some merchants only sell to allied faction members
- Faction conflicts can create dynamic events

### PS1 Aesthetic Reminders
When building settlements, maintain the visual style:
- Low-poly building geometry
- Limited texture variety (reuse textures)
- Visible vertex wobble at distance
- Fog to limit draw distance
- Dithered shadows
- Limited NPC animation frames
