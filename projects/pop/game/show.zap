# The title, the cutscenes and the ending as a script of steps run a tick (1/60 s) at a time
# (SDLPoP's show_title, load_intro, proc_cutscene_frame, fade_in_1/2, transition_ltr; the
# original's blocking loops unrolled): each step either acts at once or waits its ticks.

pub type Step:
	MakeOffscreen(height i64)
	TitleImages(blue bool)
	Image(which i64)   # draw_full_image onto the picture off the display
	CopyAll   # the picture off the display shown whole
	CopyTitles   # its part the title's texts take
	Wait(ticks i64)   # do_wait / pop_wait
	SoundNow(id i64)   # play_sound_from_buffer
	WaitSound   # until the sound ends
	Transition   # transition_ltr: the picture shown from the left, 2 columns at a time
	FadeIn(rows i64)   # fade_in_2
	FadeOut(rows i64)   # fade_out_2
	Intro(whichImages i64)   # load_intro up to its cutscene
	Act(code i64, arg i64)   # a cutscene's instant action
	Frames(n i64)   # proc_cutscene_frame(n)
	CutFadeIn   # fade_in_1, through cutscene frames
	CutFadeOut   # fade_out_1
	FramesWhileSound   # proc_cutscene_frame(1) while a sound plays
	SceneEnd   # load_intro's end; a key in the cutscene skips to here
	ClearScreenAndSounds
	HallOfFame   # the ending's new time among the best
	ShowHof
	NameBox   # the box its name is typed in
	EnterName   # input_str

# the actions of the cutscenes
pub actPlaySound = 0
pub actHourglass = 1   # set_hourglass_state
pub actHourglassFrame = 2   # set_hourglass_state(hourglass_frame())
pub actSandflow = 3
pub actFrameTime = 4
pub actSeqKid = 5   # seqtbl_offset_kid_char
pub actSeqShad = 6
pub actKidFrame0 = 7
pub actInit = 8   # a character placed: arg one of the inits below, saved as the kid (arg >= 100: as the shadow)
pub actFlash = 9   # flash_time 5 in white
pub actDisableKeys = 10

# the characters' starts in cutscenes
pub initMouseCu8 = 0
pub initMouseGo = 1
pub initPrincessCrouching = 2
pub initPrincessStand = 3
pub initPrincessX156 = 4
pub initPrincessLying = 5
pub initPrincessRight = 6
pub initEndingPrincess = 7
pub initMouse1 = 8
pub initPrincess = 9
pub initVizier = 10
pub initEndingKid = 11

# what follows a show
pub thenPlayLevel = 0   # the level loaded after its cutscene (arg: the level)
pub thenDemo = 1
pub thenTitle = 2

pub fn startShow(mut g Game, move steps Step[], then i64, thenArg i64):
	g.showSteps = steps
	g.showPc = 0
	g.showWait = -1
	g.showThen = then
	g.showThenArg = thenArg
	g.inShow = true

# a key, or the button, this tick (do_paused's answer)
pub fn hasKey(g Game) bool:
	g.input.pressed != "" or g.input.left or g.input.right or g.input.up or g.input.down or
		g.input.shift or
		g.input.restart or
		g.input.showTime or g.input.nextLevel

# a tick of the show; false when it handed back to the game
pub fn runShowTick(mut g Game) bool:
	g.soundsPlayed.clear()
	g.flashShown = -1
	loop:
		if not g.inShow: return false
		if g.showPc >= g.showSteps.len:
			g.endShow()
			return false
		done = g.runStep(g.showSteps[g.showPc])
		if not g.inShow: return false   # a key started the game
		if not done: break   # the step waits: the tick is over
		g.showPc += 1
		g.showWait = -1
	g.tickSounds(1)
	true

