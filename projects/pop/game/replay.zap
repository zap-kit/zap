# Replays (SDLPoP's replay.c, doc/replay_format.txt): the moves of a game recorded a byte a tick
# with the state it started from, and played again. The file is the .p1r of SDLPoP, so its
# replays play here and these there.

import fs

replayMagic = "P1R"
replayVersion = 102
replayMinVersion = 101
replayDeprecation = 2   # 2 and up: a random draw wasted in loose_shake as DOS does
implementationName = "SDLPoP in Zap"
pub replaysFolder = "replays"
pub seekNextRoom = 0
pub seekNextLevel = 1

pub type Blob:
	bytes u8[]

# a replay as the file holds it
pub type Replay:
	savestate u8[] = []
	sections Blob[] = []   # the options of the five sections
	startLevel i64 = -1
	seed i64 = 0
	ticks i64 = 0
	deprecation i64 = 2
	levelset str = ""
	moves u8[] = []

# the 2 bits of a move's x or y, signed
fn signed2(bits i64):
	-1 if bits == 3 else bits

# start_recording: the game from the next tick on is kept
pub fn startRecording(mut g Game):
	g.currTick = 0
	g.recording = true
	g.replayMoves = []

# add_replay_move: this tick's controls kept, with the state it starts from at the first
fn addReplayMove(mut g Game):
	if g.currTick == 0:
		g.prandom(1)   # makes sure the seed is begun
		g.replay.seed = g.randomSeed
		g.replay.savestate = g.savestate()
		g.displayTextBottom("RECORDING")
		g.textTimeTotal = 24
		g.textTimeRemaining = 24
	bits = (g.controlX & 3) | ((g.controlY & 3) << 2)
	if g.controlShift != 0: bits |= 0x10
	bits |= g.specialMove << 5
	g.specialMove = 0
	if g.currTick < g.replayMoves.len:
		g.replayMoves[g.currTick] = u8.wrap(bits)
	else:
		g.replayMoves.push(u8.wrap(bits))
	g.currTick += 1

# stop_recording: the dialog that asks the replay's file name, then the replay saved
pub fn stopRecording(mut g Game):
	g.recording = false
	g.saveReplayDialog(false)

# save_recorded_replay_dialog: the name is typed over the game, a tick at a time; `thenRestart`
# is Ctrl+R's, which starts the game again afterwards
pub fn saveReplayDialog(mut g Game, thenRestart bool):
	g.screen.copyRect(dialogPeelRect(), false)
	g.drawDialog("Save replay\nenter the filename...\n\n")
	g.needFullRedraw = 1
	g.saveReplayWait = true
	g.saveReplayThen = thenRestart
	g.startInputStr(replayNameRect, textColor, replayNameColor, 0, 64)

replayNameRect = Rect(104, 62, 118, 258)
replayNameColor = 8

# a tick of the dialog: Enter saves, Esc cancels
pub fn saveReplayTick(mut g Game):
	status = g.inputStrTick()
	if status > 0 and g.inputStr.text.isEmpty:
		g.startInputStr(replayNameRect, textColor, replayNameColor, 0, 64)   # at least a letter
		return
	if status == 0: return
	g.saveReplayWait = false
	if status > 0:
		_ = fs.createDir(g.savePath(replaysFolder))
		_ = fs.writeBytes(g.savePath("{replaysFolder}/{g.inputStr.text}.p1r"), g.recordedReplay())
		g.displayTextBottom("REPLAY SAVED")
	else:
		g.displayTextBottom("REPLAY CANCELED")
	g.textTimeTotal = 24
	g.textTimeRemaining = 24
	if g.saveReplayThen: g.restartGame()

# save_recorded_replay: the bytes of the file
pub fn recordedReplay(g Game) u8[]:
	out = replayMagic.bytes().copy()
	out.pushU16le(0)
	out.push(u8.wrap(replayVersion))
	out.push(u8.wrap(replayDeprecation))
	out.pushU32le(0)   # when it was made, which nothing reads
	out.pushU32le(0)
	out.push(0)   # the original levels
	out.push(u8.wrap(implementationName.len))
	out.extend(implementationName.bytes())
	out.pushU32le(g.replay.savestate.len)
	out.extend(g.replay.savestate)
	for i in 0..5:
		section = g.options.replayBytes(i)
		out.pushU32le(section.len)
		out.extend(section)
	out.pushU16le(g.startLevel)
	out.pushU32le(g.replay.seed)
	out.pushU32le(g.currTick)
	out.extend(g.replayMoves[..g.currTick])
	out

