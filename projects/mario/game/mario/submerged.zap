# Mario's actions in the water (mario_actions_submerged.c): the plunge into it, floating idle,
# the breaststroke and the flutter kick. The stick pitches and turns him, the water lifts him
# near its surface and sinks him below, a flowing current's floor carries him along, and he walks
# out where the floor rises above the surface.
#
# Not ported, each falling back to floating idle: holding things, the shell, punches and throws,
# knockbacks, shocks, whirlpools (their pull too), the metal cap's walking under water, and the
# water's death. Bubbles, splashes, waves and sounds are not drawn or played; Mario's head does
# not turn.

import n64

minSwimStrength = 160
minSwimSpeed f32 = 16.0

# sWaterCurrentSpeeds: a flowing current's speed by its force's upper byte
waterCurrentSpeeds = [28, 12, 8, 4]

# water step results (mario_step.h)
waterStepNone = 0
waterStepHitFloor = 1
waterStepHitCeiling = 2
waterStepCancelled = 3
waterStepHitWall = 4

surfaceFlowingWater = 0x000E

# mario_execute_submerged_action
fn executeSubmergedAction(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	mut cam Camera
) bool:
	if m.checkCommonSubmergedCancels(s, cam): return true
	m.quicksandDepth = 0.0
	a = m.action
	if a == actWaterIdle: return m.actWaterIdleStep(s, anims)
	if a == actWaterActionEnd: return m.actWaterActionEndStep(s, anims)
	if a == actDrowning: return m.actDrowningStep(s, anims)
	if a == actBreaststroke: return m.actBreaststrokeStep(s, anims)
	if a == actSwimmingEnd: return m.actSwimmingEndStep(s, anims)
	if a == actFlutterKick: return m.actFlutterKickStep(s, anims)
	if a == actWaterPlunge: return m.actWaterPlungeStep(s, anims)
	m.fallBack(s)

# check_common_submerged_cancels: out of the water where the floor rises over its surface, or
# held at the surface; drowning when his health runs out
fn checkCommonSubmergedCancels(mut m Mario, s Surfaces, mut cam Camera):
	if m.pos.y > f32(m.waterLevel - 80):
		if f32(m.waterLevel - 80) > m.floorHeight:
			m.pos.y = f32(m.waterLevel - 80)
		else:
			# (the shell he might hold is let go: holding is not ported)
			return m.transitionSubmergedToWalking(s, cam)
	if m.health < 0x100 and (m.action & (actFlagIntangible | actFlagInvulnerable)) == 0:
		m.setMarioAction(s, actDrowning, 0)
	false

# ---------- the water's step ----------

# swimming_near_surface
fn swimmingNearSurface(m Mario):
	if (m.flags & marioMetalCap) != 0: return false
	f32(m.waterLevel - 80) - m.pos.y < 400.0

# get_buoyancy: lifted near the surface, sinking a little below it while not swimming
fn getBuoyancy(m Mario):
	buoyancy f32 = 0.0
	if (m.flags & marioMetalCap) != 0:
		buoyancy = -18.0
		if (m.action & actFlagInvulnerable) != 0:
			buoyancy = -2.0
	elif m.swimmingNearSurface():
		buoyancy = 1.25
	elif (m.action & actFlagMoving) == 0:
		buoyancy = -2.0
	buoyancy

# perform_water_full_step: out of the walls, between the floor and the ceiling
fn performWaterFullStep(mut m Mario, s Surfaces, nextPos0 Vec3):
	nextPos = nextPos0
	wall = s.resolveAndReturnWallCollisions(nextPos, 10.0, 110.0)
	floorHeight, floor = s.findFloor(nextPos.x, nextPos.y, nextPos.z)
	ceilHeight, _ = s.vec3fFindCeil(nextPos, floorHeight)
	if floor < 0: return waterStepCancelled
	if nextPos.y >= floorHeight:
		if ceilHeight - nextPos.y >= 160.0:
			m.pos = nextPos
			m.floor = floor
			m.floorHeight = floorHeight
			return waterStepHitWall if wall >= 0 else waterStepNone
		if ceilHeight - floorHeight < 160.0: return waterStepCancelled
		# the water ceiling downwarp
		m.pos = Vec3(nextPos.x, ceilHeight - 160.0, nextPos.z)
		m.floor = floor
		m.floorHeight = floorHeight
		return waterStepHitCeiling
	if ceilHeight - floorHeight < 160.0: return waterStepCancelled
	m.pos = Vec3(nextPos.x, floorHeight, nextPos.z)
	m.floor = floor
	m.floorHeight = floorHeight
	waterStepHitFloor

