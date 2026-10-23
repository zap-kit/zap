# Mario's actions on the move (mario_actions_moving.c): walking and running, slowing down,
# skidding and turning around, sliding, and the first frames of each landing.

import n64

# check_common_moving_cancels: into the water when under its surface (shockwaves, squishing and
# death are not ported)
fn checkCommonMovingCancels(mut m Mario, s Surfaces, mut cam Camera):
	if m.pos.y < f32(m.waterLevel - 100): return m.setWaterPlungeAction(s, cam)
	false

# struct LandingAction: what a landing turns into
type LandingAction:
	numFrames i64
	doubleJumpTimer i64   # unk02
	verySteepAction i64
	endAction i64
	aPressedAction i64
	offFloorAction i64
	slideAction i64
	tripleJumpOnA bool   # set_triple_jump_action rather than set_jumping_action on A

fn landingActionOf(action i64):
	if action == actFreefallLand:
		return LandingAction(
			numFrames = 4,
			doubleJumpTimer = 5,
			verySteepAction = actFreefall,
			endAction = actFreefallLandStop,
			aPressedAction = actDoubleJump,
			offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = false)
	if action == actSideFlipLand:
		return LandingAction(
			numFrames = 4,
			doubleJumpTimer = 5,
			verySteepAction = actFreefall,
			endAction = actSideFlipLandStop,
			aPressedAction = actDoubleJump,
			offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = false)
	if action == actLongJumpLand:
		return LandingAction(
			numFrames = 6,
			doubleJumpTimer = 5,
			verySteepAction = actFreefall,
			endAction = actLongJumpLandStop,
			aPressedAction = actLongJump,
			offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = false)
	if action == actDoubleJumpLand:
		return LandingAction(
			numFrames = 4,
			doubleJumpTimer = 5,
			verySteepAction = actFreefall,
			endAction = actDoubleJumpLandStop,
			aPressedAction = actJump,
			offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = true)
	if action == actTripleJumpLand:
		return LandingAction(
			numFrames = 4,
			doubleJumpTimer = 0,
			verySteepAction = actFreefall,
			endAction = actTripleJumpLandStop,
			aPressedAction = 0,
			offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = false)
	if action == actBackflipLand:
		return LandingAction(
			numFrames = 4,
			doubleJumpTimer = 0,
			verySteepAction = actFreefall,
			endAction = actBackflipLandStop,
			aPressedAction = actBackflip,
			offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = false)
	# sJumpLandAction
	LandingAction(
		numFrames = 4,
		doubleJumpTimer = 5,
		verySteepAction = actFreefall,
		endAction = actJumpLandStop,
		aPressedAction = actDoubleJump,
		offFloorAction = actFreefall, slideAction = actBeginSliding, tripleJumpOnA = false)

# mario_execute_moving_action
fn executeMovingAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	mut cam Camera
) bool:
	if m.checkCommonMovingCancels(s, cam): return true
	if m.marioUpdateQuicksand(s, 0.25): return true
	a = m.action
	if a == actWalking: return m.actWalkingStep(s, anims)
	if a == actTurningAround: return m.actTurningAroundStep(s, anims)
	if a == actFinishTurningAround: return m.actFinishTurningAroundStep(s, anims)
	if a == actBraking: return m.actBrakingStep(s, anims)
	if a == actDecelerating: return m.actDeceleratingStep(s, anims)
	if a == actButtSlide:
		return commonSlideActionWithJump(
			m,
			s,
			anims,
			actButtSlideStop,
			actJump,
			actButtSlideAir,
			animSlide
		)
	if a == actStomachSlide:
		return m.stomachSlideAction(s, anims, actStomachSlideStop, actFreefall, animSlideDive)
	if a == actCrouchSlide: return m.actCrouchSlideStep(s, anims)
	if a == actJumpLand: return m.landingAction(s, anims, animLandFromSingleJump)
	if a == actFreefallLand: return m.landingAction(s, anims, animGeneralLand)
	if a == actDoubleJumpLand: return m.landingAction(s, anims, animLandFromDoubleJump)
	if a == actSideFlipLand:
		# act_side_flip_land: the model faces back, as the flip left it
		if m.commonLandingCancels(s, landingActionOf(a)): return true
		if m.commonLandingAction(s, anims, animSlideflipLand, actFreefall) != groundStepHitWall:
			m.drawYaw = i16.wrap(m.drawYaw + 0x8000)
		return false
	if a == actTripleJumpLand:
		m.input &= ~inputAPressed
		return m.landingAction(s, anims, animTripleJumpLand)
	if a == actBackflipLand:
		if (m.input & inputZDown) == 0:
			m.input &= ~inputAPressed
		return m.landingAction(s, anims, animTripleJumpLand)
	if a == actLongJumpLand:
		if (m.input & inputZDown) == 0:
			m.input &= ~inputAPressed
		return landingAction(
			m,
			s,
			anims,
			animCrouchFromSlowLongJump if m.longJumpIsSlow else animCrouchFromFastLongJump
		)
	m.fallBack(s)

