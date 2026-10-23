# The common form a machine's instructions lower to (m68k/lower.zap for the 68000): steps over
# numbered temporaries holding 32 bits, the machine's registers and its flags, so one interpreter
# runs it (interpret.zap) and one translator writes it as Zap (the recompiler), whichever
# processor it came from. A step writes at most one temporary (d) from up to three (a, b, c) and a
# constant k; a flag step writes one flag, so the flags no later step reads are left out.

pub type Op:
	Const   # d = k
	Get   # d = register a (0-7 d0-d7, 8-15 a0-a7)
	Put   # register a = b, its low `size` bytes only when size is 1 or 2
	Load   # d = the size bytes at address a, zero-extended
	Store   # the size bytes at address a = b
	Add   # d = a + b, modulo 2^32
	Sub
	Mul
	And
	Or
	Xor
	Shl   # d = a << b (b below 32)
	Shr   # d = a >> b, zeros in
	Not   # d = ~a
	Sext   # d = the low `size` bytes of a, sign-extended
	Zext   # d = the low `size` bytes of a
	Eq   # d = 1 when a == b, else 0
	Ltu   # d = 1 when a < b as unsigned
	Select   # d = b when a != 0, else c
	Code   # d = the address of code offset k where the code runs
	FlagN   # n = the sign bit of a's low `size` bytes
	FlagZ   # z = a's low `size` bytes are zero
	FlagZAnd   # z = z and a's low `size` bytes are zero (ADDX, SUBX, NEGX, ABCD keep a zero)
	FlagSet   # the flag k = a != 0
	CarryAdd   # d = the carry out of a + b at `size` (c the sum)
	OverAdd   # d = the overflow of a + b = c at `size`
	CarrySub   # d = the borrow of a - b at `size` (c the difference)
	OverSub   # d = the overflow of a - b = c at `size`
	Cond   # d = 1 when the condition k (0-15) holds
	GetCcr   # d = the flags as the condition code register's bits
	PutCcr   # the flags = a's bits
	GetSr   # d = the status register (its system byte and the flags)
	PutSr
	Helper   # d = helper k of a, b, c at `size` (helpers.zap), its flags as helperFlags says
	Jump   # to code offset k
	JumpIf   # to code offset k when a != 0, else on to the next instruction
	JumpTo   # to the address a
	Aline   # the A-line trap of word k, then on to the next instruction
	Exception   # the exception of vector k (TRAP, CHK, an illegal word)
	ExceptionIf   # the exception of vector k when a != 0 (a division by zero), else on
	Stop   # the processor halts (STOP), k the status register it loads

pub type Step:
	op Op
	d i64 = -1
	a i64 = -1
	b i64 = -1
	c i64 = -1
	k i64 = 0
	size i64 = 4

# the flags' bits in the condition code register
pub flagC = 0
pub flagV = 1
pub flagZ = 2
pub flagN = 3
pub flagX = 4
pub allFlags = 31

# whether the step ends the instructions run in a row: what follows it is reached only by a jump
pub fn isEnd(s Step) bool:
	match s.op:
		Jump, JumpTo, Aline, Exception, Stop: true
		_: false

# The flags a step reads, as a mask of the flags' bits (where a jump goes is the analysis's to
# follow).
pub fn flagsRead(s Step) i64:
	match s.op:
		FlagZAnd: 1 << flagZ
		Cond: conditionFlags(s.k)
		GetCcr, GetSr: allFlags
		Helper: helperFlagsRead(s.k)
		_: 0

# the flags a step writes
pub fn flagsWritten(s Step) i64:
	match s.op:
		FlagN: 1 << flagN
		FlagZ, FlagZAnd: 1 << flagZ
		FlagSet: 1 << s.k
		PutCcr, PutSr, Aline: allFlags
		Helper: helperFlagsWritten(s.k)
		_: 0

# whether the step does more than write its temporary: a step that does not, whose temporary
# nothing reads, is left out
pub fn hasEffect(s Step) bool:
	match s.op:
		Put, Store, PutCcr, PutSr, Helper, Jump, JumpIf, JumpTo, Aline, Exception, ExceptionIf, Stop, FlagN, FlagZ, FlagZAnd, FlagSet: true
		_: false

# the temporaries a step reads
pub fn temporariesRead(s Step) i64[]:
	match s.op:
		Const, Get, Code, Cond, GetCcr, GetSr, Jump, Aline, Exception, Stop: []
		Put, Store, Add, Sub, Mul, And, Or, Xor, Shl, Shr, Eq, Ltu: [s.a, s.b]
		CarryAdd, OverAdd, CarrySub, OverSub, Select: [s.a, s.b, s.c]
		Helper: [s.a, s.b, s.c].filter(it >= 0)
		_: [s.a]

# the flags a condition reads
pub fn conditionFlags(cc i64) i64:
	c = 1 << flagC
	v = 1 << flagV
	z = 1 << flagZ
	n = 1 << flagN
	match cc:
		0, 1: 0
		2, 3: c | z
		4, 5: c
		6, 7: z
		8, 9: v
		10, 11: n
		12, 13: n | v
		_: n | v | z

# whether the condition holds for the flags
pub fn holds(cc i64, c bool, v bool, z bool, n bool) bool:
	match cc:
		0: true
		1: false
		2: not c and not z
		3: c or z
		4: not c
		5: c
		6: not z
		7: z
		8: not v
		9: v
		10: not n
		11: n
		12: n == v
		13: n != v
		14: n == v and not z
		_: z or n != v
