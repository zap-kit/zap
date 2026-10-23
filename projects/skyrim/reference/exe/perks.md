# Perks and their entry points

SkyrimSE.exe 1.7.104.0. Names are CommonLibSSE-NG's where they have one (`BGSPerk`,
`BGSPerkEntry`, `BGSEntryPoint`, `BGSEntryPointPerkEntry`, `BGSSkillPerkTreeNode`). Ported in
`skyrim/esm/perk.zap` (the records), `game/sim/perks.zap` (what an actor holds and the entry
points), `game/sim/perktree.zap` (choosing in a constellation), `interface/statsmenu.zap`.

## The records

- `BGSPerk::Load` 0x140396cc0. PERK: EDID, FULL, DESC, the CTDAs before DATA (the conditions that
  say who may take it, +0x58), DATA (trait, minimum level, ranks, playable, hidden), NNAM the next
  perk of its chain (`BGSPerk+0x78`), then the entries. Each rank of a tree's perk is a record of
  its own, linked by NNAM (Armsman 00, 20, 40, 60, 80); an earlier rank stops applying through a
  `HasPerk(next) == 0` condition on its own entries, not by any replacement.
- An entry opens with PRKE (type 0 quest, 1 ability, 2 entry point; rank; priority) and closes with
  PRKF. Quest: DATA = quest form, stage. Ability: DATA = spell. Entry point: DATA = entry point,
  function, number of parameters (the owner counts); then for each parameter that has conditions a
  PRKC (its index) followed by its CTDAs; EPFT the type of the function's data (1 one value, 2 two
  values, 3 leveled list, 4 activate choice, 5 spell, 6 text) and EPFD the data.
- The entry points are the table at 0x1420994f0 (0x20 bytes each: name, parameter list, function
  type); the 92 are CommonLibSSE-NG's enum (`kModSkillUse` 0x16, `kModAttackDamage` 0x23...).
  The function kinds (the `DAT_14209a080` table, 0x18 each): 1 set 0x14038d2c0, 2 add 0x14038d330,
  3 multiply 0x14038d3a0, 4 add range 0x14038d410, 5 add actor value mult 0x14038d550, 6 absolute
  0x14038d8e0, 7 negative absolute 0x14038d950, 8 add leveled list 0x14038d9c0, 9 add activate
  choice 0x14038db70, 10 select spell 0x14038de50, 11 select text 0x14038dec0, 12 set to actor
  value mult 0x14038d630, 13 multiply actor value mult 0x14038d710, 14 multiply 1 + actor value
  mult 0x14038d7f0, 15 set text 0x14038e030. The numeric ones check the data's type (one value for
  1 to 3, two for 4, 5, 12 to 14); Skyrim.esm uses 1, 2, 3 and 14 for numbers (and 9, 10, 11, 15
  for the rest).

## Holding a perk

