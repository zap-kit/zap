# long: the table of actions by code and their listing, one line per action
#
# The actions' names by code (SWF specification v19, chapter 5), for listings and for the survey
# of what a movie's code uses.

names = [
	(0x04, "NextFrame"), (0x05, "PreviousFrame"), (0x06, "Play"), (0x07, "Stop"),
	(0x08, "ToggleQuality"), (0x09, "StopSounds"), (0x0A, "Add"), (0x0B, "Subtract"),
	(0x0C, "Multiply"), (0x0D, "Divide"), (0x0E, "Equals"), (0x0F, "Less"), (0x10, "And"),
	(0x11, "Or"), (0x12, "Not"), (0x13, "StringEquals"), (0x14, "StringLength"),
	(0x15, "StringExtract"), (0x17, "Pop"), (0x18, "ToInteger"), (0x1C, "GetVariable"),
	(0x1D, "SetVariable"), (0x20, "SetTarget2"), (0x21, "StringAdd"), (0x22, "GetProperty"),
	(0x23, "SetProperty"), (0x24, "CloneSprite"), (0x25, "RemoveSprite"), (0x26, "Trace"),
	(0x27, "StartDrag"), (0x28, "EndDrag"), (0x29, "StringLess"), (0x2A, "Throw"),
	(0x2B, "CastOp"), (0x2C, "ImplementsOp"), (0x30, "RandomNumber"), (0x31, "MBStringLength"),
	(0x32, "CharToAscii"), (0x33, "AsciiToChar"), (0x34, "GetTime"), (0x35, "MBStringExtract"),
	(0x36, "MBCharToAscii"), (0x37, "MBAsciiToChar"), (0x3A, "Delete"), (0x3B, "Delete2"),
	(0x3C, "DefineLocal"), (0x3D, "CallFunction"), (0x3E, "Return"), (0x3F, "Modulo"),
	(0x40, "NewObject"), (0x41, "DefineLocal2"), (0x42, "InitArray"), (0x43, "InitObject"),
	(0x44, "TypeOf"), (0x45, "TargetPath"), (0x46, "Enumerate"), (0x47, "Add2"), (0x48, "Less2"),
	(0x49, "Equals2"), (0x4A, "ToNumber"), (0x4B, "ToString"), (0x4C, "PushDuplicate"),
	(0x4D, "StackSwap"), (0x4E, "GetMember"), (0x4F, "SetMember"), (0x50, "Increment"),
	(0x51, "Decrement"), (0x52, "CallMethod"), (0x53, "NewMethod"), (0x54, "InstanceOf"),
	(0x55, "Enumerate2"), (0x60, "BitAnd"), (0x61, "BitOr"), (0x62, "BitXor"),
	(0x63, "BitLShift"), (0x64, "BitRShift"), (0x65, "BitURShift"), (0x66, "StrictEquals"),
	(0x67, "Greater"), (0x68, "StringGreater"), (0x69, "Extends"), (0x81, "GotoFrame"),
	(0x83, "GetURL"), (0x87, "StoreRegister"), (0x88, "ConstantPool"), (0x8A, "WaitForFrame"),
	(0x8B, "SetTarget"), (0x8C, "GoToLabel"), (0x8D, "WaitForFrame2"), (0x8E, "DefineFunction2"),
	(0x8F, "Try"), (0x94, "With"), (0x96, "Push"), (0x99, "Jump"), (0x9A, "GetURL2"),
	(0x9B, "DefineFunction"), (0x9D, "If"), (0x9E, "Call"), (0x9F, "GotoFrame2")
]

# the action's name by its code, "Action<code>" for one not in the specification
pub fn actionName(code i64) str:
	for (c, name) in names:
		if c == code: return name.copy()
	"Action0x{code:02X}"

# the code of an action as decoded
pub fn codeOf(a Action) i64:
	match a:
		Op(code): code
		GotoFrame: 0x81
		GetUrl: 0x83
		StoreRegister: 0x87
		ConstantPool: 0x88
		WaitForFrame: 0x8A
		SetTarget: 0x8B
		GotoLabel: 0x8C
		WaitForFrame2: 0x8D
		Function(def): 0x8E if def.two else 0x9B
		Try: 0x8F
		With: 0x94
		Push: 0x96
		Jump: 0x99
		GetUrl2: 0x9A
		If: 0x9D
		Call: 0x9E
		GotoFrame2: 0x9F
		Unknown(code, _): code

# one line per action, as a disassembler prints them: index, name and data
pub fn blockLines(b Block, indent str) str[]:
	lines = []
	pool = []
	for k, a in b.actions:
		if a is ConstantPool(items): pool = items.copy()
		lines.push("{indent}{k:>4} {actionName(a.codeOf())} {a.dataText(pool)}")
	lines

fn dataText(a Action, pool str[]):
	match a:
		GotoFrame(f): "{f}"
		GetUrl(url, target): "\"{url}\" \"{target}\""
		StoreRegister(r): "r{r}"
		ConstantPool(items): "{items.len} strings"
		WaitForFrame(f, skip): "{f} skip {skip}"
		SetTarget(name): "\"{name}\""
		GotoLabel(label): "\"{label}\""
		WaitForFrame2(skip): "skip {skip}"
		Function(def): "{def.name}({def.params.join(", ")}) {def.body}..{def.end}"
		Try(t): "try ..{t.tryEnd} catch ..{t.catchEnd} finally ..{t.finallyEnd}"
		With(end): "..{end}"
		Push(items): items.map(.pushText(pool)).join(", ")
		Jump(to): "-> {to}"
		GetUrl2(flags): "{flags}"
		If(to): "-> {to}"
		GotoFrame2(play, bias): "play {play} bias {bias}"
		_: ""

fn pushText(p PushItem, pool str[]):
	match p:
		Text(s): "\"{s}\""
		Number(x): "{x}"
		Null: "null"
		Undefined: "undefined"
		Register(r): "r{r}"
		Boolean(b): "{b}"
		Constant(k): "'{pool[k]}'" if k < pool.len else "c{k}"
