# The interface over the game as the game shows it: the HUD each frame, fed from the game's model
# (the player's health, magicka and stamina, the compass from the cell's north marker, what the
# crosshair is on), and one menu at a time opened by the game's keys (controlmap.txt): I the
# inventory, Q the favorites, Tab the tween menu (whose magic and inventory open their menus), Esc the journal's system page, T the wait menu, E activating what
# the crosshair is on (a container's menu, an item taken, the dialogue with an actor, the sleep
# menu on a bed the player may sleep in). A menu gets the frame's keys and closes when it asks the
# game to (CloseMenu, CloseTweenMenu, the wait menu's OK and Cancel, the message box's button) or
# on Tab and Esc where the movie leaves them to the game. The dialogue leaves the HUD in its
# DialogueMode (the compass and the notices, no crosshair) and the scene undarkened.

import engine
import engine.swf
import engine.swf.avm1
import game
import game.dialogue
import game.sim
import papyrus
import save
import skyrim
import skyrim.nif
import world

# How dark the game makes the scene under a menu, measured on its captures (the scene's mean color
# under the menu over the same view's without it): the journal 0.40, a message box 0.45, the
# inventory and the container 0.87, the tween menu 0.90; the wait menu leaves it.
shadeJournal = 0.40
shadeMessage = 0.45
shadeItems = 0.87
shadeTween = 0.90
shadeNone = 1.0

# a lock's level that only its key opens (XLOC's 255, "Requires Key")
impossibleLock = 255
# the sounds of the notices of a lock (ShowHUDMessage's second argument, 0x14094dc60, 0x140283210)
pub lockedSound = "DRSLocked"
pub lockpickingUnlockSound = "UILockpickingUnlock"
# the cell's north marker, the base form the game's NorthMarker references
northMarker = 0x3
# the lockpick and the skeleton key (Skyrim.esm's default objects LKPK and SKLK): the lockpicking
# menu opens for a player who holds one (LockpickingMenu::OpenMenu 0x14094dc60)
lockpickForm = 0xA
skeletonKeyForm = 0x3_A070
# the external calls that close a menu
closingCalls = ["CloseMenu", "CloseTweenMenu", "OK", "Cancel", "buttonPress", "QuickSave",
	"LoadGame"]
# what the tween menu's HighlightMenu counts: the skills (Up), the magic (Left), the inventory
# (Right) and the map (Down), as its FrameToLabelMap lists them from the second
tweenSkills = 1
tweenMagic = 2
tweenInventory = 3

# The wait or sleep menu while it is open (SleepWaitMenu 0x140974e00): whether it is the sleep,
# whether the hours chosen are passing, the real seconds since the slider last moved.
pub type SleepWaitPanel:
	sleeping bool
	running bool = false
	timer f32 = 0.0

# The sound the wait or sleep menu plays as it closes: only when its run had begun.
pub fn closingSound(sw SleepWaitPanel) str?:
	sleepWaitEndSound if sw.running else none

pub type Screen:
	install skyrim.Install
	texts GameTexts
	width i64
	height i64
	hud avm1.Player
	hudCache swf.DrawCache
	target i64 = 0   # the reference the crosshair is on, 0 for none
	shown HudState? = none   # what the HUD showed the frame before
	items ItemMenu? = none
	panel avm1.Player? = none   # the tween menu, the journal, the wait menu or a message box
	dialogue DialogueMenu? = none
	book BookMenu? = none
	subtitles bool = false   # bDialogueSubtitles: the dialogue's lines shown as text
	menuCache swf.DrawCache? = none
	shade f32 = 1.0   # how much of the scene's light shows under the open menu
	tweenChoice i64 = 0   # what the tween menu highlights (its HighlightMenu)
	saves save.Listed[] = []   # the saves of the folder, the journal's lists
	prefs Prefs   # the player's settings and keys, which the journal's pages change
	requests Request[] = []   # what the player asked of the saves, for the game to carry out
	noticesShown i64 = 0   # how many of the world's notifications the HUD has shown
	eye StealthEye = StealthEye()   # the stealth meter over the crosshair
	sleepWait SleepWaitPanel? = none   # the open panel is the wait or the sleep menu
	traveling i64 = 0   # the load door the player activated, for the game to go through (travel.zap)
	sounds sim.SoundAsk[] = []   # the sounds the interface asked for, taken by the game's sound system

