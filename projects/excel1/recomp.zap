# Recompiles Excel's 68000 code to Zap: reads the prepared application's CODE resources, finds the
# reachable code of each from its jump table entries (m68k/flow.zap), and writes each segment as a
# Zap function (m68k/recompiler.zap) into projects/excel1/recomp/segments/, and projects/excel1/recomp/excel.zap, the
# program that runs Excel with them: the driver (projects/excel1/driver) runs a recompiled segment where it
# holds the code and the interpreter elsewhere; both share the machine and the same lowered steps,
# so the run ends in the machine state the interpreted one does (projects/excel1/main.zap, --state). Run
# from the repository root after projects/excel1/prepare.zap:
#
#   zap run projects/excel1/recomp.zap
#   zap run projects/excel1/recomp/excel.zap [the options of projects/excel1/main.zap]

import disk
import fs
import m68k

file = args[0] if not args.isEmpty else "Excel Program/Microsoft Excel"
fork = fs.readBytes("projects/excel1/assets/{file}.rsrc") ?? fail("no prepared {file}: {error}")
resources = disk.readResources(fork) ?? fail

# what a run noted in each segment (projects/excel1/main.zap --reached): "run seg offset", an instruction it
# ran, code the jump table does not lead to (the handlers Excel's p-code interpreter jumps to
# through a table); "write seg offset", a byte it wrote, data kept among the code
noted = (fs.readFile("projects/excel1/recomp/reached.txt") ?? "")
	.lines()
	.filter(it != "")
	.map(.split(" "))

fn notedOffsets(kind str, seg i64):
	noted.filter(.len == 3 and it[0] == kind and it[1] == "{seg}").map(i64.parse(it[2]) ?? -1)

# the offsets into segment `seg` that CODE 0's jump table names: a routine's entry point. An entry
# is `offset, MOVE.W #seg,-(SP) (3F3C), seg, _LoadSeg (A9F0)`, 8 bytes, after CODE 0's 16-byte head;
# and the offsets a run reached there
fn entriesOf(seg i64):
	out = notedOffsets("run", seg)
	code0 = resources.find(.kind == "CODE" and .id == 0) ?? return out
	at = 16
	while at + 8 <= code0.bytes.len:
		if code0.bytes.u16be(at + 2) == 0x3F3C and code0.bytes.u16be(at + 6) == 0xA9F0 and
			code0.bytes.u16be(at + 4) == seg:
			out.push(4 + i64(code0.bytes.u16be(at)))
		at += 8
	out if not out.isEmpty else [4]

# writes the text unless the file holds it already: whether it wrote
fn writeChanged(path str, text str):
	fs.writeChanged(path, text.bytes()) ?? fail("cannot write {path}: {error}")

_ = fs.createDir("projects/excel1/recomp")
_ = fs.createDir("projects/excel1/recomp/segments")
mut written = 0
mut given = []
for r in resources:
	if r.kind != "CODE" or r.id <= 0: continue
	flow = m68k.analyze(r.bytes, 4, r.bytes.len - 4, entriesOf(r.id))
	source = flow.emitFunction("segment{r.id}", notedOffsets("write", r.id))
	if writeChanged("projects/excel1/recomp/segments/segment{r.id}.zap", source):
		written += 1
	given.push("driver.Segment(id = {r.id}, run = segments.segment{r.id}, code = segments.segment{r.id}Code)")
	print("CODE {r.id}: {flow.code.len} instructions, {flow.entries.len} entries recompiled")
program = [
	"# written by projects/excel1/recomp.zap from Excel's code: Excel run with its segments recompiled",
	"",
	"import driver",
	"import segments",
	"",
	"driver.runExcel([{given.join(", ")}])",
	""
]
if writeChanged("projects/excel1/recomp/excel.zap", program.join("\n")): written += 1
print("{written} files written to projects/excel1/recomp")
