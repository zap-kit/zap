# The princess's room of the cutscenes and the title's pictures (SDLPoP's seg001.c and seg000.c
# draw_full_image; the Apple II's PRINCESS.S): the room's background, its torches, hourglass and
# stars, the characters of the cutscenes, and the title screens' full pictures.

import dos
import dos.pop

pub chtabPrincessInStory = 3
pub chtabJaffarOrPrincess = 4
pub chtabPrincessRoom = 8
pub chtabPrincessBed = 9
pub chtabTitle40 = 10
pub chtabTitle50 = 11

# the full pictures: their table, picture, blitter and place
pub imageTitleMain = 0
pub imageTitlePresents = 1
pub imageTitleGame = 2
pub imageTitlePop = 3
pub imageTitleMechner = 4
pub imageHofPop = 5
pub imageStoryFrame = 6
pub imageStoryAbsence = 7
pub imageStoryMarry = 8
pub imageStoryHail = 9
pub imageStoryCredits = 10

blitWhite = 8

type FullImage:
	chtab i64
	id i64
	blit i64
	x i64
	y i64

fullImages = [
	FullImage(chtabTitle50, 0, blitNoTransp, 0, 0),
	FullImage(chtabTitle50, 1, blitNoTransp, 96, 106),
	FullImage(chtabTitle50, 2, blitNoTransp, 96, 122),
	FullImage(chtabTitle50, 3, blitTransp, 24, 107),
	FullImage(chtabTitle50, 4, blitNoTransp, 48, 184),
	FullImage(chtabTitle50, 3, blitTransp, 24, 24),
	FullImage(chtabTitle40, 0, blitNoTransp, 0, 0),
	FullImage(chtabTitle40, 1, blitWhite, 24, 25),
	FullImage(chtabTitle40, 2, blitWhite, 24, 25),
	FullImage(chtabTitle40, 3, blitWhite, 24, 25),
	FullImage(chtabTitle40, 4, blitWhite, 24, 26)
]

# a table of a DAT and the DAC row its palette sets (load_chtab_from_file)
pub fn loadChtab(mut g Game, chtab i64, resource i64, file str, row i64):
	g.chtabs[chtab] = pop.spriteTableOf(pop.DatChain([pop.loadDat(g.install, file)]), resource)
	g.setRowOf(chtab, row)

pub fn freeChtabsFrom(mut g Game, first i64):
	for i in first..g.chtabs.len:
		g.chtabs[i] = none

# load_title_images: TITLE.DAT's tables, the text frame's background dark blue (or dark red)
pub fn loadTitleImages(mut g Game, blueBackground bool):
	g.loadChtab(chtabTitle40, 40, "TITLE.DAT", 11)
	g.loadChtab(chtabTitle50, 50, "TITLE.DAT", 12)
	r = 0x04 if blueBackground else 0x20
	b = 0x18 if blueBackground else 0x00
	g.pal.setPal(11 * 16 + 14, r, 0, b)
	if g.chtabs[chtabTitle40] is mut t:
		t.palette.colors[14] = dos.vgaColor(u8(r), 0, u8(b))

# draw_full_image, onto the screen being drawn
pub fn drawFullImage(mut g Game, which i64):
	f = fullImages[which]
	if f.blit == blitWhite:
		g.drawMonoImage(f.chtab, f.id, f.x, f.y, 11 * 16 + 15)
	else:
		g.drawImage(f.chtab, f.id, f.x, f.y, f.blit, false)

fn drawMonoImage(mut g Game, chtab i64, id i64, x i64, y i64, color i64):
	if g.chtabs[chtab] is t:
		if t.pictures[id] is p:
			g.screen.drawMono(g.pal, p, x, y, color)

# ---------- the princess's room ----------

type Star:
	x i64
	y i64
	color i64

starColors = [8, 7, 15, 15, 7]
princessTorchXh = [11, 26]
princessTorchXl = [5, 3]

pub fn startStars() Star[]:
	[
		Star(20, 97, 0),
		Star(16, 104, 1),
		Star(23, 110, 2),
		Star(17, 116, 3),
		Star(24, 120, 4),
		Star(18, 128, 0)
	]

# draw_star: a star of the window a colour further
pub fn drawStar(mut g Game, which i64, markDirty bool):
	g.stars[which].color = (g.stars[which].color + 1) % 5
	r = Rect(
		top = g.stars[which].y,
		left = g.stars[which].x,
		bottom = g.stars[which].y + 1,
		right = g.stars[which].x + 1
	)
	g.screen.drawRect(g.pal, r, starColors[g.stars[which].color])
	if markDirty: g.addDrect(r)