# the step at the show's counter: true when done, false when it waits a tick more
fn runStep(mut g Game, step Step) bool:
	match step:
		MakeOffscreen(h):
			g.screen.makeOffscreen(h)
			true
		TitleImages(blue):
			g.loadTitleImages(blue)
			true
		Image(which):
			g.screen.toOnscreen = false
			g.drawFullImage(which)
			g.screen.toOnscreen = true
			true
		CopyAll:
			g.screen.copyRect(Rect(0, 0, 200, 320), false)
			true
		CopyTitles:
			g.screen.copyRect(Rect(top = 106, left = 24, bottom = 195, right = 296), false)
			true
		Wait(ticks): g.waitTicks(ticks)
		SoundNow(id):
			g.currentSound = id
			g.startSound(id)
			true
		WaitSound: g.waitSoundTick()
		Transition: g.transitionTick()
		FadeIn(rows): g.fadeTick(true, rows)
		FadeOut(rows): g.fadeTick(false, rows)
		Intro(which): g.introTick(which)
		Act(code, arg):
			g.cutsceneAct(code, arg)
			true
		Frames(n): g.framesTick(n, false)
		CutFadeIn: g.cutFadeTick(true)
		CutFadeOut: g.cutFadeTick(false)
		FramesWhileSound: g.framesTick(1, true)
		SceneEnd:
			g.endIntro()
			true
		ClearScreenAndSounds:
			g.clearScreenAndSounds()
			true
		HallOfFame:
			g.enterHallOfFame()
			true
		ShowHof:
			g.showHof()
			true
		NameBox:
			g.drawNameBox()
			true
		EnterName: g.enterNameTick()

# the title's waits give way to a key: the game starts
fn titleKey(mut g Game):
	if g.startLevel < 0 and g.hasKey(): return g.startFromKey()
	false

fn waitTicks(mut g Game, ticks i64):
	if g.showWait < 0: g.showWait = ticks
	if g.titleKey(): return false
	if g.showWait == 0: return true
	g.showWait -= 1
	g.showWait == 0

fn waitSoundTick(mut g Game):
	if g.titleKey(): return false
	not g.isSoundPlaying()

# transition_ltr: 160 strips of 2 columns at 120 a second, two a tick
fn transitionTick(mut g Game):
	if g.showWait < 0: g.showWait = 0
	if g.titleKey(): return false
	loop 2:
		if g.showWait < 320:
			g.screen.copyRect(
				Rect(top = 0, left = g.showWait, bottom = 200, right = g.showWait + 2),
				false
			)
			g.showWait += 2
	g.showWait >= 320

# fade_in_2 / fade_out_2: the palette a step brighter (or darker) every 2 ticks, 64 steps
fn fadeTick(mut g Game, fadeIn bool, rows i64):
	if g.showWait < 0:
		g.showWait = 0
		g.fadePos = 0x40 if fadeIn else 0
		if not fadeIn: g.screen.copyRect(Rect(0, 0, 200, 320), false)
	if g.titleKey(): return false
	g.showWait += 1
	if g.showWait % 2 == 1:
		g.fadePos += -1 if fadeIn else 1
		g.screen.fadeOnscreen(g.fadePos)
		done = g.fadePos == 0 if fadeIn else g.fadePos >= 0x40
		if done:
			if fadeIn:
				g.screen.copyRect(Rect(0, 0, 200, 320), false)
			else:
				g.screen.toOnscreen = true
				g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)
			return true
	false

# load_intro: the room drawn once the sound playing ends
fn introTick(mut g Game, whichImages i64):
	if g.showWait < 0:
		g.showWait = 0
		g.screen.toOnscreen = true
		g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)
		g.startIntro(whichImages)
	if g.isSoundPlaying(): return false
	g.needDrects = true
	g.resetCutscene()
	true

# a key in a cutscene (but the time's end) skips the rest of it; in the title's, starts the game
fn cutsceneKey(mut g Game):
	if g.disableKeys or not g.hasKey(): return false
	if g.titleKey(): return true
	g.stopSounds()
	g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)
	g.fading = 0
	while g.showPc < g.showSteps.len and not g.showSteps[g.showPc].isSceneEnd():
		g.showPc += 1
	g.showPc -= 1   # the runner steps past to the scene's end
	true

fn isSceneEnd(step Step):
	match step:
		SceneEnd: true
		_: false

