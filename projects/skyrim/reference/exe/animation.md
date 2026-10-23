# Animation: the names the executable uses with the behavior graph

Read from `SkyrimSE.exe` 1.7.104 with REA. The graph itself (0_master.hkx and the behaviors) is
read by `skyrim/hkx/graph.zap`; what the executable adds is the set of node names, graph variables
and events it writes and listens to. They are one static table of BSFixedStrings
(`FixedStrings`, built by 0x140224be0, called from 27 places; one BSFixedString per 8 bytes), so
a port that keeps the graph's own names needs exactly these.

## The table (offset: name)

Node names: 0x00 "NPC Root [Root]", 0x08 "NPC", 0x10 "NPC Head [Head]", 0x18 "NPC Pelvis [Pelv]",
0x20 "NPC Spine [Spn0]", 0x28 "NPC Spine1 [Spn1]", 0x30 "NPC Spine2 [Spn2]", 0x38 "NPC L Foot
[Lft ]", 0x40 "NPC R Foot [Rft ]", 0x48 "NPC L Calf [LClf]", 0x50 "NPC R Calf [RClf]", 0x58
"SpecialIdle_Cast", 0x60 "SpecialIdle_AreaEffect", 0x68 "AttachSound", 0x70 "Sound Marker", 0x78
"Skinned Decal Node", 0x80 "Decal Node", 0x88 "ModelSwapNode", 0x90 "Open", 0x98 "Close", 0xa0
"DVPG", 0xa8 "Prn", 0xb0 "Weapon", 0xb8 "WeaponSword", 0xc0 "WeaponDagger", 0xc8 "WeaponAxe",
0xd0 "WeaponMace", 0xd8 "Shield", 0xe0 "WeaponBack", 0xe8 "WeaponBow", 0xf0 "Quiver", 0xf8
"EditorMarker", 0x100..0x110 "EditorMarker:0..2", 0x118 "ArrowQuiver", 0x120 "MarkerSource",
0x128 "MarkerTarget", 0x130 "AttachLight", 0x138 "skin", 0x140 "FaceGenEars", 0x148 "Unequip",
0x150 "LaserSight", 0x158 "AimSight", 0x160 "Decal", 0x168 "Permanent Decal", 0x170 "grabLeft",
0x178 "grabRight", 0x180 "Arrow:0", 0x188 "ArrowBone", 0x190 "BSFaceGenNiNodeSkinned", 0x198
"EntryPoint", 0x1a0 "NPC L UpperArm [LUar]", 0x1a8 "NPC L Forearm [LLar]", 0x1b0 "NPC R UpperArm
[RUar]", 0x1b8 "NPC LookNode [Look]", 0x1c0 "NPC Tail1", 0x1c8 "NPC TailHub", 0x1d0 "NPC Pelvis",
0x1d8 "Talking", 0x1e0 "Camera1st [Cam1]", 0x1e8 "Camera3rd [Cam3]", 0x1f0
"HeadMeshForExport_FaceGenAndMorphs:0", 0x1f8 "PinnedLimb", 0x200 "Backpack", 0x208
"ProjectileNode", 0x210 "BlastRadiusNode", 0x218 "TorchFire", 0x220 "##LightOn", 0x228 "NPC COM
[COM ]", 0x230 "SkinAttachment", 0x238 "NPC Neck [Neck]", 0x240 "##NifRound", 0x248 "Scb", 0x250
"UpperBody", 0x258 "##LightOff", 0x260 "NPC Head MagicNode [Hmag]", 0x268 "NPC L MagicNode
[LMag]", 0x270 "NPC R MagicNode [RMag]", 0x278 "MagicLeft", 0x280 "MagicRight", 0x288
"MagicOther", 0x290 "Camera Control", 0x298 "NPC Root [Root]", 0x2a0 "SaddleBone", 0x2a8
"PerchFireNode", 0x2b0 "GraphDeleting".

Graph variables (the game sets them; the behaviors read them): 0x2b8 IsBlocking, 0x2c0
IsShouting, 0x2c8 IsPlayer, 0x2d0 IsNPC, 0x2d8 iIsPlayer, 0x2e0 fScale, 0x2e8 FemaleOffset, 0x2f0
IsFirstPerson, 0x2f8 i1stPerson, 0x300 fIsFirstPerson, 0x308 bHumanoidFootIKEnable, 0x310
iSyncIdleLocomotion, 0x318 iSyncTurnState, 0x320 IsAttackReady, 0x328 bVoiceReady, 0x330
bMLh_Ready, 0x338 bMRh_Ready, 0x340 bEquipOk, 0x350 IsSprinting, 0x358 iSyncSprintState, 0x360
weapAdj, 0x368 weaponSpeedMult, 0x370 leftWeaponSpeedMult, 0x378 BowZoom, 0x380 bBowZoomed, 0x388
iLeftHandType, 0x390 iRightHandType, 0x398 iLeftHandEquipped, 0x3a0 iRightHandEquipped, 0x3a8
bLeftHand, 0x3b0 bRightHand, 0x3b8 fIdleTimer, 0x3c0 Injured, 0x3c8 Land, 0x3d0 bCrashLand, 0x3d8
LandTypeIndex, 0x3e0 ActorResponse, 0x3e8 PlayerCharacterResponse, 0x3f0 TailPitchCurrent, 0x3f8
TailPitchMax, 0x400 TailYawCurrent, 0x408 TailYawMax, 0x410 LookAtHeadingMaxAngle, 0x4a0
fCastStrength, 0x4a8 staggerMagnitude, 0x4b0 staggerDirection, 0x4b8 IsBusy, 0x4c0 Imod, 0x4c8
Rimod, 0x4d0 DistToGoal, 0x500 VelocityZ, 0x508 Speed, 0x510 TurnDelta, 0x518 Direction, 0x520
SpeedSampled, 0x528 HorseSpeedSampled, 0x530 LookAtOutOfRange, 0x538 AimHeadingMax, 0x540
AimPitchMax, 0x548 AimHeadingCurrent, 0x550 AimPitchCurrent, 0x558 iSyncForwardState, 0x560
iSyncStrafeState, 0x568 bAnimationDriven, 0x570 bAllowRotation, 0x578 bIsSynced, 0x580
bSpeedSynced, 0x588 bDisableInterp, 0x590 iGetUpType, 0x5a0 fFlameProjectileLength, 0x5b0
bAimActive, 0x5b8 TurnDynamic, 0x5c0 bForceIdleStop, 0x5c8 ConstraintOffset.

