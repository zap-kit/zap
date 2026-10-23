# Prepares Ragnarok from the player's own Ragnarok Online LATAM install: nothing of the game is
# in the repository, each player prepares it from the client they have. Reads the map and the
# hero out of the install's GRF archives once and writes them ready to use into
# projects/ragnarok/assets/prepared/ (game/prepare.zap): the game then reads only those files and opens
# at once (it runs this itself, once, when they are missing or of an older format). Run from
# the repository root:
#
#   zap run projects/ragnarok/prepare.zap [--install <dir>] [--sheets]
#
# The install dir defaults to C:\Gravity\Ragnarok. --sheets also draws the character and
# monster sheets as the ragassets service rendered them (projects/ragnarok/render.zap) into
# projects/ragnarok/assets/sprites/ro/: 16 columns by 8 rows of 128-pixel cells, feet at (64, 116); rows
# the facings front, front-right, right, back-right, back, back-left, left, front-left; columns
#   0-1 standing, 2-9 walking, 10-12 an attack, 13 a skill (or the attack's end), 14 hit, 15 dead.

import image
import game
import ragnarok
import fs

type Hero:
	name str
	job str   # the job's dir and file name, in Korean
	female bool
	head i64
	weapon str   # the weapon's suffix, in Korean
	skill i64   # the action of column 13, -1 for the attack's end

heroes = [
	Hero(name = "warrior", job = "기사", female = false, head = 4, weapon = "_검", skill = -1),
	Hero(name = "ranger", job = "헌터", female = true, head = 6, weapon = "_활", skill = -1),
	Hero(name = "mage", job = "위저드", female = true, head = 8, weapon = "_롯드", skill = 96),
	Hero(name = "cleric", job = "프리스트", female = false, head = 2, weapon = "_클럽", skill = 96),
]

# the monsters, in the order of game.monsterStats: (sheet name, sprite name)
monsters = [
	("poring", "poring"),
	("lunatic", "lunatic"),
	("savage", "savage"),
	("snowier", "snowier"),
	("siroma", "siroma"),
	("spore", "spore"),
	("mandragora", "mandragora"),
	("scorpion", "scorpion"),
	("desertwolf", "desert_wolf"),
	("minorous", "minorous")
]

fn heroFigure(i ragnarok.Install, h Hero, shadow ragnarok.Sprite):
	i.playerFigure(h.job, h.female, h.head, h.weapon, shadow)

fn monsterFigure(i ragnarok.Install, name str, shadow ragnarok.Sprite):
	ragnarok.Figure(
		sprites = [i.needSprite("몬스터/{name}", ragnarok.kindMonster), shadow.copy()],
		imf = none,
		player = false
	)

# frame k of n spread over m columns: the k-th of m evenly spaced frames
fn spread(k i64, m i64, n i64):
	0 if m <= 1 or n <= 1 else k * (n - 1) / (m - 1)

fn pasteFrame(mut sheet image.Image, frames image.Image[], index i64, column i64, row i64):
	if index < 0 or index >= frames.len: return
	sheet.paste(frames[index], column * ragnarok.canvasSize, row * ragnarok.canvasSize)

# A body's sheet. Ragnarok numbers directions from the front turning to its left (0 south,
# 1 southwest, ...): row r shows direction (8 - r) % 8. Actions are 8 apart, one per direction.
fn sheet(
	fig ragnarok.Figure,
	idle i64,
	walk i64,
	attack i64,
	skill i64,
	hurt i64,
	dead i64
):
	px = image.Image(
		16 * ragnarok.canvasSize,
		8 * ragnarok.canvasSize,
		fill = image.Rgba8(0, 0, 0, 0)
	)
	for row in 0..8:
		d = (8 - row) % 8
		stand = fig.renderAction(idle + d)
		px.pasteFrame(stand, 0, 0, row)
		px.pasteFrame(stand, stand.len / 2, 1, row)
		moving = fig.renderAction(walk + d)
		for k in 0..8:
			px.pasteFrame(moving, spread(k, 8, moving.len), 2 + k, row)
		hit = fig.renderAction(attack + d)
		for k in 0..3:
			px.pasteFrame(hit, spread(k, 3, hit.len), 10 + k, row)
		if skill >= 0:
			cast = fig.renderAction(skill + d)
			px.pasteFrame(cast, cast.len / 2, 13, row)
		else:
			px.pasteFrame(hit, hit.len - 1, 13, row)
		hurtFrames = fig.renderAction(hurt + d)
		px.pasteFrame(hurtFrames, hurtFrames.len / 2, 14, row)
		deadFrames = fig.renderAction(dead + d)
		px.pasteFrame(deadFrames, deadFrames.len - 1, 15, row)
	px

fn save(img image.Image, dir str, name str):
	path = "{dir}/{name}.png"
	img.savePng(path) ?? fail("cannot write {path}")
	print(name)

install = args.option("--install") ?? ragnarok.defaultInstall
game.prepareGame(install, game.startMap)
if not args.hasFlag("--sheets"): return
dir = "projects/ragnarok/assets/sprites/ro"
archives = ragnarok.openInstall(install) ?? fail
_ = fs.createDir(dir)
shadow = archives.needSprite("shadow", ragnarok.kindShadow)
# the heroes: player actions idle 0, walk 8, attack 40, casting 96, hurt 48, dead 64
for h in heroes:
	archives.heroFigure(h, shadow).sheet(0, 8, 40, h.skill, 48, 64).save(dir, h.name)
# the monsters: idle 0, walk 8, attack 16, hurt 24, dead 32
for (name, sprite) in monsters:
	archives.monsterFigure(sprite, shadow).sheet(0, 8, 16, -1, 24, 32).save(dir, name)
