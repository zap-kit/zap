# Combat: what the executable computes that the records do not say

Read from `SkyrimSE.exe` 1.7.104 with REA. The behavior tree's weights and nodes are already in
`game/combat/chances.zap` and NOTES.md (addresses 0x1408f1xxx..0x1408f3xxx); here what was still by
hand: the stagger, the confidence modifier, and the method that finds a setting's readers.

## Finding a setting's readers

A `SettingT` object is 24 bytes: vtable, value, name pointer (`settings.md`). The code reads the
value at `object + 8`, so REA's `xrefs` on that address lists the readers (an `xrefs` on the
object itself only gives its static initializer). Checked on fCombatAttackChanceMin: `xrefs
0x1420a1738` gives 0x1408f2742, inside the Attack node 0x1408f2720 chances.zap names.

## The stagger magnitude (0x1407f0690)

`staggerOf(attacker, target, weapon, given)`: `attacker`/`target` are actors (their
`ActorValueOwner` is at `actor + 0xb8`, slot 1 reads an actor value: 9 Block, 0x24 Mass, 0x57
WardPower), `weapon` the attacking `TESObjectWEAP` (0 for an unarmed or spell hit), `given` a
magnitude passed in (0 to compute one). The settings are the game settings (`gmst-floats-m-z.md`
has their defaults).

