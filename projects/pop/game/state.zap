# The game's variables (SDLPoP's data.h and types.h; the DOS game's data segment), in one struct
# the routines share. Numbers are i64; where the C variable is a byte, a signed byte, a word or a
# short, the routines store through byte(), sbyte(), word() and short(), so values wrap as there.

import dos.pop
import image

pub fn byte(v i64) i64:
	v & 0xFF

pub fn sbyte(v i64) i64:
	((v + 0x80) & 0xFF) - 0x80

pub fn word(v i64) i64:
	v & 0xFFFF

pub fn short(v i64) i64:
	((v + 0x8000) & 0xFFFF) - 0x8000

# a character (char_type): its frame, place (x 58 the screen's left, a tile 14 wide; y the
# bottom of its feet), facing (-1 left, 0 right, 0x56 none), tile, action and sequence
pub type CharType:
	frame i64 = 0
	x i64 = 0   # byte
	y i64 = 0   # byte
	direction i64 = 0   # sbyte
	currCol i64 = 0   # sbyte
	currRow i64 = 0   # sbyte
	action i64 = 0
	fallX i64 = 0   # sbyte
	fallY i64 = 0   # sbyte
	room i64 = 0
	repeat i64 = 0
	charid i64 = 0   # 0 kid, 1 shadow, 2 guard, 4 skeleton, 5 princess, 6 vizier, 24 mouse
	sword i64 = 0
	alive i64 = 0   # sbyte: -1 alive
	currSeq i64 = 0   # word: an address of the sequence table

pub dirRight = 0
pub dirLeft = -1
pub dirNone = 0x56

# the object being added to the objects' table, as save_obj keeps it
pub type ObjVars:
	tilepos i64 = 0
	x i64 = 0
	y i64 = 0
	direction i64 = 0
	id i64 = 0
	chtab i64 = 0
	clipTop i64 = 0
	clipBottom i64 = 0
	clipLeft i64 = 0
	clipRight i64 = 0

# the draw tables (back_table_type, midtable_type, wipetable_type, objtable_type)
pub type BackItem:
	xh i64
	xl i64
	y i64
	chtabId i64
	id i64
	blit i64

pub type Rect:
	top i64
	left i64
	bottom i64
	right i64

pub type MidItem:
	xh i64
	xl i64
	y i64
	chtabId i64
	id i64
	peel bool
	clip Rect
	blit i64

pub type WipeItem:
	left i64
	bottom i64
	height i64
	width i64
	color i64
	layer i64

pub type ObjItem:
	xh i64 = 0
	xl i64 = 0
	y i64 = 0
	chtabId i64 = 0
	id i64 = 0
	direction i64 = 0
	objType i64 = 0
	clip Rect = Rect(0, 0, 0, 0)
	tilepos i64 = 0

# a transitional object and a mob (trob_type, mob_type)
pub type Trob:
	tilepos i64 = 0
	room i64 = 0
	trobType i64 = 0   # sbyte

pub type Mob:
	xh i64 = 0
	y i64 = 0
	room i64 = 0
	speed i64 = 0   # sbyte
	mobType i64 = 0
	row i64 = 0

