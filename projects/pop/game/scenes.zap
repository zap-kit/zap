# The scripts of the title, the cutscenes between levels, the time's end and the ending
# (SDLPoP's seg000.c show_title and seg001.c's cutscenes; the Apple II's PRINCESS.S), as the
# show's steps.

fn act(code i64, arg i64):
	Step.Act(code, arg)

fn sound(id i64):
	Step.Act(actPlaySound, id)

fn seqKid(seq i64):
	Step.Act(actSeqKid, seq)

fn seqShad(seq i64):
	Step.Act(actSeqShad, seq)

fn initKid(which i64):
	Step.Act(actInit, which)

fn initShad(which i64):
	Step.Act(actInit, 100 + which)

fn frames(n i64):
	Step.Frames(n)

# the cutscene before level n, none for most (tbl_cutscenes)
pub fn cutsceneSteps(g Game, n i64) Step[]:
	if n == 2 or n == 6: return g.cutscene2And6()
	if n == 4:
		return [
			sound(soundCutscene2),
			act(actHourglassFrame, 0),
			initShad(initPrincessLying),
			.CutFadeIn,
			frames(26),
			.CutFadeOut
		]
	if n == 8:
		return [
			sound(soundCutscene8),
			act(actHourglassFrame, 0),
			initKid(initMouseCu8),
			initShad(initPrincessCrouching),
			.CutFadeIn,
			frames(20),
			seqKid(seqMouseStandUpAndGo),
			frames(20),
			seqShad(seqPrincessStandUpPV2),
			frames(20),
			act(actKidFrame0, 0),
			.CutFadeOut
		]
	if n == 9:
		return [
			sound(soundCutscene8),
			act(actHourglassFrame, 0),
			initShad(initPrincessStand),
			.CutFadeIn,
			initKid(initMouseGo),
			frames(5),
			seqShad(seqPrincessCrouchDownPV2),
			frames(9),
			seqKid(seqMouseStand),
			frames(58),
			.CutFadeOut
		]
	if n == 12:
		if g.hourglassFrame() >= 6:
			return [
				act(actHourglassFrame, 0),
				initShad(initPrincessX156),
				sound(soundCutscene12ShortTime),
				.CutFadeIn,
				frames(2),
				seqShad(98),
				frames(24),
				.CutFadeOut
			]
		return g.cutscene2And6()
	[]

fn cutscene2And6(g Game):
	[
		sound(soundCutscene2),
		act(actHourglassFrame, 0),
		initShad(initPrincessRight),
		Step.CutFadeIn,
		frames(26),
		Step.CutFadeOut
	]

# the princess waits, Jaffar comes and turns the hourglass (the title's story)
fn pvScene():
	[
		initShad(initPrincess),
		Step.CutFadeIn,
		initKid(initVizier),
		frames(2),
		sound(soundStory2Princess),
		Step.FramesWhileSound,
		act(actFrameTime, 8),
		frames(5),
		sound(soundGateClosing),
		Step.FramesWhileSound,
		sound(soundPrincessDoorOpening),
		frames(3),
		seqShad(98),   # the princess turns
		frames(5),
		seqKid(96),   # Jaffar walks
		frames(6),
		sound(soundStory3JaffarComes),
		seqKid(97),   # Jaffar stops
		frames(4),
		frames(18),
		seqKid(96),
		frames(30),
		seqKid(97),
		frames(35),
		seqKid(102),   # Jaffar conjures
		act(actFrameTime, 7),
		frames(1),
		seqShad(99),   # the princess steps back
		frames(17),
		act(actFlash, 0),
		Step.FramesWhileSound,
		seqKid(100),   # Jaffar stops conjuring and leaves
		act(actSandflow, 0),
		frames(6),
		sound(soundStory4JaffarLeaves),
		frames(24),
		act(actHourglass, 2),
		frames(9),
		seqShad(113),   # the princess looks down
		frames(28),
		Step.CutFadeOut
	]

# the cutscene with its load_intro around it
fn intro(whichImages i64, scene Step[]):
	steps = [Step.Intro(whichImages)]
	steps.extend(scene)
	steps.push(.SceneEnd)
	steps

# play_level's start: the level's cutscene, then the level
pub fn playLevel(mut g Game, n i64):
	if n != g.currentLevel:
		scene = g.cutsceneSteps(g.options.optAt("tbl_cutscenes_by_index", n))
		if not scene.isEmpty and not g.recording and not g.replaying:
			g.startShow(intro(1 if n > 2 else 0, scene), thenPlayLevel, n)
			return
	g.playLevelAfterIntro(n)

