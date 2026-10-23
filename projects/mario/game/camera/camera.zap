# The camera as the game moves it (camera.c). Each frame, after Mario moved, update_camera copies
# Lakitu's goal of the last frame into the camera and runs the camera's mode: in Castle Grounds
# the free roaming one (mode_lakitu_camera: Lakitu some 800 units behind Mario, turning back
# behind him when he stops, around walls that hide him, over the floor and the water), on the
# water's surface the one behind Mario. update_lakitu then flies Lakitu's drawn place and focus
# toward that goal. Mario reads the yaw it leaves (c->yaw) on the next frame, for the way the
# stick points.
#
# Not ported: cutscenes, C-up (first person), the R button's cameras (Mario's and the fixed one),
# the modes other levels use (radial, 8 directions, fixed, boss, parallel tracking, slide,
# spiral stairs, cannon: they fall back to Lakitu's), other levels' triggers, shakes, the
# handheld sway and the field of view.

# camera modes (camera.h)
pub cameraModeNone = 0x00
pub cameraModeBehindMario = 0x03
pub cameraModeClose = 0x04
pub cameraModeCUp = 0x06
pub cameraModeWaterSurface = 0x08
pub cameraModeFreeRoam = 0x10

# gCameraMovementFlags
camMoveReturnToMiddle = 0x0001
camMoveZoomedOut = 0x0002
camMoveRotateRight = 0x0004
camMoveRotateLeft = 0x0008
camMoveEnteredRotateSurface = 0x0010
camMoveMetalBelowWater = 0x0020
camMoveFixInPlace = 0x0040
camMoveUnknown8 = 0x0080
camMovingIntoMode = 0x0100
camMoveInitCamera = 0x0800
camMoveAlreadyZoomedOut = 0x1000
pub camMoveCUpMode = 0x2000
camMoveSubmerged = 0x4000
camMoveRotate = camMoveRotateRight | camMoveRotateLeft | camMoveReturnToMiddle
camMoveRestrict = camMoveEnteredRotateSurface | camMoveMetalBelowWater | camMoveFixInPlace | camMoveUnknown8

# sStatusFlags
camFlagSmoothMovement = 0x0001
camFlagBlockSmoothMovement = 0x0002
camFlagFrameAfterCamInit = 0x0004
camFlagCamNearWall = 0x0020
camFlagSleeping = 0x0040
camFlagCollidedWithWall = 0x0200
camFlagStartTransition = 0x0400
camFlagTransitionOutOfCUp = 0x0800
camFlagBlockAreaProcessing = 0x1000
camFlagBehindMarioPostDoor = 0x8000

# the C buttons (os_cont.h), as Controls carries them
pub cButtonRight = 0x0001
pub cButtonLeft = 0x0002
pub cButtonDown = 0x0004
pub cButtonUp = 0x0008

# surface types the camera treats apart (surface_terrains.h)
surfaceDeathPlane = 0x000A
surfaceWallMisc = 0x0028

