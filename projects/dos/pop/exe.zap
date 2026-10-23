# The tables PRINCE.EXE (v1.4, not packed) keeps in its data segment: the animation sequences,
# the frames of the kid, the guards and the cutscenes' people, and the swords. Their places are
# those of SDLPoP's (seqtbl.c, seg006.c) v1.0 tables, 0x10C bytes further in v1.4.

import fs
import image

# where the data segment starts in the file
dataInFile = 0x1_8D20

# a frame of a character: its picture, the sword drawn with it, where it is drawn from the
# character's place and what it needs
pub type Frame:
	image i64
	sword i64   # 0x3F the sword's frame, 0xC0 the table of the picture
	dx i64
	dy i64
	flags i64   # 0x1F the weight's x, 0x20 thin, 0x40 needs floor, 0x80 the even/odd pixel

pub type SwordFrame:
	image i64
	dx i64
	dy i64

pub type Tables:
	seqBase i64   # the data address of the first byte of `sequences`
	sequences u8[]
	seqStarts i64[]   # sequence n's data address at n (n from 1)
	kidFrames Frame[]
	guardFrames Frame[]
	cutsceneFrames Frame[]
	swordFrames SwordFrame[]
	data u8[]   # the whole data segment, for its other tables (and what lies past them)
	font Font

	# a byte of the data segment at a v1.4 data address
	pub fn dataByte(address i64) u8:
		data[address]

# the game's font (SDLPoP's hc_font_data, kept in PRINCE.EXE just before the data segment):
# characters first..last, each a picture of one bit a pixel
pub type Font:
	first i64
	last i64
	aboveBaseline i64
	belowBaseline i64
	lineSpace i64
	charSpace i64
	pictures Picture?[]

seqtblAt = 0x1A7A
seqtblBytes = 2310
seqCount = 115

fn framesAt(exe u8[], address i64, count i64):
	at = dataInFile + address
	(0..count).map(
		Frame(
			image = exe[at + it * 5],
			sword = exe[at + it * 5 + 1],
			dx = i8.wrap(exe[at + it * 5 + 2]),
			dy = i8.wrap(exe[at + it * 5 + 3]),
			flags = exe[at + it * 5 + 4]
		)
	)

fontInFile = 0x1_8710

fn fontOf(exe u8[]):
	at = fontInFile
	first = i64(exe[at])
	last = i64(exe[at + 1])
	pictures = []
	for i in 0..=last - first:
		image = exe[at + i64(exe.u16le(at + 10 + i * 2))..].copy()
		if image.u16le(0) == 0:
			image[0] = 1   # SDLPoP's: a picture of no height, one line of nothing
		pictures.push(pictureOf(image))
	Font(
		first,
		last,
		aboveBaseline = exe.u16le(at + 2),
		belowBaseline = exe.u16le(at + 4),
		lineSpace = exe.u16le(at + 6),
		charSpace = exe.u16le(at + 8),
		pictures
	)

# the tables of PRINCE.EXE's bytes
pub fn tablesOf(exe u8[]) Tables:
	seq = dataInFile + seqtblAt
	if exe.len < seq + seqtblBytes or exe[seq] != 0xF9 or exe[seq + 2] != 0xFF:
		fail("PRINCE.EXE is not v1.4's: no sequence table at {seq}")
	starts = dataInFile + seqtblAt - seqCount * 2
	swordsAt = dataInFile + 0x181E
	Tables(
		seqBase = seqtblAt,
		sequences = exe[seq..seq + seqtblBytes].copy(),
		seqStarts = (0..seqCount).map(i64(exe.u16le(starts + it * 2))),
		kidFrames = framesAt(exe, 0x10EC, 241),
		guardFrames = framesAt(exe, 0x15A2, 41),
		cutsceneFrames = framesAt(exe, 0x1670, 86),
		data = exe[dataInFile..].copy(),
		font = fontOf(exe),
		swordFrames = (0..51).map(
			SwordFrame(
				image = exe[swordsAt + it * 3],
				dx = i8.wrap(exe[swordsAt + it * 3 + 1]),
				dy = i8.wrap(exe[swordsAt + it * 3 + 2])
			)
		)
	)

# the tables of the install dir's PRINCE.EXE
pub fn loadTables(dir str) Tables:
	tablesOf(fs.readBytes("{dir}/PRINCE.EXE") ?? fail("cannot read {dir}/PRINCE.EXE: {error}"))

# the address in v1.4 of a v1.0 data address (SDLPoP's "data:XXXX" comments name v1.0's)
pub fn v14(address10 i64) i64:
	address10 + 0x10C
