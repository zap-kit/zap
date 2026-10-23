# A run of Microsoft Excel 1.00 on the Mac written in Zap, from the command line's options: the
# machine booted from the prepared disks, Excel's 68000 code run from its first instruction (the
# recompiled segments where a program gives them, the interpreter elsewhere). With none of the
# headless options below, the run is live: the Mac's screen in a window, the real mouse and keys
# and clock (live.zap), until the window closes. Headless, the run stops when Excel has waited for
# input --idle times with none left to give. Both projects/excel1/main.zap (all interpreted) and the program
# projects/excel1/recomp.zap writes (projects/excel1/recomp/excel.zap) run Excel so:
#
#   --headless       no window
#   --input "down v h; move v h; up v h; key c"   the mouse and keys, given each time Excel waits
#   --idle n         the null events Excel waits before the next input or the run's end (100)
#   --shot a.png     the screen saved at the end (or when the run stops on an error)
#   --expect b.png   the screen compared with a picture: the pixels that differ printed
#   --state          the machine's state at the end printed: its registers and a hash of memory
#   --traps          each trap told as it is called
#   --reached        the offsets of the instructions run in each CODE segment, and of the bytes
#                    written there, added to projects/excel1/recomp/reached.txt for projects/excel1/recomp.zap: the
#                    entries of its flow analysis, and the code it leaves to the interpreter
#   --limit n, --break a, --watch a, --dump a, --mem a   stop after n instructions or at an
#                    address, tell the writes of one, list code and memory when the run stops

import cpu
import fs
import image
import m68k
import mac

# a recompiled CODE segment: its number, its function, which runs its code from an offset into
# the segment (its code at codeBase) until it hands back, the offset where it did, and the offsets
# its instructions span ([start, end) each): a write there makes the function stale
pub type Segment:
	id i64
	run fn(u32, u32) u32
	code m68k.Span[]

mut segments Segment[] = []
mut changed {i64: bool} = {}   # the segments whose code the program wrote over: interpreted then

# where a recompiled segment's code lies now: from its handle's master pointer, its code from
# start to end (0, 0 while it is not loaded)
type Placed:
	start i64
	end i64

mut placed Placed[] = []

# the segment's place, read again when its master pointer changed
fn placeOf(k i64):
	h = mac.segmentHandles.get(segments[k].id) ?? return Placed(start = 0, end = 0)
	base = mac.address(cpu.read32(h))
	if base == 0: return Placed(start = 0, end = 0)
	if placed[k].start != i64(base) + 4:
		placed[k] = Placed(start = i64(base) + 4, end = base + mac.handleSize(h))
		watch(base, mac.handleSize(h))
	placed[k].copy()

# where the recompiled code hands back when one of its segments holds pc; pc when none does
fn recompiledAt(pc u32):
	for k in 0..segments.len:
		p = placeOf(k)
		if pc < p.start or pc >= p.end or segments[k].id in changed: continue
		base = u32(p.start - 4)
		run = segments[k].run
		return base + run(pc - base, base)
	pc

# the segment's pages marked as code, so that a write there is told (codeWritten)
fn watch(base i64, size i64):
	if cpu.codePages[base >> 8] and cpu.codePages[(base + size - 1) >> 8]: return
	for page in (base >> 8)..((base + size + 255) >> 8):
		cpu.codePages[page] = true

# the segment and offset of an address inside a loaded segment's code, none outside them
fn segmentOffset(at i64) (i64, i64)?:
	for id, h in mac.segmentHandles.copy():
		base = i64(mac.address(cpu.read32(h)))
		if base != 0 and at >= base + 4 and at < base + mac.handleSize(h): return (id, at - base)
	none

fn codeWritten(at i64):
	m68k.codeWritten(at)
	id, offset = segmentOffset(at) ?? return
	cpu.codePages[at >> 8] = true   # the page stays watched (a write clears its mark)
	if isRecording:
		noted["write {id} {offset}"] = true
		return
	for s in segments:
		if s.id == id and s.code.any(offset >= .start and offset < .end): changed[id] = true

# what a run noted for the recompiler (--reached): "run segment offset" for an instruction run,
# "write segment offset" for a byte written
mut noted {str: bool} = {}
mut isRecording = false

