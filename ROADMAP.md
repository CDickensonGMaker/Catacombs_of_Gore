# Catacombs of Gore - Development Roadmap

## Current Sprint: Magic System Completion

### Completed (Feb 3, 2025)

#### Hotbar Assignment UI
- [x] Right-click context menu on inventory items, equipped items, and spells
- [x] "Assign to Hotbar [1-0]" menu with 10 slots
- [x] Styled to match dark gothic theme
- [x] Plays UI confirm sound on assignment

#### Spell Tooltip System
- [x] Floating tooltip on spell hover in Magic tab
- [x] Shows: name, school, level, description, effect, cost, requirements, special effects
- [x] Comparison indicators vs equipped spell (+/- values in green/red)
- [x] Requirements show green (met) or red (not met)

#### Magic Tab Restructure
- [x] Changed from Labels to ItemList for mouse tracking
- [x] Hover triggers floating tooltip
- [x] Right-click shows hotbar assignment menu
- [x] Shows "EQUIPPED SPELL" section

#### Mana System (Replaced Spell Slots)
- [x] Conversion: mana_cost = slot_cost × 10
- [x] SpellData: Added `mana_cost` field and `get_mana_cost()` helper
- [x] SpellCaster: Checks and consumes mana instead of spell slots
- [x] PlayerController: Mana check with feedback message
- [x] HUD: Hidden spell slot icons (mana bar already exists)
- [x] UI: All displays updated to show mana

#### Soul Drain Enhancements
- [x] Added `manasteal_percent` field to SpellData
- [x] Implemented mana restoration in CombatManager
- [x] Soul Drain: 50% lifesteal + 25% manasteal

#### Bug Fixes
- [x] Fixed SpellCaster not finding CharacterData (fallback to GameManager.player_data)
- [x] Fixed magic_missile target_type (was BEAM, now PROJECTILE)
- [x] Fixed soul_drain target_type (was PROJECTILE, now BEAM)
- [x] Fixed SpellCaster owner_entity null (auto-set to parent)
- [x] Fixed projectile spawn null checks
- [x] Fixed damage number 2D/3D position mismatch
- [x] Fixed BEAM raycast collision mask (was 4+8, now 4+64 for enemies+hurtbox)
- [x] Fixed BEAM raycast origin (now uses chest height when cast_origin is null)
- [x] Fixed AOE_SELF healing (now includes caster as target)
- [x] Added chain target logic for Lightning Bolt

### In Progress

#### Spell Type Implementation
- [x] PROJECTILE spells (Magic Missile) - WORKING
- [x] BEAM spells (Lightning Bolt, Soul Drain) - FIXED (needs testing)
- [x] AOE_SELF spells (Healing Light) - FIXED (needs testing)
- [ ] CONE spells - UNTESTED
- [ ] AOE_POINT spells - UNTESTED
- [ ] SINGLE_ENEMY spells - UNTESTED
- [ ] SELF spells - UNTESTED

### Backlog

#### Combat Polish
- [ ] Spell visual effects (particles, lights)
- [ ] Spell impact effects
- [ ] Spell audio (cast sounds, impact sounds)
- [ ] Spell cooldown display on hotbar
- [ ] Casting animation integration

#### UI Improvements
- [ ] Hotbar visual display showing assigned items/spells
- [ ] Cooldown indicators on hotbar
- [ ] Mana cost preview before casting
- [ ] Spell school icons

#### Balance & Tuning
- [ ] Review mana costs for all spells
- [ ] Mana regeneration rate tuning
- [ ] Spell damage scaling with Knowledge
- [ ] Spell requirement thresholds

---

## Future Sprints

### Sprint: Enemy AI & Combat
- Enemy spellcasters
- Dodge/block mechanics
- Stagger system
- Combat feedback improvements

### Sprint: Progression System
- Skill point allocation
- Spell learning from scrolls
- Spell trainers
- Level-up stat bonuses

### Sprint: World Building
- Zone transitions
- Save/load system
- NPC dialogue
- Quest system integration

---

## Known Issues

1. ~~**BEAM spells don't fire**~~ - FIXED: Collision mask and raycast origin corrected
2. ~~**AOE_SELF spells don't work**~~ - FIXED: Caster now included as target for healing
3. **Debug prints still in code** - Remove before release
4. **No visual effects** - Beam/AOE spells work but have no visual feedback yet

## Technical Debt

- Remove debug print statements from spell_caster.gd, player_controller.gd, inventory_manager.gd
- Consolidate spell type handling (some have debug prints, some don't)
- SpellCaster.owner_entity should be properly set in scene, not auto-detected
