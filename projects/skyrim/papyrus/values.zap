# Papyrus's values and the conversions its `cast` and comparisons make: ints are 32-bit and wrap,
# floats are 32-bit, strings compare without case, objects and arrays are handles into the VM.

pub type Value:
	None
	Int(n i64)
	Float(x f32)
	Bool(b bool)
	Str(text str)
	Object(id i64)   # an instance in Runtime.objects
	Array(id i64)   # an array in Runtime.arrays

# x wrapped to a signed 32-bit int, as Papyrus's arithmetic overflows
pub fn wrap32(x i64) i64:
	((x + 0x8000_0000) & 0xFFFF_FFFF) - 0x8000_0000

# Papyrus's float to string: six decimals
pub fn floatText(x f32) str:
	"{x:.6}"

# a value given from an operand of the file (an identifier is read by the VM, not here)
pub fn literal(o Operand) Value:
	match o:
		Text(text): .Str(text.copy())
		Int(n): .Int(n)
		Float(x): .Float(x)
		Bool(b): .Bool(b)
		_: .None

# the value a variable of this type starts with when the file gives none
pub fn defaultOf(typeName str) Value:
	match typeName.lower():
		"int": .Int(0)
		"float": .Float(0.0)
		"bool": .Bool(false)
		"string": .Str("")
		_: .None

pub fn isTrue(v Value, arrayLength i64) bool:
	match v:
		None: false
		Int(n): n != 0
		Float(x): x != 0.0
		Bool(b): b
		Str(text): not text.isEmpty
		Object(id): id != 0
		Array(id): arrayLength > 0

# the leading number of a text, as the game's atoi reads one (0 when there is none)
fn textInt(text str):
	t = text.trimmed()
	end = 0
	while end < t.len and
		(t[end] >= '0' and t[end] <= '9' or end == 0 and (t[end] == '-' or t[end] == '+')):
		end += 1
	i64.parse(t[..end]) ?? 0

pub fn asInt(v Value) i64:
	match v:
		Int(n): n
		Float(x): wrap32(i64(x))
		Bool(b): 1 if b else 0
		Str(text): wrap32(textInt(text))
		_: 0

pub fn asFloat(v Value) f32:
	match v:
		Int(n): f32(n)
		Float(x): x
		Bool(b): 1.0 if b else 0.0
		Str(text): f32.parse(text.trimmed()) ?? f32(textInt(text))
		_: 0.0

pub fn isNumber(v Value) bool:
	match v:
		Int, Float: true
		_: false

fn sign(above bool, below bool):
	1 if above else -1 if below else 0

# -1, 0 or 1 as a < b, a == b, a > b; numbers by value, strings without case, the rest by handle
pub fn compareValues(a Value, b Value) i64:
	if a.isNumber() and b.isNumber():
		if a is Int(x) and b is Int(y): return sign(x > y, x < y)
		return sign(a.asFloat() > b.asFloat(), a.asFloat() < b.asFloat())
	if a is Str(x) and b is Str(y): return x.lower().cmp(y.lower())
	if a is Bool(x) and b is Bool(y): return sign(x and not y, y and not x)
	0

pub fn valuesEqual(a Value, b Value) bool:
	if a.isNumber() and b.isNumber(): return a.compareValues(b) == 0
	if a is Str(x) and b is Str(y): return x.lower() == y.lower()
	if a is Bool(x) and b is Bool(y): return x == y
	if a is Array(x) and b is Array(y): return x == y
	a.handleOf() == b.handleOf() and not a.isNumber() and not b.isNumber()

# an object's handle, 0 for none, -1 for anything else
fn handleOf(v Value):
	match v:
		None: 0
		Object(id): id
		_: -1