# show_title
pub fn startTitle(mut g Game):
	g.initCopyprot()
	if g.options.isOn("skip_title"):
		g.startGameAt(g.startLevel if g.startLevel >= 0 else g.options.opt("first_level"))
		return
	g.startLevel = -1
	g.clearScreenAndSounds()
	steps = [
		Step.MakeOffscreen(200),
		Step.TitleImages(true),
		Step.Image(imageTitleMain),
		Step.FadeIn(0x1000),
		Step.CopyAll,
		Step.SoundNow(soundIntroMusic),
		Step.Image(imageTitlePresents),
		Step.Wait(0x82),
		Step.CopyTitles,
		Step.Image(imageTitleMain),
		Step.Wait(0xCD),
		Step.CopyTitles,
		Step.Image(imageTitleMain),
		Step.Image(imageTitleGame),
		Step.Wait(0x41),
		Step.CopyTitles,
		Step.Image(imageTitleMain),
		Step.Wait(0x10E),
		Step.CopyTitles,
		Step.Image(imageTitleMain),
		Step.Image(imageTitlePop),
		Step.Image(imageTitleMechner),
		Step.Wait(0xEB),
		Step.CopyTitles,
		Step.Image(imageStoryFrame),
		Step.Image(imageStoryAbsence),
		Step.WaitSound,
		Step.SoundNow(soundStory1Absence),
		Step.Transition,
		Step.Wait(0x258),
		Step.FadeOut(0x800)
	]
	steps.extend(intro(0, pvScene()))
	steps.extend([
		.TitleImages(true),
		.Image(imageStoryFrame),
		.Image(imageStoryMarry),
		.FadeIn(0x800),
		.Image(imageTitleMain),
		.Image(imageTitlePop),
		.Image(imageTitleMechner),
		.WaitSound,
		.Transition,
		.Wait(0x78),
		.Image(imageStoryFrame),
		.Image(imageStoryCredits),
		.Transition,
		.Wait(0x168)
	])
	if not g.hallOfFame.isEmpty:
		steps.extend(
			[
				.Image(imageStoryFrame),
				.Image(imageHofPop),
				.ShowHof,
				.Transition,
				.Wait(0xF0)
			]
		)
	steps.extend([.WaitSound, .FadeOut(0x1800), .MakeOffscreen(192)])
	g.startShow(steps, thenDemo, 0)

# start_game's last step: the game from level n
pub fn startGameAt(mut g Game, n i64):
	g.inShow = false
	g.showSteps = []
	g.startLevel = n
	g.clearScreenAndSounds()
	g.screen.makeOffscreen(192)
	g.initGame(n)

# expired: the hourglass run out, then the title
pub fn expiredShow(mut g Game):
	g.clearScreenAndSounds()
	g.screen.makeOffscreen(200)
	scene = [
		act(actDisableKeys, 0),
		act(actHourglass, 7),
		act(actSandflow, -1),
		sound(soundOutOfTime),
		Step.CutFadeIn,
		frames(2),
		frames(100),
		Step.CutFadeOut,
		Step.WaitSound
	]
	g.startShow(intro(1, scene), thenTitle, 0)

# end_sequence: the kid and the princess, the hall of fame, then the title
pub fn endSequence(mut g Game):
	scene = [
		act(actDisableKeys, 0),
		Step.CopyAll,
		sound(soundEmbrace),
		initShad(initEndingPrincess),
		initKid(initEndingKid),
		frames(8),
		seqShad(seqPrincessTurnAndHug),
		frames(5),
		seqKid(seqStopRun),
		frames(2),
		act(actKidFrame0, 0),
		frames(39)
	]
	if not g.options.isOn("no_mouse_in_ending"):
		scene.extend([initKid(initMouse1), frames(9), seqKid(seqMouseStandsUp), frames(41)])
	scene.extend([
		.CutFadeOut,
		.WaitSound
	])
	steps = intro(1, scene)
	steps.extend([
		.ClearScreenAndSounds,
		.SoundNow(soundEndingMusic),
		.MakeOffscreen(200),
		.TitleImages(false),
		.Image(imageStoryFrame),
		.Image(imageStoryHail),
		.FadeIn(0x800),
		.Wait(900),
		.Image(imageTitleMain),
		.Transition,
		.Wait(240 - 80)
	])
	if g.hofPlace() < 6:
		# a time among the six best: its name asked
		steps.extend([
			.FadeOut(0x1000),
			.HallOfFame,
			.Image(imageStoryFrame),
			.Image(imageHofPop),
			.ShowHof,
			.NameBox,
			.FadeIn(0x1800),
			.EnterName,
			.Wait(120),
			.Image(imageTitleMain),
			.Transition
		])
	steps.extend([.WaitSound, .FadeOut(0x1000)])
	g.startShow(steps, thenTitle, 0)

# clear_screen_and_sounds
pub fn clearScreenAndSounds(mut g Game):
	g.stopSounds()
	g.screen.toOnscreen = true
	g.peels.clear()
	g.freeChtabsFrom(chtabKid)
	g.currentLevel = -1

