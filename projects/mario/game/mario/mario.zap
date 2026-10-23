# Mario, as the game moves him 30 times a second (mario.c): the stick and the buttons become
# what he means to do (how far and which way, seen from the camera), the level around him is
# looked up, then his action runs, and runs again while it hands over to another in the same
# frame. Before it, the objects he touched are dealt with (interaction.zap). The actions live in
# stationary.zap, moving.zap, airborne.zap and submerged.zap and step him with step.zap, each a
# port of the game's function of the name given beside it. Angles are the game's (trig.zap):
# 0x10000 a turn, a yaw of 0 facing +z, sins(yaw) the x of that direction.
#
# Not ported yet, each falling back to the nearest supported action of its group (see
# fallBack): holding, riding, shockwaves, squishing, special floors (death planes, warps),
# first person, the B button's punches, kicks and dives, ground pounds, wall kicks and bonks,
# ledge grabs and climbs, poles, crawling, sleeping, panting, knockbacks, the metal cap under
# water, deaths, and the automatic, cutscene and object actions.

import n64

pub type Controls:
	stickX f32   # -64..64, right
	stickY f32   # -64..64, up (away from the camera)
	aPressed bool   # jump
	aDown bool
	zPressed bool   # crouch
	zDown bool
	cPressed i64   # the C buttons pressed this frame (camera.zap's cButton*)
	cDown i64   # and held

# struct MarioState, the parts of it this port moves (and the parts of his object it reads)
pub type Mario:
	pos Vec3
	vel Vec3
	forwardVel f32
	slideVelX f32
	slideVelZ f32
	slideYaw i64
	faceYaw i64   # faceAngle[1]
	facePitch i64   # faceAngle[0]
	faceRoll i64   # faceAngle[2]
	angleVelPitch i64   # angleVel
	angleVelYaw i64
	angleVelRoll i64
	drawYaw i64   # the model's turn (header.gfx.angle[1]): his face, but where an action turns it alone
	drawPitch i64   # header.gfx.angle[0]
	drawRoll i64   # header.gfx.angle[2]
	drawLift f32   # how far over his place the model is drawn (header.gfx.pos[1] - pos[1])
	walkingPitch i64   # oMarioWalkingPitch, the model leaning into a slope while he runs
	intendedMag f32
	intendedYaw i64
	stickX f32   # the controller's stick, as the swimming actions read it
	stickY f32
	input i64
	flags i64
	action i64
	prevAction i64
	actionArg i64
	actionState i64
	actionTimer i64
	framesSinceA i64
	floor i64   # an index into the level's surfaces, -1 none
	floorHeight f32
	floorAngle i64
	ceil i64
	ceilHeight f32
	wall i64
	waterLevel i64
	peakHeight f32
	quicksandDepth f32
	squishTimer i64
	doubleJumpTimer i64
	wallKickTimer i64
	health i64
	hurtCounter i64
	healCounter i64
	invincTimer i64
	collidedObjInteractTypes i64
	interactObj i64   # an index of the level's objects, -1 none
	usedObj i64
	polePos f32   # oMarioPolePos
	poleYawVel i64   # oMarioPoleYawVel
	poleUnk108 i64   # oMarioPoleUnk108
	swimStrength i64   # sSwimStrength
	floatPhase i64   # D_80339FD0: the bob on the water's surface after a stroke
	floatStep i64   # D_80339FD2
	floatHeight f32   # D_80339FD4
	# m->statusForCamera: what the camera reads of him (update_mario_info_for_cam)
	camPos Vec3
	camFacePitch i64
	camFaceYaw i64
	camAction i64
	longJumpIsSlow bool   # oMarioLongJumpIsSlow
	steepJumpYaw i64   # oMarioSteepJumpYaw
	ticks i64   # gGlobalTimer
	# his animation (header.gfx.unk38): which, its frame, and the parts of its header read
	anim i64
	animFrame i64
	animAccel i64
	animAssist i64   # animFrameAccelAssist: the frame in 16.16
	animFlags i64
	animStart i64
	animLoopStart i64
	animLoopEnd i64

# input flags (sm64.h)
inputNonzeroAnalog = 0x0001
inputAPressed = 0x0002
inputOffFloor = 0x0004
inputInPoisonGas = 0x0100
inputAboveSlide = 0x0008
inputFirstPerson = 0x0010
inputNoMovement = 0x0020   # INPUT_UNKNOWN_5
inputSquished = 0x0040
inputADown = 0x0080
inputInWater = 0x0200
inputBPressed = 0x2000
inputZDown = 0x4000
inputZPressed = 0x8000