# load_intro's first half: the room drawn into the picture kept off the display, its tables loaded
pub fn startIntro(mut g Game, whichImages i64):
	g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)
	g.freeChtabsFrom(chtabPrincessInStory)
	g.loadChtab(chtabPrincessRoom, 950, "PV.DAT", 13)
	g.loadChtab(chtabPrincessBed, 980, "PV.DAT", 14)
	g.screen.toOnscreen = false
	g.drawImage(chtabPrincessRoom, 0, 0, 0, blitNoTransp, false)
	g.drawImage(chtabPrincessBed, 0, 0, 142, blitOr, false)
	g.chtabs[chtabPrincessBed] = none
	if g.chtabs[chtabPrincessRoom] is mut t:
		t.pictures[0] = none
	g.loadChtab(chtabPrincessInStory, 800, "PV.DAT", 9)
	g.loadChtab(chtabJaffarOrPrincess, 50 * whichImages + 850, "PV.DAT", 10)
	for i in 0..6:
		g.drawStar(i, false)
	g.screen.toOnscreen = true

# reset_cutscene
pub fn resetCutscene(mut g Game):
	g.guard.frame = 0
	g.kid.frame = 0
	g.whichTorch = 0
	g.disableKeys = false
	g.hourglassState = 0
	g.hourglassSandflow = -1
	g.cutsceneFrameTime = 6
	g.clearTileWipes()
	g.nextSound = -1

# load_intro's end: the tables of the cutscenes gone, the screen black
pub fn endIntro(mut g Game):
	g.freeChtabsFrom(chtabPrincessInStory)
	g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)

# a frame of a cutscene: both characters' sequences played, the room drawn and copied, a star
# twinkling every other frame (proc_cutscene_frame up to its wait)
pub fn cutsceneFrame(mut g Game):
	g.playKidSeq()
	g.playOppSeq()
	g.drawPrincessRoomBg()
	if g.fading == 0:
		g.copyDrects()
	if g.cutsceneWaitFrames & 1 != 0:
		g.drawStar(g.prandom(5), true)
	if g.flashTime != 0:
		g.doFlash(g.flashColor)
		g.flashTime -= 1
		g.removeFlash()
	if not g.isSoundPlaying():
		g.playNextSound()

fn playKidSeq(mut g Game):
	g.loadkid()
	if g.char.frame != 0:
		g.playSeq()
		g.savekid()

fn playOppSeq(mut g Game):
	g.loadshadAndOpp()
	if g.char.frame != 0:
		g.playSeq()
		g.saveshad()

fn drawPrincessRoomBg(mut g Game):
	g.clearTables()
	g.loadkid()
	if g.char.frame != 0:
		g.loadFrameToObj()
		g.objTilepos = 30
		g.addObjtable(0)
	g.loadshad()
	if g.char.frame != 0:
		g.loadFrameToObj()
		g.objTilepos = 30
		g.addObjtable(0)
	g.redrawNeededTiles()
	g.addForetable(chtabPrincessRoom, 2, 30, 0, 167, blitTransp)   # a piece of pillar
	g.princessRoomTorch()
	g.drawHourglass()
	g.drawTables()

fn princessRoomTorch(mut g Game):
	loop 2:
		g.whichTorch = 1 - g.whichTorch
		g.princessTorchFrame[g.whichTorch] = g.getTorchFrame(g.princessTorchFrame[g.whichTorch])
		g.addBacktable(
			chtabFlameSwordPotion,
			g.princessTorchFrame[g.whichTorch] + 1,
			princessTorchXh[g.whichTorch],
			princessTorchXl[g.whichTorch],
			116,
			blitNoTransp
		)

fn drawHourglass(mut g Game):
	if g.hourglassSandflow >= 0:
		g.hourglassSandflow = (g.hourglassSandflow + 1) % 3
		if g.hourglassState >= 7: return
		g.addForetable(chtabPrincessRoom, g.hourglassSandflow + 10, 20, 0, 164, blitTransp)
	if g.hourglassState != 0:
		g.addMidtable(chtabPrincessRoom, g.hourglassState + 2, 19, 0, 168, blitTransp, true)

timeBound = [6, 17, 33, 65]

# the hourglass's picture for the minutes left
pub fn hourglassFrame(g Game) i64:
	index = 0
	while index < 4 and timeBound[index] <= g.remMin:
		index += 1
	6 - index
