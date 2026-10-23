# PRINCE.HOF, the hall of fame (SDLPoP's seg001.c hof_read and hof_write): the count of times
# (2 bytes), then 6 entries of a name (25 bytes, ended by a zero), the minutes left and the ticks
# (2 bytes each), 29 bytes an entry.

import fs

pub hofFile = "PRINCE.HOF"
hofEntryBytes = 29
hofMax = 6

# hof_read: the times of the file, none when it is missing or short
pub fn readHallOfFame(mut g Game):
	g.hallOfFame = []
	b = fs.readBytes(g.savePath(hofFile)) ?? []
	if b.len < 2 + hofMax * hofEntryBytes: return
	count = i64(b.u16le(0)).min(hofMax)
	for i in 0..count:
		at = 2 + i * hofEntryBytes
		g.hallOfFame.push(
			HofEntry(
				name = b.cStringAt(at, 24),
				min = i16.wrap(b.u16le(at + 25)),
				tick = i16.wrap(b.u16le(at + 27))
			)
		)

# hof_write: the six places, the ones not in use zero
pub fn writeHallOfFame(g Game):
	b = []
	b.pushU16le(g.hallOfFame.len)
	for i in 0..hofMax:
		e = g.hallOfFame[i] if i < g.hallOfFame.len else HofEntry(name = "", min = 0, tick = 0)
		name = e.name.bytes()
		for k in 0..25:
			b.push(name[k] if k < name.len and k < 24 else 0)
		b.pushU16le(e.min & 0xFFFF)
		b.pushU16le(e.tick & 0xFFFF)
	_ = fs.writeBytes(g.savePath(hofFile), b)