# The interface from the install for a world of these game settings, in a window of width x
# height pixels; the GPU must be ready (a window open).
pub fn openScreen(dir str, settings {str: f64}, subtitles bool, width i64, height i64) Screen ? str:
	install = try skyrim.openInstall(dir)
	texts = try install.openTexts(settings)
	hud = try install.openHud(width, height)
	prefs = install.openPrefs(skyrim.ownDir() ?? "")
	hud.setOpacity(prefs.number("fHUDOpacity:Interface"))
	Screen(install, texts, width, height, hud, hudCache = swf.newDrawCache(), subtitles, prefs)

# a message box shown, as a script's Message.Show or the game's own notices show one
pub fn showMessage(mut s Screen, text str, buttons str[]):
	s.showPanel(s.install.openMessageBox(text, buttons, s.width, s.height), shadeMessage)

# whether a menu is open: the game stops while one is
pub fn isMenuOpen(s Screen) bool:
	s.items != none or s.panel != none or s.dialogue != none or s.book != none

# the actor the player is in dialogue with, none for none
pub fn talkingTo(s Screen) i64?:
	d = try s.dialogue
	d.c.speaker if d.c.phase != .Ended else none

# the heading the compass reads from: the cell's north marker's turn, 0 without one
fn northOf(w sim.GameWorld):
	for id in w.forms.keys().sorted():
		f = w.forms[id]
		if f.base == northMarker and f.cell == w.cell: return f64(f.rotation.z).degrees()
	0.0

# The interface's frame of dt seconds: the input given to the open menu, else its keys used to open
# one or to activate; the HUD fed from the world, the camera's heading (degrees), its eye and view
# direction (the game's units, z up).
pub fn update(
	mut s Screen,
	mut t dialogue.Talk,
	i game.Input,
	dt f32,
	heading f64,
	eye Vec3,
	dir Vec3,
	enemy f64
):
	if s.isMenuOpen():
		s.updateMenu(t, i, dt)
	else:
		for k in i.pressed:
			s.openFor(t, k)
	s.showScriptMessages(t)
	s.sounds.extend(t.vm.rt.world.takeSoundAsks())
	w = ref t.vm.rt.world
	a = w.actors.get(w.player) ?? return
	state = HudState(health = f64(a.percentOf("health")) * 100.0,
		magicka = f64(a.percentOf("magicka")) * 100.0,
		stamina = f64(a.percentOf("stamina")) * 100.0, heading, north = northOf(w), enemy,
		compass = s.prefs.isOn("bShowCompass:Interface"))
	s.hud.updateHud(state)
	best, _ = w.highestLevel()
	s.hud.updateStealth(s.eye, 100 if best > 0 else 0, w.stealth.sneaking)
	s.hud.fadeFullMeters(state, s.shown)
	s.shown = state
	target = 0 if s.isMenuOpen() else (w.targetOf(eye, dir) ?? 0)
	if target != s.target:
		s.target = target
		s.hud.showTarget(s.texts.targetText(w, target), s.prefs.isOn("bShowCrosshair:Interface"))
	if w.notifications.len < s.noticesShown: s.noticesShown = w.notifications.len
	for text in w.notifications[s.noticesShown..]:
		s.hud.showNotice(text)
	s.noticesShown = w.notifications.len
	s.hud.advance()

# The sounds asked for since the last call, in order (menus' and the world's).
pub fn takeSounds(mut s Screen) sim.SoundAsk[]:
	out = s.sounds.copy()
	s.sounds.clear()
	out

# the interface sound `name` asked for
fn ask(mut s Screen, name str):
	s.sounds.push(sim.SoundAsk(name = name.copy()))

# the messages the scripts showed (Message.Show): a box over the game, else a notice
fn showScriptMessages(mut s Screen, mut t dialogue.Talk):
	shown = t.vm.rt.world.shownMessages.copy()
	t.vm.rt.world.shownMessages.clear()
	for id in shown:
		text, buttons, box = s.texts.messageOf(id)
		if not box: t.vm.rt.world.notifications.push(text)
		elif not s.isMenuOpen(): s.showMessage(text, buttons if not buttons.isEmpty else ["Ok"])