1. The base:
   - when the attacker is an actor that is blocking (0x1406cba10): 0x14041f230, the block
     stagger:
     `((Block * fStaggerAttackMult + fStaggerAttackBase) / (targetMass * fStaggerMassMult + fStaggerMassBase)) * state * weaponMult * shieldFactor`,
     with Block the attacker's Block skill and targetMass the target's Mass actor value; `state`
     is 1, or fStaggerRecoilingMult when the target's flags `+0xcc & 0xc00` (recoiling), times
     fStaggerRunningMult when the target runs (0x1406742a0), times fStaggerBlockingMult when the
     target blocks (0x1406aef60); `weaponMult` is fStaggerShieldMult when the attacker holds a
     shield (0x1406ca230), else fStagger2WeapMult for a two-handed weapon type (weapon `+0x19d`
     in 5..7, or 9), else fStagger1WeapMult, else 1 with nothing equipped; `shieldFactor` is the
     current attack's `BGSAttackData` `+0x34` (0x1406ca270 gives the attack data; its `Data` at
     `+0x18` has `staggerOffset` at `+0x1c`: the race's ATKD stagger of the attack, 0.5 for the
     Nord's bashStart). Floor fStaggerMin.
   - else 0x14041f5e0, the hit stagger: `targetMass` as above, times fStaggerPlayerMassMult when
     the target is the player (`DAT_1431df300`); `base = 1 / (targetMass * fStaggerMassMult +
     fStaggerMassBase)` (1 when that is under 0.0001), times `given` when given, else times the
     weapon's `+0x188` (the WEAP DNAM's stagger value, 1 without a weapon) times the attack's
     ATKD stagger (0x1406ca270's `+0x34`, as above: the Nord's 0 for attackStart, 1 for
     attackPowerStartForward, 0.5 for the fists' power attack); plus the attacker's WardPower
     (actor value 0x57) when the weapon type `+0x19d` is 7 or 9 (a staff or a bow... the two
     values with `(type - 7) & 0xfd == 0`); minus `max(0, (targetMass - fStaggerMassOffsetBase) *
     fStaggerMassOffsetMult)`.
2. When the base is positive, no magnitude was given, the target is a blocking actor
   (0x1406aef60) with a block timer `+0xe8 >= 0`: the target's shield (0x1406ca230) gives
   `shieldRating = shield->+0x200 * 0.01` (the ARMO's armor rating field), else with no shield
   and the target's `+0xcc & 0xe0 > 0x5f` (weapon drawn) the equipped weapon's block rating
   through 0x14028c140 (0x140720660 reads the right hand); then
   `blockTerm = fStaggerBlockAttackShieldMult * shieldRating + fStaggerBlockAttackShieldBase +
   fStaggerBlockMult * Block + fStaggerBlockBase + max(0, (Mass - fStaggerMassOffsetBase) *
   fStaggerMassOffsetMult)` (0x14041f560, with the target's Block skill and Mass) and
   `result = max(fStaggerMin, base - blockTerm)`.

With the defaults (fStaggerMassBase 0, fStaggerMassMult 1, offset base 3 and mult 0.15, block
base 0.5 and mult 0.005, shield base 1 and mult -0.005): an unblocked power attack on a mass-1 NPC
staggers by the weapon's stagger value, a plain attack not at all (the Nord's ATKD stagger is 0),
less 0 for a mass under 3; a block takes off at least 1.5. Ported: `game/combat/damage.zap`'s
`hitStagger`, `bashStagger` and `blockedStagger`, the race's ATKD read by `records.zap`.

## The confidence modifier

0x140855990 is the constructor of the per-actor combat state object (0x2f dwords; `+0x00` 100.0,
`+0x04` 0x10000, `+0x98` the owner): it draws once `[0x1c] = random(fCombatConfidenceModifierMin,
fCombatConfidenceModifierMax)` (-0.5..0.5) and `[0xe] = random(fCombatDialogueTauntMinElapsedTime,
fCombatDialogueTauntMaxElapsedTime)` (3..10 s, the next taunt), `[0xd] = [0x2d] = DAT_14324430c`
(the game's clock), `[0x2e] = 0.1`. 0x1401d6e40(min, max) is the random-in-range used across the
combat code. The modifier is added to the actor's confidence when the flight decision is made;
the decision itself (the node reading `+0x1c`) was not followed.

## CombatTargetSelector (vtable 0x141955910)

Seven slots: 0x140862b70 (destructor), 0x140eebf20, 0x140861f40 (the class name), 0x140861db0
and 0x140861e80 (save and load), 0x140861da0, 0x1415a97c8. CombatTargetSelectorStandard
(constructor 0x140861fc0) picks in 0x140862040: when its target is no longer valid, or
`clock - lastCheck > wait`, it runs 0x1408622e0 and sets `wait` to fCombatSelectTargetUpdateTime
(1.0) when the pick is unchanged, fCombatSelectTargetSwitchUpdateTime (3.0) when it changed.
0x1408622e0 walks the combat group's targets (valid by 0x1408629a0) and keeps the highest score,
from -FLT_MAX; with one target the score is 0, else the sum of (static floats 0x1420b9d90..dc0):

- the combat memory of the pair (0x1406a22d0) when its time `+0x38` is within 2.0 s: 1000 when its
  flag `+0x15` is set, else 1000 when the target is the current one and `+0x18` is within 2.0 s;
  plus 100 when its flag `+0x14` is set;
- 100 when it is the current target;
- 100 when both are melee or both not (0x140868df0: no weapon, or a WEAP of animation type < 7);
- `(1 - min(distance, 2048) / 2048) x 1000`, the distance 2048 in another worldspace (0 for the
  current target);
- 0x143254ba8 (BSS, written by no code: 0) when the target's attacker count exceeds one;
- 2000 less when it is not detected (0x140563180) within fCombatRangedDistance 1024 or across
  worldspaces, 2500 less when unreachable across worldspaces;
- 500 less when its virtual 0x4c8 says so, 500 less when 0x140691aa0 (fleeing: its combat
  controller's state, or a flee package of type 0x16 or 0x0a).

Ported in `game/combat/select.zap`, the two flags read as "the target hurt the fighter" and "the
fighter hurt the target", detection as fSneakMaxDistance.

## The block share (0x14041f4d0) and the hit (0x1407f09d0)

`blockShare(rating, block, shieldPerks, armed, unarmed, power)`: the skill's factor is
`lerp(fArmorRatingBase, fArmorRatingMax, Block * 0.01)`; with a shield (neither flag set)
`(factor + shieldPerks) * rating * fShieldScalingFactor * 0.01 + fShieldBaseFactor`, `rating` the
shield's armor rating (ARMO `+0x200` x 0.01); with a weapon `factor * damage * fBlockWeaponScaling
* 0.01 + fBlockWeaponBase`, `damage` the attacking weapon's (its `+0xc0` slot 0x20); times
fBlockPowerAttackMult against a power attack. The hit (0x1407f09d0) then runs the perk entry point
0x27 over it, caps it at `fPlayerMaxResistance * 0.01` and multiplies the damage by `1 - share`;
fBlockMax is read by no code. The same function takes the armor off before: `rating *
fArmorScalingFactor * 0.01` plus the actor's slot 0x738 (the pieces' base factor), the perk entry
0x25, capped at `fMaxArmorRating * 0.01`, the damage times `1 - that`. The plugin's GMSTs overwrite
these static settings' values at load (fShieldBaseFactor 0.45, fMaxArmorRating 80...). Ported in
`game/combat/damage.zap`.

## The barter factor (0x140420be0)

Called by the barter menu's show (0x140900580) with the player's Speechcraft (actor value 0x11):
`buy = max(lerp(fBarterMax, fBarterMin, Speech * 0.01), fBarterBuyMin)`, `sell = min(1 / buy,
fBarterSellMax)`; the menu then applies the perk entry points 8 and 0x3c and clamps buy at least
fMinBuyMult and sell at most fMaxSellMult before `SetBarterMultipliers(buy, sell)`. Ported in
`game/sim/economy.zap`.

## Flight (0x140856ce0)

The combat state (0x140855990's object) keeps the actor's Confidence actor value (index 1: 0
Cowardly .. 4 Foolhardy) at `+0x6d`, the modifier drawn at its start (fCombatConfidenceModifierMin
.. Max) at `+0x70`, its own damage a second at `+0x78` and threat at `+0x74` (0x140856ac0), and at
`+0` the threat ratio (0x140856b90, 100 by default): its combat group's threat (0x14081f830, the
members' `+0x74`) over the group's targets' threat (`+0xd0`, summed by 0x14081f4d0). 0x140856ce0
decides: true (flee) when the actor is in bleedout (its virtual 0x2f0, or life state bits), else
when `threshold(level + modifier) > ratio` (the modifier skipped at levels 0 and 4), where
0x1401dea40 reads the table at 0x1420781e8 (fConfidenceCowardly, Cautious, Average, Brave,
Foolhardy) between whole levels, the level clamped to 0..4. "Boost Confidence" (0x140856a80) raises
the level by one when it is under 4 and its threshold under 100. A threat (0x1406c9130) is
`dps / (1 - min(0.99, fArmorScalingFactor x DamageResist x 0.01 + the actor's base armor factor))
x Health`; the damage a second (0x1406cc570) the equipped items' 0x14086b020: a weapon's damage
(0x14041e9b0) x its speed (`+0x170`) x fCombatDPSMeleeSpeedMult (fCombatDPSBowSpeedMult for a bow
or crossbow), the unarmed "weapon" without one. fAIFlee* and the fConfidence* settings' own names
are read by no code: the table is reached through 0x1420781e8. Ported in `game/combat/flee.zap`.
