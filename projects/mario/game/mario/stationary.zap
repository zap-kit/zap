# Mario's actions standing still (mario_actions_stationary.c): idle, crouching, and the last
# frames of a landing or a skid, each ending in another action when its animation does.

import n64

# mario_execute_stationary_action
fn executeStationaryAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	mut cam Camera
) bool:
	if m.checkCommonStationaryCancels(s, cam): return true
	if m.marioUpdateQuicksand(s, 0.5): return true
	a = m.action
	if a == actIdle: return m.actIdleStep(s, anims)
	if a == actCrouching: return m.actCrouchingStep(s, anims)
	if a == actStartCrouching: return m.actStartCrouchingStep(s, anims)
	if a == actStopCrouching: return m.actStopCrouchingStep(s, anims)
	if a == actJumpLandStop: return m.landStop(s, anims, 0, animLandFromSingleJump, actIdle)
	if a == actDoubleJumpLandStop: return m.landStop(s, anims, 0, animLandFromDoubleJump, actIdle)
	if a == actFreefallLandStop: return m.landStop(s, anims, 0, animGeneralLand, actIdle)
	if a == actSideFlipLandStop:
		# act_side_flip_land_stop: the model faces back, as the flip left it
		if m.landStop(s, anims, 0, animSlideflipLand, actIdle): return true
		m.drawYaw = i16.wrap(m.drawYaw + 0x8000)
		return false
	if a == actTripleJumpLandStop: return m.landStop(s, anims, actJump, animTripleJumpLand, actIdle)
	if a == actBackflipLandStop:
		if (m.input & inputZDown) == 0 or m.animFrame >= 6:
			m.input &= ~inputAPressed
		return m.landStop(s, anims, actBackflip, animTripleJumpLand, actIdle)
	if a == actLongJumpLandStop:
		m.input &= ~inputBPressed
		return landStop(
			m,
			s,
			anims,
			actJump,
			animCrouchFromSlowLongJump if m.longJumpIsSlow else animCrouchFromFastLongJump,
			actCrouching
		)
	if a == actBrakingStop: return m.actBrakingStopStep(s, anims)
	if a == actButtSlideStop: return m.actButtSlideStopStep(s, anims)
	m.fallBack(s)

# check_common_stationary_cancels: into the water when under its surface (squishing and death
# are not ported)
fn checkCommonStationaryCancels(mut m Mario, s Surfaces, mut cam Camera):
	if m.pos.y < f32(m.waterLevel - 100):
		m.updateMarioSoundAndCamera(cam)
		return m.setWaterPlungeAction(s, cam)
	false

# check_common_idle_cancels
fn checkCommonIdleCancels(mut m Mario, s Surfaces):
	if m.floorNormalY(s) < 0.29237169: return m.marioPushOffSteepFloor(s, actFreefall, 0)
	if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, actJump, 0)
	if (m.input & inputOffFloor) != 0: return m.setMarioAction(s, actFreefall, 0)
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actBeginSliding, 0)
	if (m.input & inputNonzeroAnalog) != 0:
		m.faceYaw = m.intendedYaw
		return m.setMarioAction(s, actWalking, 0)
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actPunching, 0)
	if (m.input & inputZDown) != 0: return m.setMarioAction(s, actStartCrouching, 0)
	false

# act_idle: the head turned left, right, then ahead, each to its end; after ten turns on flat
# ground he would fall asleep (not ported: he goes on idling). Quicksand, poison gas and
# panting at low health are not ported.
fn actIdleStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.checkCommonIdleCancels(s): return true
	if m.actionState == 3: return m.setMarioAction(s, actStartSleeping, 0)
	if (m.actionArg & 1) != 0:
		m.setMarioAnimation(anims, animStandAgainstWall)
	else:
		if m.actionState == 0:
			m.setMarioAnimation(anims, animIdleHeadLeft)
		elif m.actionState == 1:
			m.setMarioAnimation(anims, animIdleHeadRight)
		elif m.actionState == 2:
			m.setMarioAnimation(anims, animIdleHeadCenter)
		if m.isAnimAtEnd():
			m.actionState += 1
			if m.actionState == 3:
				deltaYOfFloorBehindMario = m.pos.y -
					m.findFloorHeightRelativePolar(s, -0x8000, 60.0)
				if deltaYOfFloorBehindMario < -24.0 or 24.0 < deltaYOfFloorBehindMario:
					m.actionState = 0
				else:
					m.actionTimer += 1
					if m.actionTimer < 10:
						m.actionState = 0
	m.stationaryGroundStep(s)
	false