pub type Camera:
	# struct Camera
	mode i64
	defMode i64
	cutscene i64
	yaw i64   # from Mario's focus to the camera: what the stick's "up" points away from
	nextYaw i64
	cPos Vec3   # where this frame's mode puts the camera (c->pos)
	cFocus Vec3   # and where it looks (c->focus)
	# gLakituState
	curPos Vec3
	curFocus Vec3
	goalPos Vec3
	goalFocus Vec3
	pos Vec3   # where the frame is seen from
	focus Vec3   # and toward
	posHSpeed f32
	posVSpeed f32
	focHSpeed f32
	focVSpeed f32
	lakituYaw i64
	lakituNextYaw i64
	lakituMode i64
	lakituDefMode i64
	lastFrameAction i64
	# sMarioGeometry
	currFloor i64
	currFloorHeight f32
	currFloorType i64
	currCeil i64
	currCeilHeight f32
	currCeilType i64
	prevFloor i64
	prevFloorHeight f32
	prevFloorType i64
	prevCeil i64
	prevCeilHeight f32
	prevCeilType i64
	waterHeight f32
	# sModeTransition
	transitionMarioPos Vec3
	framesLeft i64
	transPosDist f32
	transPosPitch i64
	transPosYaw i64
	transFocDist f32
	transFocPitch i64
	transFocYaw i64
	# sModeInfo
	newMode i64
	lastMode i64
	modeMax i64
	modeFrame i64
	# the rest of camera.c's state
	statusFlags i64   # sStatusFlags
	movementFlags i64   # gCameraMovementFlags
	selectionFlags i64   # sSelectionFlags
	yawSpeed i64   # sYawSpeed
	zoomDist f32   # gCameraZoomDist
	panDistance f32   # sPanDistance
	zoomAmount f32   # sZoomAmount
	zeroZoomDist f32   # sZeroZoomDist
	cSideButtonYaw i64   # sCSideButtonYaw
	avoidYawVel i64   # sAvoidYawVel
	behindMarioSoundTimer i64
	cButtonsPressed i64   # sCButtonsPressed
	yawAfterDoorCutscene i64
	oldPosition Vec3
	oldFocus Vec3

fn zero3():
	Vec3(0.0, 0.0, 0.0)

# create_camera (the area's GEO_CAMERA node: its mode), then reset_camera: everything at its
# start and the camera set up on its first update
pub fn newCamera(mode i64) Camera:
	Camera(
		mode,
		defMode = mode,
		cutscene = 0,
		yaw = 0,
		nextYaw = 0,
		cPos = zero3(),
		cFocus = zero3(),
		curPos = zero3(),
		curFocus = zero3(),
		goalPos = zero3(),
		goalFocus = zero3(),
		pos = zero3(),
		focus = zero3(),
		posHSpeed = 0.0,
		posVSpeed = 0.0,
		focHSpeed = 0.0,
		focVSpeed = 0.0,
		lakituYaw = 0,
		lakituNextYaw = 0,
		lakituMode = 0,
		lakituDefMode = 0,
		lastFrameAction = 0,
		currFloor = -1,
		currFloorHeight = 0.0,
		currFloorType = 0,
		currCeil = -1,
		currCeilHeight = 0.0,
		currCeilType = 0,
		prevFloor = -1,
		prevFloorHeight = 0.0,
		prevFloorType = 0,
		prevCeil = -1,
		prevCeilHeight = 0.0,
		prevCeilType = 0,
		waterHeight = 0.0,
		transitionMarioPos = zero3(),
		framesLeft = 0,
		transPosDist = 0.0,
		transPosPitch = 0,
		transPosYaw = 0,
		transFocDist = 0.0,
		transFocPitch = 0,
		transFocYaw = 0,
		newMode = 0,
		lastMode = 0,
		modeMax = 0,
		modeFrame = 0,
		statusFlags = 0,
		movementFlags = camMoveInitCamera,
		selectionFlags = 0,
		yawSpeed = 0,
		zoomDist = 800.0,
		panDistance = 0.0,
		zoomAmount = 0.0,
		zeroZoomDist = 0.0,
		cSideButtonYaw = 0,
		avoidYawVel = 0,
		behindMarioSoundTimer = 0, cButtonsPressed = 0, yawAfterDoorCutscene = 0, oldPosition = zero3(), oldFocus = zero3())

# ---------- the frame ----------

