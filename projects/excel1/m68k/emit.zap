# The recompiler's back end: a list of common-form steps (cpu/form.zap) written as Zap source,
# one statement a step, over locals `t0..` and the machine (cpu/machine.zap). The same steps the
# interpreter runs (cpu/interpret.zap), so a recompiled block ends in the same machine state as the
# interpreted one; the recompiler emits whole functions from these (recomp.zap).

import cpu

# the Zap expression of a value step, over `t0..` and the machine (mirrors interpret.valueOf)
fn valueExpr(s cpu.Step):
	a = "t[{s.a}]"
	b = "t[{s.b}]"
	c = "t[{s.c}]"
	size = s.size
	match s.op:
		Const: "u32.wrap({s.k})"
		Get: "cpu.register({s.a})"
		Load: "cpu.read({a}, {size})"
		Add: "{a} + {b}"
		Sub: "{a} - {b}"
		Mul: "{a} * {b}"
		And: "{a} & {b}"
		Or: "{a} | {b}"
		Xor: "{a} ^ {b}"
		Shl: "{a} << {b} if {b} < 32 else 0"
		Shr: "{a} >> {b} if {b} < 32 else 0"
		Not: "~{a}"
		Sext: "cpu.sext({a}, {size})"
		Zext: "{a} & cpu.sizeMask({size})"
		Eq: "cpu.boolBit({a} == {b})"
		Ltu: "cpu.boolBit({a} < {b})"
		Select: "{b} if {a} != 0 else {c}"
		Code: "codeBase + u32.wrap({s.k})"
		CarryAdd: "cpu.msb({a} & {b} | ({a} | {b}) & ~{c}, {size})"
		OverAdd: "cpu.msb(({a} ^ {c}) & ({b} ^ {c}), {size})"
		CarrySub: "cpu.msb({b} & ~{a} | {c} & ~{a} | {b} & {c}, {size})"
		OverSub: "cpu.msb(({a} ^ {b}) & ({a} ^ {c}), {size})"
		Cond: "cpu.boolBit(cpu.holds({s.k}, cpu.cc, cpu.cv, cpu.cz, cpu.cn))"
		GetCcr: "cpu.ccr()"
		GetSr: "cpu.sr()"
		Helper: "cpu.helper({s.k}, {a} if {s.a} >= 0 else 0, {b} if {s.b} >= 0 else 0, {size})"
		_: "0"

# the lines of a single step, each at `indent`; a control step appends nothing (control is written
# by the caller, from isEnd and the step's fields)
pub fn stepLines(s cpu.Step, indent str) str[]:
	size = s.size
	match s.op:
		Put:
			value = "cpu.merged(cpu.register({s.a}), t[{s.b}], {size})" if s.a < 8 else "t[{s.b}]"
			["{indent}cpu.setRegister({s.a}, {value})"]
		Store: ["{indent}cpu.write(t[{s.a}], t[{s.b}], {size})"]
		FlagN: ["{indent}cpu.cn = cpu.msb(t[{s.a}], {size}) != 0"]
		FlagZ: ["{indent}cpu.cz = t[{s.a}] & cpu.sizeMask({size}) == 0"]
		FlagZAnd: ["{indent}cpu.cz = cpu.cz and t[{s.a}] & cpu.sizeMask({size}) == 0"]
		FlagSet: ["{indent}cpu.setFlagBit({s.k}, t[{s.a}] != 0)"]
		PutCcr: ["{indent}cpu.setCcr(t[{s.a}])"]
		PutSr: ["{indent}cpu.setSr(t[{s.a}])"]
		Jump, JumpIf, JumpTo, Aline, Exception, ExceptionIf, Stop: []
		_: ["{indent}t[{s.d}] = {s.valueExpr()}"]

# the number of temporary slots a block of steps uses (the highest index written, plus one)
pub fn temporaryCount(steps cpu.Step[]) i64:
	top = 0
	for s in steps:
		if s.d >= 0: top = top.max(s.d + 1)
	top
