# The interpreter's instructions: every opcode in every widths it runs in written as a Zap function
# by the same translation as the cartridge's code (emitops, emitmem, cycles), its address, operand
# and the address after it the function's variables (Instr.symbolic). cpu.interpret runs them where
# no translated function is: code the game writes into RAM, an address no jump the preparation saw
# reaches, a task resumed in the middle of a function. The same bus cycles, the same flags.
#
# A function takes the instruction's address and gives the next one to run, or cpu.leaving when a
# return took the code past it (cpu.ret where); the widths it leaves in are cpu.widthsNow.

# the widths an instruction runs in: native mode's four, and emulation mode's
interpretedWidths = [
	Widths(e = false, m = false, x = false),
	Widths(e = false, m = false, x = true),
	Widths(e = false, m = true, x = false),
	Widths(e = false, m = true, x = true),
	powerOn
]

# the interpreter's function of an opcode in widths
fn interpretedName(opcode i64, w Widths):
	"i{opcode:02x}{w.widthBits()}"

# The functions of every opcode in every widths, a text each, and the step that runs one:
# `step(at, widths)` the instruction at `at`.
pub fn interpreterTexts(d Decoder) (str[], str):
	texts = []
	arms = []
	for row in d.rows:
		for w in interpretedWidths:
			size = 1 + operandSize(row.mode, w)
			i = Instr(
				at = -1,
				opcode = row.opcode,
				name = row.name.copy(),
				mode = row.mode.copy(),
				value = -1,
				size,
				widths = w,
				symbolic = true
			)
			name = interpretedName(row.opcode, w)
			texts.push("\n{i.interpretedFunction(name).join("\n")}\n")
			arms.push("\t\t0x{row.opcode | (w.widthBits() << 8):03X}: return {name}(at)")
	step = [
		"# the instruction at `at` run in `widths` (bits e, m, x): the address of the next, or cpu.leaving",
		"pub fn step(at u32, widths u32) u32:",
		"\tmatch u32(console.read8(at)) | (widths << 8):"
	]
	step.extend(arms)
	step.extend(
		["\t\t_: pass", "\tcpu.unsupported(at, \"an opcode in widths \{widths}\")", "\tcpu.leaving"]
	)
	(texts, "\n{step.join("\n")}\n")

# One instruction as an interpreter's function: its cycles and what it does, then the address
# after it unless it went elsewhere.
fn interpretedFunction(i Instr, name str):
	ft = FnText(
		lines = [],
		temps = 0,
		dispatched = false,
		patches = {},
		name = name.copy(),
		returnText = "return cpu.leaving"
	)
	for line in i.leadCycles():
		ft.put(1, line)
	ft.interpreted(1, i)
	if ft.lines.isEmpty or not ft.lines[len - 1].startsWith("\treturn "):
		ft.put(1, "return nextAt")
	body = ft.lines.join("\n")
	out = ["fn {name}(at u32) u32:"]
	if "operand" in body:
		out.push("\toperand = cpu.operandAt(at, {i.size - 1})")
	if "nextAt" in body:
		out.push("\tnextAt = (at & 0xFF_0000) | ((at + {i.size}) & 0xFFFF)")
	out.extend(ft.lines)
	out

# What the instruction does where the interpreter runs it: its flow by the address it gives,
# the widths rep, sep and plp leave read from the status they make, the rest as translated.
fn interpreted(mut ft FnText, depth i64, i Instr):
	bits = i.widths.widthBits()
	if i.name in conditionalBranches:
		ft.put(depth, "if {conditionText(i.name)}:")
		ft.branchTaken(depth + 1, i)
		return
	match i.name:
		"bra": ft.branchTaken(depth, i)
		"brl": ft.put(depth, "return {i.targetText()}")
		"jmp", "jml", "jsr", "jsl":
			calls = i.name == "jsr" or i.name == "jsl"
			target = ""
			if i.mode == "w":
				if calls: ft.pushReturn(depth, i)
				target = "(at & 0xFF_0000) | operand"
			elif i.mode == "l":
				if calls: ft.pushReturn(depth, i)
				target = "operand"
			else:
				target = ft.indirectTargetLines(depth, i)
			if not calls:
				ft.put(depth, "return {target}")
				return
			ft.put(depth, "cpu.goFrom({target}, {bits})")
			ft.put(depth, "if cpu.ret != nextAt: return cpu.leaving")
		"rts":
			ft.put(depth, "cpu.returnShort(at >> 16, {bits})")
			ft.put(depth, "console.idle()")
			ft.put(depth, "return cpu.leaving")
		"rtl":
			ft.put(depth, "cpu.returnLong({bits})")
			ft.put(depth, "return cpu.leaving")
		"rti":
			ft.put(depth, "cpu.returnInterrupt()")
			ft.put(depth, "return cpu.leaving")
		"plp": ft.put(depth, "cpu.pullStatusAny()")
		"rep", "sep": ft.put(depth, "cpu.changeStatus(u8.wrap(operand), {i.name == "sep"})")
		_: ft.operation(depth, i, allFlags)

# a branch taken: an internal cycle, one more in emulation mode across a page, then its target
fn branchTaken(mut ft FnText, depth i64, i Instr):
	ft.put(depth, "console.idle()")
	if i.widths.e:
		ft.put(depth, "if ({i.targetText()} ^ nextAt) & 0xFF00 != 0: console.idle()")
	ft.put(depth, "return {i.targetText()}")