# update_camera: the camera's frame, after Mario's
pub fn updateCamera(mut c Camera, m Mario, s Surfaces, ctl Controls):
	# (update_camera_hud_status and the R button's switch to Mario's camera: not ported)
	c.statusFlags &= ~camFlagFrameAfterCamInit
	if (c.movementFlags & camMoveInitCamera) != 0:
		c.initCamera(m, s)
		c.movementFlags &= ~camMoveInitCamera
		c.statusFlags |= camFlagFrameAfterCamInit
	c.prevFloorHeight = c.currFloorHeight
	c.prevCeilHeight = c.currCeilHeight
	c.prevFloor = c.currFloor
	c.prevCeil = c.currCeil
	c.prevFloorType = c.currFloorType
	c.prevCeilType = c.currCeilType
	c.findMarioFloorAndCeil(m, s)
	c.cPos = c.goalPos
	c.cFocus = c.goalFocus
	c.yaw = c.lakituYaw
	c.nextYaw = c.lakituNextYaw
	c.mode = c.lakituMode
	c.defMode = c.lakituDefMode
	c.cameraCourseProcessing(m)
	c.cButtonsPressed = findCButtonsPressed(c.cButtonsPressed, ctl.cPressed, ctl.cDown)
	# (no cutscene plays: none is ported)
	c.yawSpeed = 0x400
	if c.mode == cameraModeBehindMario:
		c.nextYaw = c.modeBehindMario(m, s)
	elif c.mode == cameraModeWaterSurface:
		# mode_water_surface_camera: exactly the same as behind Mario
		c.nextYaw = c.modeBehindMario(m, s)
	else:
		# CAMERA_MODE_FREE_ROAM and CLOSE: mode_lakitu_camera (the other modes are not ported)
		c.modeLakituCamera(m, s, ctl)
	# (start_cutscene(get_cutscene_from_mario_status): its cutscenes are not ported; the fixed
	# camera held by R is not either)
	c.updateLakitu(m, s)
	c.lastFrameAction = m.camAction

# init_camera: the camera at the level's start, 400 units behind Mario and 125 over the floor
# under him (Castle Grounds: from elsewhere than the start, 800 in front of him and 400 to the
# side; the waterfall's and the wing cap tower's exit cutscenes are not ported)
fn initCamera(mut c Camera, m Mario, s Surfaces):
	c.lakituMode = c.mode
	c.lakituDefMode = c.defMode
	c.posHSpeed = 0.3
	c.posVSpeed = 0.3
	c.focHSpeed = 0.8
	c.focHSpeed = 0.3   # @bug set back to back, as the game does
	c.statusFlags &= ~camFlagSmoothMovement
	c.findMarioFloorAndCeil(m, s)
	c.prevFloorHeight = c.currFloorHeight
	c.prevCeilHeight = c.currCeilHeight
	c.prevFloor = c.currFloor
	c.prevCeil = c.currCeil
	c.prevFloorType = c.currFloorType
	c.prevCeilType = c.currCeilType
	c.cutscene = 0
	marioOffset = Vec3(0.0, 125.0, 400.0)
	if not m.isWithin100UnitsOfMario(Vec3(-1328.0, 260.0, 4664.0)):
		marioOffset.x = -400.0
		marioOffset.z = -800.0
	c.lakituMode = cameraModeFreeRoam
	c.cPos = m.camPos.offsetRotated(marioOffset, m.camFacePitch, m.camFaceYaw)
	if c.mode != cameraModeBehindMario:
		floor, _ = s.findFloor(m.camPos.x, m.camPos.y + 100.0, m.camPos.z)
		c.cPos.y = floor + 125.0
	c.cFocus = m.camPos
	c.curPos = c.cPos
	c.curFocus = c.cFocus
	c.goalPos = c.cPos
	c.goalFocus = c.cFocus
	c.pos = c.cPos
	c.focus = c.cFocus
	c.lakituYaw = c.cFocus.calculateYaw(c.cPos)
	c.lakituNextYaw = c.lakituYaw
	c.yaw = c.lakituYaw
	c.nextYaw = c.lakituYaw

# camera_course_processing: Castle Grounds has no camera triggers and no case of its own in the
# area switch, so only the blocking of area processing is left
fn cameraCourseProcessing(mut c Camera, m Mario):
	oldMode = c.mode
	if c.mode == cameraModeCUp:
		c.mode = c.lastMode
	c.checkBlockingAreaProcessing(m)
	c.statusFlags &= ~camFlagBlockAreaProcessing
	if oldMode == cameraModeCUp:
		c.lastMode = c.mode
		c.mode = oldMode
	c.mode