# act_crouching
fn actCrouchingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, actBackflip, 0)
	if (m.input & inputOffFloor) != 0: return m.setMarioAction(s, actFreefall, 0)
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actBeginSliding, 0)
	if (m.input & inputFirstPerson) != 0: return m.setMarioAction(s, actStopCrouching, 0)
	if (m.input & inputZDown) == 0: return m.setMarioAction(s, actStopCrouching, 0)
	if (m.input & inputNonzeroAnalog) != 0: return m.setMarioAction(s, actStartCrawling, 0)
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actPunching, 9)
	m.stationaryGroundStep(s)
	m.setMarioAnimation(anims, animCrouching)
	false

# stopping_step
fn stoppingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}, animID i64, action i64):
	m.stationaryGroundStep(s)
	m.setMarioAnimation(anims, animID)
	if m.isAnimAtEnd():
		m.setMarioAction(s, action, 0)

# act_braking_stop
fn actBrakingStopStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputOffFloor) != 0: return m.setMarioAction(s, actFreefall, 0)
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actPunching, 0)
	if (m.input & inputFirstPerson) == 0 and
		(m.input & (inputNonzeroAnalog | inputAPressed | inputOffFloor | inputAboveSlide)) != 0:
		return m.checkCommonActionExits(s)
	m.stoppingStep(s, anims, animStopSkid, actIdle)
	false

# act_butt_slide_stop
fn actButtSlideStopStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & (inputNonzeroAnalog | inputAPressed | inputOffFloor | inputAboveSlide)) != 0:
		return m.checkCommonActionExits(s)
	m.stoppingStep(s, anims, animStopSlide, actIdle)
	false

# act_start_crouching
fn actStartCrouchingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}) bool:
	m.crouchingTransition(s, anims, animStartCrouching, actCrouching)

# act_stop_crouching
fn actStopCrouchingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}) bool:
	m.crouchingTransition(s, anims, animStopCrouching, actIdle)

# the body the game writes twice in the two above: the animation played, then `endAction`
fn crouchingTransition(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	animID i64,
	endAction i64
):
	if (m.input & inputOffFloor) != 0: return m.setMarioAction(s, actFreefall, 0)
	if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, actBackflip, 0)
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actBeginSliding, 0)
	m.stationaryGroundStep(s)
	m.setMarioAnimation(anims, animID)
	if m.isAnimPastEnd():
		m.setMarioAction(s, endAction, 0)
	false

# landing_step
fn landingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}, animID i64, action i64):
	m.stationaryGroundStep(s)
	m.setMarioAnimation(anims, animID)
	if m.isAnimAtEnd(): return m.setMarioAction(s, action, 0)
	false

# check_common_landing_cancels: A jumps again (`action`, or as set_jump_from_landing decides
# when it is 0); the stick walks on
fn checkCommonLandingCancels(mut m Mario, s Surfaces, action i64):
	if (m.input & inputFirstPerson) != 0: return m.setMarioAction(s, actIdle, 0)
	if (m.input & inputAPressed) != 0:
		if action == 0: return m.setJumpFromLanding(s)
		return m.setJumpingAction(s, action, 0)
	if (m.input & (inputNonzeroAnalog | inputAPressed | inputOffFloor | inputAboveSlide)) != 0:
		return m.checkCommonActionExits(s)
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actPunching, 0)
	false

# act_*_land_stop: a landing's last frames, standing, its animation played out, then `next`
fn landStop(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	jumpAction i64,
	animID i64,
	next i64
):
	if m.checkCommonLandingCancels(s, jumpAction): return true
	m.landingStep(s, anims, animID, next)
	false