# the open menu's frame: its keys, what it asked of the game answered, closed when it asks
fn updateMenu(mut s Screen, mut t dialogue.Talk, i game.Input, dt f32):
	if s.dialogue is mut d:
		d.updateDialogue(t, i, dt)
		merchant = t.vm.rt.world.barterWith
		if d.done:
			s.closeMenu()
		elif merchant != 0 and d.c.phase == .Choosing:
			d.c.endConversation(t)
			s.closeMenu()
			t.vm.rt.world.barterWith = 0
			w = ref t.vm.rt.world
			s.openItemMenu(s.install.openBarter(s.texts, w, merchant, s.width, s.height),
				shadeItems)
		return
	if s.book is mut b:
		controls = ref s.prefs.controls
		for k in i.pressed:
			if controls.isMenuCommand(controls.menuMode, "Cancel", k):
				b.open = false
			elif controls.isMenuCommand(controls.book, "NextPage", k):
				t.vm.rt.world.heardPage(b.turnPage(true), b.note)
			elif controls.isMenuCommand(controls.book, "PrevPage", k):
				t.vm.rt.world.heardPage(b.turnPage(false), b.note)
			elif controls.isMenuCommand(controls.menuMode, "Accept", k) and b.at != 0:
				t.vm.rt.world.takeRef(b.at, t.vm.rt.world.player)
				b.open = false
		if i.rightPressed: t.vm.rt.world.heardPage(b.turnPage(true), b.note)
		if i.leftPressed: t.vm.rt.world.heardPage(b.turnPage(false), b.note)
		b.p.advance()
		if not b.open: s.closeMenu()
		return
	if s.items is mut menu:
		for k in i.pressed:
			menu.p.press(k)
			if menu.favorites and s.keyCommand(k) == "Favorites": menu.open = false
			if k == .Char('F'): menu.favoriteSelected(s.texts, t.vm.rt.world)
			if menu.favorites and s.hotkeySlot(k) >= 0:
				menu.assignHotkey(s.texts, t.vm.rt.world, s.hotkeySlot(k))
		if i.rightPressed and menu.magic: menu.equipSelectedLeft(s.texts, t.vm.rt.world)
		menu.answer(s.texts, t.vm.rt.world)
		menu.p.advance()
		if not menu.open: s.closeMenu()
		return
	closing = i.pressed.any(s.keyCommand(it) in ["Tween Menu", "Pause"])
	opening = 0
	if s.sleepWait is mut sw and s.panel is mut p:
		if s.texts.passSleepWait(t, sw, p, dt): closing = true
	if s.panel is mut p:
		for k in i.pressed:
			if not s.prefs.controls.remapTo(p, k): p.press(k)
		for c in p.takeExternal():
			t.vm.rt.world.playCallSound(c)
			if c.name == "buttonPress": t.vm.rt.world.playUi(messageBoxButtonSound)
			if s.sleepWait is mut sw:
				if c.name == "OK":
					t.startSleepWait(sw, c.numberArg(1))
					continue
				if c.name == "Cancel" and sw.running:
					t.vm.rt.world.sleepWait = none
					if sw.sleeping: t.vm.sendSleepStop(true)
			if c.name in closingCalls: closing = true
			if p.answerSaveCall(c, s.saves) is request: s.requests.push(request)
			if s.prefs.answerOptionCall(p, c): s.applyPrefs()
			s.prefs.controls.answerInputCall(p, c)
			if t.vm.rt.world.answerLevelUp(c) != none:
				closing = true
				opening = tweenSkills
			if c.name == "HighlightMenu": s.tweenChoice = c.numberArg(1)
			if c.name == "OpenHighlightedMenu": opening = s.tweenChoice
		p.advance()
	if closing or opening != 0: s.closeMenu()
	w = ref t.vm.rt.world
	if opening == tweenSkills:
		s.openSkills(t)
	if opening == tweenMagic:
		s.openItemMenu(s.install.openMagic(s.texts, w, s.width, s.height), shadeItems)
	if opening == tweenInventory:
		s.openItemMenu(s.install.openInventory(s.texts, w, s.width, s.height), shadeItems)

# The skills: the level-up menu first when the character has the experience for a level, else the
# stats menu.
fn openSkills(mut s Screen, mut t dialogue.Talk):
	w = ref t.vm.rt.world
	if w.canLevelUp():
		s.showPanel(s.install.openLevelUp(s.width, s.height), shadeNone)
		return
	s.ask(statsOpenSound)
	s.showPanel(
		s.install.openStats(s.texts, w, save.defaultPlayerName, s.width, s.height),
		shadeNone
	)

# The chosen hours begun: the clock passes from the next frame (PlayerCharacter::StartWaiting
# 0x1407414c0, Actor::StartSleeping 0x140741370, which also sends the sleep's start).
pub fn startSleepWait(mut t dialogue.Talk, mut sw SleepWaitPanel, hours i64):
	t.vm.rt.world.playUi(sleepWaitAcceptSound)
	now = t.vm.rt.world.daysPassed
	t.vm.rt.world.startSleepWait(hours, sw.sleeping)
	if sw.sleeping: t.vm.sendSleepStart(now, now + hours / 24.0)
	sw.running = true
	sw.timer = 0.0