# check_blocking_area_processing
fn checkBlockingAreaProcessing(mut c Camera, m Mario):
	if (m.camAction & actFlagMetalWater) != 0 or c.mode == cameraModeBehindMario or
		c.mode == cameraModeWaterSurface:
		c.statusFlags |= camFlagBlockAreaProcessing
	if c.mode == cameraModeBehindMario and
		(m.camAction & (actFlagSwimming | actFlagMetalWater)) == 0:
		c.statusFlags |= camFlagBlockAreaProcessing

# find_c_buttons_pressed: which C buttons are held, the last pressed of each pair winning
fn findCButtonsPressed(currentState0 i64, buttonsPressed i64, buttonsDown i64):
	currentState = currentState0
	if (buttonsPressed & cButtonLeft) != 0:
		currentState |= cButtonLeft
		currentState &= ~cButtonRight
	if (buttonsDown & cButtonLeft) == 0:
		currentState &= ~cButtonLeft
	if (buttonsPressed & cButtonRight) != 0:
		currentState |= cButtonRight
		currentState &= ~cButtonLeft
	if (buttonsDown & cButtonRight) == 0:
		currentState &= ~cButtonRight
	if (buttonsPressed & cButtonUp) != 0:
		currentState |= cButtonUp
		currentState &= ~cButtonDown
	if (buttonsDown & cButtonUp) == 0:
		currentState &= ~cButtonUp
	if (buttonsPressed & cButtonDown) != 0:
		currentState |= cButtonDown
		currentState &= ~cButtonUp
	if (buttonsDown & cButtonDown) == 0:
		currentState &= ~cButtonDown
	currentState

# find_mario_floor_and_ceil: the floor and ceiling at Mario (their types as the camera sees
# them, the surfaces and heights as Mario does)
fn findMarioFloorAndCeil(mut c Camera, m Mario, s Surfaces):
	p = m.camPos
	floorType, typeFloor = s.findFloor(p.x, p.y + 10.0, p.z, forCamera = true)
	c.currFloorType = s.all[typeFloor].kind if floorType != floorLowerLimit and typeFloor >= 0
		else 0
	ceilType, typeCeil = s.findCeiling(p.x, p.y - 10.0, p.z, forCamera = true)
	c.currCeilType = s.all[typeCeil].kind if ceilType != ceilingLimit and typeCeil >= 0 else 0
	floorHeight, floor = s.findFloor(p.x, p.y + 10.0, p.z)
	c.currFloorHeight = floorHeight
	c.currFloor = floor
	ceilHeight, ceil = s.findCeiling(p.x, p.y - 10.0, p.z)
	c.currCeilHeight = ceilHeight
	c.currCeil = ceil
	c.waterHeight = s.waterLevel(p.x, p.z)

# set_camera_mode: a mode Mario's code switches to (the water's surface, behind him, back to the
# level's own). The transition's start and end it stores (sModeInfo.transitionStart/End) and the
# area yaw it takes feed only C-up and the radial modes, not ported, and what the transition
# function does to c->focus is overwritten at the camera's next update.
pub fn setCameraMode(mut c Camera, mode0 i64, frames i64):
	mode = mode0
	c.movementFlags &= ~(camMoveRestrict | camMoveRotate)
	c.movementFlags |= camMovingIntoMode
	if mode == cameraModeNone:
		mode = cameraModeClose
	# (sCUpCameraPitch, sModeOffsetYaw, sLakituDist, sLakituPitch, sAreaYawChange go to 0: no
	# ported mode reads them)
	c.newMode = mode if mode != -1 else c.lastMode
	c.lastMode = c.mode
	c.modeMax = frames
	c.modeFrame = 1
	c.mode = c.newMode
	c.lakituMode = c.mode

# ---------- the free roaming camera ----------

# mode_lakitu_camera, mode_default_camera
fn modeLakituCamera(mut c Camera, m Mario, s Surfaces, ctl Controls):
	c.zoomDist = 800.0
	c.nextYaw = c.updateDefaultCamera(m, s, ctl)
	c.panAheadOfPlayer(m)

