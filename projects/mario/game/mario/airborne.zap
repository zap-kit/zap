# Mario's actions in the air (mario_actions_airborne.c): the jumps, the flips and falling, each
# steered a little by the stick, landing into its own landing action.

import n64

# mario_execute_airborne_action
fn executeAirborneAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	mut cam Camera
) bool:
	if m.checkCommonAirborneCancels(s, cam): return true
	a = m.action
	if a == actJump: return m.actJumpStep(s, anims)
	if a == actDoubleJump: return m.actDoubleJumpStep(s, anims)
	if a == actFreefall: return m.actFreefallStep(s, anims)
	if a == actSideFlip: return m.actSideFlipStep(s, anims)
	if a == actSteepJump: return m.actSteepJumpStep(s, anims)
	if a == actTripleJump: return m.actTripleJumpStep(s, anims)
	if a == actBackflip: return m.actBackflipStep(s, anims)
	if a == actLongJump: return m.actLongJumpStep(s, anims)
	m.fallBack(s)

# check_common_airborne_cancels: into the water when under its surface (squishing and the
# vertical wind are not ported)
fn checkCommonAirborneCancels(mut m Mario, s Surfaces, mut cam Camera):
	if m.pos.y < f32(m.waterLevel - 100): return m.setWaterPlungeAction(s, cam)
	m.quicksandDepth = 0.0
	false

# check_fall_damage: a fall from high enough hurts (and squashes him a moment)
fn checkFallDamage(mut m Mario, s Surfaces, hardFallAction i64):
	fallHeight = m.peakHeight - m.pos.y
	damageHeight f32 = 1150.0
	if m.action != actTwirling and s.all[m.floor].kind != surfaceBurning:
		if m.vel.y < -55.0:
			if fallHeight > 3000.0:
				m.hurtCounter += 16 if (m.flags & marioCapOnHead) != 0 else 24
				return m.dropAndSetMarioAction(s, hardFallAction, 4)
			elif fallHeight > damageHeight and not m.marioFloorIsSlippery(s):
				m.hurtCounter += 8 if (m.flags & marioCapOnHead) != 0 else 12
				m.squishTimer = 30
	false

# should_get_stuck_in_ground: a long fall onto soft snow or sand
fn shouldGetStuckInGround(m Mario, s Surfaces):
	floor = s.all[m.floor]
	t = floor.kind
	if ((terrainType & 7) == terrainSnow or (terrainType & 7) == terrainSand) and
		t != surfaceBurning and t != surfaceHard and not (t >= 0x35 and t <= 0x37):
		if m.peakHeight - m.pos.y > 1000.0 and floor.normal.y >= 0.8660254: return true
	false

# check_fall_damage_or_get_stuck (ACT_FEET_STUCK_IN_GROUND is not ported: see fallBack)
fn checkFallDamageOrGetStuck(mut m Mario, s Surfaces, hardFallAction i64) bool:
	if m.shouldGetStuckInGround(s):
		m.dropAndSetMarioAction(s, 0x0002_033C, 0)
		return true
	m.checkFallDamage(s, hardFallAction)

# check_kick_or_dive_in_air
fn checkKickOrDiveInAir(mut m Mario, s Surfaces):
	if (m.input & inputBPressed) != 0:
		return m.setMarioAction(s, actDive if m.forwardVel > 28.0 else actJumpKick, 0)
	false

# check_horizontal_wind
fn checkHorizontalWind(mut m Mario, s Surfaces):
	floor = s.all[m.floor]
	if floor.kind != surfaceHorizontalWind: return false
	pushAngle i64 = i16.wrap(floor.force << 8)
	m.slideVelX += 1.2 * sins(pushAngle)
	m.slideVelZ += 1.2 * coss(pushAngle)
	speed = (m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ).sqrt()
	if speed > 48.0:
		m.slideVelX = m.slideVelX * 48.0 / speed
		m.slideVelZ = m.slideVelZ * 48.0 / speed
		speed = 32.0
	elif speed > 32.0:
		speed = 32.0
	m.vel.x = m.slideVelX
	m.vel.z = m.slideVelZ
	m.slideYaw = atan2s(m.slideVelZ, m.slideVelX)
	m.forwardVel = speed * coss(m.faceYaw - m.slideYaw)
	true

# update_air_without_turn: his speed slowly let go of; the stick pushes it on and to the sides
fn updateAirWithoutTurn(mut m Mario, s Surfaces):
	if m.checkHorizontalWind(s): return
	sidewaysSpeed = 0.0
	dragThreshold = 48.0 if m.action == actLongJump else 32.0
	m.forwardVel = approach(m.forwardVel, 0.0, 0.35, 0.35)
	if (m.input & inputNonzeroAnalog) != 0:
		intendedDYaw i64 = i16.wrap(m.intendedYaw - m.faceYaw)
		intendedMag = m.intendedMag / 32.0
		m.forwardVel += intendedMag * coss(intendedDYaw) * 1.5
		sidewaysSpeed = intendedMag * sins(intendedDYaw) * 10.0
	if m.forwardVel > dragThreshold:
		m.forwardVel -= 1.0
	if m.forwardVel < -16.0:
		m.forwardVel += 2.0
	m.slideVelX = m.forwardVel * sins(m.faceYaw)
	m.slideVelZ = m.forwardVel * coss(m.faceYaw)
	m.slideVelX += sidewaysSpeed * sins(m.faceYaw + 0x4000)
	m.slideVelZ += sidewaysSpeed * coss(m.faceYaw + 0x4000)
	m.vel.x = m.slideVelX
	m.vel.z = m.slideVelZ