# tilt_body_running: the model's pitch (the body's tilts themselves are drawing only: not ported)
fn tiltBodyRunning(m Mario, s Surfaces):
	pitch = m.findFloorSlope(s, 0)
	pitch = i16.wrap(i64(f32(pitch) * m.forwardVel / 40.0))
	-pitch

# align_with_floor: on the floor (the model's tilt to it is drawing only)
fn alignWithFloor(mut m Mario):
	m.pos.y = m.floorHeight

# begin_walking_action
fn beginWalkingAction(mut m Mario, s Surfaces, forwardVel f32, action i64, actionArg i64) bool:
	m.faceYaw = m.intendedYaw
	m.marioSetForwardVel(forwardVel)
	m.setMarioAction(s, action, actionArg)

# check_ledge_climb_down: walking slowly off a ledge onto a wall's face below it
fn checkLedgeClimbDown(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.forwardVel >= 10.0: return
	w = s.findWallCollisions(m.pos.x, m.pos.y, m.pos.z, -10.0, 10.0, false)
	if w.wall < 0: return
	floorHeight, floor = s.findFloor(w.x, m.pos.y, w.z)
	if floor < 0 or m.pos.y - floorHeight <= 160.0: return
	n = s.all[w.wall].normal
	wallAngle = atan2s(n.z, n.x)
	wallDYaw i64 = i16.wrap(wallAngle - m.faceYaw)
	if wallDYaw > -0x4000 and wallDYaw < 0x4000:
		m.pos.x = w.x - 20.0 * n.x
		m.pos.z = w.z - 20.0 * n.z
		m.facePitch = 0
		m.faceYaw = i16.wrap(wallAngle + 0x8000)
		m.setMarioAction(s, actLedgeClimbDown, 0)
		m.setMarioAnimation(anims, animClimbDownLedge)

# slide_bonk
fn slideBonk(mut m Mario, s Surfaces, fastAction i64, slowAction i64):
	if m.forwardVel > 16.0:
		m.marioBonkReflection(s, true)
		m.dropAndSetMarioAction(s, fastAction, 0)
	else:
		m.marioSetForwardVel(0.0)
		m.setMarioAction(s, slowAction, 0)

# set_triple_jump_action
fn setTripleJumpAction(mut m Mario, s Surfaces) bool:
	if (m.flags & marioWingCap) != 0: return m.setMarioAction(s, actFlyingTripleJump, 0)
	if m.forwardVel > 20.0: return m.setMarioAction(s, actTripleJump, 0)
	m.setMarioAction(s, actJump, 0)

# update_sliding_angle
fn updateSlidingAngle(mut m Mario, s Surfaces, accel f32, lossFactor f32):
	floor = s.all[m.floor]
	slopeAngle = atan2s(floor.normal.z, floor.normal.x)
	steepness = (floor.normal.x * floor.normal.x + floor.normal.z * floor.normal.z).sqrt()
	m.slideVelX += accel * steepness * sins(slopeAngle)
	m.slideVelZ += accel * steepness * coss(slopeAngle)
	m.slideVelX *= lossFactor
	m.slideVelZ *= lossFactor
	m.slideYaw = atan2s(m.slideVelZ, m.slideVelX)
	facingDYaw i64 = i16.wrap(m.faceYaw - m.slideYaw)
	newFacingDYaw = facingDYaw
	if newFacingDYaw > 0 and newFacingDYaw <= 0x4000:
		newFacingDYaw -= 0x200
		if newFacingDYaw < 0:
			newFacingDYaw = 0
	elif newFacingDYaw > -0x4000 and newFacingDYaw < 0:
		newFacingDYaw += 0x200
		if newFacingDYaw > 0:
			newFacingDYaw = 0
	elif newFacingDYaw > 0x4000 and newFacingDYaw < 0x8000:
		newFacingDYaw += 0x200
		if newFacingDYaw > 0x8000:
			newFacingDYaw = 0x8000
	elif newFacingDYaw > -0x8000 and newFacingDYaw < -0x4000:
		newFacingDYaw -= 0x200
		if newFacingDYaw < -0x8000:
			newFacingDYaw = -0x8000
	m.faceYaw = i16.wrap(m.slideYaw + newFacingDYaw)
	m.vel.x = m.slideVelX
	m.vel.y = 0.0
	m.vel.z = m.slideVelZ
	m.marioUpdateMovingSand(s)
	m.marioUpdateWindyGround(s)
	# (the speed is capped a frame late: the game's butt slide speed glitch)
	m.forwardVel = (m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ).sqrt()
	if m.forwardVel > 100.0:
		m.slideVelX = m.slideVelX * 100.0 / m.forwardVel
		m.slideVelZ = m.slideVelZ * 100.0 / m.forwardVel
	if newFacingDYaw < -0x4000 or newFacingDYaw > 0x4000:
		m.forwardVel *= -1.0

# update_sliding
fn updateSliding(mut m Mario, s Surfaces, stopSpeed f32):
	intendedDYaw i64 = i16.wrap(m.intendedYaw - m.slideYaw)
	forward = coss(intendedDYaw)
	sideward = sins(intendedDYaw)
	if forward < 0.0 and m.forwardVel >= 0.0:
		forward *= 0.5 + 0.5 * m.forwardVel / 100.0
	floorClass = m.marioGetFloorClass(s)
	accel = 7.0
	lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.92
	if floorClass == classVerySlippery:
		accel = 10.0
		lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.98
	elif floorClass == classSlippery:
		accel = 8.0
		lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.96
	elif floorClass == classNotSlippery:
		accel = 5.0
	oldSpeed = (m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ).sqrt()
	# (the new x speed turns the old z one: the game's slightly lopsided rotation)
	m.slideVelX += m.slideVelZ * (m.intendedMag / 32.0) * sideward * 0.05
	m.slideVelZ -= m.slideVelX * (m.intendedMag / 32.0) * sideward * 0.05
	newSpeed = (m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ).sqrt()
	if oldSpeed > 0.0 and newSpeed > 0.0:
		m.slideVelX = m.slideVelX * oldSpeed / newSpeed
		m.slideVelZ = m.slideVelZ * oldSpeed / newSpeed
	m.updateSlidingAngle(s, accel, lossFactor)
	if not m.marioFloorIsSlope(s) and m.forwardVel * m.forwardVel < stopSpeed * stopSpeed:
		m.marioSetForwardVel(0.0)
		return true
	false

# apply_slope_accel: a slope speeds him downhill and slows him uphill; then his speed is his
# velocity
fn applySlopeAccel(mut m Mario, s Surfaces):
	floor = s.all[m.floor]
	steepness = (floor.normal.x * floor.normal.x + floor.normal.z * floor.normal.z).sqrt()
	floorDYaw i64 = i16.wrap(m.floorAngle - m.faceYaw)
	if m.marioFloorIsSlope(s):
		slopeClass = m.marioGetFloorClass(s)
		slopeAccel = 1.7
		if slopeClass == classVerySlippery:
			slopeAccel = 5.3
		elif slopeClass == classSlippery:
			slopeAccel = 2.7
		elif slopeClass == classNotSlippery:
			slopeAccel = 0.0
		if floorDYaw > -0x4000 and floorDYaw < 0x4000:
			m.forwardVel += slopeAccel * steepness
		else:
			m.forwardVel -= slopeAccel * steepness
	m.slideYaw = m.faceYaw
	m.slideVelX = m.forwardVel * sins(m.faceYaw)
	m.slideVelZ = m.forwardVel * coss(m.faceYaw)
	m.vel.x = m.slideVelX
	m.vel.y = 0.0
	m.vel.z = m.slideVelZ
	m.marioUpdateMovingSand(s)
	m.marioUpdateWindyGround(s)

# apply_landing_accel
fn applyLandingAccel(mut m Mario, s Surfaces, frictionFactor f32):
	m.applySlopeAccel(s)
	if not m.marioFloorIsSlope(s):
		m.forwardVel *= frictionFactor
		if m.forwardVel * m.forwardVel < 1.0:
			m.marioSetForwardVel(0.0)
			return true
	false

# apply_slope_decel
fn applySlopeDecel(mut m Mario, s Surfaces, decelCoef f32):
	floorClass = m.marioGetFloorClass(s)
	decel = decelCoef * 2.0
	if floorClass == classVerySlippery:
		decel = decelCoef * 0.2
	elif floorClass == classSlippery:
		decel = decelCoef * 0.7
	elif floorClass == classNotSlippery:
		decel = decelCoef * 3.0
	m.forwardVel = approach(m.forwardVel, 0.0, decel, decel)
	stopped = m.forwardVel == 0.0
	m.applySlopeAccel(s)
	stopped

# update_decelerating_speed
fn updateDeceleratingSpeed(mut m Mario, s Surfaces):
	m.forwardVel = approach(m.forwardVel, 0.0, 1.0, 1.0)
	stopped = m.forwardVel == 0.0
	m.marioSetForwardVel(m.forwardVel)
	m.marioUpdateMovingSand(s)
	m.marioUpdateWindyGround(s)
	stopped

# update_walking_speed: toward what the stick asks, the face turned toward it 0x800 a frame at most
fn updateWalkingSpeed(mut m Mario, s Surfaces):
	maxTargetSpeed = 24.0 if m.floor >= 0 and s.all[m.floor].kind == surfaceSlow else 32.0
	targetSpeed = m.intendedMag if m.intendedMag < maxTargetSpeed else maxTargetSpeed
	if m.quicksandDepth > 10.0:
		targetSpeed = f32(f64(targetSpeed) * (6.25 / f64(m.quicksandDepth)))
	if m.forwardVel <= 0.0:
		m.forwardVel += 1.1
	elif m.forwardVel <= targetSpeed:
		m.forwardVel += 1.1 - m.forwardVel / 43.0
	elif m.floorNormalY(s) >= 0.95:
		m.forwardVel -= 1.0
	if m.forwardVel > 48.0:
		m.forwardVel = 48.0
	m.faceYaw = i16.wrap(
		m.intendedYaw - approach(i16.wrap(m.intendedYaw - m.faceYaw), 0, 0x800, 0x800)
	)
	m.applySlopeAccel(s)

# should_begin_sliding
fn shouldBeginSliding(m Mario):
	if (m.input & inputAboveSlide) != 0:
		slideLevel = (terrainType & 7) == terrainSlide
		movingBackward = m.forwardVel <= -1.0
		if slideLevel or movingBackward or m.marioFacingDownhill(false): return true
	false

# analog_stick_held_back
fn analogStickHeldBack(m Mario):
	intendedDYaw i64 = i16.wrap(m.intendedYaw - m.faceYaw)
	intendedDYaw < -0x471C or intendedDYaw > 0x471C

# check_ground_dive_or_punch (punching and diving are not ported: see fallBack)
fn checkGroundDiveOrPunch(mut m Mario, s Surfaces):
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actMovePunching, 0)
	false

