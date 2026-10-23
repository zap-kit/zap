# The DOS game's numbers by name (SDLPoP's types.h and data.h): tiles, actions, sequences,
# sounds, controls and the constant tables of places.

# tiles (the low 5 bits of a room's tile)
pub tileEmpty = 0
pub tileFloor = 1
pub tileSpike = 2
pub tilePillar = 3
pub tileGate = 4
pub tileStuck = 5
pub tileCloser = 6   # the drop button
pub tileDoortopWithFloor = 7   # the tapestry
pub tileBigpillarBottom = 8
pub tileBigpillarTop = 9
pub tilePotion = 10
pub tileLoose = 11
pub tileDoortop = 12
pub tileMirror = 13
pub tileDebris = 14
pub tileOpener = 15   # the raise button
pub tileLevelDoorLeft = 16
pub tileLevelDoorRight = 17
pub tileChomper = 18
pub tileTorch = 19
pub tileWall = 20
pub tileSkeleton = 21
pub tileSword = 22
pub tileBalconyLeft = 23
pub tileBalconyRight = 24
pub tileLatticePillar = 25
pub tileLatticeDown = 26
pub tileLatticeSmall = 27
pub tileLatticeLeft = 28
pub tileLatticeRight = 29
pub tileTorchWithDebris = 30

# actions
pub actStand = 0
pub actRunJump = 1
pub actHangClimb = 2
pub actInMidair = 3
pub actInFreefall = 4
pub actBumped = 5
pub actHangStraight = 6
pub actTurn = 7
pub actHurt = 99

# characters
pub charidKid = 0
pub charidShadow = 1
pub charidGuard = 2
pub charidSkeleton = 4
pub charidPrincess = 5
pub charidVizier = 6
pub charidMouse = 0x18

pub swordSheathed = 0
pub swordDrawn = 2

# controls: an arrow or the button released, held, or held but already acted on
pub ctrlReleased = 0
pub ctrlIgnore = 1
pub ctrlHeld = -1
pub ctrlHeldLeft = -1
pub ctrlHeldRight = 1
pub ctrlHeldForward = -1
pub ctrlHeldBackward = 1
pub ctrlHeldUp = -1
pub ctrlHeldDown = 1

# the sequence table's commands
seqDx = 0xFB
seqDy = 0xFA
seqFlip = 0xFE
seqJmpIfFeather = 0xF7
seqJmp = 0xFF
seqUp = 0xFD
seqDown = 0xFC
seqAction = 0xF9
seqSetFall = 0xF8
seqKnockUp = 0xF5
seqKnockDown = 0xF4
seqSound = 0xF2
seqEndLevel = 0xF1
seqGetItem = 0xF3
seqDie = 0xF6

# sequences (indices of seqtbl_offsets)
pub seqStartRun = 1
pub seqStand = 2
pub seqStandingJump = 3
pub seqRunJump = 4
pub seqTurn = 5
pub seqRunTurn = 6
pub seqFall = 7
pub seqJumpUpAndGrabStraight = 8
pub seqClimbUp = 10
pub seqReleaseLedgeAndLand = 11
pub seqStopRun = 13
pub seqJumpUpIntoCeiling = 14
pub seqGrabLedgeMidair = 15
pub seqJumpUpAndGrab = 16
pub seqSoftLand = 17
pub seqFallAfterStandingJump = 18
pub seqFall19 = 19
pub seqMediumLand = 20
pub seqFallAfterRunningJump = 21
pub seqCrushed = 22
pub seqReleaseLedgeAndFall = 23
pub seqJumpUpAndGrabForward = 24
pub seqHangAgainstWall = 25
pub seqCrouchWhileRunning = 26
pub seqJumpUpWithNothingAbove = 28
pub seqSafeStep1 = 29
pub seqStartRunAfterTurn = 43
pub seqStepOnEdge = 44
pub seqBumpfall = 45
pub seqHardbump = 46
pub seqBump = 47
pub seqStandUpFromCrouch = 49
pub seqCrouch = 50
pub seqSpiked = 51
pub seqLooseFloorFellOnKid = 52
pub seqChomped = 54
pub seqDrawSword = 55
pub seqGuardForwardWithSword = 56
pub seqBackWithSword = 57
pub seqGuardStrike = 58
pub seqTurnWithSword = 60
pub seqParryAfterStrike = 61
pub seqParry = 62
pub seqGuardActiveAfterFall = 63
pub seqPushedBackWithSword = 64
pub seqBumpForwardWithSword = 65
pub seqStrikeAfterParry = 66
pub seqClimbDown = 68
pub seqAttackWasParried = 69
pub seqGoUpOnLevelDoor = 70
pub seqDying = 71
pub seqClimbUpToClosedGate = 73
pub seqHitBySword = 74
pub seqStrike = 75
pub seqGuardStandInactive = 77
pub seqDrink = 78
pub seqCrouchHop = 79
pub seqStandFlipped = 80
pub seqKidPushedOffLedge = 81
pub seqGuardPushedOffLedge = 82
pub seqGuardFall = 83
pub seqRun = 84
pub seqStabbedToDeath = 85
pub seqForwardWithSword = 86
pub seqGuardBecomeInactive = 87
pub seqSkelWakeUp = 88
pub seqTurnDrawSword = 89
pub seqEnGarde = 90
pub seqGetSword = 91
pub seqPutSwordAway = 92
pub seqPutSwordAwayFast = 93
pub seqPrincessStandPV1 = 94
pub seqJaffarStandPV1 = 95
pub seqMouseStandsUp = 101
pub seqPrincessLyingPV2 = 103
pub seqStartFallInFrontOfWall = 104
pub seqMouseForward = 105
pub seqMouse = 106
pub seqMouseStandUpAndGo = 107
pub seqPrincessTurnAndHug = 108
pub seqPrincessStandPV2 = 109
pub seqPrincessCrouchingPV2 = 110
pub seqPrincessStandUpPV2 = 111
pub seqPrincessCrouchDownPV2 = 112
pub seqMouseStand = 114