- `Actor::HasPerk` 0x14069f920 -> `ActorProcess::HasPerk` 0x1407280c0 gives the perk's rank (0 for
  none) from the actor's `BGSPerkRankArray` (`FindPerkInRanksVisitor`). Papyrus `Actor.AddPerk`
  0x140360010 (calls the actor's virtual +0x7d8 with rank 0), `RemovePerk` 0x140360130 (+0x7e0)
  and `HasPerk` 0x1403601d0 (-> 0x1403394e0). The player's own list is `PlayerCharacter+0x4d8`
  (0x14075bb70); the rank event (type 0x5f, `FUN_1406694c0`) is handled by 0x140397640: the
  entries whose rank + 1 is the new rank are applied (vtable +0x58), those whose rank + 1 is the old
  one removed (+0x50). Entry-point entries are inserted into the actor process's per-entry-point
  lists (0x5c lists of 0x18 bytes at `ActorProcess+8 -> +0x288`, 0x14069f950) sorted by
  0x140397600: priority (+9) higher first, then rank (+8) lower first. Quest entries
  (0x140395c00) set the stage; ability entries (0x140395f80) add the spell.
- The Rested spells are abilities whose magic effect (MGEF DATA +136, `EffectSetting` +0xd8) names a
  perk (RestedPerk 1.05, RestedWellPerk 1.1, RestedMarriagePerk); the port gives an actor the perks
  of the abilities it knows at rank 1. The place the exe adds that perk was not found (the
  active effect's start does not call the +0x7d8 virtual), so this is the effect of the data, not a
  port of the call.

## Asking the entry points

`BGSEntryPoint::HandleEntryPoint(entry, owner, args..., results...)` 0x14038cff0: the entry's
parameter count (table +0x8) counts the owner; then one pointer for each result of the function
type (`DAT_14209a1f0`: 1 for a number). The owner's list for the entry point is walked
(`Actor::ForEachPerkEntry` 0x14069f9c0) with `HandleEntryPointVisitor` 0x14038d170: an entry is
asked `EvaluateConditions` (0x1403960d0): it needs exactly its parameter count of forms; for each
parameter the entry's tab (the conditions of its PRKC) must hold for that form, a null form
meeting only an empty tab; then its function runs on the value with the owner as the actor whose
values the actor-value functions read (current value, `ActorValueOwner` +8).

Call sites ported (entry, owner, parameters, value):

| entry | site | owner | parameters | value |
|---|---|---|---|---|
| 0x16 skill use | 0x14078dcb0 | the player | - | the amount a use adds, after the use mult (also for the unscaled uses) |
| 0x1c power attack damage, 0 weapon damage, 0x23 attack damage | the hit's data 0x1407f0030..0x1407f17c0 | attacker | weapon, target | the hit's damage |
| 0x24 incoming damage | 0x1407f17c0 | target | attacker, weapon | the same |
| 0x12 sneak attack mult | 0x1407f17c0 | attacker | weapon, target | the multiplier, then the damage times it |
| 8 buy prices, 0x3c sell prices | the barter menu 0x140900580 | the player | merchant | the factors (buy at least 1, sell at most 1 after) |
| 0x38 pickpocket chance | 0x14041d860 | thief | victim, item | the chance after the detected penalty, before the limits |
| 0x26 spell cost | 0x140151780 area (`MagicItem::GetCost`) | caster | spell | the magicka cost |
| 0x1e duration, 0x1d magnitude | active effect start 0x1405baed0 | caster | spell, target | the effect's |
| 0x2a, 0x29 incoming duration and magnitude | same | target | spell | the same |

Not ported: the others (crit, armor and resistance 0x25, bashing 0x1a, detection 0x2f 0x30 0x39 0xf
whose pure formulas in `game/stealth` take no world, lockpicking, smithing, alchemy 0x42 at the
table, enchanting, leveled-list and spell entries, the quest-stage `Activate` choices).

## Choosing a perk in the stats menu

- The tree is the AVIF's nodes: PNAM the perk, FNAM, XNAM/YNAM grid place, HNAM/VNAM the place in
  the constellation, SNAM the skill, CNAM each child's index, INAM the node's index
  (`BGSSkillPerkTreeNode`, 0x140446920). Node 0 is the root (no perk).
- The confirmation callback `PerkSelectConfirmCallback` 0x140982480 (after "Are you sure you want
  this perk?") runs 0x1409790a0: it takes the node (menu+0x1c8 -> `0x1409812b0`), walks the chain of
  its perk by +0x78 counting what the player has (`Actor::HasPerk`), takes the first he has not,
  and when the conditions of that perk's record (+0x58, `FUN_1404a6e20`) hold for the player and he
  has not all of them: the player's virtual +0x7d8 (AddPerk, rank 1), the sound
  `UISkillsPerkSelect2D`, perk points -1 (0x14097e820: the byte at `PlayerCharacter+0xb11`), the
  card updated (0x14097a2e0), and `SetStatsMode(no points, points)` called on the movie.
  0x14097f8b0 is the same test without the effect (the key handler asks it before the box);
  0x14097e710 the points.
- The menu has no GameDelegate call for the choice: the 3D cursor and the box are the game's; the
  port's `chooseSkillPerk` is the confirmation. Not ported: the constellation scene, the cursor,
  `SetDescriptionCard` for a perk node.