# Mario's flags
marioNormalCap = 0x0000_0001
marioVanishCap = 0x0000_0002
marioMetalCap = 0x0000_0004
marioWingCap = 0x0000_0008
marioCapOnHead = 0x0000_0010
marioJumpHeightControl = 0x0000_0100   # MARIO_UNKNOWN_08: a jump A was pressed for; never cleared here
marioActionSoundPlayed = 0x0001_0000
marioMarioSoundPlayed = 0x0002_0000
marioFarFallSound = 0x0004_0000   # MARIO_UNKNOWN_18
pub marioPunching = 0x0010_0000
marioKicking = 0x0020_0000
marioTripping = 0x0040_0000
marioUnknown25 = 0x0200_0000   # his place is not passed on to the camera
marioAirWallHit = 0x4000_0000   # MARIO_UNKNOWN_30
marioPushingWall = 0x8000_0000   # MARIO_UNKNOWN_31

# action groups and flags: the group is action & 0x1C0
actGroupMask = 0x1C0
actGroupStationary = 0x000
actGroupMoving = 0x040
actGroupAirborne = 0x080
actGroupSubmerged = 0x0C0
actIdMask = 0x1FF
actFlagStationary = 0x0000_0200
actFlagMoving = 0x0000_0400
actFlagAir = 0x0000_0800
actFlagIntangible = 0x0000_1000
actFlagSwimming = 0x0000_2000
actFlagMetalWater = 0x0000_4000
actFlagShortHitbox = 0x0000_8000
actFlagRidingShell = 0x0001_0000
actFlagInvulnerable = 0x0002_0000
actFlagDiving = 0x0008_0000
actFlagOnPole = 0x0010_0000
actFlagHanging = 0x0020_0000
actFlagControlJumpHeight = 0x0200_0000
actFlagAllowFirstPerson = 0x0400_0000

# actions (sm64.h)
pub actIdle = 0x0C40_0201
pub actStartSleeping = 0x0C40_0202
pub actStandingAgainstWall = 0x0C40_0209
pub actCrouching = 0x0C00_8220
pub actStartCrouching = 0x0C00_8221
pub actStopCrouching = 0x0C00_8222
pub actStartCrawling = 0x0C00_8223
pub actBackflipLandStop = 0x0800_022F
pub actJumpLandStop = 0x0C00_0230
pub actDoubleJumpLandStop = 0x0C00_0231
pub actFreefallLandStop = 0x0C00_0232
pub actSideFlipLandStop = 0x0C00_0233
pub actTripleJumpLandStop = 0x0800_023A
pub actLongJumpLandStop = 0x0800_023B
pub actBrakingStop = 0x0C00_023D
pub actButtSlideStop = 0x0C00_023E
pub actWalking = 0x0400_0440
pub actTurningAround = 0x0000_0443
pub actFinishTurningAround = 0x0000_0444
pub actBraking = 0x0400_0445
pub actCrawling = 0x0400_8448
pub actDecelerating = 0x0400_044A
pub actBeginSliding = 0x0000_0050
pub actButtSlide = 0x0084_0452
pub actStomachSlide = 0x008C_0453
pub actMovePunching = 0x0080_0457
pub actCrouchSlide = 0x0480_8459
pub actHardBackwardGroundKb = 0x0002_0460
pub actBackwardGroundKb = 0x0002_0462
pub actGroundBonk = 0x0002_0466
pub actJumpLand = 0x0400_0470
pub actFreefallLand = 0x0400_0471
pub actDoubleJumpLand = 0x0400_0472
pub actSideFlipLand = 0x0400_0473
pub actQuicksandJumpLand = 0x0000_0476
pub actTripleJumpLand = 0x0400_0478
pub actLongJumpLand = 0x0000_0479
pub actBackflipLand = 0x0400_047A
pub actJump = 0x0300_0880
pub actDoubleJump = 0x0300_0881
pub actTripleJump = 0x0100_0882
pub actBackflip = 0x0100_0883
pub actSteepJump = 0x0300_0885
pub actWallKickAir = 0x0300_0886
pub actSideFlip = 0x0100_0887
pub actLongJump = 0x0300_0888
pub actDive = 0x0188_088A
pub actFreefall = 0x0100_088C
pub actButtSlideAir = 0x0300_088E
pub actFlyingTripleJump = 0x0300_0894
pub actFlying = 0x1088_0899
pub actTwirling = 0x1080_08A4
pub actForwardRollout = 0x0100_08A6
pub actAirHitWall = 0x0000_08A7
pub actGroundPound = 0x0080_08A9
pub actSlideKick = 0x0180_08AA
pub actJumpKick = 0x0180_08AC
pub actBackwardRollout = 0x0100_08AD
pub actBackwardAirKb = 0x0102_08B0
pub actSoftBonk = 0x0102_08B6
pub actQuicksandDeath = 0x0002_1312
pub actSleeping = 0x0C00_0203
pub actFirstPerson = 0x0C00_0227
pub actRidingHoot = 0x0000_04A8
pub actWaterJump = 0x0100_0889
pub actShotFromCannon = 0x0088_0898
pub actHoldWaterJump = 0x0100_08A3
pub actWaterIdle = 0x3800_22C0
pub actWaterActionEnd = 0x3000_22C2
pub actDrowning = 0x3000_32C4
pub actBreaststroke = 0x3000_24D0
pub actSwimmingEnd = 0x3000_24D1
pub actFlutterKick = 0x3000_24D2
pub actWaterShellSwimming = 0x3000_24D6
pub actWaterPlunge = 0x3000_22E2
pub actMetalWaterJump = 0x0000_44F8
pub actHoldMetalWaterJump = 0x0000_44F9
pub actGrabPoleSlow = 0x0010_0341
pub actGrabPoleFast = 0x0010_0342
pub actTopOfPole = 0x0010_0345
pub actStartHanging = 0x0820_0348
pub actLedgeGrab = 0x0800_034B
pub actLedgeClimbDown = 0x0000_054E
pub actPunching = 0x0080_0380
pub actStomachSlideStop = 0x0000_0386

