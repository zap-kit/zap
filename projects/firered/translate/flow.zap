# The flow of the cartridge's code: which addresses are functions, and each function's
# instructions, the places its jumps reach (labels) and its jump tables. Functions are found from
# the entry, the calls and the constant jumps of those found, and the words of the cartridge that
# point at Thumb code that decodes cleanly (the tables of callbacks).

import arm

pub romBase = 0x0800_0000

# The cartridge's bytes read as code.
pub type Code:
	rom u8[]
	decoder arm.Decoder

	pub fn isInRom(at i64) bool:
		at >= romBase and at - romBase + 4 <= rom.len

	pub fn word(at i64) u32:
		rom.u32le(at - romBase)

	pub fn instrAt(at i64, thumb bool) arm.Instr:
		off = at - romBase
		if not thumb: return decoder.decodeArm(rom.u32le(off), at)
		decoder.decodeThumb(rom.u16le(off), rom.u16le(off + 2), at)

	# the value of a load relative to the program counter: the literal it reads from the cartridge
	pub fn literal(i arm.Instr) u32?:
		at = try self.literalAddress(i)
		self.word(at)

	# the address of the word a load relative to the program counter reads
	pub fn literalAddress(i arm.Instr) i64?:
		match i.op:
			Load(4, false, _, n, Imm(v, _), true, up, false) and n == arm.pc:
				at = (i.pcValue() & ~3) + (v if up else -i64(v))
				if self.isInRom(at): return at
				none
			_: none

	# Explores the function at `entry`: every instruction its jumps reach, each in its state (a jump
	# to an address made from the program counter, `add r1, pc, #4; bx r1`, goes on in the other
	# state, in the same function). A branch to another function's entry (in `entries`) is a call
	# that returns where this function returns.
	pub fn explore(entry i64, thumb bool, entries {i64: bool}) Function:
		f = Function(
			entry,
			thumb,
			instrs = [],
			labels = {},
			tables = {},
			known = {},
			calls = [],
			taken = [],
			isClean = true
		)
		f.labels[entry] = true
		seen {i64: bool} = {}
		found = []
		starts = [key(entry, thumb)]
		while not starts.isEmpty:
			self.walk(f, starts, entries, seen, found)
			f.instrs = found.sortedBy(.at)
			starts = self.resolveJumps(f).filter(not (it & ~1 in seen))
		f

	# the instructions reached from the starts (keys: bit 0 the state), added to found
	fn walk(mut f Function,
		starts i64[],
		entries {i64: bool},
		mut seen {i64: bool},
		mut found arm.Instr[]
	):
		work = starts.copy()
		while work.pop() is k:
			at = k & ~1
			thumb = k & 1 == 1
			if at in seen: continue
			seen[at] = true
			if not self.isInRom(at) or found.len > 20_000:
				f.isClean = false
				continue
			i = self.instrAt(at, thumb)
			found.push(i)
			next = key(i.next(), thumb)
			if i.cond != arm.always: work.push(next)
			match i.op:
				Branch(target, true):
					f.calls.push(key(target, thumb))
					work.push(next)
				Branch(target, false):
					if target != f.entry and key(target, thumb) in entries:
						f.calls.push(key(target, thumb))
						continue
					f.labels[target] = true
					work.push(key(target, thumb))
				Undefined: f.isClean = false
				_:
					if not thumb and i.pcAddress() is v and i.op is Alu(_, _, d, _, _):
						if d == arm.lr:
							f.labels[v] = true
							work.push(v)
						else:
							f.taken.push(key(v, false))
					if not i.writesPc():
						work.push(next)

	# The jumps through registers not seen before: a literal one names a function; one to an address
	# made from the program counter goes on in the function, in the state its bit 0 says; a table
	# names its cases. What goes on in the function, to explore (keys).
	fn resolveJumps(mut f Function):
		starts = []
		for k in 0..f.instrs.len:
			i = f.instrs[k]
			if not i.jumpsToRegister() or i.at in f.tables or i.at in f.known: continue
			if i.op is Exchange(m) and self.constantBefore(f, k, m) is v:
				f.known[i.at] = v
				if self.isMadeFromPc(f, k, m):
					f.labels[v & ~1] = true
					starts.push(v)
				else:
					f.calls.push(v)
				continue
			cases = self.tableCases(f, k)
			if cases.isEmpty: continue
			f.tables[i.at] = cases.copy()
			for c in cases:
				f.labels[c] = true
				starts.push(key(c, i.thumb))
		starts

	# the constant a register holds at instruction k: a literal loaded into it, or an address made
	# from the program counter
	fn constantBefore(f Function, k i64, r i64) i64?:
		j = try f.setterBefore(k, r)
		if self.literal(f.instrs[j]) is v: return i64(v)
		f.instrs[j].pcAddress()

	fn isMadeFromPc(f Function, k i64, r i64):
		j = f.setterBefore(k, r) ?? return false
		f.instrs[j].pcAddress() != none

	# The cases of a jump through a table: the table's address is a literal loaded just before, its
	# length the compare that guards it (`cmp r0, #7` then `bhi`), else the words that point at code
	# near the jump.
	fn tableCases(f Function, k i64):
		jump = f.instrs[k]
		base = 0
		count = 0
		j = k - 1
		while j >= 0 and j >= k - 12:
			i = f.instrs[j]
			if base == 0 and self.literal(i) is v and self.isInRom(v) and v > jump.at and
				v < jump.at + 64:
				base = v
			if count == 0 and i.op is Alu(kind, _, _, _, Imm(n, _)) and kind == arm.aluCmp and
				j + 1 < f.instrs.len and
				f.instrs[j + 1].op is Branch(_, false) and f.instrs[j + 1].cond == 8:
				count = i64(n) + 1
			j -= 1
		if base == 0 and jump.op is Load(4, false, _, n, Reg(_, 0, 2), true, true, false) and
			n == arm.pc:
			base = jump.pcValue()   # ldr pc, [pc, r0, lsl #2]: the table right after the jump
		if base == 0: return []
		cases = []
		limit = count if count > 0 else 256
		while cases.len < limit and self.isInRom(base + 4 * cases.len):
			c = i64(self.word(base + 4 * cases.len))
			if count == 0 and (not self.isInRom(c) or c < f.entry or c > jump.at + 0x1_0000): break
			cases.push(c & ~1)
		cases