# the cutscenes' characters (init_princess and its kin), as char
fn initCutsceneChar(mut g Game, which i64):
	if which == initMouseCu8:
		g.initMouseGoChar()
		g.char.x = 144
		g.seqtblOffsetChar(seqMouse)
		g.playSeq()
	elif which == initMouseGo:
		g.initMouseGoChar()
	elif which == initPrincessCrouching:
		g.princessAt(false, 131, 169, seqPrincessCrouchingPV2)
	elif which == initPrincessStand:
		g.princessAt(true, 144, 169, seqPrincessStandPV1)
	elif which == initPrincessX156:
		g.initPrincessChar()
		g.char.x = 156
	elif which == initPrincessLying:
		g.princessAt(false, 92, 162, seqPrincessLyingPV2)
	elif which == initPrincessRight:
		g.initPrincessChar()
		g.char.direction = dirRight
	elif which == initEndingPrincess:
		g.princessAt(false, 136, 164, seqPrincessStandPV2)
	elif which == initMouse1:
		g.initMouseGoChar()
		g.char.x = byte(g.char.x - 2)
		g.char.y = 164
	elif which == initPrincess:
		g.initPrincessChar()
	elif which == initVizier:
		g.initPerson(charidVizier, 198, 166, seqJaffarStandPV1)
	elif which == initEndingKid:
		g.initPerson(charidKid, 198, 164, seqStartRun)

# a character facing left at (x, y) in a sequence
fn initPerson(mut g Game, charid i64, x i64, y i64, seq i64):
	g.char.charid = charid
	g.char.x = x
	g.char.y = y
	g.char.direction = dirLeft
	g.seqtblOffsetChar(seq)
	g.playSeq()

fn initPrincessChar(mut g Game):
	g.initPerson(charidPrincess, 120, 166, seqPrincessStandPV1)

# init_princess (turned right if asked), then placed and started in another sequence
fn princessAt(mut g Game, right bool, x i64, y i64, seq i64):
	g.initPrincessChar()
	if right: g.char.direction = dirRight
	g.char.x = x
	g.char.y = y
	g.seqtblOffsetChar(seq)
	g.playSeq()

fn initMouseGoChar(mut g Game):
	g.initPerson(charidMouse, 199, 167, seqMouseForward)

# ---------- the hall of fame ----------

pub type HofEntry:
	name str
	min i64
	tick i64

hofRects = [
	Rect(84, 72, 96, 248),
	Rect(98, 72, 110, 248),
	Rect(112, 72, 124, 248),
	Rect(126, 72, 138, 248),
	Rect(140, 72, 152, 248),
	Rect(154, 72, 166, 248)
]

# where the time left at the end goes among the six best times, 6 when it doesn't
fn hofPlace(g Game):
	index = 0
	while index < g.hallOfFame.len and
		not (
			g.hallOfFame[index].min < g.remMin or
				(g.hallOfFame[index].min == g.remMin and g.hallOfFame[index].tick < g.remTick)
		):
		index += 1
	index

# the ending's time put in its place, its name to be typed
fn enterHallOfFame(mut g Game):
	g.hofIndex = g.hofPlace()
	g.hallOfFame.insert(g.hofIndex, HofEntry(name = "", min = g.remMin, tick = g.remTick))
	while g.hallOfFame.len > 6:
		g.hallOfFame.pop()

# the box the name is typed in, over its place (offset4_rect_add)
fn nameRect(g Game):
	r = hofRects[g.hofIndex]
	Rect(top = r.top - 1, left = r.left - 4, bottom = r.bottom - 1, right = r.right - 40)

fn drawNameBox(mut g Game):
	g.screen.toOnscreen = false
	g.nameBoxPeel = g.screen.readPeel(g.nameRect())
	g.screen.drawRect(g.pal, g.nameRect(), nameBoxColor)
	g.screen.toOnscreen = true

nameColor = 0xBE
nameBoxColor = 0xB7

# input_str in the hall of fame: a line that is empty, or cancelled, is asked again
fn enterNameTick(mut g Game):
	if g.showWait < 0:
		g.showWait = 0
		g.startInputStr(g.nameRect(), nameColor, nameBoxColor, 4, 24)
	status = g.inputStrTick()
	g.hallOfFame[g.hofIndex].name = g.inputStr.text.copy()
	if status < 0 or (status > 0 and g.inputStr.text.isEmpty):
		g.startInputStr(g.nameRect(), nameColor, nameBoxColor, 4, 24)
	if status <= 0 or g.inputStr.text.isEmpty: return false
	g.screen.restorePeel(g.nameBoxPeel)
	g.showHofText(hofRects[g.hofIndex], -1, g.inputStr.text)
	g.writeHallOfFame()
	true

fn showHof(mut g Game):
	g.screen.toOnscreen = false
	for i in 0..g.hallOfFame.len:
		e = g.hallOfFame[i]
		# a time left of 0 is 0:00; a negative one is time counted up from 0:00
		minutes = e.min - 1 if e.min > 0 else (0 if e.min == 0 else e.min.abs() - 1)
		seconds = e.tick / 12 if e.min > 0 else (0 if e.min == 0 else (719 - e.tick) / 12)
		g.showHofText(hofRects[i], -1, e.name)
		g.showHofText(hofRects[i], 1, "{minutes}:{seconds:02}")
	g.screen.toOnscreen = true

fn showHofText(mut g Game, r Rect, xAlign i64, text str):
	shadow = Rect(top = r.top + 1, left = r.left + 1, bottom = r.bottom + 1, right = r.right + 1)
	g.showText(shadow, xAlign, 0, text, 0)
	g.showText(r, xAlign, 0, text, 0xB7)