# begin_braking_action
fn beginBrakingAction(mut m Mario, s Surfaces) bool:
	if m.actionState == 1:
		m.faceYaw = i16.wrap(m.actionArg)
		return m.setMarioAction(s, actStandingAgainstWall, 0)
	if m.forwardVel >= 16.0 and m.floorNormalY(s) >= 0.17364818:
		return m.setMarioAction(s, actBraking, 0)
	m.setMarioAction(s, actDecelerating, 0)

# anim_and_audio_for_walk: tiptoeing, walking or running by his speed, each played as fast as
# he goes; the actionTimer is the gait (0 starting to tiptoe, 1 tiptoe, 2 walk, 3 run)
fn animAndAudioForWalk(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	targetPitch = 0
	val04 = m.intendedMag if m.intendedMag > m.forwardVel else m.forwardVel
	if val04 < 4.0:
		val04 = 4.0
	if m.quicksandDepth > 50.0:
		# (MARIO_ANIM_MOVE_IN_QUICKSAND: not read; he walks)
		m.setMarioAnimWithAccel(anims, animWalking, i64(val04 / 4.0 * 65536.0))
		m.actionTimer = 0
	else:
		choosing = true
		while choosing:
			t = m.actionTimer
			if t == 0:
				if val04 > 8.0:
					m.actionTimer = 2
				else:
					val14 = i64(val04 / 4.0 * 65536.0)
					if val14 < 0x1000:
						val14 = 0x1000
					m.setMarioAnimWithAccel(anims, animStartTiptoe, val14)
					if m.isAnimPastFrame(23):
						m.actionTimer = 2
					choosing = false
			elif t == 1:
				if val04 > 8.0:
					m.actionTimer = 2
				else:
					val14 = i64(val04 * 65536.0)
					if val14 < 0x1000:
						val14 = 0x1000
					m.setMarioAnimWithAccel(anims, animTiptoe, val14)
					choosing = false
			elif t == 2:
				if val04 < 5.0:
					m.actionTimer = 1
				elif val04 > 22.0:
					m.actionTimer = 3
				else:
					m.setMarioAnimWithAccel(anims, animWalking, i64(val04 / 4.0 * 65536.0))
					choosing = false
			elif t == 3:
				if val04 < 18.0:
					m.actionTimer = 2
				else:
					m.setMarioAnimWithAccel(anims, animRunning, i64(val04 / 4.0 * 65536.0))
					targetPitch = m.tiltBodyRunning(s)
					choosing = false
			else:
				# (no other gait: the game would spin here forever)
				choosing = false
	m.walkingPitch = i16.wrap(approach(m.walkingPitch, targetPitch, 0x800, 0x800))

# push_or_sidle_wall: pushing against a wall met head on, sidestepping along one met aslant
fn pushOrSidleWall(mut m Mario, s Surfaces, anims {i64: n64.Animation}, startPos Vec3):
	dx = m.pos.x - startPos.x
	dz = m.pos.z - startPos.z
	movedDistance = (dx * dx + dz * dz).sqrt()
	val04 = i64(movedDistance * 2.0 * 65536.0)
	if m.forwardVel > 6.0:
		m.marioSetForwardVel(6.0)
	wallAngle = 0
	dWallAngle = 0
	if m.wall >= 0:
		n = s.all[m.wall].normal
		wallAngle = atan2s(n.z, n.x)
		dWallAngle = i16.wrap(wallAngle - m.faceYaw)
	if m.wall < 0 or dWallAngle <= -0x71C8 or dWallAngle >= 0x71C8:
		m.flags |= marioPushingWall
		m.setMarioAnimation(anims, animPushing)
	else:
		if dWallAngle < 0:
			m.setMarioAnimWithAccel(anims, animSidestepRight, val04)
		else:
			m.setMarioAnimWithAccel(anims, animSidestepLeft, val04)
		m.actionState = 1
		m.actionArg = wallAngle + 0x8000
		m.drawYaw = i16.wrap(wallAngle + 0x8000)

# act_walking (tilt_body_walking leans the drawn body only: not ported)
fn actWalkingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.shouldBeginSliding(): return m.setMarioAction(s, actBeginSliding, 0)
	if (m.input & inputFirstPerson) != 0: return m.beginBrakingAction(s)
	if (m.input & inputAPressed) != 0: return m.setJumpFromLanding(s)
	if m.checkGroundDiveOrPunch(s): return true
	if (m.input & inputNoMovement) != 0: return m.beginBrakingAction(s)
	if m.analogStickHeldBack() and m.forwardVel >= 16.0:
		return m.setMarioAction(s, actTurningAround, 0)
	if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actCrouchSlide, 0)
	m.actionState = 0
	startPos = m.pos
	m.updateWalkingSpeed(s)
	step = m.performGroundStep(s)
	if step == groundStepLeftGround:
		m.setMarioAction(s, actFreefall, 0)
		m.setMarioAnimation(anims, animGeneralFall)
	elif step == groundStepNone:
		m.animAndAudioForWalk(s, anims)
	elif step == groundStepHitWall:
		m.pushOrSidleWall(s, anims, startPos)
		m.actionTimer = 0
	m.checkLedgeClimbDown(s, anims)
	false