# animations (mario_animation_ids.h)
pub animBackflip = 0x04
pub animSkidOnGround = 0x0F
pub animStopSkid = 0x10
pub animCrouchFromFastLongJump = 0x11
pub animCrouchFromSlowLongJump = 0x12
pub animFastLongJump = 0x13
pub animSlowLongJump = 0x14
pub animClimbDownLedge = 0x1C
pub animIdleOnLedge = 0x33
pub animWalking = 0x48
pub animLandFromDoubleJump = 0x4B
pub animDoubleJumpFall = 0x4C
pub animSingleJump = 0x4D
pub animLandFromSingleJump = 0x4E
pub animDoubleJumpRise = 0x50
pub animFallFromSlideKick = 0x53
pub animGeneralFall = 0x56
pub animGeneralLand = 0x57
pub animPushing = 0x6C
pub animRunning = 0x72
pub animStandAgainstWall = 0x7E
pub animSidestepLeft = 0x7F
pub animSidestepRight = 0x80
pub animSlideDive = 0x89
pub animStopSlide = 0x8F
pub animFallFromSlide = 0x90
pub animSlide = 0x91
pub animTiptoe = 0x92
pub animStopCrouching = 0x96
pub animStartCrouching = 0x97
pub animCrouching = 0x98
pub animTurningPart1 = 0xBC
pub animTurningPart2 = 0xBD
pub animSlideflipLand = 0xBE
pub animSlideflip = 0xBF
pub animTripleJumpLand = 0xC0
pub animTripleJump = 0xC1
pub animIdleHeadLeft = 0xC3
pub animIdleHeadRight = 0xC4
pub animIdleHeadCenter = 0xC5
pub animStartTiptoe = 0xCA
pub animDrowningPart1 = 0xA5
pub animDrowningPart2 = 0xA6
pub animSwimPart1 = 0xAA
pub animSwimPart2 = 0xAB
pub animFlutterkick = 0xAC
pub animWaterActionEnd = 0xAD
pub animWaterIdle = 0xB2

