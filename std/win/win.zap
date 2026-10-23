# The parts of the Windows API a program calls by hand, declared once: libraries and the
# functions in them, events, handles, the memory the system hands out, and the basics of COM (an
# object's method from its table, QueryInterface, Release, GUIDs, HRESULTs). A module of the
# standard library: `import win`, then win.loadFunction("kernel32.dll", "CreateEventA"),
# win.memoryAt(address, n).write(0, floats), win.release(object).
#
# A COM object is the address of a pointer to its table of methods; a method is called with the
# object first. A program declares each method it calls as an `extern loaded fn` and binds it to
# win.method(object, slot) before the call (the slot is the method's place in its interface's
# table, as the system's headers declare it).

# name NUL-ended; 0 when there is none
pub extern fn GetProcAddress(module i64, name str) i64
# name NUL-ended; 0 when it cannot be loaded
pub extern fn LoadLibraryA(name str) i64
pub extern fn CreateEventA(security i64, manual bool, initial bool, name i64) i64
# ms -1: for ever
pub extern fn WaitForSingleObject(h i64, ms i64) i32
pub extern fn CloseHandle(h i64) bool

extern loaded fn comQueryInterface(object i64, riid u8[], out object i64) i32
extern loaded fn comRelease(object i64) i32

# held while a thread binds comRelease or comQueryInterface and calls it: a background job and
# its starter both release objects
comLock = Atomic(0)

# the address of the function `name` in the system library `library`, 0 when there is none
pub fn loadFunction(library str, name str) i64:
	GetProcAddress(LoadLibraryA("{library}\0"), "{name}\0")

# ---------- memory the system hands out ----------

# Foreign memory: `len` bytes at an address the system gave (a mapped GPU buffer, a sound card's
# buffer, a string it allocated), whose address and length are taken on trust as an extern's
# signature is. Each read and write is checked against `len` (past it the program stops, as at an
# index out of bounds) and copies in line; the program's side is a list, whose length bounds it.
pub type MemoryView:
	address i64
	len i64

	# the n bytes from byte `at`, as a view of their own
	fn part(at i64, n i64):
		self.checkRoom(at, n)
		MemoryView(address = address + at, len = n)

	# the values' bytes written from byte `at`
	fn write<T Copy>(at i64, values T[]):
		checkRoom(self, at, values.byteSize)
		rt.copyToAddress(address + at, values)

	# `into` filled with the bytes from byte `at`, as many as it holds
	fn read<T Copy>(at i64, mut into T[]):
		checkRoom(self, at, into.byteSize)
		rt.copyFromAddress(into, address + at)

	# the n bytes from byte `at`, as a list of their own
	fn bytes(at i64, n i64):
		out u8[] = zeros(n.max(0))
		self.read(at, out)
		out

	# the 8-byte word at byte `at` (an address the system keeps there: a table's, a method's), as on
	# str and u8[]
	fn loadWord(at i64) u64:
		self.checkRoom(at, 8)
		u64.wrap(rt.wordAtAddress(address + at))

	# the bytes of `from` written from byte `at`
	fn copyFrom(at i64, from MemoryView):
		self.checkRoom(at, from.len)
		rt.copyBetweenAddresses(address + at, from.address, from.len)

pub fn memoryAt(address i64, len i64) MemoryView:
	MemoryView(address, len = len.max(0))

# stops the program unless the n bytes from `at` are within the view
fn checkRoom(m MemoryView, at i64, n i64):
	if at < 0 or n < 0 or n > m.len - at: rt.boundsFail()

# ---------- COM ----------

# the address of an object's method in slot `slot` of its table
pub fn method(object i64, slot i64) i64:
	table = i64(memoryAt(object, 8).loadWord(0))
	i64(memoryAt(table + slot * 8, 8).loadWord(0))

# IUnknown::Release of an object, nothing for 0
pub fn release(object i64):
	if object != 0:
		lockCom()
		bindExtern(comRelease, method(object, 2))
		comRelease(object)
		comLock.compareSwap(1, 0)

# the object as another of its interfaces (QueryInterface), 0 when it has none
pub fn queryInterface(object i64, riid u8[]) i64:
	lockCom()
	bindExtern(comQueryInterface, method(object, 0))
	hr = comQueryInterface(object, riid, out result)
	comLock.compareSwap(1, 0)
	result if hr >= 0 else 0

fn lockCom():
	while not comLock.compareSwap(0, 1):
		rt.SwitchToThread()

# a GUID's 16 bytes from its text ("189819f1-1db6-4b57-be54-1821339b85f7"): its first three
# groups little-endian, the rest as written
pub fn guid(text str) u8[]:
	hex = text.replace("-", "")
	raw = (0..16).map(u8(hex[it * 2].hexValue() * 16 + hex[it * 2 + 1].hexValue()))
	[
		raw[3],
		raw[2],
		raw[1],
		raw[0],
		raw[5],
		raw[4],
		raw[7],
		raw[6],
		raw[8],
		raw[9],
		raw[10],
		raw[11],
		raw[12],
		raw[13],
		raw[14],
		raw[15]
	]

# an HRESULT as the system documents it: "0x887a0005"
pub fn hresultText(hr i32) str:
	"0x{i64(hr) & 0xFFFFFFFF:08x}"

# ---------- randomness ----------

extern "bcrypt.dll" fn BCryptGenRandom(algorithm i64, buf u8[], n i64, flags i64) i32

# n bytes from the system's random generator, fit for secrets (a token, a key)
pub fn secureRandom(n i64) u8[]:
	bytes u8[] = zeros(n)
	BCryptGenRandom(0, bytes, n, 2)   # BCRYPT_USE_SYSTEM_PREFERRED_RNG
	bytes