# act_turning_around: skidding with the stick held back, then walking off the other way
fn actTurningAroundStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actBeginSliding, 0)
	if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, actSideFlip, 0)
	if (m.input & inputNoMovement) != 0: return m.setMarioAction(s, actBraking, 0)
	if not m.analogStickHeldBack(): return m.setMarioAction(s, actWalking, 0)
	if m.applySlopeDecel(s, 2.0): return m.beginWalkingAction(s, 8.0, actFinishTurningAround, 0)
	if m.performGroundStep(s) == groundStepLeftGround:
		m.setMarioAction(s, actFreefall, 0)
	if m.forwardVel >= 18.0:
		m.setMarioAnimation(anims, animTurningPart1)
	else:
		m.setMarioAnimation(anims, animTurningPart2)
		if m.isAnimAtEnd():
			if m.forwardVel > 0.0:
				m.beginWalkingAction(s, -m.forwardVel, actWalking, 0)
			else:
				m.beginWalkingAction(s, 8.0, actWalking, 0)
	false

# act_finish_turning_around
fn actFinishTurningAroundStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actBeginSliding, 0)
	if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, actSideFlip, 0)
	m.updateWalkingSpeed(s)
	m.setMarioAnimation(anims, animTurningPart2)
	if m.performGroundStep(s) == groundStepLeftGround:
		m.setMarioAction(s, actFreefall, 0)
	if m.isAnimAtEnd():
		m.setMarioAction(s, actWalking, 0)
	m.drawYaw = i16.wrap(m.drawYaw + 0x8000)
	false