# a function's key: its address with bit 0 set for Thumb, as a bx reads it
pub fn key(at i64, thumb bool) i64:
	at | (1 if thumb else 0)

pub type Function:
	entry i64
	thumb bool
	instrs arm.Instr[]   # by address
	labels {i64: bool}   # where a jump lands: the entry, branch targets, the cases of tables
	tables {i64: i64[]}   # a jump through a table, by the jump's address: its cases
	known {i64: i64}   # a jump to a register whose value is a constant: the value
	calls i64[]   # the keys of the functions it calls or jumps to by a constant
	taken i64[]   # the keys of code whose address it takes (adr), functions if they decode
	isClean bool   # every instruction reached decodes, every jump stays in the cartridge

	pub fn instrIndex(at i64) i64?:
		lo = 0
		hi = instrs.len
		while lo < hi:
			mid = (lo + hi) / 2
			if instrs[mid].at < at:
				lo = mid + 1
			else:
				hi = mid
		if lo < instrs.len and instrs[lo].at == at: return lo
		none

# whether the instruction writes the program counter, and so ends the way through it
pub fn writesPc(i arm.Instr) bool:
	match i.op:
		Alu(kind, _, d, _, _): d == arm.pc and (kind < arm.aluTst or kind > arm.aluCmn)
		Load(_, _, d, _, _, _, _, _): d == arm.pc
		Block(load, _, list, _, _, _, _): load and (list >> arm.pc) & 1 == 1
		Branch(_, link): not link
		Exchange, Undefined: true
		_: false

# whether the instruction jumps to an address it computes
pub fn jumpsToRegister(i arm.Instr) bool:
	match i.op:
		Branch, Undefined: false
		_: i.writesPc()

# The address an instruction makes from the program counter (`adr`, `mov lr, pc`; Thumb's from
# the word below it): into lr it is where a call through a register returns, a label of the
# function; elsewhere code whose address is kept.
fn pcAddress(i arm.Instr) i64?:
	base = i.pcValue() & ~3 if i.thumb else i.pcValue()
	match i.op:
		Alu(4, _, _, n, Imm(v, _)) and n == arm.pc: base + v
		Alu(13, _, _, _, Reg(15, 0, 0)): i.pcValue()
		_: none

# the instruction that last set register r before instruction k, in the same straight run of
# the few before it
fn setterBefore(f Function, k i64, r i64) i64?:
	j = k - 1
	while j >= 0 and j >= k - 4:
		i = f.instrs[j]
		if i.next() != f.instrs[j + 1].at or i.writesPc() or f.instrs[j + 1].at in f.labels:
			return none
		if i.writesReg(r): return j
		j -= 1
	none

# whether the instruction may change register r
pub fn writesReg(i arm.Instr, r i64) bool:
	match i.op:
		Alu(kind, _, d, _, _): d == r and (kind < arm.aluTst or kind > arm.aluCmn)
		Mul(_, d, _, _, _): d == r
		MulLong(_, _, _, lo, hi, _, _): lo == r or hi == r
		Load(_, _, d, n, _, _, _, back): d == r or (back and n == r)
		Store(_, _, n, _, _, _, back): back and n == r
		Block(load, n, list, _, _, back, _): (load and (list >> r) & 1 == 1) or (back and n == r)
		Swap(_, d, _, _): d == r
		ReadPsr(d, _): d == r
		WritePsr: r == arm.sp or r == arm.lr
		_: false
