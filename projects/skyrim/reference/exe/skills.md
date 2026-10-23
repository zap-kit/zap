# Skills, levels and the stats menu

SkyrimSE.exe 1.7.104.0. Names are CommonLibSSE-NG's where they have one. `PlayerCharacter+0x9c0`
points to `PlayerSkills`, whose `Data` is: xp (+0x0), levelThreshold (+0x4), then for each of the
18 skills (actor values 6 to 23) a `SkillData` at 0x8 + 0xc k: the skill's level when the
character last rose (+0x8), its xp in the level (+0xc), its threshold (+0x10); the legendary count
of each at 0xe0 + 4 k. Settings below are `SettingT` addresses; the value is at +8.

## Experience of a skill

- `Actor::UseSkill(av, points, advanceObject, action)` is the virtual at +0x7b8 (slot 0xf7);
  `PlayerCharacter`'s (0x1407499e0) does nothing for points <= 0 and calls `AddSkillExperience`.
  The base `Actor`'s (0x1406990e0) is empty: NPCs gain nothing.
- `PlayerSkills::AddSkillExperience(av, points, object, action, scaled, quiet)` 0x14078dcb0: for a
  skill below 100 (the constant at 0x141b5bf14), `AVIF+0x108` is the AVSK (`useMult`, `useOffset`,
  `improveMult`, `improveOffset`, read by 0x1404454e0). `scaled` (UseSkill) makes the amount
  `points x useMult + useOffset`; the perk entry point 0x16 (Mod Skill Usage) then changes it
  (0x14038cff0; this is where the Rested bonus applies, through the perks of its ability). The
  amount is added to the skill's xp; while xp >= threshold: xp -= threshold, the skill's base
  value +1 (`ActorValueOwner::ModBaseActorValue`, slot 5), the new threshold is
  `pow(level, fSkillUseCurve 0x1420a8ca0) x improveMult + improveOffset` (0 from 100), the
  character's xp gains `floor((n+1) n / 2) - floor(n (n-1) / 2)` times `fXPPerSkillRank`
  (0x1420a8ce8), that is the new level n, and the SkillIncrease event is sent (0x14073af50).
  Unless quiet, the notice `sSkillIncreased` ("%s Increased to %i") is shown (0x1409364b0).
- `IncrementSkill` 0x140749a20 -> `PlayerSkills` 0x14078e0a0 (a skill book, a trainer): count 0 is 1;
  each level adds `threshold - xp` unscaled and quiet but for the last; the share of the level
  already earned (xp / threshold) is kept of the new one. The Papyrus natives are 0x14035d110
  (AdvancePCSkill) and 0x14035d1c0 (IncrementPCSkill). 0x14078e200 is the legendary reset (xp and
  threshold 0, the count +1).
- The thresholds at the start: 0x14078ea70 measures them from the skills' levels.

## Where the player's skills are used

All call the virtual at +0x7b8. Ported (game/combat/practice.zap, game/sim/skills.zap):

| site | skill | amount |
|---|---|---|
| 0x1406cd2f0 (the hit handler), attacker is the player, total damage > 0 | the hit's skill (HitData+0x88) | the weapon's base damage (`TESAttackDamageForm` slot 4), 0 without a weapon |
| same, bash flag (HitData flag 0x4000) | Block | `0x14041f410`: damage x (`fShieldBashSkillUseMult` 0x1420a7cf8 / `fWeaponBashSkillUseMult` 0x1420a7d28) + (`fShieldBashSkillUseBase` 0x1420a7ce0 5 / `fWeaponBashSkillUseBase` 0x1420a7d10 1) |
| same, the player is hit and the hit is blocked (flag 1) | Block | (physical - total damage) x `fWeaponBlockSkillUseMult` (0x1420a7e00) + `fWeaponBlockSkillUseBase` (0x1420a7de8) |
| same, not blocked | Heavy (11) or Light (12) Armor | the physical damage; each worn armor (rating > 0, not clothing) adds 2 to its skill for the body piece, else 1; a roll `rand % 6` under the light weight is light, under light plus heavy is heavy, else none |
| the magic effects' update and cast: 0x1405bd8f0, 0x1405bf8d0 (concentration, each update), 0x1405c39e0 (once, when the spell is let go), 0x1405c41b0 (cloaks), 0x1405c5890 | the effect's school | `SpellItem::GetSkillUsageData` 0x140155540: the costliest effect's cost (at most the spell's cost when not auto-calculated) x `EffectSetting+0x100` (skill usage); a concentration spell x dt |
| player update 0x140756950 | Sneak (15) | `0x140421800`: `fSkillUsageSneakPerSecond` (0x1420aa9f8) x dt while 0 != 100 - highest detection < `iSkillUsageSneakFullDetection` (100) |
| the stealth meter 0x14093a7e0 reaching 0 (`$HIDDEN`), 0x140756ab0 | Sneak | `fSkillUsageSneakHidden` (0x1420aaa10, 2.5) |
| pickpocket success 0x140759b90 | Pickpocket (13) | `0x140421ca0`: pow(value taken, `fPickpocketSkillUsesCurve` 0x1420aabc0) |
| barter, each stack bought or sold (`BarterMenu` 0x1409014e0) | Speech (17) | `GetSpeechcraftBarterExperience` 0x140228940: the item's (tempered) value rounded to 0.1 |