# act_braking: skidding to a stop
fn actBrakingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputFirstPerson) == 0 and
		(m.input & (inputNonzeroAnalog | inputAPressed | inputOffFloor | inputAboveSlide)) != 0:
		return m.checkCommonActionExits(s)
	if m.applySlopeDecel(s, 2.0): return m.setMarioAction(s, actBrakingStop, 0)
	if (m.input & inputBPressed) != 0: return m.setMarioAction(s, actMovePunching, 0)
	step = m.performGroundStep(s)
	if step == groundStepLeftGround:
		m.setMarioAction(s, actFreefall, 0)
	elif step == groundStepHitWall:
		m.slideBonk(s, actBackwardGroundKb, actBrakingStop)
	m.setMarioAnimation(anims, animSkidOnGround)
	false

# act_decelerating: the stick let go, slowing to a stand
fn actDeceleratingStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	slopeClass = m.marioGetFloorClass(s)
	if (m.input & inputFirstPerson) == 0:
		if m.shouldBeginSliding(): return m.setMarioAction(s, actBeginSliding, 0)
		if (m.input & inputAPressed) != 0: return m.setJumpFromLanding(s)
		if m.checkGroundDiveOrPunch(s): return true
		if (m.input & inputNonzeroAnalog) != 0: return m.setMarioAction(s, actWalking, 0)
		if (m.input & inputZPressed) != 0: return m.setMarioAction(s, actCrouchSlide, 0)
	if m.updateDeceleratingSpeed(s): return m.setMarioAction(s, actIdle, 0)
	step = m.performGroundStep(s)
	if step == groundStepLeftGround:
		m.setMarioAction(s, actFreefall, 0)
	elif step == groundStepHitWall:
		if slopeClass == classVerySlippery:
			m.marioBonkReflection(s, true)
		else:
			m.marioSetForwardVel(0.0)
	if slopeClass == classVerySlippery:
		m.setMarioAnimation(anims, animIdleHeadLeft)
	else:
		val0C = i64(m.forwardVel / 4.0 * 65536.0)
		if val0C < 0x1000:
			val0C = 0x1000
		m.setMarioAnimWithAccel(anims, animWalking, val0C)
	false