# the animations Mario uses, read once
pub usedAnimations = [
	animBackflip,
	animSkidOnGround,
	animStopSkid,
	animCrouchFromFastLongJump,
	animCrouchFromSlowLongJump,
	animFastLongJump,
	animSlowLongJump,
	animClimbDownLedge,
	animIdleOnLedge,
	animWalking,
	animLandFromDoubleJump,
	animDoubleJumpFall,
	animSingleJump,
	animLandFromSingleJump,
	animDoubleJumpRise,
	animFallFromSlideKick,
	animGeneralFall,
	animGeneralLand,
	animPushing,
	animRunning,
	animStandAgainstWall,
	animSidestepLeft,
	animSidestepRight,
	animSlideDive,
	animStopSlide,
	animFallFromSlide,
	animSlide,
	animTiptoe,
	animStopCrouching,
	animStartCrouching,
	animCrouching,
	animTurningPart1,
	animTurningPart2,
	animSlideflipLand,
	animSlideflip,
	animTripleJumpLand,
	animTripleJump,
	animIdleHeadLeft,
	animIdleHeadRight,
	animIdleHeadCenter,
	animStartTiptoe,
	animDrowningPart1, animDrowningPart2, animSwimPart1, animSwimPart2, animFlutterkick, animWaterActionEnd, animWaterIdle]

# animation flags (types.h)
animFlagNoLoop = 0x01
animFlagForward = 0x02   # played from its end toward its start
animFlagFrozen = 0x04   # ANIM_FLAG_2

# surface types (surface_terrains.h) and the classes of how slippery they are
surfaceBurning = 0x0001
surfaceHangable = 0x0005
surfaceSlow = 0x0009
surfaceVerySlippery = 0x0013
surfaceSlippery = 0x0014
surfaceNotSlippery = 0x0015
surfaceShallowQuicksand = 0x0021
surfaceDeepQuicksand = 0x0022
surfaceInstantQuicksand = 0x0023
surfaceDeepMovingQuicksand = 0x0024
surfaceShallowMovingQuicksand = 0x0025
surfaceQuicksand = 0x0026
surfaceMovingQuicksand = 0x0027
surfaceNoiseSlippery = 0x002A
surfaceHorizontalWind = 0x002C
surfaceInstantMovingQuicksand = 0x002D
surfaceHard = 0x0030
surfaceHardSlippery = 0x0035
surfaceHardVerySlippery = 0x0036
surfaceHardNotSlippery = 0x0037
surfaceVerticalWind = 0x0038
surfaceNoiseVerySlippery73 = 0x0073
surfaceNoiseVerySlippery74 = 0x0074
surfaceNoiseVerySlippery = 0x0075
surfaceNoCamColVerySlippery = 0x0078
surfaceNoCamColSlippery = 0x0079
surfaceSwitch = 0x007A
classDefault = 0x0000
classVerySlippery = 0x0013
classSlippery = 0x0014
classNotSlippery = 0x0015

# the level's terrain (its script's TERRAIN_TYPE): Castle Grounds is grass
terrainGrass = 0
terrainSnow = 2
terrainSand = 3
terrainSlide = 6
terrainType = terrainGrass

# ---------- the start, the frame ----------

# init_mario: standing where the level puts him (on the floor under him), facing its way; in
# the water when he starts under it
pub fn newMario(s Surfaces, x f32, y f32, z f32, yaw i64) Mario:
	m = Mario(
		pos = Vec3(x, y, z),
		vel = Vec3(0.0, 0.0, 0.0),
		forwardVel = 0.0,
		slideVelX = 0.0,
		slideVelZ = 0.0,
		slideYaw = 0,
		faceYaw = i16.wrap(yaw),
		facePitch = 0,
		faceRoll = 0,
		angleVelPitch = 0,
		angleVelYaw = 0,
		angleVelRoll = 0,
		drawYaw = i16.wrap(yaw),
		drawPitch = 0,
		drawRoll = 0,
		drawLift = 0.0,
		walkingPitch = 0,
		intendedMag = 0.0,
		intendedYaw = i16.wrap(yaw),
		stickX = 0.0,
		stickY = 0.0,
		input = 0,
		flags = marioCapOnHead | marioNormalCap,
		action = actIdle,
		prevAction = 0,
		actionArg = 0,
		actionState = 0,
		actionTimer = 0,
		framesSinceA = 0xFF,
		floor = -1,
		floorHeight = 0.0,
		floorAngle = 0,
		ceil = -1,
		ceilHeight = 0.0,
		wall = -1,
		waterLevel = i64(s.waterLevel(x, z)),
		peakHeight = y,
		quicksandDepth = 0.0,
		squishTimer = 0,
		doubleJumpTimer = 0,
		wallKickTimer = 0,
		health = 0x880,
		hurtCounter = 0,
		healCounter = 0,
		invincTimer = 0,
		collidedObjInteractTypes = 0,
		interactObj = -1,
		usedObj = -1,
		polePos = 0.0,
		poleYawVel = 0,
		poleUnk108 = 0,
		swimStrength = minSwimStrength,
		floatPhase = 0,
		floatStep = 0,
		floatHeight = 0.0,
		camPos = Vec3(x, y, z),
		camFacePitch = 0,
		camFaceYaw = i16.wrap(yaw),
		camAction = 0,
		longJumpIsSlow = false,
		steepJumpYaw = 0,
		ticks = 0,
		anim = -1,
		animFrame = 0,
		animAccel = 0,
		animAssist = 0,
		animFlags = 0,
		animStart = 0,
		animLoopStart = 0, animLoopEnd = 0)
	floorHeight, floor = s.findFloor(m.pos.x, m.pos.y, m.pos.z)
	m.floorHeight = floorHeight
	m.floor = floor
	if m.pos.y < m.floorHeight:
		m.pos.y = m.floorHeight
	m.action = actWaterIdle if m.pos.y <= f32(m.waterLevel - 100) else actIdle
	m.updateMarioInfoForCam()
	m

