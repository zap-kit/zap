# The sprites of a figure read from the install: a sprite is its ACT and its SPR under
# data\sprite\, a player is a body, a head, a weapon (and its slash), the shadow and the body's
# IMF, named in Korean as the client names them.

import ragnarok.act
import ragnarok.spr

# the sprite at data\sprite\{path} (.act and .spr), none when the install has no such sprite
pub fn loadSprite(i Install, path str, kind i64, order i64 = 0) Sprite?:
	actBytes = try i.installReadPath("data/sprite/{path}.act")
	sprBytes = try i.installReadPath("data/sprite/{path}.spr")
	act = act.parseAct(actBytes) ?? fail("{path}.act: {error}")
	spr = spr.parseSpr(sprBytes) ?? fail("{path}.spr: {error}")
	Sprite(act, spr, kind, order)

pub fn needSprite(i Install, path str, kind i64) Sprite:
	i.loadSprite(path, kind) ?? fail("data/sprite/{path} is not in the install")

# A player of the job (its dir and file name, in Korean), sex, head number and weapon suffix
# (in Korean, "_검" a sword), standing on the shadow.
pub fn playerFigure(i Install, job str, female bool, head i64, weapon str, shadow Sprite) Figure:
	sex = "여" if female else "남"
	sprites = [
		i.needSprite("인간족/몸통/{sex}/{job}_{sex}", kindBody),
		i.needSprite("인간족/머리통/{sex}/{head}_{sex}", kindHead)
	]
	if weapon != "":
		path = "인간족/{job}/{job}_{sex}{weapon}"
		sprites.push(i.needSprite(path, kindWeapon))
		if i.loadSprite("{path}_검광", kindWeapon, 1) is s:   # the slash, when the weapon has one
			sprites.push(s)
	sprites.push(shadow.copy())
	imf act.Imf? = none
	if i.installReadPath("data/imf/{job}_{sex}.imf") is bytes:
		match act.parseImf(bytes):
			m: imf = m
			error: fail("the IMF of {job}: {error}")
	Figure(sprites, imf, player = true)