# common_slide_action
fn commonSlideAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	endAction i64,
	airAction i64,
	animation i64
):
	step = m.performGroundStep(s)
	if step == groundStepLeftGround:
		m.setMarioAction(s, airAction, 0)
	elif step == groundStepNone:
		m.setMarioAnimation(anims, animation)
		m.alignWithFloor()
	elif step == groundStepHitWall:
		if not m.marioFloorIsSlippery(s):
			m.slideBonk(s, actGroundBonk, endAction)
		elif m.wall >= 0:
			n = s.all[m.wall].normal
			wallAngle = atan2s(n.z, n.x)
			slideSpeed = (m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ).sqrt()
			slideSpeed = f32(f64(slideSpeed) * 0.9)
			if slideSpeed < 4.0:
				slideSpeed = 4.0
			m.slideYaw = i16.wrap(wallAngle - i16.wrap(m.slideYaw - wallAngle) + 0x8000)
			m.slideVelX = slideSpeed * sins(m.slideYaw)
			m.vel.x = m.slideVelX
			m.slideVelZ = slideSpeed * coss(m.slideYaw)
			m.vel.z = m.slideVelZ
		m.alignWithFloor()

# common_slide_action_with_jump
fn commonSlideActionWithJump(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	stopAction i64,
	jumpAction i64,
	airAction i64,
	animation i64
):
	if m.actionTimer == 5:
		if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, jumpAction, 0)
	else:
		m.actionTimer += 1
	if m.updateSliding(s, 4.0): return m.setMarioAction(s, stopAction, 0)
	m.commonSlideAction(s, anims, stopAction, airAction, animation)
	false