# update_default_camera: behind Mario, turning back behind him when he stops, around walls that
# hide him, over the floor and the water; returns the camera's next yaw
fn updateDefaultCamera(mut c Camera, m Mario, s Surfaces, ctl Controls):
	yawGoal i64 = i16.wrap(m.camFaceYaw + 0x8000)
	avoidStatus = 0
	ceilHeight0, ceil = s.findCeiling(c.goalPos.x, c.goalPos.y, c.goalPos.z, forCamera = true)
	ceilHeight = ceilHeight0
	c.handleCButtonMovement(ctl)
	dist0, pitch0, yaw0 = m.camPos.vec3fGetDistAndAngle(c.cPos)
	dist = dist0
	pitch = pitch0
	yaw = yaw0
	zoomDist, dist = c.updateDefaultCameraZoom(m, dist0)
	nextYawVel, closeToMario, dist, pitch, yaw = c.updateDefaultCameraTurn(m, ctl, dist, pitch, yaw)
	if -16.0 < ctl.stickY:
		c.yaw = yaw
	posHeight0, focHeight = c.calcYToCurrFloor(m, s, 1.0, 200.0, 0.9, 200.0)
	posHeight = posHeight0
	cPos = c.cPos
	avoidStatus, yaw = c.updateDefaultCameraAvoidWalls(
		m,
		s,
		cPos,
		yawGoal,
		yaw,
		nextYawVel,
		closeToMario
	)
	# zoomed out only when no wall is in the way and Lakitu hit none
	if avoidStatus == 0 and (c.statusFlags & camFlagCollidedWithWall) == 0:
		dist = approachF32Asymptotic(dist, zoomDist - 100.0, 0.05)
	cPos = m.camPos.vec3fSetDistAndAngle(dist, pitch, yaw)
	cPos.y += posHeight + 125.0
	# away from walls
	pushed, collisions = s.collideWithWalls(cPos, 10.0, 80.0)
	cPos = pushed
	if collisions != 0:
		c.statusFlags |= camFlagCollidedWithWall
	c.cFocus = Vec3(m.camPos.x, m.camPos.y + 125.0 + focHeight, m.camPos.z)
	marioFloorHeight, marioFloor, camFloorHeight0 = c.updateDefaultCameraFloors(m, s, cPos)
	camFloorHeight = camFloorHeight0
	cPos.y = camFloorHeight
	tempPos = cPos
	tempPos.y -= 125.0
	if marioFloor >= 0 and camFloorHeight <= marioFloorHeight:
		avoidStatus = c.cFocus.isRangeBehindSurface(tempPos, s.all[marioFloor], 0, -1)
		if avoidStatus != 1 and ceilHeight > marioFloorHeight:
			camFloorHeight = marioFloorHeight
	posHeight = 0.0
	if c.mode == cameraModeFreeRoam:
		posHeight = 100.0
		if (c.movementFlags & camMoveZoomedOut) != 0:
			posHeight = 375.0
	c.updateDefaultCameraLimits(m, s, cPos, camFloorHeight, posHeight, ceilHeight, ceil, zoomDist)
	yaw

fn updateDefaultCameraZoom(mut c Camera, m Mario, dist0 f32):
	dist = dist0
	# zoomed out by C-down (Lakitu's camera: Mario's would go further)
	zoomDist = c.zoomDist
	if (c.movementFlags & camMoveZoomedOut) != 0:
		zoomDist = c.zoomDist + 400.0
	if (m.camAction & actFlagHanging) != 0 or m.camAction == actRidingHoot:
		zoomDist *= 0.8
	# not zooming out, the distance only shrinks
	if c.zoomAmount == 0.0:
		if dist > zoomDist:
			dist -= 50.0
			if dist < zoomDist:
				dist = zoomDist
	else:
		c.zoomAmount -= 30.0
		if c.zoomAmount < 0.0:
			c.zoomAmount = 0.0
		if dist > zoomDist:
			dist -= 30.0
			if dist < zoomDist:
				dist = zoomDist
		if dist < zoomDist:
			dist += 30.0
			if dist > zoomDist:
				dist = zoomDist
	(zoomDist, dist)