# apply_water_current: a flowing current's floor carries him along (whirlpools are not ported)
fn applyWaterCurrent(m Mario, s Surfaces, step0 Vec3):
	step = step0
	f = s.all[m.floor]
	if f.kind == surfaceFlowingWater:
		currentAngle i64 = i16.wrap(f.force << 8)
		currentSpeed = f32(waterCurrentSpeeds[f.force >> 8])
		step.x += currentSpeed * sins(currentAngle)
		step.z += currentSpeed * coss(currentAngle)
	step

# perform_water_step: by his speed (and the current while he swims), kept 80 units under the surface
fn performWaterStep(mut m Mario, s Surfaces):
	step = m.vel
	if (m.action & actFlagSwimming) != 0:
		step = m.applyWaterCurrent(s, step)
	nextPos = m.pos + step
	if nextPos.y > f32(m.waterLevel - 80):
		nextPos.y = f32(m.waterLevel - 80)
		m.vel.y = 0.0
	stepResult = m.performWaterFullStep(s, nextPos)
	m.drawLift = 0.0
	m.drawPitch = i16.wrap(-m.facePitch)
	m.drawYaw = m.faceYaw
	m.drawRoll = m.faceRoll
	stepResult

# update_water_pitch: the model's pitch eased (raised a little when pointing down)
fn updateWaterPitch(mut m Mario):
	if m.drawPitch > 0:
		m.drawLift += 60.0 * sins(m.drawPitch) * sins(m.drawPitch)
	if m.drawPitch < 0:
		m.drawPitch = i16.wrap(m.drawPitch * 6 / 10)
	if m.drawPitch > 0:
		m.drawPitch = i16.wrap(m.drawPitch * 10 / 8)

# stationary_slow_down: still and level again, the water lifting or sinking him
fn stationarySlowDown(mut m Mario):
	buoyancy = m.getBuoyancy()
	m.angleVelPitch = 0
	m.angleVelYaw = 0
	m.forwardVel = approach(m.forwardVel, 0.0, 1.0, 1.0)
	m.vel.y = approach(m.vel.y, buoyancy, 2.0, 1.0)
	m.facePitch = i16.wrap(approach(m.facePitch, 0, 0x200, 0x200))
	m.faceRoll = i16.wrap(approach(m.faceRoll, 0, 0x100, 0x100))
	m.vel.x = m.forwardVel * coss(m.facePitch) * sins(m.faceYaw)
	m.vel.z = m.forwardVel * coss(m.facePitch) * coss(m.faceYaw)

# update_swimming_speed: slowing over `decelThreshold`, along his pitch and yaw
fn updateSwimmingSpeed(mut m Mario, decelThreshold f32):
	buoyancy = m.getBuoyancy()
	maxSpeed f32 = 28.0
	if (m.action & actFlagStationary) != 0:
		m.forwardVel -= 2.0
	if m.forwardVel < 0.0:
		m.forwardVel = 0.0
	if m.forwardVel > maxSpeed:
		m.forwardVel = maxSpeed
	if m.forwardVel > decelThreshold:
		m.forwardVel -= 0.5
	m.vel.x = m.forwardVel * coss(m.facePitch) * sins(m.faceYaw)
	m.vel.y = m.forwardVel * sins(m.facePitch) + buoyancy
	m.vel.z = m.forwardVel * coss(m.facePitch) * coss(m.faceYaw)

# update_swimming_yaw: the stick's x turns him, banking him
fn updateSwimmingYaw(mut m Mario):
	targetYawVel i64 = -i16.wrap(i64(10.0 * m.stickX))
	if targetYawVel > 0:
		if m.angleVelYaw < 0:
			m.angleVelYaw += 0x40
			if m.angleVelYaw > 0x10:
				m.angleVelYaw = 0x10
		else:
			m.angleVelYaw = i16.wrap(approach(m.angleVelYaw, targetYawVel, 0x10, 0x20))
	elif targetYawVel < 0:
		if m.angleVelYaw > 0:
			m.angleVelYaw -= 0x40
			if m.angleVelYaw < -0x10:
				m.angleVelYaw = -0x10
		else:
			m.angleVelYaw = i16.wrap(approach(m.angleVelYaw, targetYawVel, 0x20, 0x10))
	else:
		m.angleVelYaw = i16.wrap(approach(m.angleVelYaw, 0, 0x40, 0x40))
	m.faceYaw = i16.wrap(m.faceYaw + m.angleVelYaw)
	m.faceRoll = i16.wrap(-m.angleVelYaw * 8)