# stomach_slide_action (the rollouts A or B start are not ported: see fallBack)
fn stomachSlideAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	stopAction i64,
	airAction i64,
	animation i64
):
	if m.actionTimer == 5:
		if (m.input & inputAboveSlide) == 0 and (m.input & (inputAPressed | inputBPressed)) != 0:
			return dropAndSetMarioAction(
				m,
				s,
				actForwardRollout if m.forwardVel >= 0.0 else actBackwardRollout,
				0
			)
	else:
		m.actionTimer += 1
	if m.updateSliding(s, 4.0): return m.setMarioAction(s, stopAction, 0)
	m.commonSlideAction(s, anims, stopAction, airAction, animation)
	false

# act_crouch_slide: A within 30 frames at speed is a long jump
fn actCrouchSlideStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}) bool:
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actButtSlide, 0)
	if m.actionTimer < 30:
		m.actionTimer += 1
		if (m.input & inputAPressed) != 0:
			if m.forwardVel > 10.0: return m.setJumpingAction(s, actLongJump, 0)
	if (m.input & inputBPressed) != 0:
		if m.forwardVel >= 10.0: return m.setMarioAction(s, actSlideKick, 0)
		return m.setMarioAction(s, actMovePunching, 9)
	if (m.input & inputAPressed) != 0: return m.setJumpingAction(s, actJump, 0)
	if (m.input & inputFirstPerson) != 0: return m.setMarioAction(s, actBraking, 0)
	m.commonSlideActionWithJump(s, anims, actCrouching, actJump, actFreefall, animStartCrouching)

# common_landing_action
fn commonLandingAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	animation i64,
	airAction i64
):
	if (m.input & inputNonzeroAnalog) != 0:
		m.applyLandingAccel(s, 0.98)
	elif m.forwardVel >= 16.0:
		m.applySlopeDecel(s, 2.0)
	else:
		m.vel.y = 0.0
	stepResult = m.performGroundStep(s)
	if stepResult == groundStepLeftGround:
		m.setMarioAction(s, airAction, 0)
	elif stepResult == groundStepHitWall:
		m.setMarioAnimation(anims, animPushing)
	m.setMarioAnimation(anims, animation)
	t = s.all[m.floor].kind
	if t >= surfaceShallowQuicksand and t <= surfaceMovingQuicksand:
		m.quicksandDepth += f32(4 - m.actionTimer) * 3.5 - 0.5
	stepResult

# common_landing_cancels
fn commonLandingCancels(mut m Mario, s Surfaces, landing LandingAction):
	if m.floorNormalY(s) < 0.2923717: return m.marioPushOffSteepFloor(s, landing.verySteepAction, 0)
	m.doubleJumpTimer = landing.doubleJumpTimer
	if m.shouldBeginSliding(): return m.setMarioAction(s, landing.slideAction, 0)
	if (m.input & inputFirstPerson) != 0: return m.setMarioAction(s, landing.endAction, 0)
	m.actionTimer += 1
	if m.actionTimer >= landing.numFrames: return m.setMarioAction(s, landing.endAction, 0)
	if (m.input & inputAPressed) != 0:
		if landing.tripleJumpOnA: return m.setTripleJumpAction(s)
		return m.setJumpingAction(s, landing.aPressedAction, 0)
	if (m.input & inputOffFloor) != 0: return m.setMarioAction(s, landing.offFloorAction, 0)
	false

# act_jump_land and the other landings: a few frames in which A jumps again, then their stop
fn landingAction(mut m Mario, s Surfaces, anims {i64: n64.Animation}, animation i64):
	if m.commonLandingCancels(s, landingActionOf(m.action)): return true
	m.commonLandingAction(s, anims, animation, actFreefall)
	false