# A frame of the wait or the sleep: the clock moved on, the sleep's stop sent when it ends; each
# real second the slider follows the hours left and the time shown, and the menu closes with
# none left (SleepWaitMenu's update, 0x140974e00). Whether it closes.
fn passSleepWait(
	texts GameTexts,
	mut t dialogue.Talk,
	mut sw SleepWaitPanel,
	mut p avm1.Player,
	dt f32
):
	if not sw.running: return false
	if t.vm.rt.world.stepSleepWait() and sw.sleeping: t.vm.sendSleepStop(false)
	sw.timer += dt
	if sw.timer < 1.0: return false
	left = t.vm.rt.world.hoursLeft()
	if left == 0:
		sw.timer = 0.0
		return true
	shown = match p.invoke("SleepWaitMenu_mc.getSliderValue", []):
		Num(x): i64(x)
		_: 0
	if left < shown:
		sw.timer = 0.0
		p.invoke("SleepWaitMenu_mc.modifySliderValue", [.Num(-1.0)])
		w = ref t.vm.rt.world
		p.invoke("SleepWaitMenu_mc.SetCurrentTime", [.Str(texts.dateText(w.dateOf(), false))])
	false

# the command a key is on in the player's map
fn keyCommand(s Screen, k engine.Key):
	s.prefs.controls.commandOf(k)

# the hotkey slot a key stands for (Hotkey1 to Hotkey8 are the slots 0 to 7), -1 for another key
fn hotkeySlot(s Screen, k engine.Key):
	command = s.keyCommand(k)
	if not command.startsWith("Hotkey"): return -1
	(i64.parse(command[6..]) ?? 0) - 1

# the saves of the folder, shown by the journal's lists from now on
pub fn setSaves(mut s Screen, saves save.Listed[]):
	s.saves = saves.copy()
	if s.panel is mut p: p.answerSaveLists(s.saves)

# The settings the player chose applied to what the interface shows: the HUD's opacity, the
# crosshair (shown again at the next target) and the dialogue's subtitles.
fn applyPrefs(mut s Screen):
	s.hud.setOpacity(s.prefs.number("fHUDOpacity:Interface"))
	s.target = -1
	s.subtitles = s.prefs.isOn("bDialogueSubtitles:Interface")

# the load door the player activated since the last call, 0 for none
pub fn takeTravel(mut s Screen) i64:
	door = s.traveling
	s.traveling = 0
	door

# what the player asked of the saves since the last call
pub fn takeRequests(mut s Screen) Request[]:
	out = s.requests.copy()
	s.requests.clear()
	out

fn closeMenu(mut s Screen):
	if s.sleepWait is sw and sw.closingSound() is name: s.ask(name)
	if s.dialogue != none: s.hud.invoke("{base}.ShowElements", [.Str("DialogueMode"), .Bool(false)])
	s.items = none
	s.panel = none
	s.dialogue = none
	s.book = none
	s.sleepWait = none
	s.menuCache = none

# a menu opened by the key, or what the crosshair is on activated
fn openFor(mut s Screen, mut t dialogue.Talk, k engine.Key):
	w = ref t.vm.rt.world
	command = s.keyCommand(k)
	if command == "Quick Inventory":
		s.openItemMenu(s.install.openInventory(s.texts, w, s.width, s.height), shadeItems)
	elif command == "Favorites":
		s.openItemMenu(s.install.openFavorites(s.texts, w, s.width, s.height), shadeNone)
	elif command == "Wait":
		s.showPanel(s.install.openSleepWait(s.texts, w, false, s.width, s.height), shadeNone)
		s.sleepWait = SleepWaitPanel(sleeping = false)
	elif command == "Activate":
		s.activate(t)
	elif s.hotkeySlot(k) >= 0:
		if t.vm.rt.world.useHotkey(t.vm.rt.world.player, s.hotkeySlot(k)) is why:
			t.vm.rt.world.record(why)
	elif command == "Tween Menu":
		s.showPanel(s.install.openTween(s.texts, w, s.width, s.height), shadeTween)
	elif command == "Quicksave":
		s.requests.push(.QuickSave)
	elif command == "Quickload":
		s.requests.push(.QuickLoad)
	elif command == "Pause":
		s.ask(journalOpenSound)
		s.showPanel(
			s.install.openJournal(s.texts, w, s.saves, s.prefs, s.width, s.height),
			shadeJournal
		)