# bhv_mario_update: execute_mario_action, then his object takes his place
# (copy_mario_state_to_object), then the drawing's step of his animation
# (geo_update_animation_frame, which the game runs when it draws him after the frame). The camera
# is the last frame's: Mario reads its yaw, and his code may switch its mode.
pub fn stepMario(
	mut m Mario,
	s Surfaces,
	anims {i64: n64.Animation},
	c Controls,
	mut cam Camera,
	mut objs Objects
):
	if m.action == 0: return
	m.updateMarioInputs(s, c, cam, objs)
	# (mario_handle_special_floors: death planes, warps and lava are not ported)
	m.marioProcessInteractions(s, cam, objs)
	# out of bounds: actions stop (the game warps him to his death)
	if m.floor < 0: return
	# the game loops while an action hands over in the same frame (a loop of actions would hang it; this stops)
	loop 100:
		group = m.action & actGroupMask
		inLoop = false
		if group == actGroupStationary:
			inLoop = m.executeStationaryAction(s, anims, cam)
		elif group == actGroupMoving:
			inLoop = m.executeMovingAction(s, anims, cam)
		elif group == actGroupAirborne:
			inLoop = m.executeAirborneAction(s, anims, cam)
		elif group == actGroupSubmerged:
			inLoop = m.executeSubmergedAction(s, anims, cam)
		else:
			# cutscene, automatic and object actions: none is ported
			inLoop = m.setMarioAction(s, actIdle, 0)
		if not inLoop: break
	m.squishMarioModel()
	m.setSubmergedCamPresetAndSpawnBubbles(cam)
	m.updateMarioHealth(s)
	m.updateMarioInfoForCam()
	m.marioUpdateHitboxAndCapModel(objs)
	m.copyMarioStateToObject(objs)
	m.ticks += 1
	m.advanceAnimation()

# update_mario_info_for_cam: what the camera reads of him
fn updateMarioInfoForCam(mut m Mario):
	m.camAction = m.action
	m.camFacePitch = m.facePitch
	m.camFaceYaw = m.faceYaw
	if (m.flags & marioUnknown25) == 0:
		m.camPos = m.pos

# an action that is not ported, swapped for the nearest one that is (its group's plainest)
fn fallBack(mut m Mario, s Surfaces) bool:
	group = m.action & actGroupMask
	if group == actGroupMoving: return m.setMarioAction(s, actDecelerating, 0)
	if group == actGroupAirborne: return m.setMarioAction(s, actFreefall, 0)
	if group == actGroupSubmerged: return m.setMarioAction(s, actWaterIdle, 0)
	m.setMarioAction(s, actIdle, 0)

# ---------- inputs ----------

# update_mario_inputs
fn updateMarioInputs(mut m Mario, s Surfaces, c Controls, mut cam Camera, objs Objects):
	m.input = 0
	m.collidedObjInteractTypes = objs.all[0].collidedObjInteractTypes
	m.flags &= 0xFF_FFFF
	m.updateMarioButtonInputs(c)
	m.updateMarioJoystickInputs(c, cam.yaw)
	m.updateMarioGeometryInputs(s)
	if (cam.movementFlags & camMoveCUpMode) != 0:
		if (m.action & actFlagAllowFirstPerson) != 0:
			m.input |= inputFirstPerson
		else:
			cam.movementFlags &= ~camMoveCUpMode
	if (m.input & (inputNonzeroAnalog | inputAPressed)) == 0:
		m.input |= inputNoMovement
	# (INPUT_UNKNOWN_10, set by hoots and shockwaves through his object: not ported)
	if m.wallKickTimer > 0:
		m.wallKickTimer -= 1
	if m.doubleJumpTimer > 0:
		m.doubleJumpTimer -= 1

