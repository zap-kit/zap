# Every function of the cartridge, found as flow.zap says: the cfg's functions and the interrupt
# vectors, then the functions their calls reach, closed over; each then explored again knowing
# every entry. A function called in other widths than it starts in is a function of its own in
# those (its key, as code's).

pub type Program:
	functions Function[]   # by key
	index {i64: i64}   # a function's key to its place in functions
	primary {i64: i64}   # an address to the key of its function in the widths the cfg gives
	patches {i64: Patch}   # the instructions a game translates otherwise (game.zap), by address

# The vectors' addresses (bank 0), each with the widths its code is entered in: reset and the
# emulation mode's NMI, IRQ (and brk) and cop in emulation mode; the native NMI, IRQ, brk and
# cop in any of the four,
# since an interrupt changes neither M nor X (its handler runs in the widths of the code it stops).
fn vectorEntries(code Code):
	out = []
	nativeWidths = [
		native16,
		Widths(e = false, m = false, x = true),
		Widths(e = false, m = true, x = false),
		Widths(e = false, m = true, x = true)
	]
	for (vector, native) in [
		(0xFFFC, false),
		(0xFFFA, false),
		(0xFFFE, false),
		(0xFFF4, false),
		(0xFFEA, true),
		(0xFFEE, true),
		(0xFFE6, true),
		(0xFFE4, true)
	]:
		at = i64(code.rom.u16le(romOffset(vector)))
		if not code.isCode(at): continue
		if not native:
			out.push((at, powerOn))
			continue
		for w in nativeWidths:
			out.push((at, w.copy()))
	out

pub fn discover(code Code) Program:
	primary {i64: i64} = {}
	for c in code.cfg.functions:
		primary[c.at] = key(c.at, Widths(e = false, m = c.m, x = c.x))
	entries {i64: bool} = {}
	keys {i64: bool} = {}
	for at, k in primary:
		entries[at] = true
		keys[k] = true
	if code.cfg.vectors:
		for (at, w) in code.vectorEntries():
			entries[at] = true
			keys[key(at, w)] = true
			if not (at in primary): primary[at] = key(at, w)
	work = keys.keys()
	while work.pop() is k:
		f = code.explore(addressOf(k), widthsOf(k), entries)
		for c in f.calls:
			ck = key(c.at, c.widths)
			if ck in keys or not code.isCode(c.at): continue
			entries[c.at] = true
			keys[ck] = true
			if not (c.at in primary): primary[c.at] = ck
			work.push(ck)
	functions = []
	index {i64: i64} = {}
	for k in keys.keys().sortedBy((addressOf(it) << 3) | (it >> 24)):
		index[k] = functions.len
		functions.push(code.explore(addressOf(k), widthsOf(k), entries))
	Program(functions, index, primary, patches = {})

# what the flow found, as prepare prints it
pub type Summary:
	functions i64
	variants i64   # functions at an address that has one already, in other widths
	instructions i64
	bytes i64   # the ROM's bytes decoded as code, each once
	cfgBytes i64   # the bytes the cfg's functions span, less its data regions
	inData i64   # instructions in the cfg's data regions (code the cfg took for data)
	unresolved i64   # jumps through memory no dispatch names
	conflicts i64
	unknownPlp i64
	unclean i64

	pub fn text() str:
		"{functions} functions ({variants} in a second widths), {instructions} instructions, {bytes} bytes of code ({cfgBytes} in the cfg's functions, {inData} instructions in its data regions), {unresolved} unresolved jumps; {conflicts} plp in two widths, {unknownPlp} plp without php, {unclean} functions unclean"

pub fn summary(code Code, p Program) Summary:
	covered bool[] = zeros(code.rom.len)
	s = Summary(
		functions = p.functions.len,
		variants = p.functions.len - p.primary.len,
		instructions = 0,
		bytes = 0,
		cfgBytes = 0,
		inData = 0,
		unresolved = 0,
		conflicts = 0,
		unknownPlp = 0,
		unclean = 0
	)
	for f in p.functions:
		s.instructions += f.instrs.len
		s.unresolved += f.unresolved.len
		s.conflicts += f.conflicts.len
		s.unknownPlp += f.unknownPlp
		if not f.isClean: s.unclean += 1
		for i in f.instrs:
			if code.isData[romOffset(i.at)]: s.inData += 1
			for k in 0..i.size:
				covered[romOffset(i.at + k)] = true
	s.bytes = covered.count(true)
	spanned bool[] = zeros(code.rom.len)
	for c in code.cfg.functions:
		for at in c.at..c.end:
			if code.isCode(at) and not code.isData[romOffset(at)]: spanned[romOffset(at)] = true
	s.cfgBytes = spanned.count(true)
	s
