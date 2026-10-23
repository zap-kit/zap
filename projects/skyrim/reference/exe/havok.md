# Havok: the collision filter the executable builds

Read from `SkyrimSE.exe` 1.7.104 with REA. The world's solver settings and the deactivation
classes are already in `game/havokworld.zap` (hkpWorld's constructor); here the `bhkCollisionFilter`
(vtable 0x141a825f0), built by 0x14107c3e0 and filled by 0x14107cbd0 (724 lines of bit sets,
parsed by script from the pseudocode).

## The layout (`bhkCollisionFilter`, singleton `DAT_1421a3e00`)

| offset | what |
|---|---|
| +0x4c | the next collision group (starts at 10) |
| +0x50 | `bipedBitfields[32]`, one uint32 per biped part, bit j = the part collides with part j |
| +0xd0 | 64 uint32, nearly empty: [9] = 4, [11] = 2, [13] = 3 (not identified) |
| +0x1d0 | `layerBitfields[64]`, one uint64 per layer, bit j = the layer collides with layer j; all set first, then cleared pair by pair |
| +0x3d0.. | the layer names (47 BSFixedStrings from the table at 0x1420d1f80) and the biped part names (29, from 0x1420d2100) |

## The layers (COL_LAYER), in the table's order

0 UNIDENTIFIED, 1 STATIC, 2 ANIMSTATIC, 3 TRANSPARENT, 4 CLUTTER, 5 WEAPON, 6 PROJECTILE, 7 SPELL,
8 BIPED, 9 TREES, 10 PROPS, 11 WATER, 12 TRIGGER, 13 TERRAIN, 14 TRAP, 15 NONCOLLIDABLE,
16 CLOUDTRAP, 17 GROUND, 18 PORTAL, 19 DEBRIS SMALL, 20 DEBRIS LARGE, 21 ACOUSTIC SPACE,
22 ACTORZONE, 23 PROJECTILEZONE, 24 GASTRAP, 25 SHELLCASING, 26 TRANSPARENT SMALL,
27 INVISIBLE WALL, 28 TRANSPARENT SMALL ANIM, 29 WARD, 30 CHARCONTROLLER, 31 STAIRHELPER,
32 DEADBIP, 33 BIPED NO CC, 34 AVOIDBOX, 35 COLLISIONBOX, 36 CAMERASPHERE, 37 DOORDETECTION,
38 CONEPROJECTILE, 39 CAMERAPICK, 40 ITEMPICK, 41 LINEOFSIGHT, 42 PATHPICK, 43 CUSTOMPICK1,
44 CUSTOMPICK2, 45 SPELLEXPLOSION, 46 DROPPINGPICK.

A body's layer is the low 7 bits of its `bhkRigidBody` collision filter info (the NIF's
`bhkCollisionObject` layer), the collision group the high 16 bits (`+0x4c` hands them out).

## The layer matrix: who does not collide with whom

Every pair collides unless listed (the matrix is symmetric; each line names the layers the layer
does not touch).

| layer | does not collide with |
|---|---|
| UNIDENTIFIED | CHARCONTROLLER |
| STATIC, ANIMSTATIC, CLUTTER, TREES, PROPS, TERRAIN, TRAP, GROUND, CUSTOMPICK1, CUSTOMPICK2, SPELLEXPLOSION | PORTAL, ACOUSTIC SPACE |
| TRANSPARENT, SPELL, TRIGGER, TRANSPARENT SMALL, TRANSPARENT SMALL ANIM, AVOIDBOX, CAMERAPICK, PATHPICK | PORTAL, DEBRIS SMALL, ACOUSTIC SPACE |
| WEAPON | BIPED, PORTAL, ACOUSTIC SPACE |
| PROJECTILE | BIPED, PORTAL, DEBRIS SMALL, ACOUSTIC SPACE |
| BIPED | WEAPON, PROJECTILE, PORTAL, DEBRIS SMALL, DEBRIS LARGE, ACOUSTIC SPACE, CHARCONTROLLER, DEADBIP |
| WATER, NONCOLLIDABLE, CLOUDTRAP | PORTAL, DEBRIS SMALL, DEBRIS LARGE, ACOUSTIC SPACE |
| PORTAL | every layer but ACTORZONE, PROJECTILEZONE, GASTRAP, SHELLCASING, INVISIBLE WALL, WARD, STAIRHELPER, BIPED NO CC, COLLISIONBOX, CAMERASPHERE, DOORDETECTION, CONEPROJECTILE, ITEMPICK, DROPPINGPICK and UNIDENTIFIED (two more bits, 16 CLOUDTRAP and 18 PORTAL itself, are cleared through a temporary the parser did not follow) |
| DEBRIS SMALL | TRANSPARENT, PROJECTILE, SPELL, BIPED, WATER, TRIGGER, NONCOLLIDABLE, CLOUDTRAP, PORTAL, TRANSPARENT SMALL, TRANSPARENT SMALL ANIM, CHARCONTROLLER, AVOIDBOX, CAMERASPHERE, CAMERAPICK, ITEMPICK, LINEOFSIGHT, PATHPICK, DROPPINGPICK |
| DEBRIS LARGE | BIPED, WATER, NONCOLLIDABLE, CLOUDTRAP, PORTAL, LINEOFSIGHT |
| ACOUSTIC SPACE | as PORTAL's list without DEBRIS SMALL, DEBRIS LARGE and CHARCONTROLLER (bits 16 and 21 cleared through a temporary) |
| CHARCONTROLLER | UNIDENTIFIED, BIPED, PORTAL, DEBRIS SMALL, DEADBIP |
| DEADBIP | BIPED, PORTAL, ACOUSTIC SPACE, CHARCONTROLLER |
| CAMERASPHERE, ITEMPICK, DROPPINGPICK | DEBRIS SMALL |
| LINEOFSIGHT | PORTAL, DEBRIS SMALL, DEBRIS LARGE, ACOUSTIC SPACE |
| ACTORZONE, PROJECTILEZONE, GASTRAP, SHELLCASING, INVISIBLE WALL, WARD, STAIRHELPER, BIPED NO CC, COLLISIONBOX, DOORDETECTION, CONEPROJECTILE | collide with everything (their bits are never cleared; the zones are phantoms) |

