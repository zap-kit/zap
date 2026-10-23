# The game's smaller menus opened and filled as the game does: the message box (messagebox.swf:
# GameDelegate's setMessageText and setButtons), the sleep and wait menu (sleepwaitmenu.swf: the
# date and whether it is sleep), the journal on its system page (quest_journal.swf, the bottom
# bar's date, level and level progress answered to RequestPlayerInfo).

import engine.swf.avm1
import game.sim
import save
import skyrim

# the journal's system page (Quest_Journal.PAGE_SYSTEM)
systemPage = 2

# a message box saying `text` over its buttons
pub fn openMessageBox(
	install skyrim.Install,
	text str,
	buttons str[],
	width i64,
	height i64
) avm1.Player ? str:
	p = try install.openPlayer("interface/messagebox.swf", width, height)
	p.delegate("setMessageText", [.Str(text.copy()), .Bool(false)])
	labels avm1.Value[] = [.Num(0.0)]
	labels.extend(buttons.map(avm1.Value.Str(.copy())))
	p.delegate("setButtons", labels)
	p

# the wait menu (the sleep menu when `sleeping`) at the world's hour
pub fn openSleepWait(
	install skyrim.Install,
	t GameTexts,
	w sim.GameWorld,
	sleeping bool,
	width i64,
	height i64
) avm1.Player ? str:
	p = try install.openPlayer("interface/sleepwaitmenu.swf", width, height)
	p.invokeText("InitExtensions()")
	p.invokeText("SetPlatform(0, false)")
	p.invoke("SleepWaitMenu_mc.SetSleeping", [.Bool(sleeping)])
	p.invoke("SleepWaitMenu_mc.SetCurrentTime", [.Str(t.dateText(w.dateOf(), false))])
	p

# the player's level
fn levelOf(w sim.GameWorld):
	w.playerLevel()

# the percent of the way to the next level
fn levelPercent(w sim.GameWorld):
	xp, needed = w.levelProgress()
	f64(xp / needed * 100.0) if needed > 0.0 else 0.0

# the journal opened on its system page, as Esc opens it
pub fn openJournal(
	install skyrim.Install,
	mut t GameTexts,
	w sim.GameWorld,
	saves save.Listed[],
	prefs Prefs,
	width i64,
	height i64
) avm1.Player ? str:
	p = try install.openPlayer("interface/quest_journal.swf", width, height)
	p.m.responses["RequestPlayerInfo"] = [.Str(t.dateText(w.dateOf(), true)),
		.Num(f64(w.levelOf())), .Num(w.levelPercent())]
	p.m.responses["ShouldShowMod"] = [.Bool(true)]   # the system list shows Creations
	p.m.responses["RequestIsOnPC"] = [.Bool(true)]   # the quit list: the desktop and the main menu
	p.m.responses["ShouldShowKinectTunerOption"] = [.Bool(false)]
	for event, button in prefs.controls.bindings.buttonNames():
		p.m.responses["GetButtonFromUserEvent:{event}"] = [.Str(button.copy())]
	p.answerSystemPage(t)
	p.answerOptionPages(prefs)
	p.answerInputList(prefs.controls)
	p.answerSaveLists(saves)
	p.invokeText("InitExtensions()")
	p.invokeText("SetPlatform(0, false)")
	p.invoke("QuestJournalFader.Menu_mc.RestoreSavedSettings", [.Num(f64(systemPage)),
		.Bool(false)])
	p

# the tween menu, as Tab opens it: GameDelegate's ShowMenu(level up, date, level, level progress)
pub fn openTween(
	install skyrim.Install,
	t GameTexts,
	w sim.GameWorld,
	width i64,
	height i64
) avm1.Player ? str:
	p = try install.openPlayer("interface/tweenmenu.swf", width, height)
	p.invokeText("InitExtensions()")
	p.invokeText("SetPlatform(0, false)")
	p.delegate("ShowMenu", [.Bool(w.canLevelUp()), .Str(t.dateText(w.dateOf(), true)),
		.Num(f64(w.levelOf())), .Num(w.levelPercent())])
	p
