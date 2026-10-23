# Leveled lists, of actors (LVLN) and of items (LVLI): LVLD the chance of nothing (or LVLG, a
# global holding it), LVLF the flags (1: pick from every level up to the player's, else from the
# highest such level alone; 2: an entry's count rolled again for each one; 4, items only: every
# entry), LVLO the entries (a level, a form, a count). A list's form may be a list again. Layout
# after UESP's Skyrim Mod File Format pages (LVLI, LVLN).

flagAllLevels = 1
flagEachCount = 2
flagUseAll = 4

pub type LeveledEntry:
	level i64
	form i64
	count i64

# a form and how many of it a list gives
pub type Counted:
	form i64
	count i64

# Where the game rolls when it reads a list: the chance of nothing (a roll of 0 to 99 below LVLD
# gives nothing) and which of the eligible entries it gives (one of them, evenly). A fair dice
# rolls as the game does, seeded; the plain one reads a new game as its first roll would fall
# here: the first eligible entry in list order, and nothing only when the chance of nothing is
# 100 (no roll can give).
pub type Dice:
	rng Random = Random(1)
	fair bool = false

# whether a roll of 0 to 99 falls below percent
pub fn below(mut d Dice, percent i64) bool:
	if not d.fair: return percent >= 100
	d.rng.nextInt(0, 100) < percent

# which of n choices the roll gives
pub fn choose(mut d Dice, n i64) i64:
	if not d.fair or n <= 1: return 0
	d.rng.nextInt(0, n)

fn entriesOf(r Record):
	r.fields.filter(.tag == "LVLO" and .size >= 12).map(
		LeveledEntry(
			level = r.body.u16le(.at),
			form = r.body.u32le(.at + 4),
			count = r.body.u16le(.at + 8)
		)
	)

# The entries the game picks from at the player's `level`: those at or below it, and of them only
# those at the highest such level unless the list picks from all levels. When every entry lies
# above the level, the lowest entries stand in.
fn eligible(entries LeveledEntry[], flags i64, level i64):
	if entries.isEmpty: return []
	below = entries.filter(.level <= level)
	if below.isEmpty:
		lowest = entries.map(.level).min() ?? 0
		return entries.filter(.level == lowest).map(.copy())
	if (flags & flagAllLevels) != 0: return below.map(.copy())
	top = below.map(.level).max() ?? 0
	below.filter(.level == top).map(.copy())

fn leveledFlags(r Record):
	at = dataOf(r.fields, "LVLF") ?? return 0
	i64(r.body[at])

# the chance of nothing in percent: the global LVLG names when it has one, else LVLD
fn chanceNone(mut e Esm, r Record) i64:
	if r.formOf("LVLG") is global:
		g = e.recordOf(global) ?? return 0
		at = dataOf(g.fields, "FLTV") ?? return 0
		return i64(g.body.f32le(at))
	at = dataOf(r.fields, "LVLD") ?? return 0
	r.body[at]

fn isLeveled(r Record):
	r.kind == "LVLN" or r.kind == "LVLI"

# One reading of a leveled list (LVLN or LVLI) at the player's `level`: the forms it gives with
# their counts, nested lists read in turn. An item list's chance of nothing is rolled at each
# reading; an entry's count multiplies what its form gives, read once, or the form is read again
# for each one when the list says so.
fn readList(mut e Esm, r Record, level i64, mut dice Dice):
	if r.kind == "LVLI" and dice.below(e.chanceNone(r)): return []
	flags = r.leveledFlags()
	picked = r.entriesOf().eligible(flags, level)
	if picked.isEmpty: return []
	chosen = picked if (flags & flagUseAll) != 0 and r.kind == "LVLI"
		else [picked[dice.choose(len)].copy()]
	out = []
	for entry in chosen:
		if (flags & flagEachCount) != 0:
			out.extend(e.leveledCounts(entry.form, entry.count, level, dice))
		else:
			for c in e.leveledCounts(entry.form, 1, level, dice):
				out.push(Counted(..c, count = c.count * entry.count))
	out

# `count` readings of a leveled list at the player's `level` (a container's or an inventory's
# entry), nested lists resolved to their leaves; any other form is itself, `count` of it.
pub fn leveledCounts(mut e Esm, form i64, count i64, level i64, mut dice Dice) Counted[]:
	r = e.recordOf(form) ?? return [Counted(form, count)]
	if not r.isLeveled(): return [Counted(form, count)]
	out = []
	loop count:
		out.extend(e.readList(r, level, dice))
	out

# The forms a leveled list gives at the player's `level` as a new game reads it (the plain dice),
# nested lists resolved to their leaves; any other form is itself.
pub fn pickLeveled(mut e Esm, form i64, level i64) i64[]:
	dice = Dice()
	e.leveledCounts(form, 1, level, dice).map(.form)