# update_swimming_pitch: the stick's y pitches him (up points him down)
fn updateSwimmingPitch(mut m Mario):
	targetPitch i64 = -i16.wrap(i64(252.0 * m.stickY))
	pitchVel = 0x100 if m.facePitch < 0 else 0x200
	if m.facePitch < targetPitch:
		m.facePitch = i16.wrap(m.facePitch + pitchVel)
		if m.facePitch > targetPitch:
			m.facePitch = targetPitch
	elif m.facePitch > targetPitch:
		m.facePitch = i16.wrap(m.facePitch - pitchVel)
		if m.facePitch < targetPitch:
			m.facePitch = targetPitch

# common_idle_step: floating, turned and pitched by the stick, its animation played at `accel`
# (0: at its own speed)
fn commonIdleStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}, animation i64, accel i64):
	m.updateSwimmingYaw()
	m.updateSwimmingPitch()
	m.updateSwimmingSpeed(minSwimSpeed)
	m.performWaterStep(s)
	m.updateWaterPitch()
	if accel == 0:
		m.setMarioAnimation(anims, animation)
	else:
		m.setMarioAnimWithAccel(anims, animation, accel)

# reset_float_globals: the bob on the surface after a stroke starts
fn resetFloatGlobals(mut m Mario):
	m.floatPhase = 0
	m.floatStep = 0x800
	m.floatHeight = f32(m.facePitch) / 256.0 + 20.0

# float_surface_gfx: the model bobbing at the surface, once
fn floatSurfaceGfx(mut m Mario):
	if m.floatStep != 0 and m.pos.y > f32(m.waterLevel - 85) and m.facePitch >= 0:
		m.floatPhase = i16.wrap(m.floatPhase + m.floatStep)
		if m.floatPhase >= 0:
			m.drawLift += m.floatHeight * sins(m.floatPhase)
			return
	m.floatStep = 0

# common_swimming_step: a stroke's step, his pitch kept off the floor and the ceiling and turned
# off a wall when the stick is let go
fn commonSwimmingStep(mut m Mario, s Surfaces, swimStrength i64):
	m.updateSwimmingYaw()
	m.updateSwimmingPitch()
	m.updateSwimmingSpeed(f32(swimStrength) / 10.0)
	stepResult = m.performWaterStep(s)
	if stepResult == waterStepHitFloor:
		floorPitch i64 = i16.wrap(-m.findFloorSlope(s, -0x8000))
		if m.facePitch < floorPitch:
			m.facePitch = floorPitch
	elif stepResult == waterStepHitCeiling:
		if m.facePitch > -0x3000:
			m.facePitch = i16.wrap(m.facePitch - 0x100)
	elif stepResult == waterStepHitWall:
		if m.stickY == 0.0:
			if f32(m.facePitch) > 0.0:
				m.facePitch = i16.wrap(m.facePitch + 0x200)
				if m.facePitch > 0x3F00:
					m.facePitch = 0x3F00
			else:
				m.facePitch = i16.wrap(m.facePitch - 0x200)
				if m.facePitch < -0x3F00:
					m.facePitch = -0x3F00
	m.updateWaterPitch()
	m.floatSurfaceGfx()

# check_water_jump: out of the water when A is pressed at its surface with the stick held back
fn checkWaterJump(mut m Mario, s Surfaces):
	probe = i64(m.pos.y + 1.5)
	if (m.input & inputAPressed) != 0:
		if probe >= m.waterLevel - 80 and m.facePitch >= 0 and m.stickY < -60.0:
			m.angleVelPitch = 0
			m.angleVelYaw = 0
			m.angleVelRoll = 0
			m.vel.y = 62.0
			return m.setMarioAction(s, actWaterJump, 0)
	false

# ---------- the actions ----------

# act_water_idle (the metal cap and B's punch are not ported)
fn actWaterIdleStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputAPressed) != 0: return m.setMarioAction(s, actBreaststroke, 0)
	accel = 0x1_0000
	if m.facePitch < -0x1000:
		accel = 0x3_0000
	m.commonIdleStep(s, anims, animWaterIdle, accel)
	false