fn openItemMenu(mut s Screen, move opened ItemMenu ? str, shade f32):
	match opened:
		menu:
			s.items = menu
			s.menuCache = swf.newDrawCache()
			s.shade = shade
		error: eprint("menu: {error}")

fn showPanel(mut s Screen, move opened avm1.Player ? str, shade f32):
	match opened:
		p:
			s.panel = p
			s.menuCache = swf.newDrawCache()
			s.shade = shade
		error: eprint("menu: {error}")

# What the crosshair is on activated: an actor talked to, else the game's model told, a
# container's menu or a bed's sleep menu opened as it answers.
fn activate(mut s Screen, mut t dialogue.Talk):
	target = s.target
	if target == 0: return
	s.target = 0
	if (t.vm.rt.world.forms.get(target)?.baseKind ?? "") == "NPC_":
		if t.vm.rt.world.canPickpocket(target):
			w = ref t.vm.rt.world
			s.openItemMenu(s.install.openPickpocket(s.texts, w, target, s.width, s.height),
				shadeItems)
		else:
			s.talkTo(t, target)
		return
	a, _ = t.vm.activateRef(target, t.vm.rt.world.player)
	w = ref t.vm.rt.world
	match a:
		Opened(container):
			s.openItemMenu(s.install.openContainer(s.texts, w, container, s.width, s.height),
				shadeItems)
		Used(kind, _, _, _):
			if kind == nif.furnitureSleep:
				s.showPanel(s.install.openSleepWait(s.texts, w, true, s.width, s.height), shadeNone)
				s.sleepWait = SleepWaitPanel(sleeping = true)
		# LockpickingMenu::OpenMenu (0x14094dc60) and TESObjectDOOR::Activate (0x140283210): a
		# lock that needs its key says so, a key that opens it is named
		Teleported(door, _, _): s.traveling = door
		Locked(level):
			s.texts.noticeLocked(t.vm.rt.world, level)
		DoorMoved(_, key):
			if key != 0:
				t.vm.rt.world.showNotice(
					s.texts.setting("sOpenWithKey").replace("%s", s.texts.nameOf(key)),
					lockpickingUnlockSound
				)
		Reading(book):
			match s.install.openBook(s.texts, w, book, target, s.width, s.height):
				b:
					s.book = b
					s.menuCache = swf.newDrawCache()
					s.shade = shadeNone
				error: eprint("menu: {error}")
		_: pass

# What a lock the player cannot open says (LockpickingMenu::OpenMenu 0x14094dc60): a lock that
# needs its key, or no lockpick to pick it with (the lockpicking menu itself is not modelled).
pub fn noticeLocked(texts GameTexts, mut w sim.GameWorld, level i64):
	if level >= impossibleLock:
		w.showNotice(texts.setting("sImpossibleLock"), lockedSound)
		return
	inv = w.inventories.get(w.player) ?? sim.Inventory()
	if inv.countOf(lockpickForm) == 0 and inv.countOf(skeletonKeyForm) == 0:
		w.showNotice(texts.setting("sOutOfLockpicks"), lockedSound)

# the dialogue with the actor opened when it has something to say
fn talkTo(mut s Screen, mut t dialogue.Talk, actor i64):
	c = t.startConversation(actor) ?? return
	match s.install.openDialogue(c, s.subtitles, s.width, s.height):
		d:
			s.dialogue = d
			s.menuCache = swf.newDrawCache()
			s.shade = shadeNone
			s.hud.invoke("{base}.ShowElements", [.Str("DialogueMode"), .Bool(true)])
		error: eprint("menu: {error}")

# whether the scene under the open menu is dimmed, and so blurred
pub fn dimsScene(s Screen) bool:
	s.isMenuOpen() and s.shade < 1.0

# the HUD, or the open menu (the game hides the HUD under its menus but the dialogue), drawn over
# the frame
pub fn draw(mut s Screen, mut r engine.Renderer):
	if not s.isMenuOpen() or s.dialogue != none: s.hud.draw(s.hudCache, r)
	if s.dimsScene():
		r.fillRect(0.0, 0.0, f32(s.width), f32(s.height), Vec4(0.0, 0.0, 0.0, 1.0 - s.shade))
	if s.menuCache is mut cache:
		if s.items is menu: menu.p.draw(cache, r)
		if s.panel is p: p.draw(cache, r)
		if s.dialogue is d: d.p.draw(cache, r)
		if s.book is mut b: b.drawBook(cache, r, s.width, s.height)