# update_mario_button_inputs (no B button yet)
fn updateMarioButtonInputs(mut m Mario, c Controls):
	if c.aPressed:
		m.input |= inputAPressed
	if c.aDown:
		m.input |= inputADown
	if m.squishTimer == 0:
		if c.zDown:
			m.input |= inputZDown
		if c.zPressed:
			m.input |= inputZPressed
	if (m.input & inputAPressed) != 0:
		m.framesSinceA = 0
	elif m.framesSinceA < 0xFF:
		m.framesSinceA += 1

# update_mario_joystick_inputs, the stick held to 64 as adjust_analog_stick holds it
fn updateMarioJoystickInputs(mut m Mario, c Controls, cameraYaw i64):
	stickX = c.stickX
	stickY = c.stickY
	stickMag = (stickX * stickX + stickY * stickY).sqrt()
	if stickMag > 64.0:
		stickX *= 64.0 / stickMag
		stickY *= 64.0 / stickMag
		stickMag = 64.0
	m.stickX = stickX
	m.stickY = stickY
	mag = stickMag / 64.0 * (stickMag / 64.0) * 64.0
	m.intendedMag = mag / 2.0 if m.squishTimer == 0 else mag / 8.0
	if m.intendedMag > 0.0:
		m.intendedYaw = i16.wrap(atan2s(-stickY, stickX) + cameraYaw)
		m.input |= inputNonzeroAnalog
	else:
		m.intendedYaw = m.faceYaw

# update_mario_geometry_inputs: the walls around him pushed out of, the floor under him, the
# ceiling over it, the water
fn updateMarioGeometryInputs(mut m Mario, s Surfaces):
	s.resolveAndReturnWallCollisions(m.pos, 60.0, 50.0)
	s.resolveAndReturnWallCollisions(m.pos, 30.0, 24.0)
	floorHeight, floor = s.findFloor(m.pos.x, m.pos.y, m.pos.z)
	m.floorHeight = floorHeight
	m.floor = floor
	ceilHeight, ceil = s.vec3fFindCeil(m.pos, m.floorHeight)
	m.ceilHeight = ceilHeight
	m.ceil = ceil
	gasLevel = s.poisonGasLevel(m.pos.x, m.pos.z)
	m.waterLevel = i64(s.waterLevel(m.pos.x, m.pos.z))
	if m.floor >= 0:
		f = s.all[m.floor]
		m.floorAngle = atan2s(f.normal.z, f.normal.x)
		if m.pos.y > f32(m.waterLevel - 40) and m.marioFloorIsSlippery(s):
			m.input |= inputAboveSlide
		if m.pos.y > m.floorHeight + 100.0:
			m.input |= inputOffFloor
		if m.pos.y < f32(m.waterLevel - 10):
			m.input |= inputInWater
		if m.pos.y < gasLevel - 100.0:
			m.input |= inputInPoisonGas

# ---------- changing action ----------

# set_mario_action: what starting a moving or an airborne action does, then the action
fn setMarioAction(mut m Mario, s Surfaces, action0 i64, actionArg i64):
	action = action0
	group = action & actGroupMask
	if group == actGroupMoving:
		action = m.setMarioActionMoving(s, action)
	elif group == actGroupAirborne:
		action = m.setMarioActionAirborne(action, actionArg)
	elif group == actGroupSubmerged:
		action = m.setMarioActionSubmerged(action)
	# (set_mario_action_cutscene: no cutscene action is ported)
	m.flags &= ~(marioActionSoundPlayed | marioMarioSoundPlayed)
	if (m.action & actFlagAir) == 0:
		m.flags &= ~marioFarFallSound
	m.prevAction = m.action
	m.action = action
	m.actionArg = actionArg
	m.actionState = 0
	m.actionTimer = 0
	true

# drop_and_set_mario_action (he holds nothing yet)
fn dropAndSetMarioAction(mut m Mario, s Surfaces, action i64, actionArg i64) bool:
	m.setMarioAction(s, action, actionArg)

# set_mario_action_submerged: the metal cap's jump under water starts upward
fn setMarioActionSubmerged(mut m Mario, action i64):
	if action == actMetalWaterJump or action == actHoldMetalWaterJump:
		m.vel.y = 32.0
	action