# act_water_action_end: the end of a stroke, then idle
fn actWaterActionEndStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputAPressed) != 0: return m.setMarioAction(s, actBreaststroke, 0)
	m.commonIdleStep(s, anims, animWaterActionEnd, 0)
	if m.isAnimAtEnd():
		m.setMarioAction(s, actWaterIdle, 0)
	false

# act_breaststroke: a stroke, faster when A is pressed again early in it, a flutter kick when A
# is held through it
fn actBreaststrokeStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.actionArg == 0:
		m.swimStrength = minSwimStrength
	m.actionTimer += 1
	if m.actionTimer == 14: return m.setMarioAction(s, actFlutterKick, 0)
	if m.checkWaterJump(s): return true
	if m.actionTimer < 6:
		m.forwardVel += 0.5
	if m.actionTimer >= 9:
		m.forwardVel += 1.5
	if m.actionTimer >= 2:
		if m.actionTimer < 6 and (m.input & inputAPressed) != 0:
			m.actionState = 1
		if m.actionTimer == 9 and m.actionState == 1:
			m.setAnimToFrame(0)
			m.actionState = 0
			m.actionTimer = 1
			m.swimStrength = minSwimStrength
	if m.actionTimer == 1:
		m.resetFloatGlobals()
	m.setMarioAnimation(anims, animSwimPart1)
	m.commonSwimmingStep(s, m.swimStrength)
	false

# act_swimming_end: the stroke's glide; held A strokes again, stronger
fn actSwimmingEndStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.actionTimer >= 15: return m.setMarioAction(s, actWaterActionEnd, 0)
	if m.checkWaterJump(s): return true
	if (m.input & inputADown) != 0 and m.actionTimer >= 7:
		if m.actionTimer == 7 and m.swimStrength < 280:
			m.swimStrength += 10
		return m.setMarioAction(s, actBreaststroke, 1)
	if m.actionTimer >= 7:
		m.swimStrength = minSwimStrength
	m.actionTimer += 1
	m.forwardVel -= 0.25
	m.setMarioAnimation(anims, animSwimPart2)
	m.commonSwimmingStep(s, m.swimStrength)
	false

# act_flutter_kick: kicking while A is held, toward 12 units a frame
fn actFlutterKickStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if (m.input & inputADown) == 0:
		if m.actionTimer == 0 and m.swimStrength < 280:
			m.swimStrength += 10
		return m.setMarioAction(s, actSwimmingEnd, 0)
	m.forwardVel = approach(m.forwardVel, 12.0, 0.1, 0.15)
	m.actionTimer = 1
	m.swimStrength = minSwimStrength
	if m.forwardVel < 14.0:
		m.setMarioAnimation(anims, animFlutterkick)
	m.commonSwimmingStep(s, m.swimStrength)
	false

# act_drowning: his last breath (the warp to his death is not ported)
fn actDrowningStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	if m.actionState == 0:
		m.setMarioAnimation(anims, animDrowningPart1)
		if m.isAnimAtEnd():
			m.actionState = 1
	elif m.actionState == 1:
		m.setMarioAnimation(anims, animDrowningPart2)
	m.stationarySlowDown()
	m.performWaterStep(s)
	false

# act_water_plunge: sinking from the fall into the water until it stops him (or the floor does,
# or 20 frames pass), then the end of a stroke, or a flutter kick when A is held (or he dived)
fn actWaterPlungeStep(mut m Mario, s Surfaces, anims {i64: n64.Animation}):
	# (holding something and the metal cap change what follows: not ported)
	stateFlags = 0
	endVSpeed = -5.0
	if m.swimmingNearSurface():
		endVSpeed = 0.0
	if (m.prevAction & actFlagDiving) != 0 or (m.input & inputADown) != 0:
		stateFlags |= 2
	m.actionTimer += 1
	m.stationarySlowDown()
	stepResult = m.performWaterStep(s)
	if m.actionState == 0:
		m.actionState = 1
	if stepResult == waterStepHitFloor or m.vel.y >= endVSpeed or m.actionTimer > 20:
		if stateFlags == 0:
			m.setMarioAction(s, actWaterActionEnd, 0)
		else:
			m.setMarioAction(s, actFlutterKick, 0)
		m.floatStep = 0
	if stateFlags == 0:
		m.setMarioAnimation(anims, animWaterActionEnd)
	else:
		m.setMarioAnimation(anims, animFlutterkick)
	false