# load_replay: the replay of a file's bytes; none when it is not one this reads
pub fn readReplay(b u8[]) Replay?:
	if b.len < 20 or not b.startsWith(replayMagic): return none
	r = Reader(d = b, at = 3)
	class = r.u16()
	version = r.u8()
	deprecation = r.u8()
	r.skip(8)
	levelset = r.bytes(r.u8()).cStringAt(0)
	r.bytes(r.u8())
	if class != 0 or version < replayMinVersion or deprecation > replayDeprecation: return none
	size = r.u32()
	if not r.has(size): return none
	rep = Replay(deprecation, levelset, savestate = r.bytes(size))
	loop 5:
		n = r.u32()
		if not r.has(n): return none
		rep.sections.push(Blob(r.bytes(n)))
	rep.startLevel = r.i16()
	rep.seed = r.u32()
	rep.ticks = r.u32()
	if not r.has(rep.ticks): return none
	rep.moves = r.bytes(rep.ticks)
	rep

# start_replay: the replay played from its first tick, its options in force until it ends
pub fn startReplay(mut g Game, rep Replay):
	g.replay = rep.copy()
	g.replayMoves = rep.moves.copy()
	g.storedOptions = g.options.copy()
	for i in 0..5:
		g.options.setReplayBytes(i, rep.sections[i].bytes)
	g.options.values["enable_replay"] = [1]
	g.replaying = true
	g.currTick = 0
	g.startLevel = rep.startLevel
	g.initGame(rep.startLevel)

# the replays of the folder, the newest first
fn replayFiles(g Game):
	dir = g.savePath(replaysFolder)
	names = (fs.list(dir) ?? []).filter(.endsWith(".p1r")).map("{dir}/{it}")
	names.sortedBy(-(fs.modified(it) ?? 0))

# open_next_replay_file and start_replay: the next replay of the folder played; false when
# there is none
pub fn startNextReplay(mut g Game) bool:
	files = g.replayFiles()
	while g.nextReplayNumber < files.len:
		file = files[g.nextReplayNumber].copy()
		g.nextReplayNumber += 1
		if fs.readBytes(file) is b:
			if readReplay(b) is rep:
				g.replayFromFolder = true
				g.startReplay(rep)
				return true
	g.nextReplayNumber = 0
	false

# replay_cycle: Tab in a replay: the next one of the folder, or the game from its title
fn cycleReplay(mut g Game):
	g.replaying = false
	g.skippingReplay = false
	g.options = g.storedOptions.copy()
	if not g.replayFromFolder or not g.startNextReplay():
		g.replayFromFolder = false
		g.startLevel = -1
		g.startTitle()

# replay_restore_level: the state the replay began from, put back before the first room is drawn
fn replayRestoreLevel(mut g Game):
	if g.currTick == 0:
		g.loadSavestate(g.replay.savestate)
		g.restoreRoomAfterQuickLoad()

# end_replay: the game goes back to its title
pub fn endReplay(mut g Game):
	g.replaying = false
	g.skippingReplay = false
	g.options = g.storedOptions.copy()
	g.startLevel = -1
	g.startTitle()

# do_replay_move: this tick's controls are the replay's
fn doReplayMove(mut g Game):
	if g.currTick == 0:
		g.randomSeed = g.replay.seed
	if g.currTick == g.replay.ticks:
		g.endReplay()
		return
	if g.currentLevel == g.nextLevel:
		m = i64(g.replayMoves[g.currTick])
		g.controlX = signed2(m & 3)
		g.controlY = signed2((m >> 2) & 3)
		if g.remMin != 0 and g.kid.alive > 6:
			g.controlShift = ctrlReleased   # restarting is a special move
		else:
			g.controlShift = ctrlHeld if (m & 0x10) != 0 else ctrlReleased
		special = m >> 5
		if special == moveRestart:
			g.stopSounds()
			g.isRestartLevel = true
		elif special == moveEffectEnd:
			g.stopSounds()
			if g.needLevel1Music == 2: g.needLevel1Music = 0
			g.isFeatherFall = 0
		g.currTick += 1
