# The common form run step by step on the machine: the reference the translated code is checked
# against, and the way to run code no translation reaches.

# where the steps of an instruction go on to
pub type Exit:
	Next
	Jump(target i64)   # a code offset
	JumpTo(address u32)
	Aline(word i64)
	Exception(vector i64)
	Stop(status i64)

# what the Mac does for an A-line trap and an exception: given the trap's word (or the vector) and
# the address after the instruction, the address to go on at
pub mut onAline fn(i64, u32) u32 = (_, next): next
# what the code reaching an address past the memory (the ROM's routines) does: where it goes on
pub mut onRomCall fn(u32) u32 = (at): at
pub mut onException fn(i64, u32) u32 = (vector, _): unhandled(vector)

pub fn msb(v u32, size i64) u32:
	v >> (size * 8 - 1) & 1

pub fn sext(v u32, size i64) u32:
	match size:
		1: u32.wrap(i64(i8.wrap(i64(v & 0xFF))))
		2: u32.wrap(i64(i16.wrap(i64(v & 0xFFFF))))
		_: v

pub fn boolBit(b bool) u32:
	1 if b else 0

fn unhandled(vector i64) u32:
	stop("exception {vector}")
	0

# the value of a step that writes a temporary from others, t the temporaries
pub fn valueOf(s Step, t u32[], codeBase u32) u32:
	match s.op:
		Const: u32.wrap(s.k)
		Get: register(s.a)
		Load: read(t[s.a], s.size)
		Add: t[s.a] + t[s.b]
		Sub: t[s.a] - t[s.b]
		Mul: t[s.a] * t[s.b]
		And: t[s.a] & t[s.b]
		Or: t[s.a] | t[s.b]
		Xor: t[s.a] ^ t[s.b]
		Shl: t[s.a] << t[s.b] if t[s.b] < 32 else 0
		Shr: t[s.a] >> t[s.b] if t[s.b] < 32 else 0
		Not: ~t[s.a]
		Sext: sext(t[s.a], s.size)
		Zext: t[s.a] & sizeMask(s.size)
		Eq: boolBit(t[s.a] == t[s.b])
		Ltu: boolBit(t[s.a] < t[s.b])
		Select: t[s.b] if t[s.a] != 0 else t[s.c]
		Code: codeBase + u32.wrap(s.k)
		CarryAdd: msb(t[s.a] & t[s.b] | (t[s.a] | t[s.b]) & ~t[s.c], s.size)
		OverAdd: msb((t[s.a] ^ t[s.c]) & (t[s.b] ^ t[s.c]), s.size)
		CarrySub: msb(t[s.b] & ~t[s.a] | t[s.c] & ~t[s.a] | t[s.b] & t[s.c], s.size)
		OverSub: msb((t[s.a] ^ t[s.b]) & (t[s.a] ^ t[s.c]), s.size)
		Cond: boolBit(holds(s.k, cc, cv, cz, cn))
		GetCcr: ccr()
		GetSr: sr()
		Helper: helper(s.k, t[s.a] if s.a >= 0 else 0, t[s.b] if s.b >= 0 else 0, s.size)
		_: 0

pub fn setFlagBit(f i64, on bool):
	match f:
		0: cc = on
		1: cv = on
		2: cz = on
		3: cn = on
		_: cx = on

# Runs the steps of an instruction: where it goes on to.
pub fn execute(steps Step[], mut t u32[], codeBase u32) Exit:
	for s in steps:
		match s.op:
			Put:
				setRegister(s.a, merged(register(s.a), t[s.b], s.size) if s.a < 8 else t[s.b])
			Store: write(t[s.a], t[s.b], s.size)
			FlagN: cn = msb(t[s.a], s.size) != 0
			FlagZ: cz = t[s.a] & sizeMask(s.size) == 0
			FlagZAnd: cz = cz and t[s.a] & sizeMask(s.size) == 0
			FlagSet: setFlagBit(s.k, t[s.a] != 0)
			PutCcr: setCcr(t[s.a])
			PutSr: setSr(t[s.a])
			Jump: return .Jump(s.k)
			JumpIf:
				if t[s.a] != 0: return .Jump(s.k)
			JumpTo: return .JumpTo(t[s.a])
			Aline: return .Aline(s.k)
			Exception: return .Exception(s.k)
			ExceptionIf:
				if t[s.a] != 0: return .Exception(s.k)
			Stop: return .Stop(s.k)
			_: t[s.d] = s.valueOf(t, codeBase)
	.Next