Not ported (call sites): Lockpicking (14) 0x14094f0c0 and 0x14094f6d0 (the amount by the lock's
level, `LockpickingMenu::GetSkillUsage` 0x1404215f0: `fSkillUsageLockPick*`), Smithing (10) the
crafting and tempering menus 0x14091fab0, 0x140920860, 0x140921de0, 0x1409225f0, 0x1409228d0
(`GetConstructedObjectSkillAdvanceAmount` 0x140421be0, tempering 0x140421960), Enchanting (23)
0x140944590, training (`TrainingMenu::SetSkillXpPercent` 0x140986030, `iSkillPointsTagSkillMult`),
the Papyrus `Game.AdvanceSkill` 0x140a23d20, and the other UseSkill callers 0x1406ca640 and
0x1406d8890 (not read).

## The character's level

- `PlayerSkills::CanLevelUp` 0x14078e250: xp >= threshold (`levelThreshold`).
- `UpdateLevel` handler 0x14035d240 (the console/script command): while the character can: step
  0x14078e270 (the sound `UILevelUp`, the level +1 in the player's base, the LevelIncrease event
  0x14073afe0) then `AdvanceLevel(0)`.
- `PlayerSkills::AdvanceLevel(addThreshold)` 0x14078e320: xp -= threshold (the old one; true adds
  nothing); the new threshold is `level x fXPLevelUpMult (0x1420a8cd0) + fXPLevelUpBase
  (0x1420a8cb8)` with the level already raised (Skyrim.esm: 25 and 75; the exe's 30 and 170); each
  skill's `level` is read again from the actor value owner (slot 2); the perk-granting arrays at
  `DAT_14219e570+0x90` are walked; health is raised by `fPCHealthLevelBonus` (0x1420a8f58,
  Skyrim.esm: 0); the damage modifier of health, magicka and stamina (0x18 to 0x1a) is taken off
  (0x1406c5440 reads it, 0x1406c47f0 undoes it): all three restored.
- The level-up menu (`LevelUpMenu`, levelupmenu.swf) registers `addHealth`, `addMagicka`,
  `addStamina` and `PlaySound` (0x14094aa80). The choice 0x14094ad60: `ModBaseActorValue(av,
  iAVDhmsLevelUp 0x14209ca98)` (10), for stamina also `ModActorValue(0, carryweight 0x20,
  fLevelUpCarryWeightMod 0x1420a8d00)` (Skyrim.esm 5), then `AdvanceLevel(0)`, the menu closed.
  The port raises the level in the same step as the choice (the exe's `UpdateLevel` step does it
  before the menu's `AdvanceLevel` reads the new level; the call that runs it for the menu was not
  found).
- It is offered when the character can rise and `0x1409924d0` (a global at form 0x148's value 1)
  does not block: the tween menu's open (0x140988710, `StartOpenMenuAnim(levelUp, date, level,
  progress)`) and waking from sleep (0x1407415a0). The HUD reminds "Level up available." every
  `iLevelUpReminder` (0x140936de0).
- Perk points are `PlayerCharacter+0xb11` (a byte); the stats menu spends one per perk
  (0x14097e820, which adds its argument when the menu is not in the Beast mode). The level is
  risen in the stats menu's message handler (0x140976a50): when the character can rise (0x14078e250) it
  calls UpdateLevel (0x14078e270), opens the level-up menu (0x14094ac40) and adds one perk point
  (0x14097e820 with 1); the port does the same.

## The stats menu

- `StatsMenu` (statsmenu.swf; vtable 0x141980128, constructor callbacks 0x140978020) is told:
  `UpdateSkillList` 0x140979790: `StatsMenu.SkillStatsA` (SetVariableArray) holds 5 values for
  each of the 18 skills (the order is the menu's array at `StatsMenu+0x50`, default Heavy Armor):
  the actor value's current value rounded down, its name (0x140442fd0), `xp / threshold x 100`
  (0x14078dc10), the colour (0x140992510: current less base less damage modifier below -0.001 red
  `#FF0000`, above 0.001 green `#189515`, else `#FFFFFF`) and the legendary count; then
  `UpdateSkillList(english)`.
- `SetPlayerInfo` 0x14097da30 (13 arguments): the player's name, level, `xp / threshold x 100`,
  the race's name, then for magicka, health and stamina the current value (rounded down, not below
  0), the maximum (current less the damage modifier) and the colour.
- `SetStatsMode(perkPoints == 0, perkPoints)` 0x14097a0d0; `ShowLegendaryButtonHint` when a
  skill is 100 (0x14097a2e0); `SetDescriptionCard` (8 values: the selected skill's description,
  value, the next rank's perk...) 0x14097a2e0; the camera `MoveCamera`/`SetFadedIn`; the sounds
  `UISkillsStop`, `UISkillsGlow`, `UISkillsPerkSelect2D`, `UISkillsTransitionUp`.
- The movie registers these with `GameDelegate.addCallBack` (`SetDescriptionCard`, `SetPlayerInfo`,
  `UpdateSkillList`, `HideRing`, `SetPerkCount`, `ShowLegendaryButtonHint`); the port calls them
  through `delegate`. The movie's own loading raises 8 script errors in the port's AVM1 (five
  `gotoAndStop` on a clip it does not find, three `SetText` calls before `InitExtensions` defines
  it, as in the game's order); the later calls raise none.
- The perk tree (`BGSSkillPerkTreeNode`, the 3D constellations `INTPerkStars01.nif`,
  `INTPerkLine01.nif`), choosing a perk (0x140978580: "Are you sure you want this perk?", then
  0x1409790a0) and the entry points are in `perks.md`; the constellations' 3D scene is not ported.