pub type Game:
	install str
	tables pop.Tables
	chtabs pop.SpriteTable?[]   # chtab 0 sword .. 9 princess's bed
	guardPalettes u8[]   # PRINCE.DAT 10: 48 bytes a colour of guard
	levelVarPalettes u8[]   # PRINCE.DAT 20: v1.3's colours of levels
	levelsDat pop.Dat
	level pop.Level
	screen Screen
	pal Palette
	sounds pop.SoundBank
	input Input = Input()
	isKeyboardMode bool = true

	# the level being played
	currentLevel i64 = -1
	nextLevel i64 = 0
	drawnRoom i64 = 0
	nextRoom i64 = 0
	differentRoom i64 = 0
	loadedRoom i64 = 0
	currRoomBase i64 = 0   # curr_room_tiles: the loaded room's first tile in the level
	roomL i64 = 0
	roomR i64 = 0
	roomA i64 = 0
	roomB i64 = 0
	roomBR i64 = 0
	roomBL i64 = 0
	roomAR i64 = 0
	roomAL i64 = 0

	# characters
	kid CharType = CharType()
	guard CharType = CharType(direction = 0x56, charid = 2)
	char CharType = CharType()
	opp CharType = CharType()
	curFrame pop.Frame = pop.Frame(image = 255, sword = 0, dx = 0, dy = 0, flags = 0)

	# tiles read
	currTile i64 = 0
	currModifier i64 = 0
	currTile2 i64 = 0
	currTilepos i64 = 0
	currRoom i64 = 0
	tileCol i64 = 0
	tileRow i64 = 0
	throughTile i64 = 0
	infrontx i64 = 0
	edgeType i64 = 0

	# collisions
	charColRight i64 = 0
	charColLeft i64 = 0
	charTopRow i64 = 0
	prevCharTopRow i64 = 0
	prevCharColRight i64 = 0
	prevCharColLeft i64 = 0
	charBottomRow i64 = 0
	charWidthHalf i64 = 0
	charHeight i64 = 0
	charXLeft i64 = 0
	charXLeftColl i64 = 0
	charXRightColl i64 = 0
	charXRight i64 = 0
	charTopY i64 = 0
	collisionRow i64 = 0
	prevCollisionRow i64 = -1
	prevCollRoom i64[] = fill(10, -1)
	currRowCollRoom i64[] = fill(10, -1)
	belowRowCollRoom i64[] = fill(10, -1)
	aboveRowCollRoom i64[] = fill(10, -1)
	currRowCollFlags i64[] = zeros(10)
	aboveRowCollFlags i64[] = zeros(10)
	belowRowCollFlags i64[] = zeros(10)
	prevCollFlags i64[] = zeros(10)
	collTileLeftXpos i64 = 0
	bumpColLeftOfWall i64 = 0
	bumpColRightOfWall i64 = 0
	rightCheckedCol i64 = 0
	leftCheckedCol i64 = 0
	fallFrame i64 = 0

	# controls
	controlShift i64 = 0
	controlY i64 = 0
	controlX i64 = 0
	controlShift2 i64 = 0
	controlForward i64 = 0
	controlBackward i64 = 0
	controlUp i64 = 0
	controlDown i64 = 0
	ctrl1Forward i64 = 0
	ctrl1Backward i64 = 0
	ctrl1Up i64 = 0
	ctrl1Down i64 = 0
	ctrl1Shift2 i64 = 0

	# hit points and the game's state
	hitpCurr i64 = 0
	hitpMax i64 = 0
	hitpDelta i64 = 0
	hitpBegLev i64 = 3
	guardhpCurr i64 = 0
	guardhpMax i64 = 0
	guardhpDelta i64 = 0
	remMin i64 = 60
	remTick i64 = 719
	textTimeRemaining i64 = 0
	textTimeTotal i64 = 0
	isShowTime i64 = 0
	checkpoint i64 = 0
	upsideDown i64 = 0
	resurrectTime i64 = 0
	needLevel1Music i64 = 0
	haveSword i64 = 0
	isScreaming i64 = 0
	offguard i64 = 0
	droppedout i64 = 0
	knock i64 = 0
	isGuardNotice i64 = 0
	isFeatherFall i64 = 0
	flashColor i64 = 0
	flashTime i64 = 0
	grabTimer i64 = 0
	canGuardSeeKid i64 = 0
	holdingSword i64 = 0
	unitedWithShadow i64 = 0
	leveldoorOpen i64 = 0
	demoIndex i64 = 0
	demoTime i64 = 0
	guardSkill i64 = 0
	guardRefrac i64 = 0
	kidSwordStrike i64 = 0
	justblocked i64 = 0
	guardNoticeTimer i64 = 0
	jumpedThroughMirror i64 = 0
	distanceMirror i64 = 0
	shadowInitialized i64 = 0
	pickupObjType i64 = 0
	roomleaveResult i64 = 0
	exitRoomTimer i64 = 0
	currGuardColor i64 = 0
	seamless i64 = 0
	isRestartLevel bool = false
	needFullRedraw i64 = 0
	needRedrawBecauseFlipped i64 = 0
	isBlindMode i64 = 0
	leveldoorRight i64 = 0
	leveldoorYbottom i64 = 0
	palaceWallColors i64[] = zeros(44 * 3)
	randomSeed i64 = 0   # dword

	# sound: the one to play next, the one playing and how many ticks it has left
	nextSound i64 = -1
	currentSound i64 = -1
	soundPlaying bool = false
	soundTicksLeft i64 = 0
	lastLooseSound i64 = 0
	soundInterruptible i64[] = soundInterruptibleStart.copy()
	soundsPlayed i64[] = []   # this frame's, for the host to play
	soundsStopped bool = false   # the host stops what plays

	# the colour the screen's black flashed in this frame (-1 none)
	flashShown i64 = -1

	# transitional objects and mobs
	trob Trob = Trob()
	trobs Trob[] = []
	curmob Mob = Mob()
	mobs Mob[] = []
	curmobIndex i64 = 0

	# drawing
	drawXh i64 = 0
	drawnRow i64 = 0
	drawBottomY i64 = 0
	drawMainY i64 = 0
	drawnCol i64 = 0
	tileLeft i64 = 0
	modifierLeft i64 = 0
	leftroomTiles i64[] = zeros(3)
	leftroomMods i64[] = zeros(3)
	rowBelowTiles i64[] = zeros(10)
	rowBelowMods i64[] = zeros(10)
	addTable i64 = 0   # ptr_add_table: the table the tile routines add to
	gateTopY i64 = 0
	gateOpenness i64 = 0
	gateBottomY i64 = 0
	obj2 ObjVars = ObjVars()
	backtable BackItem[] = []
	foretable BackItem[] = []
	midtable MidItem[] = []
	wipetable WipeItem[] = []
	objtable ObjItem[] = []
	peels Peel[] = []
	drects Rect[] = []   # what the tables drew, to copy to the display
	needDrects bool = false
	objDirection i64 = 0
	objClipLeft i64 = 0
	objClipTop i64 = 0
	objClipRight i64 = 320
	objClipBottom i64 = 192
	objXh i64 = 0
	objXl i64 = 0
	objY i64 = 0
	objChtab i64 = 0
	objId i64 = 0
	objTilepos i64 = 0
	objX i64 = 0
	wipeFrames i64[] = zeros(30)
	wipeHeights i64[] = zeros(30)
	redrawFramesAnim i64[] = zeros(30)
	redrawFrames2 i64[] = zeros(30)
	redrawFramesFloorOverlay i64[] = zeros(30)
	redrawFramesFull i64[] = zeros(30)
	redrawFramesFore i64[] = zeros(30)
	tileObjectRedraw i64[] = zeros(30)
	redrawFramesAbove i64[] = zeros(10)
	redrawHeight i64 = 0

	# the shows: the title, the cutscenes and the ending as steps run a tick at a time
	inShow bool = false
	showSteps Step[] = []
	showPc i64 = 0
	showWait i64 = -1   # a waiting step's ticks or columns, -1 before it starts
	showThen i64 = 0
	showThenArg i64 = 0
	startLevel i64 = -1   # -1 in the title and the demo
	fading i64 = 0   # a cutscene's fade: 1 in, -1 out
	fadePos i64 = 0
	fadeSubTick i64 = 0
	cutsceneWaitFrames i64 = 0
	cutsceneTicksLeft i64 = 0
	cutsceneFrameTime i64 = 6
	disableKeys bool = false
	hourglassState i64 = 0
	hourglassSandflow i64 = -1
	whichTorch i64 = 0
	princessTorchFrame i64[] = [1, 6]
	stars Star[] = startStars()
	hallOfFame HofEntry[] = []
	hofIndex i64 = 0
	nameBoxPeel Peel = Peel(rect = Rect(0, 0, 0, 0), pixels = image.Image(1, 1))
	inputStr InputStr = InputStr()

	# the keys, the saves and the replays
	options Options = Options()
	storedOptions Options = Options()   # the options while a replay's are in force
	saveDir str = ""   # where QUICKSAVE.SAV, PRINCE.SAV and PRINCE.HOF are kept
	isPaused bool = false
	menu Menu = Menu()
	settingsDir str = "."   # where SDLPoP.ini and SDLPoP.cfg are
	timerShown bool = false   # T: the time left over the game
	menuWanted bool = false   # Backspace asked for the menu even when Esc does not
	menuFont pop.Font = smallFont()
	smallFont bool = false   # the menu's font is the one in use
	frameLength i64 = 5   # the ticks the frame being played lasts
	soundOn bool = true
	pausedWait bool = false   # the game waits for a key after Esc
	cheatsEnabled bool = false
	needQuickSave bool = false
	needQuickLoad bool = false
	dontResetTime bool = false
	recording bool = false
	replaying bool = false
	saveReplayWait bool = false   # the dialog that asks a replay's name is up
	saveReplayThen bool = false   # Ctrl+R ended the recording: the game starts again after it
	skippingReplay bool = false   # the replay runs on without waits or sounds
	replaySeekTarget i64 = 0   # where skipping stops: seekNextRoom, seekNextLevel
	currTick i64 = 0
	specialMove i64 = 0
	replayMoves u8[] = []
	replay Replay = Replay()
	nextReplayNumber i64 = 0   # the replay of the folder that Tab plays next
	replayFromFolder bool = false
	copyprotPlac i64 = 0   # the potion level's right potion, 0..13
	copyprotIdx i64 = 0   # the manual's entry it is asked by
	cplevelEntr i64[] = zeros(14)
	copyprotRoom i64[] = [3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4]
	pendingStart i64 = -1   # a game to start when the frame is over
	dialogWait bool = false   # a message waits for a key
	keepLastSeed i64 = 0
	preservedSeed i64 = 0

	# how the game ends
	gameOver bool = false