For the inn: the clutter (CLUTTER, PROPS), the statics and the character controller all collide
with each other; the player's capsule (CHARCONTROLLER) ignores the BIPED ragdoll bodies and the
dead (DEADBIP), which is why a ragdoll never pushes the walker; WEAPON and PROJECTILE pass through
BIPED (hits are detected by the game's own sweeps, not by Havok contacts).

## The biped parts (the ragdoll's self-collision)

The parts in the table's order: 0 OTHER, 1 HEAD, 2 BODY, 3 SPINE1, 4 SPINE2, 5 LUPPERARM,
6 LFOREARM, 7 LHAND, 8 LTHIGH, 9 LCALF, 10 LFOOT, 11 RUPPERARM, 12 RFOREARM, 13 RHAND,
14 RTHIGH, 15 RCALF, 16 RFOOT, 17 TAIL, 18 SHIELD, 19 QUIVER, 20 WEAPON, 21 PONYTAIL, 22 WING,
23 PACK, 24 CHAIN, 25 ADDONHEAD, 26 ADDONCHEST, 27 ADDONARM, 28 ADDONLEG. Here the bits are set
(only these pairs collide; the default is no self-collision):

| part | collides with |
|---|---|
| HEAD | LFOREARM, LHAND, RFOREARM, RHAND, TAIL, WING |
| BODY, SPINE1 | LFOREARM, LHAND, RFOREARM, RHAND, WING, CHAIN |
| SPINE2 | LFOREARM, LHAND, RFOREARM, RHAND, TAIL, WING, CHAIN |
| LUPPERARM | RFOREARM, RHAND, WING (RUPPERARM: LFOREARM, LHAND, WING) |
| LFOREARM | HEAD, BODY, SPINE1, SPINE2, LTHIGH, RUPPERARM, RFOREARM, RHAND, RTHIGH, TAIL, WING (RFOREARM mirrored) |
| LHAND | HEAD, BODY, SPINE1, SPINE2, LTHIGH, LCALF, LFOOT, RUPPERARM, RFOREARM, RHAND, RTHIGH, RCALF, RFOOT, WING (RHAND mirrored, plus SHIELD) |
| LTHIGH | LFOREARM, LHAND, RFOREARM, RHAND, RTHIGH, RCALF, RFOOT, SHIELD, WING, CHAIN (RTHIGH mirrored) |
| LCALF | LHAND, RHAND, RTHIGH, RCALF, RFOOT, SHIELD, WING, CHAIN (RCALF mirrored) |
| LFOOT | LHAND, RHAND, RTHIGH, RCALF, SHIELD, WING, CHAIN (RFOOT mirrored) |
| TAIL | HEAD, SPINE2, LFOREARM, RFOREARM, WING |
| SHIELD | LTHIGH, LCALF, LFOOT, RHAND, RTHIGH, RCALF, RFOOT, WING |
| WEAPON, PONYTAIL | WING |
| WING | every part but OTHER, QUIVER, PACK, CHAIN and the addons |
| CHAIN | BODY, SPINE1, SPINE2, LTHIGH, LCALF, LFOOT, RTHIGH, RCALF, RFOOT |

So a ragdoll's hands and forearms collide with the torso and the opposite leg; the two thighs
collide with each other but a thigh never with its own calf; the head only with the hands,
forearms and tail. `skyrim/hkx/ragdoll.zap` should filter its 18 bodies' pairs by this table
(the bodies' biped part is the NIF's / HKX's collision filter info bits 8..15).

## Not read

The constraint solver is read: `havok-solver.md` has the solver's tau and damping, the loop, the
rows of the ball and socket, the stiff spring, the limited hinge and the ragdoll (cone, twist and
plane limits, angular friction), their constants and the executable's addresses. Not read there:
the motors, the constraint chains, the contact schemas and the order a world's constraints are
turned into rows. `engine/physics` (`rows.zap`, `constraints.zap`) builds and solves those rows;
the cone limit's axis sign was misread in `havok-solver.md` (fixed there: mode 0 takes the cross
negated).
