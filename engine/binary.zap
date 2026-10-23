# Binary layouts games keep their files in, beyond what Reader and the push methods give: text
# behind a 16-bit length (a wstring in Bethesda's saves), numbers of 3 bytes, and a value of one,
# two or four bytes chosen by its size.

# the text behind its length in bytes as a u16
pub fn pushString16(mut out u8[], text str):
	out.pushU16le(text.bytes().len)
	for b in text.bytes():
		out.push(b)

# the text a pushString16 wrote
pub fn string16(mut r Reader) str:
	n = i64(r.u16())
	r.bytes(n).cStringAt(0, n)

# the three low bytes of v, the highest first
pub fn pushU24be(mut out u8[], v i64):
	out.push((v >> 16) & 255)
	out.push((v >> 8) & 255)
	out.push(v & 255)

pub fn u24be(mut r Reader) i64:
	hi = i64(r.u8())
	mid = i64(r.u8())
	hi << 16 | mid << 8 | r.u8()

# how many bytes (1, 2 or 4) hold v, as the code a length field carries
pub fn widthCode(v i64) i64:
	if v < 256: return 0
	1 if v < 65_536 else 2

# v in the width the code names (0 one byte, 1 two, 2 four), little-endian
pub fn pushWidth(mut out u8[], v i64, code i64):
	match code:
		0: out.push(u8(v))
		1: out.pushU16le(v)
		_: out.pushU32le(v)

pub fn readWidth(mut r Reader, code i64) i64:
	match code:
		0: r.u8()
		1: r.u16()
		_: r.u32()

test "text, 24-bit numbers and sized numbers read back":
	out u8[] = []
	out.pushString16("Лена")
	out.pushU24be(0x12_3456)
	out.pushWidth(70_000, 70_000.widthCode())
	out.pushWidth(300, 300.widthCode())
	out.pushWidth(9, 9.widthCode())
	r = Reader(out)
	expect r.string16() == "Лена"
	expect r.u24be() == 0x12_3456
	expect r.readWidth(2) == 70_000 and r.readWidth(1) == 300 and r.readWidth(0) == 9
	expect not r.short
