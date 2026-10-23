# Loading the DOS game's files as SDLPoP does (seg000.c init_game_main, load_lev_spr,
# load_more_opt_graf, load_level; seg009.c load_sprites_from_file): the sprite tables (chtabs)
# and the rows of the DAC their palettes set, the guards' and the levels' colour variations, and
# the levels.

import dos
import dos.pop
import image

tblGuardDat = ["GUARD.DAT", "FAT.DAT", "SKEL.DAT", "VIZIER.DAT", "SHADOW.DAT"]
tblEnvirKi = ["DUNGEON", "PALACE"]

# the chtabs
pub chtabSword = 0
pub chtabFlameSwordPotion = 1
pub chtabKid = 2
pub chtabGuard = 5
pub chtabEnvironment = 6
pub chtabEnvironmentWall = 7

# load_more_opt_graf: the environment's pictures that come from resources 1201.. (min..max, 1-based)
optgrafMin = [0x01, 0x1E, 0x4B, 0x4E, 0x56, 0x65, 0x7F, 0x0A]
optgrafMax = [0x09, 0x1F, 0x4D, 0x53, 0x5B, 0x7B, 0x8F, 0x0D]

pub fn newGame(install str) Game:
	tables = pop.loadTables(install)
	prince = pop.DatChain([pop.loadDat(install, "PRINCE.DAT")])
	kid = pop.DatChain([pop.loadDat(install, "KID.DAT")])
	chtabs pop.SpriteTable?[] = fill(12, none)
	chtabs[chtabSword] = pop.spriteTableOf(prince, 700)
	chtabs[chtabFlameSwordPotion] = pop.spriteTableOf(prince, 150)
	chtabs[chtabKid] = pop.spriteTableOf(kid, 400)
	g = Game(
		install = install.copy(),
		tables,
		chtabs,
		guardPalettes = prince.need(10).copy(),
		levelVarPalettes = prince.need(20).copy(),
		levelsDat = pop.loadDat(install, "LEVELS.DAT"),
		level = pop.levelOf(zeros(2305)),
		screen = newScreen(),
		pal = newPalette(),
		sounds = pop.loadSounds(install)
	)
	g.initPalette()
	g

# set_hc_pal, then the rows of the chtabs loaded at the start, and the two colours set_pal sets
fn initPalette(mut g Game):
	for i in 0..16:
		o = g.options
		g.pal.setPal(
			i,
			o.optAt("vga_palette", i * 3),
			o.optAt("vga_palette", i * 3 + 1),
			o.optAt("vga_palette", i * 3 + 2)
		)
	g.pal.setPal(12, 0x38, 0x00, 0x0C)   # blood, the hurt flash
	g.pal.setPal(6, 0x30, 0x26, 0x14)   # the palace's wall pattern
	g.setRowOf(chtabSword, 2)
	g.setRowOf(chtabFlameSwordPotion, 3)
	g.setRowOf(chtabKid, 7)

fn setRowOf(mut g Game, chtab i64, row i64):
	if g.chtabs[chtab] is t:
		g.pal.setRow(row, t.palette)

fn loadDats(g Game, names str[]):
	pop.DatChain(names.map(pop.loadDat(g.install, it)))

# load_lev_spr: the level's environment, its walls and its guards, with their colours
pub fn loadLevSpr(mut g Game, n i64):
	g.currentLevel = n
	g.nextLevel = n
	levelType = g.options.optAt("tbl_level_type", n)
	filename = "V{tblEnvirKi[levelType]}.DAT"
	envDat = g.loadDats([filename])
	env = pop.spriteTableOf(envDat, 200)
	for k in 0..8:
		for index in optgrafMin[k] - 1..optgrafMax[k]:
			if envDat.resource(1200 + index + 1) is b:
				if pop.pictureOf(b) is p:
					env.pictures[index] = p
	g.chtabs[chtabEnvironment] = env
	g.setRowOf(chtabEnvironment, 5)
	guardType = g.options.optAt("tbl_guard_type", n)
	g.chtabs[chtabGuard] = none
	if guardType >= 0:
		names = [tblGuardDat[guardType].copy()]
		if guardType == 0:
			names.push("GUARD1.DAT" if levelType != 0 else "GUARD2.DAT")
		g.chtabs[chtabGuard] = pop.spriteTableOf(g.loadDats(names), 750)
		g.setRowOf(chtabGuard, 8)
	g.currGuardColor = 0
	g.chtabs[chtabEnvironmentWall] = pop.spriteTableOf(envDat, 360)
	g.setRowOf(chtabEnvironmentWall, 6)
	color = g.options.optAt("tbl_level_color", n)
	if color != 0:
		envAt = 0x30 * (color - 1)
		wallAt = envAt + 0x30 * levelType
		g.setTablePalette(chtabEnvironment, envAt, 5, g.levelVarPalettes)
		g.setTablePalette(chtabEnvironmentWall, wallAt, 6, g.levelVarPalettes)

# set_pal_arr and set_chtab_palette: a table's 16 colours from `colors` (colour 0 black), and
# the DAC row's
pub fn setTablePalette(mut g Game, chtab i64, at i64, row i64, colors u8[]):
	p = pop.paletteAt(colors, at)
	if row >= 0:
		g.pal.setRow(row, p)
	p.colors[0] = dos.vgaColor(0, 0, 0)
	if g.chtabs[chtab] is mut t:
		t.palette = p

# load_level: the level's blueprint
pub fn loadLevel(mut g Game):
	g.level = g.levelsDat.loadLevel(g.currentLevel)
	g.alterModsAllrm()

# a picture's size
pub type Dims:
	width i64
	height i64

# the size of picture `id` (from 0) of chtab `chtab`, none when there is none (get_image)
pub fn pictureDims(g Game, chtab i64, id i64) Dims?:
	if g.chtabs[chtab] is t:
		if id >= 0 and id < t.pictures.len:
			if t.pictures[id] is p: return Dims(width = p.width, height = p.height)
	none
