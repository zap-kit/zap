# The flow of the cartridge's code: each function's instructions in the widths they run in, the
# places its jumps reach (labels), its calls and the jumps through memory it makes. Explored from
# the cfg's entries: a jump or a branch to another function's entry, or running into one, is a
# jump to that function (it returns where this one returns); a jump through memory goes where the
# cfg's dispatch names. The widths follow rep, sep, php and plp (the widths php kept), xce after
# clc or sec, and a call leaves the widths the cfg says its function returns with. Code reached in
# two widths is two blocks: an instruction is known by its key, its address and its widths.

import recomp.snes.cartridge

pub type Code:
	rom u8[]
	decoder Decoder
	cfg Cfg
	isData bool[]   # by offset in the ROM: the cfg's data regions, which the flow may yet reach

	pub fn isCode(at i64) bool:
		cartridge.isRomAddress(at) and romOffset(at) < rom.len

	pub fn instrAt(at i64, w Widths) Instr:
		decoder.decode(rom, romOffset(at), at, w)

	# The widths the function at f returns with when called in `called`: those, changed where the
	# cfg says it returns in other widths than it is entered in; none when the cfg does not say.
	pub fn exitWidths(f i64, called Widths) Widths?:
		k = canonical(f)
		exit = try cfg.exits.get(k)
		start = cfg.starts.get(k) ?? return exit.copy()
		out = called.copy()
		if exit.m != start.m: out.m = exit.m
		if exit.x != start.x: out.x = exit.x
		out

	# Explores the function at entry in its widths; entries are the addresses of the functions known
	# (a jump to one is a jump to that function).
	pub fn explore(entry i64, widths Widths, entries {i64: bool}) Function:
		f = Function(
			entry,
			widths,
			instrs = [],
			index = {},
			afters = {},
			labels = {},
			calls = [],
			dispatches = {},
			returns = {},
			unresolved = [],
			conflicts = [],
			unknownPlp = 0,
			isClean = true
		)
		f.labels[key(entry, widths)] = true
		work = [Path(at = entry, widths, pushed = [])]
		while work.pop() is p:
			if p.at != entry and p.at in entries and not p.loops:
				f.calls.push(Call(at = p.at, widths = p.widths))
				continue
			k = key(p.at, p.widths)
			if k in f.index: continue
			if not self.isCode(p.at) or f.instrs.len > 20_000:
				f.isClean = false
				continue
			i = self.instrAt(p.at, p.widths)
			f.index[k] = f.instrs.len
			f.instrs.push(i.copy())
			self.step(f, i, p, work)
		f.instrs = f.instrs.sortedBy((.at << 3) | widthBits(.widths))
		f.index = {}
		for n, i in f.instrs:
			f.index[keyOf(i)] = n
		f

	# the ways on from instruction i, reached by path p, added to work
	fn step(mut f Function, i Instr, p Path, mut work Path[]):
		w = p.widths
		pushed = p.pushed.copy()
		match i.name:
			"rep", "sep":
				set = i.name == "sep"
				if not w.e:
					if i.value & 0x20 != 0: w.m = set
					if i.value & 0x10 != 0: w.x = set
			"php": pushed.push(w)
			"plp":
				if pushed.pop() is kept:
					w = kept
				else:
					f.unknownPlp += 1
			"xce":
				before = i.at - 1
				if self.isCode(before) and self.rom[romOffset(before)] == 0x38:
					w = powerOn
				elif w.e:
					w.e = false
			"rts", "rtl", "rti", "stp": return
			"brk", "cop":
				f.isClean = false
				return
			"jsr", "jsl":
				if i.mode == "(w,x)":
					self.dispatchFrom(f, i, w, pushed, work)
				else:
					t = i.jumpTargetOf()
					f.calls.push(Call(at = t, widths = w))
					w = self.exitWidths(t, w) ?? w
			"jmp", "jml":
				if i.mode == "w" or i.mode == "l":
					f.goTo(i.jumpTargetOf(), w, pushed, work, i.at)
				else:
					self.dispatchFrom(f, i, w, pushed, work)
				return
			"bra", "brl":
				f.goTo(i.target(), w, pushed, work, i.at)
				return
			"pea":
				if self.isCode(i.at - 1) and self.rom[romOffset(i.at - 1)] == 0x4B:
					back = (i.at & 0xFF_0000) | ((i.value + 1) & 0xFFFF)
					f.returns[key(back, w)] = true
					f.goTo(back, w, pushed, work, back)
			_:
				if i.name in conditionalBranches: f.goTo(i.target(), w, pushed, work, i.at)
		k = i.keyOf()
		if f.afters.get(k) is before and before != w: f.conflicts.push(i.at)
		f.afters[k] = w
		work.push(Path(at = i.next(), widths = w, pushed))

	# a jump or a call through memory: where the cfg's dispatch says, the cases that are no function
	# labels of this one
	fn dispatchFrom(mut f Function, i Instr, w Widths, pushed Widths[], mut work Path[]):
		# the site as the game runs it, else as the cfg names it (its mirror in the upper banks)
		site = i.at if i.at in self.cfg.dispatches else canonical(i.at)
		d = self.cfg.dispatches.get(site) ?? Dispatch(at = i.at, calls = false, targets = [])
		if d.targets.isEmpty:
			f.unresolved.push(i.at)
			return
		f.dispatches[i.at] = d.copy()
		for t in d.targets:
			if d.calls:
				f.calls.push(Call(at = t, widths = w))
			else:
				f.goTo(t, w, pushed, work, t)

