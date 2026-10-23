# Stealth: sneaking, detection and pickpocketing

What SkyrimSE.exe 1.7.104.0 does, read from its decompilation (the functions at the addresses
below; `names.tsv` has the community names, the settings are in `gmst-*.md`). The port is
`game/stealth/` (the formulas; `hearing.zap` the events), `game/sim/stealth.zap` (the state), `game/combat/` (witnesses, sneak
attacks), `interface/` (the eye, the pickpocket menu); `stealthtests.zap` checks it.

## Sneaking

- The Sneak command (`SneakHandler::ProcessButton` 0x1407b3a80) toggles: it sends the graph the
  sneak start or stop event (`Actor::SetSneaking` 0x1406aee40 sets the graph variable `iIsInSneak`).
  `Actor::IsSneaking` 0x1403ccaa0 reads the actor state's 0x200 bit (and not 0x400).
- The sneaking player moves by the graph's sneak locomotion (`Sneak_Locomotion_Behavior`): the
  clips `sneakwalk_forward` (47.2 units a second in the behavior project's motion files) and
  `sneakrun_forward` (132.9) blended by `SpeedSampled`, the walk's and the run's at 82.5 and 350.9.
  The eye of a sneaking actor is 0.57 of its standing height (0x140685b30).

## The detection value (Actor::CalculateDetection 0x1406a33b0)

Per watcher and watched; the game keeps one `DetectionState` (0x1407c6510: level at +0x10, view
cone +0x14, line of sight +0x15) per pair and reads it again when it is older than
`fDetectionUpdateTimeMin` (1 s) and rejects it past `fDetectionUpdateTimeMax` (2 s): the table at
0x1420b8ab8 (min, max by kind; the player's kind 3 is 1 and 2), the refresh `0x1407c3eb0`, the job
`DoDetectionJob` 0x1407c5220 which stores the result with `0x1407c6600`. A watcher has detected the
watched while its level is above 0 (`Actor.IsDetectedBy` 0x140a00ef0, `RequestDetectionLevel`
0x1406a2520); a level never worked out is -1000.

1. Reach (0x14041cd30): `fSneakMaxDistance`, times `fSneakExteriorDistanceMult` outside, times
   `fSneakFlyingDistanceMult` when either flies; a watcher fighting another has
   `fDetectionCombatNonTargetDistanceMult` of it. Past it: -1000. Off the watcher's facing by more
   than `fDetectionLOSDistanceAngle` (60 degrees) the reach shrinks linearly to
   `fDetectionLOSDistanceMultInterior`/`Exterior` straight behind (0x1406a33b0).
2. Line of sight (`RequestLOS` 0x1406a2830, `CalculateLOSLocation` 0x1406a30c0): only inside half
   `fDetectionViewCone` (190 degrees) of the facing (the heading to the watched is 0x1406a32c0), a
   ray from the watcher's eye (its eye height, 0x140687450) to the watched's chest (half its
   height), head (0.85) or legs (0.15), each 0.57 of that sneaking; one reaching is a sight. The
   port takes the rays from the cell's physics (`game/seen.zap`).
3. The sum (0x14041cd90) = noise + light + skill + `fSneakBaseValue`:
   - noise = (`(int)fSneakActionMult` x the sound level of the watched's last action (Actor +0x11c,
     set by `0x14069fe50` from `0x14041d3f0`: Loud 100, Normal 50, Silent 0, Very Loud 200, for
     `fActorAlertSoundTimer` s) + (`fSneakRunningMult` when running) x (`fSneakEquippedWeightMult` x
     the weight it wears and holds (0x14023bd30) + `fSneakEquippedWeightBase`) x its Movement Noise
     Mult x moving) x `fSneakSoundsMult` x attenuation x (1 + `fSneakSleepBonus` if the watcher
     sleeps); `fSneakSoundLosMult` of it without a line of sight.
     Moving is speed >= 5 (0x1406aefa0); running is speed past the walk and the run blended by
     `fJogInterpolationBetweenWalkAndRun` (0x1406742a0).
   - attenuation = (1 - distance / reach)^`fSneakDistanceAttenuationExponent`, 0 past the reach.
   - light = (in the sight and not invisible) x attenuation x (1 + `fSneakLightRunMult` running +
     `fSneakLightMoveMult` moving) x (light level x `fSneakLightMult` (`...ExteriorMult` outside)
     + `fDetectionSneakLightMod`) x (100 - Blindness)/100 (0 asleep) x `fDetectionLargeActorSizeMult` x
     the race size's `fSneakDetectionSize*`.
   - light level = the watched's light level truncated (x `fDetectionNightEyeBonus` with the
     watcher's Night Eye), less the ambient (outside `iLightLevelExteriorMod`, inside the cell's
     ambient x 100 at most `iLightLevelInteriorMod`), kept between 0 and `iLightLevelMax`.
   - skill = (attenuation x (1 + `fSneakAlertMod` fighting + `fSneakSleepMod` asleep +
     `fSneakCombatMod` fighting another + the ambush package's `fSneakAmbushTargetMod`/`NonTarget`)
     x ((`fSneakPerceptionSkillMax` - `...Min`) x the watcher's Sneak / 100 + `...Min`) - the
     watched's Sneak while it sneaks) x `fSneakSkillMult`. The player's Sneak enters as
     `fPlayerDetectionSneakMult` x skill + `fPlayerDetectionSneakBase` (0x14041cd90 start).
   - The value is its truncation, 1 for one between 0 and 1; 0 counts as -1.
4. The light on an actor (`0x140726250`, stored in the process, 0x3a8, by `0x1406ff490`): the sum of
   the lights near it (`0x141576ca0`: dimmer x the color's mean x (1 - (distance / radius)^2)) plus the
   cell's ambient mean plus the directional mean times the shader manager's scale, times 100;
   recomputed every `fLightRecalcTimerPlayer` (0.5 s, `fLightRecalcTimer` 2 for the others).
5. A sound that is not the watched's own (a detection event, 0x14041d230): the same terms with the
   event's sound level in place of the action and the light level `iDetectEventLightLevelInterior`/
   `Exterior`; the event's reach is `fDetectEventSneakDistanceVeryLoud` for very loud sounds.

## Detection events (the second half of CalculateDetection 0x1406a33b0)

- The store: `SetActorsDetectionEvent` 0x1406f2560 writes, in the process (AIProcess +0x3d8) of the
  actor that made the noise, its sound level's value, the place, the game time and the causing
  reference; one for each actor, the next replacing it. `0x1406f26e0` drops it past
  `fDetectionEventExpireTime` (5 s); `0x1406f2540` reads it.
- The makers (the callers of 0x1406f2560): a spell effect applied (0x1405cdf50: the caster's place,
  `0x14041d3f0` of the effect's casting sound level, MGEF DATA at 140; the caster's perk entry
  0x37 may silence it; it also sets the caster's action level, 0x14069fe50), a summon (0x1405e3a50,
  Loud), an explosion (0x140261310, the EXPL's level, at the explosion), a projectile's impact
  (0x14031def0, the impact data's level), a papyrus `ObjectReference.CreateDetectionEvent`
  (0x140a451f0, the level as given). A blow makes none: a swing or a draw only sets the action
  level (0x1406cbee0: the weapon's, or the NPC's, sound level, for `fActorAlertSoundTimer`), which
  the first half's noise term reads. `0x14041d3f0` maps the record's level: 0 Loud (iSoundLevelLoud
  100), 1 Normal (50), 2 Silent (0), 3 Very Loud (200).
- The read, after a sight that left the level at -1000, -1 or 0: skipped when the watcher's faction
  reaction to the watched (0x14069ca50) is ally or friend (2, 3), and when neither it nor the
  watched holds a combat controller (Actor +0x158) and, for the player, `IsHostileToActor`
  (0x14068c9d0, the attack-on-sight rule 0x14068c170) is false. The event is then compared with
  `fDetectEventDistancePlayer` (1536; the NPCs' 512 for another watched), times
  `fDetectEventDistanceVeryLoudMult` (2) from `iSoundLevelVeryLoud`; a ray (0x1406a2e20) to its
  place, the cone test, and the sum of 0x14041d230: (`fSneakActionMult` x level x
  `fSneakSoundsMult` x (1 - distance / reach)^`fSneakDistanceAttenuationExponent`, x
  `fSneakSoundLosMult` without a line of sight; reach `fSneakMaxDistance`, `fDetectEventSneakDistance
  VeryLoud` for a very loud sound, times the exterior mult) + the light of the place
  (`iDetectEventLightLevelInterior`/`Exterior` x the light mult, x attenuation, in the cone, 0
  asleep) + `fSneakBaseValue`. Above 0 the reading is level 0 with the event's place
  (`DetectionState::Set` 0x1407c6600 keeps it at +0x3c). Else the watched's projectiles (the
  projectile manager's list, owner the watched) within `fDetectProjectileDistancePlayer` (1024;
  NPC 512) of the watcher's head are tried the same way as a Normal (50) sound.
- The cone test compares the angle to the sound in radians with half of `fDetectionViewCone` in
  degrees (the first half converts), so a sound whose point the eye reaches is always in the cone.
- A level of 0 is a noise heard and no one seen. `Actor::SendAssaultAlarm` 0x140682ed0 takes as
  witnesses the actors whose level against the criminal is above 0 (`RequestDetectionLevel`
  0x1406a2520); whatever else a heard place does (the AI packages) is not read here.
- Whether an actor attacks another on sight (0x14068c170) from the aggression value and the faction
  reaction (0 neutral, 1 enemy, 2 ally, 3 friend): unaggressive attacks no one; aggressive an enemy;
  very aggressive a neutral or an enemy (an ally or friend never); frenzied anyone.

## The eye (the stealth meter)

`PlayerCharacter` 0x140756950 runs each frame: the highest level any active actor holds against the
player (`ProcessLists` 0x140786350); above 0 the value is 100, else 0 (in combat the combat group's
stealth points, 0x140852450, are used); the HUD message (0x140935340) carries it and whether the
player sneaks (and is not in the 0x400 state). `StealthMeter::ProcessMessage` 0x14093a700 plays the
`StealthMeterInstance` timeline's `FadeIn`/`FadeOut` and sets the HUD mode `StealthMode`;
`Update` 0x14093a7e0 moves the shown value 30 percent of the way to it each frame and sets
`SneakAnimInstance`'s frame to its 1.01 times; arriving at 0 or 100 it writes `$HIDDEN` or
`$DETECTED` into `SneakTextInstance` and plays `SneakTextHolder` from `Start`.

## Sneak attacks

A sneak attack is a hit of a sneaking attacker on a target that has not detected it; the damage is
multiplied by the weapon type's `fCombatSneak*Mult`.

## Pickpocketing

- The activation text (0x1403c1000) reads "Pickpocket" for a living actor that is not a teammate,
  of a race with `kAllowPickpocket` (RACE DATA flags 0x800000), while the player sneaks. Detection
  does not decide it.
- `ContainerMenu` mode 2 (`DAT_1432560b8`): the victim's items less what it wears; the selected
  item's card gets `pickpocketChance` (0x140911310: one item of one that weighs something, the
  whole stack of one that weighs nothing; clamped 0..100); the menu sets `bNPCMode`.
- The chance (0x14041d860) = `fPickPocketTargetSkillMult` x the victim's Pickpocket +
  `...TargetSkillBase` + `fPickPocketActorSkillMult` x the player's Pickpocket + `...ActorSkillBase`
  + `fPickPocketAmountMult` x the gold value of the items + `...AmountBase` +
  `fPickPocketWeightMult` x their weight + `...WeightBase`, less `fPickPocketDetected` when the
  victim has detected the player, between `fPickPocketMinChance` and `fPickPocketMaxChance`,
  rounded half up.
- Taking (`PlayerCharacter::AttemptPickpocket` 0x140759b90) rolls 0..99 against the chance: at or
  above it the attempt fails: the victim's state is set to level 100 (0x1406a2580), a pickpocket
  crime is added (0x1406827e0; the bounty is the faction's CRVA pickpocket gold), the message "You've
  been caught pickpocketing." shows and the menu closes. Else the items move, stolen from the victim,
  the player's Pickpocket skill gaining experience by their value (`0x140421ca0`).
- Items cannot be put into the victim ("You cannot place items in a container while pickpocketing.").

## Not modelled

Perk entry points (0x39, 0x30, 0x2f, 0xf, 0x38 the pickpocket chance, 0x20, 0x45, 0x54); the skill
experience (Sneak: `fSkillUsageSneakHidden`, `fSkillUsageSneakPerSecond`; Pickpocket:
`fPickpocketSkillUsesCurve`); of the detection events the explosions', impacts' and summons'
makers and the projectiles in the air (the fights have none), the combat stealth points of the meter, the ambush
package's flag, the race size (all medium), a weapon's own sound level (all Loud, fists Normal),
`fSneakDetectionSizeLarge` actors, mounts, the flying states, and the shader manager's directional
scale (1).
