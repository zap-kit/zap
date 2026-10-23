# What Mario does with the objects he touched (interaction.c): each kind of interaction the
# objects he met offer, in the game's order of handlers, handled by the first object of that kind,
# until a handler changes his action. Ported: the pole (trees and poles, grabbed in the air). The
# other handlers (coins, stars, doors, warps, cannons, enemies, damage, text, caps, holding...) are
# not: their kinds are taken off and nothing happens.

# interaction types (interaction.h)
interactHoot = 0x0000_0001
interactGrabbable = 0x0000_0002
interactDoor = 0x0000_0004
interactDamage = 0x0000_0008
interactCoin = 0x0000_0010
interactCap = 0x0000_0020
pub interactPole = 0x0000_0040
interactKoopa = 0x0000_0080
interactUnknown08 = 0x0000_0100
interactBreakable = 0x0000_0200
interactStrongWind = 0x0000_0400
interactWarpDoor = 0x0000_0800
interactStarOrKey = 0x0000_1000
interactWarp = 0x0000_2000
interactCannonBase = 0x0000_4000
interactBounceTop = 0x0000_8000
interactWaterRing = 0x0001_0000
interactBully = 0x0002_0000
interactFlame = 0x0004_0000
interactKoopaShell = 0x0008_0000
interactBounceTop2 = 0x0010_0000
interactMrBlizzard = 0x0020_0000
interactHitFromBelow = 0x0040_0000
interactText = 0x0080_0000
interactTornado = 0x0100_0000
interactWhirlpool = 0x0200_0000
interactClamOrBubba = 0x0400_0000
interactBbhEntrance = 0x0800_0000
interactSnufitBullet = 0x1000_0000
interactShock = 0x2000_0000
interactIglooBarrier = 0x4000_0000

intStatusInteracted = 0x8000
pub intSubtypeDelayInvincibility = 0x0000_0002

# sInteractionHandlers' order
interactionOrder = [
	interactCoin,
	interactWaterRing,
	interactStarOrKey,
	interactBbhEntrance,
	interactWarp,
	interactWarpDoor,
	interactDoor,
	interactCannonBase,
	interactIglooBarrier,
	interactTornado,
	interactWhirlpool,
	interactStrongWind,
	interactFlame,
	interactSnufitBullet,
	interactClamOrBubba,
	interactBully,
	interactShock,
	interactBounceTop2,
	interactMrBlizzard,
	interactHitFromBelow,
	interactBounceTop,
	interactDamage,
	interactPole,
	interactHoot,
	interactBreakable,
	interactKoopa,
	interactKoopaShell, interactUnknown08, interactCap, interactGrabbable, interactText]

# mario_process_interactions
fn marioProcessInteractions(mut m Mario, s Surfaces, mut cam Camera, mut objs Objects):
	if (m.action & actFlagIntangible) == 0 and m.collidedObjInteractTypes != 0:
		for interactType in interactionOrder:
			if (m.collidedObjInteractTypes & interactType) != 0:
				o = objs.marioGetCollidedObject(interactType)
				m.collidedObjInteractTypes &= ~interactType
				if o >= 0 and (objs.all[o].interactStatus & intStatusInteracted) == 0:
					if m.interactWith(s, cam, objs, interactType, o): break
	# (only the damage handlers delay it: not ported)
	if m.invincTimer > 0:
		m.invincTimer -= 1
	# (check_kick_or_punch_wall: his punches and kicks are not ported)
	m.flags &= ~(marioPunching | marioKicking | marioTripping)

# the handler of an interaction type (sInteractionHandlers): only the pole's is ported
fn interactWith(
	mut m Mario,
	s Surfaces,
	mut cam Camera,
	mut objs Objects,
	interactType i64,
	o i64
):
	if interactType == interactPole: return m.interactPoleWith(s, cam, objs, o)
	false

# mario_get_collided_object: the first object his object met that offers exactly that type
fn marioGetCollidedObject(objs Objects, interactType i64):
	for i in 0..objs.all[0].numCollidedObjs:
		o = objs.all[0].collidedObject(i)
		if objs.all[o].interactType == interactType: return o
	-1

# interact_pole: grabbed in the air (unless he just let go of it), slowly or fast by his speed.
# (Mario's pole actions are not ported: their group falls back to idle.)
fn interactPoleWith(mut m Mario, s Surfaces, mut cam Camera, objs Objects, o i64):
	actionId = m.action & actIdMask
	if actionId >= 0x080 and actionId < 0x0A0:
		if (m.prevAction & actFlagOnPole) == 0 or m.usedObj != o:
			lowSpeed = m.forwardVel <= 10.0
			# (mario_stop_riding_and_holding: he rides and holds nothing, those are not ported)
			m.interactObj = o
			m.usedObj = o
			m.vel.y = 0.0
			m.forwardVel = 0.0
			m.poleUnk108 = 0
			m.poleYawVel = 0
			m.polePos = m.pos.y - objs.all[o].pos.y
			if lowSpeed: return m.setMarioAction(s, actGrabPoleSlow, 0)
			# @bug forwardVel was just set to 0 (fixed in the Shindou version)
			m.poleYawVel = i64(m.forwardVel * 256.0 + 4096.0)
			m.resetMarioPitch(cam)
			return m.setMarioAction(s, actGrabPoleFast, 0)
	false