pub fn newCode(move rom u8[], move cfg Cfg) Code:
	cartridge.hirom = cartridge.readHeader(rom).hirom
	isData bool[] = zeros(rom.len)
	for r in cfg.dataRegions:
		for at in r.from..r.to:
			isData[romOffset(at)] = true
	Code(rom, decoder = newDecoder(), cfg, isData)

# the ROM's offset of an address and its one name, as the cartridge maps them
pub fn romOffset(at i64) i64:
	cartridge.romOffset(at)

pub fn canonical(at i64) i64:
	cartridge.canonical(at)

# the widths as three bits: e, m, x
pub fn widthBits(w Widths) i64:
	(4 if w.e else 0) | (2 if w.m else 0) | (1 if w.x else 0)

# code's key: its address, its widths above
pub fn key(at i64, w Widths) i64:
	at | (w.widthBits() << 24)

pub fn addressOf(k i64) i64:
	k & 0xFF_FFFF

pub fn widthsOf(k i64) Widths:
	Widths(e = (k >> 26) & 1 == 1, m = (k >> 25) & 1 == 1, x = (k >> 24) & 1 == 1)

pub fn keyOf(i Instr) i64:
	key(i.at, i.widths)

# a call or a jump to a function, with the widths at it
pub type Call:
	at i64
	widths Widths

pub type Function:
	entry i64
	widths Widths   # at its entry
	instrs Instr[]   # by address, then widths
	index {i64: i64}   # an instruction's key to its place in instrs
	afters {i64: Widths}   # an instruction's key to the widths after it
	labels {i64: bool}   # the keys a jump lands on: the entry, branch targets, a dispatch's cases
	calls Call[]
	dispatches {i64: Dispatch}   # its jumps through memory the cfg names, by address
	returns {i64: bool}   # the keys code goes on at after a call through a pushed address (phk; pea)
	unresolved i64[]   # its jumps through memory no dispatch names
	conflicts i64[]   # the plp that leave other widths on another way to them
	unknownPlp i64   # plp with no php before it in the function: the widths kept
	isClean bool   # every instruction reached decodes in code, none is brk or cop

	# the widths after the instruction whose key is k
	pub fn afterOf(k i64) Widths:
		if k in afters: return afters[k]
		widthsOf(k)

	pub fn entryKey() i64:
		key(entry, widths)

	# a jump from `from` to `at`: back by less than a page, a loop
	fn goTo(at i64, w Widths, pushed Widths[], mut work Path[], from i64):
		labels[key(at, w)] = true
		loops = at < from and from - at < 0x100
		work.push(Path(at, widths = w, pushed = pushed.copy(), loops))

# a way through the function: where it is, its widths, the widths php kept, and whether a jump
# just back came here (a loop: another function's entry it reaches is a label of this one, so the
# loop stays one function's, not two calling each other without end)
type Path:
	at i64
	widths Widths
	pushed Widths[]
	loops bool = false

pub conditionalBranches = ["bcc", "bcs", "beq", "bne", "bmi", "bpl", "bvc", "bvs"]
