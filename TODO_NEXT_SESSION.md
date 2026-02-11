# Next Session Action Plan - Fix Remaining Spell Types

## Goal
Get ALL spell types working like Magic Missile (PROJECTILE) does now.

---

## COMPLETED FIXES (Session Feb 3, 2025)

### Phase 1: Debug Visibility - DONE
- Added debug prints to `_cast_beam_spell()`, `_cast_aoe_spell()`, `_cast_self_spell()`
- All spell types now have console output for debugging

### Phase 2: BEAM Spells - FIXED
**Issues Found & Fixed:**
1. Raycast collision mask was wrong: `4 + 8` (enemies + player_hitbox)
   - Fixed to: `4 + 64` (enemies + enemy_hurtbox)
2. Raycast origin was at ground level when cast_origin was null
   - Fixed to: Use chest height offset `Vector3(0, 1.5, 0)`
3. Added chain target logic for Lightning Bolt
   - Uses `spell.chain_targets` and `spell.chain_range`

### Phase 3: AOE_SELF Spells - FIXED
**Issues Found & Fixed:**
1. `get_enemies_in_range()` doesn't return allies/self
   - Fixed: Now explicitly adds `owner_entity` to targets for healing spells

---

## TESTING CHECKLIST

| Spell | Type | Expected Result | Status |
|-------|------|-----------------|--------|
| Magic Missile | PROJECTILE | Blue ball flies, hits enemy, deals damage | WORKING |
| Lightning Bolt | BEAM | Instant hit, chains to nearby enemies | NEEDS TESTING |
| Soul Drain | BEAM | Beam hits, damages enemy, heals + restores mana | NEEDS TESTING |
| Healing Light | AOE_SELF | Heals self | NEEDS TESTING |

---

## Phase 5: Visual/Audio Polish (30 min)

Once all spells WORK, add feedback:

1. **Beam visual** - Line or particles from caster to target
2. **AOE visual** - Circle effect around caster
3. **Cast sounds** - Check if audio files exist, wire them up
4. **Impact sounds** - On hit effects

---

## Phase 6: Cleanup (15 min)

1. Remove debug print statements (or gate behind DEBUG flag)
2. Test full combat flow: equip spell → cast → damage → mana drain → regen
3. Verify no crashes or errors in console

---

## Quick Reference: Spell Target Types

```
SELF = 0         → Buff/heal caster only
SINGLE_ENEMY = 1 → Direct hit on one enemy
SINGLE_ALLY = 2  → Direct hit on one ally
AOE_POINT = 3    → AOE at aimed location
AOE_SELF = 4     → AOE centered on caster
CONE = 5         → Cone in front of caster
BEAM = 6         → Instant raycast line
PROJECTILE = 7   → Flying projectile (WORKING)
```

---

## Files Modified

| File | Changes Made |
|------|---------|
| `spell_caster.gd` | Added debug prints, fixed beam collision mask (4+64), fixed raycast origin, fixed AOE healing to include caster, added chain logic |

---

## Success Criteria

- [ ] Lightning Bolt fires beam, hits enemy, chains to others
- [ ] Soul Drain fires beam, damages, heals HP, restores mana
- [ ] Healing Light heals player when cast
- [ ] All 4 test spells work without crashes
- [ ] Mana is consumed for all spells
- [ ] No error messages in console

---

## Debug Output to Watch For

When testing, watch the console for these messages:

**BEAM Spells (Lightning Bolt, Soul Drain):**
```
[SpellCaster] _cast_beam_spell for: Lightning Bolt
[SpellCaster] Collision mask: 68
[SpellCaster] Raycast result: { ... }  ← Should have data, not {}
[SpellCaster] Hit collider: EnemyBase
[SpellCaster] Applying damage to: EnemyBase
[SpellCaster] Chaining to up to 3 more targets  ← Lightning Bolt only
```

**AOE_SELF Spells (Healing Light):**
```
[SpellCaster] _cast_aoe_spell for: Healing Light
[SpellCaster] is_healing: true
[SpellCaster] Healing spell - added caster as target
[SpellCaster] Targets found: 1
```

If raycast result is `{}` (empty), the beam isn't hitting anything - check player aim direction.