# common_air_action_step: a step through the air; landing starts `landAction`, which runs from
# the next frame
fn commonAirActionStep(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	landAction i64,
	animation i64,
	stepArg i64
):
	m.updateAirWithoutTurn(s)
	stepResult = m.performAirStep(s, stepArg)
	if stepResult == airStepNone:
		m.setMarioAnimation(anims, animation)
	elif stepResult == airStepLanded:
		if not m.checkFallDamageOrGetStuck(s, actHardBackwardGroundKb):
			m.setMarioAction(s, landAction, 0)
	elif stepResult == airStepHitWall:
		m.setMarioAnimation(anims, animation)
		if m.forwardVel > 16.0:
			m.marioBonkReflection(s, false)
			m.faceYaw = i16.wrap(m.faceYaw + 0x8000)
			if m.wall >= 0:
				m.setMarioAction(s, actAirHitWall, 0)
			else:
				if m.vel.y > 0.0:
					m.vel.y = 0.0
				if m.forwardVel >= 38.0:
					m.setMarioAction(s, actBackwardAirKb, 0)
				else:
					if m.forwardVel > 8.0:
						m.marioSetForwardVel(-8.0)
					m.setMarioAction(s, actSoftBonk, 0)
					return 1
		else:
			m.marioSetForwardVel(0.0)
	elif stepResult == airStepGrabbedLedge:
		m.setMarioAnimation(anims, animIdleOnLedge)
		m.dropAndSetMarioAction(s, actLedgeGrab, 0)
	elif stepResult == airStepGrabbedCeiling:
		m.setMarioAction(s, actStartHanging, 0)
	# (AIR_STEP_HIT_LAVA_WALL: lava_boost_on_wall is not ported)
	stepResult

# act_jump
fn actJumpStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.checkKickOrDiveInAir(s): return true
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actGroundPound, 0)
	commonAirActionStep(
		m,
		s,
		anims,
		actJumpLand,
		animSingleJump,
		airStepCheckLedgeGrab | airStepCheckHang
	)
	false

# act_double_jump: rising, then falling, each its animation (chosen before the step)
fn actDoubleJumpStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	animation = animDoubleJumpRise if m.vel.y >= 0.0 else animDoubleJumpFall
	if m.checkKickOrDiveInAir(s): return true
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actGroundPound, 0)
	commonAirActionStep(
		m,
		s,
		anims,
		actDoubleJumpLand,
		animation,
		airStepCheckLedgeGrab | airStepCheckHang
	)
	false

# act_triple_jump
fn actTripleJumpStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actDive, 0)
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actGroundPound, 0)
	m.commonAirActionStep(s, anims, actTripleJumpLand, animTripleJump, 0)
	false

# act_backflip
fn actBackflipStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actGroundPound, 0)
	m.commonAirActionStep(s, anims, actBackflipLand, animBackflip, 0)
	false

# act_freefall
fn actFreefallStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actDive, 0)
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actGroundPound, 0)
	animation = animGeneralFall
	if m.actionArg == 1:
		animation = animFallFromSlide
	elif m.actionArg == 2:
		animation = animFallFromSlideKick
	m.commonAirActionStep(s, anims, actFreefallLand, animation, airStepCheckLedgeGrab)
	false

# act_side_flip: the model faces back while he flips
fn actSideFlipStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actDive, 0)
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actGroundPound, 0)
	if m.commonAirActionStep(s, anims, actSideFlipLand, animSlideflip, airStepCheckLedgeGrab) !=
		airStepGrabbedLedge:
		m.drawYaw = i16.wrap(m.drawYaw + 0x8000)
	false

# act_long_jump
fn actLongJumpStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	animation = animSlowLongJump if m.longJumpIsSlow else animFastLongJump
	if s.all[m.floor].kind == surfaceVerticalWind and m.actionState == 0:
		m.actionState = 1
	m.commonAirActionStep(s, anims, actLongJumpLand, animation, airStepCheckLedgeGrab)
	false

# act_steep_jump: off a floor too steep to jump from, falling back down it
fn actSteepJumpStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actDive, 0)
	m.marioSetForwardVel(0.98 * m.forwardVel)
	step = m.performAirStep(s, 0)
	if step == airStepLanded:
		if not m.checkFallDamageOrGetStuck(s, actHardBackwardGroundKb):
			m.facePitch = 0
			m.setMarioAction(s, actBeginSliding if m.forwardVel < 0.0 else actJumpLand, 0)
	elif step == airStepHitWall:
		m.marioSetForwardVel(0.0)
	m.setMarioAnimation(anims, animSingleJump)
	m.drawYaw = m.steepJumpYaw
	false