fn noteReached(pc u32):
	id, offset = segmentOffset(pc) ?? return pc
	noted["run {id} {offset}"] = true
	h = mac.segmentHandles.get(id) ?? return pc
	watch(mac.address(cpu.read32(h)), mac.handleSize(h))
	pc

pub reachedPath = "projects/excel1/recomp/reached.txt"

# the lines noted, added to the file's
fn writeReached():
	lines = (fs.readFile(reachedPath) ?? "").lines().filter(it != "").map(.copy())
	for line, _ in noted:
		if line not in lines: lines.push(line.copy())
	_ = fs.createDir("projects/excel1/recomp")
	fs.writeFile(reachedPath, "{lines.sorted().join("\n")}\n") ??
		fail("cannot write {reachedPath}: {error}")

fn runFrom(at u32):
	m68k.interpret(at, mac.returnToZap)

fn saveShot():
	match args.option("--shot"):
		path: mac.screenImage().savePng(path) ?? eprint("cannot write {path}")
		none: pass

# the machine's state when a run stops, and the screen saved to --shot's file
fn described():
	saveShot()
	dumped = m68k.listing(i64.parse(args.option("--dump") ?? "") ?? 0, 24)
	from = i64.parse(args.option("--mem") ?? "") ?? 0
	bytes = (0..64).map("{cpu.mem[from + it]:02x}").join(" ")
	"{m68k.stateText()}\n{dumped}\n  memory at {from:x}: {bytes}"

fn forget(at i64, length i64):
	w = m68k.watchAt
	if w >= at and w < at + length:
		eprint("bytes {at:x}..{at + length:x} written over {w:x} from {m68k.pc:x}")
	m68k.forgetDecoded(at, length)

# the registers and an FNV-1a hash of the emulated Mac's memory
fn stateText():
	h u64 = 14_695_981_039_346_656_037
	for b in cpu.mem[..i64(mac.memTop)]:
		h = (h ^ b) * 1_099_511_628_211
	registers = (0..16).map("{cpu.register(it):x}").join(" ")
	"state: {registers} sr {cpu.sr():x} memory {h:016x}"

# the pixels of the screen that differ from the picture's
fn compareScreen(path str):
	expected = image.loadPng(path)
	d = mac.screenImage().compare(expected)
	print("{d.pixels} pixels differ from {path}")

# Excel run with the recompiled segments given (none: all interpreted).
pub fn runExcel(recompiled Segment[]):
	segments = recompiled.copy()
	placed = fill(segments.len, Placed(start = 0, end = 0))
	mac.traceTraps = args.hasFlag("--traps")
	mac.idleLimit = i64.parse(args.option("--idle") ?? "") ?? 100
	mac.inputs = mac.parseInputs(args.option("--input") ?? "") ?? fail("--input: {error}")
	m68k.limit = i64.parse(args.option("--limit") ?? "") ?? -1
	m68k.breakAt = i64.parse(args.option("--break") ?? "") ?? -1
	m68k.watchAt = i64.parse(args.option("--watch") ?? "") ?? -10
	mac.describe = described
	cpu.onAline = mac.aline
	cpu.onException = mac.exception
	cpu.onRomCall = mac.romCall
	mac.runCode = runFrom
	mac.onCodeMoved = forget
	cpu.onCodeWrite = codeWritten
	if not segments.isEmpty: m68k.recompiled = recompiledAt
	if args.hasFlag("--reached"):
		isRecording = true
		m68k.recompiled = noteReached
	start = mac.boot("Excel Program", "Microsoft Excel")
	headless = [
		"--headless",
		"--shot",
		"--expect",
		"--input",
		"--state",
		"--reached",
		"--limit",
		"--idle"
	]
	if not headless.any(args.hasFlag(it) or args.option(it) != none): openLiveScreen()
	runFrom(start)
	saveShot()
	print("{m68k.executed} instructions interpreted, {mac.trapCount} traps")
	if args.hasFlag("--state"): print(stateText())
	if args.hasFlag("--reached"): writeReached()
	if args.option("--expect") is path:
		compareScreen(path)