fn updateDefaultCameraTurn(
	mut c Camera,
	m Mario,
	ctl Controls,
	dist0 f32,
	pitch0 i64,
	yaw0 i64
):
	dist = dist0
	pitch = pitch0
	yaw = yaw0
	closeToMario = 0
	# how fast it turns
	nextYawVel = 0
	if c.cSideButtonYaw == 0:
		nextYawVel = 0xC0 if c.mode == cameraModeFreeRoam else 0x100
		if ctl.stickX != 0.0 or ctl.stickY != 0.0:
			nextYawVel = 0x20
	else:
		if c.cSideButtonYaw < 0:
			yaw = i16.wrap(yaw + 0x200)
		if c.cSideButtonYaw > 0:
			yaw = i16.wrap(yaw - 0x200)
		c.cSideButtonYaw = cameraApproachS16Symmetric(c.cSideButtonYaw, 0, 0x100)
		nextYawVel = 0
	c.yawSpeed = 0x400
	xzDist = m.camPos.calcHorDist(c.cPos)
	if (c.statusFlags & camFlagBehindMarioPostDoor) != 0:
		if xzDist >= 250.0:
			c.statusFlags &= ~camFlagBehindMarioPostDoor
		if ((m.camFaceYaw - yaw) / 2).abs() < 0x1800:
			c.statusFlags &= ~camFlagBehindMarioPostDoor
			yaw = i16.wrap(c.yawAfterDoorCutscene + 0x8000)
			dist = 800.0
			c.statusFlags |= camFlagBlockSmoothMovement
	elif xzDist < 250.0:
		# very close to Mario: turn fast
		c.cPos.x += (250.0 - xzDist) * sins(yaw)
		c.cPos.z += (250.0 - xzDist) * coss(yaw)
		if c.cSideButtonYaw == 0:
			nextYawVel = 0x1000
			c.yawSpeed = 0
			dist, pitch, yaw = m.camPos.vec3fGetDistAndAngle(c.cPos)
		closeToMario |= 1
	(nextYawVel, closeToMario, dist, pitch, yaw)

fn updateDefaultCameraAvoidWalls(
	mut c Camera,
	m Mario,
	s Surfaces,
	cPos Vec3,
	yawGoal i64,
	yaw0 i64,
	nextYawVel i64,
	closeToMario i64
):
	yaw = yaw0
	yawVel = 0
	status, avoidYaw = c.rotateCameraAroundWalls(m, s, cPos, 0x600)
	avoidStatus = status
	if avoidStatus == 3:
		# a wall hides Mario: turn toward the way around it
		c.avoidYawVel = yaw
		c.statusFlags |= camFlagCollidedWithWall
		yaw = approachS16Asymptotic(yaw, avoidYaw, 10)
		c.avoidYawVel = i16.wrap((c.avoidYawVel - yaw) / 0x100)
	else:
		if m.forwardVel == 0.0:
			if (c.statusFlags & camFlagCollidedWithWall) != 0:
				yawDir = -1 if (yawGoal - yaw) / 0x100 >= 0 else 1
				if (c.avoidYawVel > 0 and yawDir > 0) or (c.avoidYawVel < 0 and yawDir < 0):
					yawVel = nextYawVel
			else:
				yawVel = nextYawVel
		else:
			if nextYawVel == 0x1000:
				yawVel = nextYawVel
			c.statusFlags &= ~camFlagCollidedWithWall
		# a wall near the camera: twice as fast, unless it already turned from being near Mario
		if avoidStatus != 0:
			yawVel += yawVel
		if (closeToMario & 1) != 0 and avoidStatus != 0:
			yawVel = 0
		# (no dialog is ever open: get_dialog_id() == -1)
		if yawVel != 0:
			yaw = cameraApproachS16Symmetric(yaw, yawGoal, yawVel)
	(avoidStatus, yaw)