Events and annotations (the graph sends them, the game listens, or the game sends them): 0x348
HitFrame, 0x418 English, 0x420 Russian, 0x428 Polish (the lip-sync language variants), 0x430
MLh_SpellFire_Event, 0x438 MRh_SpellFire_Event, 0x440 Voice_SpellFire_Event, 0x448 arrowRelease,
0x450 EndAnim, 0x458 StopEffect, 0x460 TweenEntryDirection, 0x468 TweenPosition, 0x470
TweenRotation, 0x478 HasTweenSpeed, 0x480 TweenSpeed, 0x488 bTweenUpdate, 0x490 TargetLocation,
0x498 MovementDirection, 0x4d8 preHitFrame, 0x4e0 weaponSwing, 0x4e8 weaponLeftSwing, 0x4f0
AttackWinStart, 0x4f8 AttackWinEnd, 0x598 ObjectActivated, 0x5a8 PairedKillTarget, 0x5d0 Left,
0x5d8 PickUp, 0x5e0 PathTweenerStart, 0x5e8 PathTweenerEnd.

The strings' addresses (REA `search_strings`): IsBlocking 0x141803dc8 ... bAimActive 0x141804408,
Speed 0x14180427c, TurnDelta 0x141804288, Direction 0x141804298, SpeedSampled 0x1418042a8,
staggerMagnitude 0x1418041c8, staggerDirection 0x1418041e0, iState 0x141a06360 (the
BShkbAnimationGraph's own, not in this table), bWantCastLeft/Right 0x14191c1e8/f8, iWantBlock
0x14191c3e8, bHeadTracking 0x14191c3f8, bInJumpState 0x14191c5e8 (the Actor's own set).

## What this settles for the port

- `game/graph.zap` feeds `Speed`, `TurnDelta`, `Direction` and `SpeedSampled` (the Walker) and
  `iSyncIdleLocomotion`, `iSyncTurnState`, `iSyncForwardState`, `iSyncStrafeState`,
  `iSyncSprintState` (the sync points NOTES.md calls still by hand are these integer variables:
  the graph's blenders sync by state index, the game only sets the integers).
- The stagger goes into the graph as `staggerMagnitude` and `staggerDirection` (the formula in
  `combat.md`) before the `staggerStart` event.
- The spells' timing events are `MLh_SpellFire_Event`, `MRh_SpellFire_Event`,
  `Voice_SpellFire_Event`; the attacks' `preHitFrame`, `HitFrame`, `weaponSwing`,
  `weaponLeftSwing`, `AttackWinStart`, `AttackWinEnd`, `arrowRelease`.

## The graph's data channels

The per-frame variables are not written by one function: 0x1406b0650 registers on an actor's graph
a list of `BSTAnimationGraphDataChannel<Actor, float, X>` objects, each named by a `FixedStrings`
entry (the table's getter is 0x1401544f0, its static at 0x14219df30), polled every frame
(vtable slot 1) and written into the graph (slot 2, the graph's virtual +0x80 SetVariable):

- `ActorSpeedChannel` (`Speed`, vtable 0x14191c240, 0x1407c6a10): the movement controller's speed
  (0x1406af0d0) over the actor's scale (0x1402e6f30, 1 under 1.2e-7); crossing 5.0 upward queues
  the default object 0x61 (Action Move Start), downward 0x62 (Action Move Stop).
- `ActorTurnDeltaChannel` (`TurnDelta`, 0x14191c2e0, 0x1407c6be0): the rotation speed times
  -57.29578 (degrees, the sign flipped); |TurnDelta| rising past 1 degree queues 0x64 Action Turn
  Left when positive, 0x63 Action Turn Right when not; falling under it 0x65 Action Turn Stop.
- `ActorDirectionChannel` (`Direction`, 0x14191c2c0, 0x1407c6d60): the movement controller's wanted
  direction from the facing (0x1406af1b0) wrapped to 0..2 pi, times 1 / 2 pi; crossing 0.25 or 0.75
  queues 0x66 Action Move Forward or 0x67 Move Backward, crossing 0 or 0.5 0x69 Move Right or 0x68
  Move Left.
- Others registered there: `TargetSpeed`, `Pitch`, `Roll`, `PitchDelta`, the weapon speeds.

The queued ids index the default object table (0x14219d1a0, built by 0x14031b830; the names
"Action Move Start".. "Action Move Right" in that order) and 0x1406f31a0 runs each action, which
reaches the graph as an event through the IDLE records. Ported in `game/graph.zap`'s `stepWalker`.

## Not read

The `BShkbAnimationGraph` virtuals (vtable 0x141a07d78, 14 slots) and
`hkbBehaviorGraph`'s (0x1419c09f0, 28 slots), and the 0x14190f898-vtable class holding
`sBasePath` (the animation file manager's root).