# set_mario_y_vel_based_on_fspeed
fn setMarioYVelBasedOnFspeed(mut m Mario, initialVelY f32, multiplier f32):
	m.vel.y = initialVelY + 0.0 + m.forwardVel * multiplier
	if m.squishTimer != 0 or m.quicksandDepth > 1.0:
		m.vel.y *= 0.5

# set_mario_action_airborne
fn setMarioActionAirborne(mut m Mario, action0 i64, actionArg i64):
	action = action0
	if m.squishTimer != 0 or m.quicksandDepth >= 1.0:
		if action == actDoubleJump or action == actTwirling:
			action = actJump
	if action == actDoubleJump:
		m.setMarioYVelBasedOnFspeed(52.0, 0.25)
		m.forwardVel *= 0.8
	elif action == actBackflip:
		m.anim = -1
		m.forwardVel = -16.0
		m.setMarioYVelBasedOnFspeed(62.0, 0.0)
	elif action == actTripleJump:
		m.setMarioYVelBasedOnFspeed(69.0, 0.0)
		m.forwardVel *= 0.8
	elif action == actFlyingTripleJump:
		m.setMarioYVelBasedOnFspeed(82.0, 0.0)
	elif action == actWaterJump or action == actHoldWaterJump:
		if actionArg == 0:
			m.setMarioYVelBasedOnFspeed(42.0, 0.0)
	elif action == actJump:
		m.anim = -1
		m.setMarioYVelBasedOnFspeed(42.0, 0.25)
		m.forwardVel *= 0.8
	elif action == actWallKickAir:
		m.setMarioYVelBasedOnFspeed(62.0, 0.0)
		if m.forwardVel < 24.0:
			m.forwardVel = 24.0
		m.wallKickTimer = 0
	elif action == actSideFlip:
		m.setMarioYVelBasedOnFspeed(62.0, 0.0)
		m.forwardVel = 8.0
		m.faceYaw = m.intendedYaw
	elif action == actSteepJump:
		m.anim = -1
		m.setMarioYVelBasedOnFspeed(42.0, 0.25)
		m.facePitch = -0x2000
	elif action == actDive:
		forwardVel = m.forwardVel + 15.0
		if forwardVel > 48.0:
			forwardVel = 48.0
		m.marioSetForwardVel(forwardVel)
	elif action == actLongJump:
		m.anim = -1
		m.setMarioYVelBasedOnFspeed(30.0, 0.0)
		m.longJumpIsSlow = not (m.forwardVel > 16.0)
		m.forwardVel *= 1.5
		if m.forwardVel > 48.0:
			m.forwardVel = 48.0
	elif action == actSlideKick:
		m.vel.y = 12.0
		if m.forwardVel < 32.0:
			m.forwardVel = 32.0
	elif action == actJumpKick:
		m.vel.y = 20.0
	m.peakHeight = m.pos.y
	m.flags |= marioJumpHeightControl
	action

# set_mario_action_moving
fn setMarioActionMoving(mut m Mario, s Surfaces, action0 i64):
	action = action0
	floorClass = m.marioGetFloorClass(s)
	forwardVel = m.forwardVel
	mag = m.intendedMag if m.intendedMag < 8.0 else 8.0
	if action == actWalking:
		if floorClass != classVerySlippery:
			if 0.0 <= forwardVel and forwardVel < mag:
				m.forwardVel = mag
		m.walkingPitch = 0
	elif action == actBeginSliding:
		action = actButtSlide if m.marioFacingDownhill(false) else actStomachSlide
	action

# set_jump_from_landing: a jump, a double jump just after landing from one, a triple jump after
# a double one at speed
fn setJumpFromLanding(mut m Mario, s Surfaces):
	if m.quicksandDepth >= 11.0: return m.setMarioAction(s, actQuicksandJumpLand, 0)
	if m.marioFloorIsSteep(s):
		m.setSteepJumpAction(s)
	elif m.doubleJumpTimer == 0 or m.squishTimer != 0:
		m.setMarioAction(s, actJump, 0)
	elif m.prevAction in [actJumpLand, actFreefallLand, actSideFlipLandStop]:
		m.setMarioAction(s, actDoubleJump, 0)
	elif m.prevAction == actDoubleJumpLand:
		if (m.flags & marioWingCap) != 0:
			m.setMarioAction(s, actFlyingTripleJump, 0)
		elif m.forwardVel > 20.0:
			m.setMarioAction(s, actTripleJump, 0)
		else:
			m.setMarioAction(s, actJump, 0)
	else:
		m.setMarioAction(s, actJump, 0)
	m.doubleJumpTimer = 0
	true