# proc_cutscene_frame(n): n frames of cutsceneFrameTime ticks; with whileSound, frames until the
# sound ends
fn framesTick(mut g Game, n i64, whileSound bool):
	if g.showWait < 0:
		g.showWait = 0
		g.cutsceneWaitFrames = n
		g.cutsceneTicksLeft = 0
	if g.cutsceneTicksLeft == 0:
		g.cutsceneFrame()
		g.cutsceneTicksLeft = g.cutsceneFrameTime
	if g.cutsceneKey(): return true
	if g.fading != 0 and g.fadeStep(): return g.framesEnded(whileSound)
	g.cutsceneTicksLeft -= 1
	if g.cutsceneTicksLeft == 0:
		g.cutsceneWaitFrames -= 1
		if g.cutsceneWaitFrames == 0: return g.framesEnded(whileSound)
	false

fn framesEnded(mut g Game, whileSound bool):
	g.cutsceneTicksLeft = 0
	if whileSound and g.isSoundPlaying():
		g.cutsceneWaitFrames = 1
		return false
	true

# fade_in_1 / fade_out_1: the cutscene's frames run on while the palette fades
fn cutFadeTick(mut g Game, fadeIn bool):
	if g.showWait < 0:
		g.showWait = 0
		g.fading = 1 if fadeIn else -1
		g.fadePos = 0x40 if fadeIn else 0
		g.fadeSubTick = 0
		g.cutsceneWaitFrames = 1
		g.cutsceneTicksLeft = 0
		if not fadeIn: g.screen.copyRect(Rect(0, 0, 200, 320), false)
	if g.cutsceneTicksLeft == 0:
		g.cutsceneWaitFrames = 1
		g.cutsceneFrame()
		g.cutsceneTicksLeft = g.cutsceneFrameTime
	if g.cutsceneKey(): return true
	if g.fadeStep():
		g.cutsceneTicksLeft = 0
		return true
	g.cutsceneTicksLeft -= 1
	false

# a fade's step every 2 ticks; true when the fade is done
fn fadeStep(mut g Game):
	g.fadeSubTick += 1
	if g.fadeSubTick % 2 == 0: return false   # a step waits 2 ticks after it
	g.fadePos += -1 if g.fading > 0 else 1
	g.screen.fadeOnscreen(g.fadePos)
	done = g.fadePos == 0 if g.fading > 0 else g.fadePos >= 0x40
	if not done: return false
	if g.fading > 0:
		g.screen.copyRect(Rect(0, 0, 200, 320), false)
	else:
		g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)
	g.fading = 0
	true

fn cutsceneAct(mut g Game, code i64, arg i64):
	if code == actPlaySound:
		g.playSound(arg)
	elif code == actHourglass:
		g.hourglassSandflow = 0
		g.hourglassState = arg
	elif code == actHourglassFrame:
		g.hourglassSandflow = 0
		g.hourglassState = g.hourglassFrame()
	elif code == actSandflow:
		g.hourglassSandflow = arg
	elif code == actFrameTime:
		g.cutsceneFrameTime = arg
	elif code == actSeqKid:
		g.loadkid()
		g.seqtblOffsetChar(arg)
		g.savekid()
	elif code == actSeqShad:
		g.loadshad()
		g.seqtblOffsetChar(arg)
		g.saveshad()
	elif code == actKidFrame0:
		g.kid.frame = 0
	elif code == actInit:
		g.initCutsceneChar(arg % 100)
		if arg >= 100:
			g.saveshad()
		else:
			g.savekid()
	elif code == actFlash:
		g.hourglassState = 1
		g.flashTime = 5
		g.flashColor = 15
	elif code == actDisableKeys:
		g.disableKeys = true

fn endShow(mut g Game):
	g.inShow = false
	then = g.showThen
	arg = g.showThenArg
	g.showSteps = []
	if then == thenPlayLevel:
		g.playLevelAfterIntro(arg)
	elif then == thenDemo:
		g.initGame(0)
	elif then == thenTitle:
		g.startTitle()
