# Eating, drinking and active effects in SkyrimSE.exe

Read in the decompilation (C:/tools/skyrim-decomp), addresses are the exe's. Ported in
`game/sim/consume.zap`; tests in `consumetests.zap`.

## Using an item

- `ActorEquipManager::EquipObject` 0x1406dc310 -> 0x1406de920 -> 0x1406b2570: a switch on the form
  type byte at +0x1a. Case 0x2e (AlchemyItem): refuse a quest item ("You can not eat quest items"),
  send the equip event, then `vfunc 0x308` (`AlchemyItem::IsPoison`): a poison opens the poison
  application (string ITMPoisonUse, 0x140749190); anything else calls `Actor::DrinkPotion` (Actor
  vtable slot 0x10F, offset 0x878) and, when it returns true, removes one of the item (slot 0x518).
- `Actor::DrinkPotion` 0x1406d5890 (the player's override 0x14075c250 calls it, then updates every
  gathered effect once more with 0 s): gets the actor's magic caster for casting source 3 (instant),
  casts the item on the actor (vfunc 0x2b0), and registers a created potion (0x14063f650).
- `AlchemyItem::IsFood` 0x1401468b0: food flag (0x2) set and not poison. IsPoison 0x140146940:
  flag 0x20000. IsMedicine 0x140146910: flag 0x10000. ENIT: cost override, flags, addiction,
  addiction chance, consumption sound (SNDR) at +16.

## ActiveEffect (0x90 bytes; CommonLibSSE-NG's layout)

- `ActiveEffect::Update` 0x1405bcde0: the first call runs `Start` (vtable 0xa0); then elapsed +=
  dt, but when duration > 0 and elapsed + dt > duration the dt is cut to what is left and elapsed
  = duration; then `Update` (vtable 0x20); the effect ends when the MGEF has the NoDuration flag
  (0x200) or duration <= elapsed, which runs `Finish` (0xa8).
- `ActiveEffect::GetMagnitude` 0x1405bb0a0 -> `GetTaperedMagnitude` 0x1404220e0 (magnitude, seconds
  left, taper duration, taper weight, taper curve): with fewer seconds left than the taper
  duration, magnitude x (left / duration)^curve x weight. MGEF DATA at 28, 52, 56. The taper is
  zero when the MGEF has NoMagnitude or NoDuration (0x600).
- `ActiveEffect::SetEffectiveness` 0x1405bada0: scales magnitude and duration by a power factor
  (1 for potions).

## ValueModifierEffect (archetype 0; Peak is 0x22 = 34)

- Constructor 0x1405e6dd0: the actor value is the MGEF's primary AV (+0xc4; out of 0..0xa4 becomes
  health); an MGEF with NoMagnitude (0x400) has magnitude 1.0.
- `Func1` 0x1405e7050 (OnAdd): the magnitude is negated when the MGEF is detrimental (flag 0x4)
  differs from the actor value's "inverted" bit (AV info +0x60 bit 9, none of those the model
  plays): harm lowers.
- `ShouldModifyOnStart` 0x1405e7170: true for a Recover MGEF (flag 0x2); otherwise when the effect's
  duration is 0 and the effect is not constant-like (0x1405e70e0: a concentration spell, a disease,
  an ability, or the enchanting flag).
- `ModifyOnStart` 0x1405e71d0: magnitude = GetMagnitude(); for the skills and attributes (AV 6..23,
  25..38, not health 24) a lowering (<= 0) is cut to what the value has; stores it as the effect's
  magnitude, then `ModifyActorValue` 0x1405e7630.
- `ShouldModifyOnUpdate` 0x1405e72f0: false for Recover; else true when the duration is not 0 or the
  effect is constant-like. `ModifyOnUpdate` 0x1405e7340 changes by GetMagnitude() x dt.
- `ShouldModifyOnFinish` 0x1405e7410: the Recover flag. `ModifyOnFinish` 0x1405e7430: for a positive
  value, first `FUN_1405e7ab0` (the cut of a lowering) and, for health when the current health is
  within 1 of the value, 1 more, given back as damage (type 2); then `ModifyActorValue` of the
  negated value.
- `ModifyActorValue` 0x1405e7630: Recover -> `FUN_1406c5220(actor, 1, av, value)` (the temporary
  modifier); otherwise a negative health change goes the hurt path (0x1406797c0), everything else
  `FUN_1406c5220(actor, 2, av, value)` (the damage modifier: kept <= 0, so a restore never goes
  above the maximum).
- Peak 0x1405d9ec0..0x1405da550: among the active effects of the same MGEF and actor value only the
  strongest is applied; the others are suspended (flag 0x400) and take over in turn.

## Not found

- The place that plays the item's consumption sound. `ActiveEffect::ApplySoundEffects` 0x1405bd510
  plays the MGEF's own sound slot 5 (a loop), not the ENIT sound.