# set_jumping_action: `action`, unless the floor is too steep to jump from
fn setJumpingAction(mut m Mario, s Surfaces, action i64, actionArg i64):
	if m.quicksandDepth >= 11.0: return m.setMarioAction(s, actQuicksandJumpLand, 0)
	if m.marioFloorIsSteep(s):
		m.setSteepJumpAction(s)
	else:
		m.setMarioAction(s, action, actionArg)
	true

# set_steep_jump_action
fn setSteepJumpAction(mut m Mario, s Surfaces):
	m.steepJumpYaw = m.faceYaw
	if m.forwardVel > 0.0:
		angleTemp i64 = i16.wrap(m.floorAngle + 0x8000)
		faceAngleTemp i64 = i16.wrap(m.faceYaw - angleTemp)
		y = sins(faceAngleTemp) * m.forwardVel
		x = coss(faceAngleTemp) * m.forwardVel * 0.75
		m.forwardVel = (y * y + x * x).sqrt()
		m.faceYaw = i16.wrap(atan2s(x, y) + angleTemp)
	m.dropAndSetMarioAction(s, actSteepJump, 0)

# check_common_action_exits
fn checkCommonActionExits(mut m Mario, s Surfaces):
	if (m.input & inputAPressed) != 0: return m.setMarioAction(s, actJump, 0)
	if (m.input & inputOffFloor) != 0: return m.setMarioAction(s, actFreefall, 0)
	if (m.input & inputNonzeroAnalog) != 0: return m.setMarioAction(s, actWalking, 0)
	if (m.input & inputAboveSlide) != 0: return m.setMarioAction(s, actBeginSliding, 0)
	false

# update_mario_sound_and_camera: out of first person, the last camera mode back; out of the
# water, the level's own (the sounds are not ported)
fn updateMarioSoundAndCamera(m Mario, mut cam Camera):
	camPreset = cam.mode
	if m.action == actFirstPerson:
		cam.movementFlags &= ~camMoveCUpMode
		cam.setCameraMode(-1, 1)
	if (m.action & (actFlagSwimming | actFlagMetalWater)) == 0:
		if camPreset == cameraModeBehindMario or camPreset == cameraModeWaterSurface:
			cam.setCameraMode(cam.defMode, 1)

# reset_mario_pitch: out of a water jump, a cannon shot or flight, level again and the level's
# camera back
fn resetMarioPitch(mut m Mario, mut cam Camera):
	if m.action in [actWaterJump, actShotFromCannon, actFlying]:
		cam.setCameraMode(cam.defMode, 1)
		m.facePitch = 0

# transition_submerged_to_walking: out of the water onto his feet
fn transitionSubmergedToWalking(mut m Mario, s Surfaces, mut cam Camera) bool:
	cam.setCameraMode(cam.defMode, 1)
	m.angleVelPitch = 0
	m.angleVelYaw = 0
	m.angleVelRoll = 0
	# (holding something he would walk holding it: holding is not ported)
	m.setMarioAction(s, actWalking, 0)

# set_water_plunge_action: into the water, slowed, 100 units under its surface, the camera
# switched to the water's
fn setWaterPlungeAction(mut m Mario, s Surfaces, mut cam Camera) bool:
	m.forwardVel /= 4.0
	m.vel.y /= 2.0
	m.pos.y = f32(m.waterLevel - 100)
	m.faceRoll = 0
	m.angleVelPitch = 0
	m.angleVelYaw = 0
	m.angleVelRoll = 0
	if (m.action & actFlagDiving) == 0:
		m.facePitch = 0
	if cam.mode != cameraModeWaterSurface:
		cam.setCameraMode(cameraModeWaterSurface, 1)
	m.setMarioAction(s, actWaterPlunge, 0)

# mario_set_forward_vel
fn marioSetForwardVel(mut m Mario, forwardVel f32):
	m.forwardVel = forwardVel
	m.slideVelX = sins(m.faceYaw) * m.forwardVel
	m.slideVelZ = coss(m.faceYaw) * m.forwardVel
	m.vel.x = m.slideVelX
	m.vel.z = m.slideVelZ

# ---------- the floor ----------