fn updateDefaultCameraFloors(mut c Camera, m Mario, s Surfaces, cPos Vec3):
	marioFloorHeight = 125.0 + c.currFloorHeight
	marioFloor = c.currFloor
	camFloor, _ = s.findFloor(cPos.x, cPos.y + 50.0, cPos.z, forCamera = true)
	camFloorHeight = camFloor + 125.0
	# the highest floor on the way to Mario
	scale = 0.1
	while scale < 1.0:
		tempPos = cPos.scaleAlongLine(m.camPos, scale)
		tempFloor, tempFloorIndex = s.findFloor(tempPos.x, tempPos.y, tempPos.z, forCamera = true)
		tempFloorHeight = tempFloor + 125.0
		if tempFloorIndex >= 0 and tempFloorHeight > marioFloorHeight:
			marioFloorHeight = tempFloorHeight
			marioFloor = tempFloorIndex
		scale += 0.2
	# (Mario's camera, CAM_MODE_MARIO_ACTIVE, lower: not ported)
	# over the water, unless the metal cap keeps it under
	waterHeight = s.waterLevel(cPos.x, cPos.z)
	if waterHeight != floorLowerLimit:
		waterHeight += 125.0
		distFromWater = waterHeight - marioFloorHeight
		if (c.movementFlags & camMoveMetalBelowWater) == 0:
			if distFromWater > 800.0 and (m.camAction & actFlagMetalWater) != 0:
				c.movementFlags |= camMoveMetalBelowWater
		else:
			if distFromWater < 400.0 or (m.camAction & actFlagMetalWater) == 0:
				c.movementFlags &= ~camMoveMetalBelowWater
		if (c.movementFlags & camMoveMetalBelowWater) == 0 and camFloorHeight < waterHeight:
			camFloorHeight = waterHeight
	else:
		c.movementFlags &= ~camMoveMetalBelowWater
	(marioFloorHeight, marioFloor, camFloorHeight)

fn updateDefaultCameraLimits(
	mut c Camera,
	m Mario,
	s Surfaces,
	cPos0 Vec3,
	camFloorHeight0 f32,
	posHeight f32,
	ceilHeight0 f32,
	ceil i64,
	zoomDist f32
):
	cPos = cPos0
	camFloorHeight = camFloorHeight0
	ceilHeight = ceilHeight0
	# over the poison gas
	gasHeight = s.poisonGasLevel(cPos.x, cPos.z)
	if gasHeight != floorLowerLimit:
		gasHeight += 130.0
		if gasHeight > c.cPos.y:
			c.cPos.y = gasHeight
	if (m.camAction & actFlagHanging) != 0 or m.camAction == actRidingHoot:
		camFloorHeight = m.camPos.y + 400.0
		if c.mode == cameraModeFreeRoam:
			camFloorHeight -= 100.0
		ceilHeight = ceilingLimit
		c.cFocus = m.camPos
	# (on a pole: Mario's pole actions are not ported)
	if camFloorHeight != floorLowerLimit:
		camFloorHeight += posHeight
		c.approachCameraHeight(camFloorHeight, 20.0)
	c.cPos.x = cPos.x
	c.cPos.z = cPos.z
	cPos = Vec3(c.goalPos.x, c.cPos.y, c.goalPos.z)
	# not lagging too far behind
	lag, lagPitch, lagYaw = cPos.vec3fGetDistAndAngle(c.cPos)
	if lag > 50.0:
		c.cPos = cPos.vec3fSetDistAndAngle(50.0, lagPitch, lagYaw)
	if c.currFloorType != surfaceDeathPlane:
		far, farPitch, farYaw = c.cFocus.vec3fGetDistAndAngle(c.cPos)
		if far > zoomDist:
			c.cPos = c.cFocus.vec3fSetDistAndAngle(zoomDist, farPitch, farYaw)
	if ceilHeight != ceilingLimit:
		ceilHeight -= 150.0
		if c.cPos.y > ceilHeight and
			c.cPos.isRangeBehindSurface(m.camPos, s.all[ceil], 0, -1) == 1:
			c.cPos.y = ceilHeight