# sounds
pub soundFellToDeath = 0
pub soundFalling = 1
pub soundTileCrashing = 2
pub soundButtonPressed = 3
pub soundGateClosing = 4
pub soundGateOpening = 5
pub soundGateClosingFast = 6
pub soundGateStop = 7
pub soundBumped = 8
pub soundGrab = 9
pub soundSwordVsSword = 10
pub soundSwordMoving = 11
pub soundGuardHurt = 12
pub soundKidHurt = 13
pub soundLeveldoorClosing = 14
pub soundLeveldoorSliding = 15
pub soundMediumLand = 16
pub soundSoftLand = 17
pub soundDrink = 18
pub soundDrawSword = 19
pub soundLooseShake1 = 20
pub soundLooseShake2 = 21
pub soundLooseShake3 = 22
pub soundFootstep = 23
pub soundDeathRegular = 24
pub soundPresentation = 25
pub soundEmbrace = 26
pub soundCutscene2 = 27   # cutscenes 2, 4, 6 and 12
pub soundDeathInFight = 28
pub soundMeetJaffar = 29
pub soundBigPotion = 30
pub soundShadowMusic = 32
pub soundSmallPotion = 33
pub soundCutscene8 = 35   # cutscenes 8 and 9
pub soundOutOfTime = 36
pub soundVictory = 37
pub soundBlink = 38
pub soundLowWeight = 39
pub soundCutscene12ShortTime = 40
pub soundEndLevelMusic = 41
pub soundVictoryJaffar = 43
pub soundSkelAlive = 44
pub soundJumpThroughMirror = 45
pub soundChomped = 46
pub soundChomper = 47
pub soundSpiked = 48
pub soundSpikes = 49
pub soundStory2Princess = 50
pub soundPrincessDoorOpening = 51
pub soundStory4JaffarLeaves = 52
pub soundStory3JaffarComes = 53
pub soundIntroMusic = 54
pub soundStory1Absence = 55
pub soundEndingMusic = 56

# colours of the VGA's first row
pub colorBlack = 0
pub colorRed = 4
pub colorBrightBlue = 9
pub colorBrightRed = 12
pub colorBrightYellow = 14
pub colorBrightWhite = 15

# places: the screen's left edge is x 58, a tile 14 wide; a row 63 high
pub tileSizeX = 14
pub tileMidX = 7
pub tileRightX = 13
pub tileSizeY = 63
pub screenspaceX = 58
pub firstOnscreenColumn = 5
pub roomCount = 24
pub tblLine = [0, 10, 20]
pub yLand = [-8, 55, 118, 181, 244]
pub xBump = [
	244,
	2,
	16,
	30,
	44,
	58,
	72,
	86,
	100,
	114,
	128,
	142,
	156,
	170,
	184,
	198,
	212,
	226,
	240,
	254
]
pub yClip = [-60, 3, 66, 129, 192]
pub dirFront = [-1, 1]
pub dirBehind = [1, -1]

# frame flags
pub frameWeightX = 0x1F
pub frameThin = 0x20
pub frameNeedsFloor = 0x40
pub frameEvenOdd = 0x80

# a replay's special moves: the level restarted, the end of the feather's fall or of the level 1
# crouch that the music's end caused
pub moveRestart = 1
pub moveEffectEnd = 2
