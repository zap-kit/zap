# Binary encoding keeps a float's bits.
type Sample:
	small f32
	big f64

test "binary encoding keeps the bits":
	s = Sample(small = 0.1, big = -0.0)
	back = Sample.fromBytes(s.toBytes()) ?? Sample(small = 0.0, big = 0.0)
	print(back)
	expect back.small.toBits() == s.small.toBits() and back.big.toBits() == s.big.toBits()
	prints """
		Sample(small = 0.1, big = 0)
		"""

# an unsigned integer turned (the count modulo the width, a negative one the other way), its
# bytes swapped, its leading and trailing zero bits counted (the width for 0), at every width
fn turned(x u32, h u16, b u8, k i64):
	"{x.rotateLeft(k):x} {h.rotateRight(k):x} {b.rotateLeft(k)}"

test "rotations, byte swaps and zero counts":
	x u32 = 0x1234_5678
	print("{x.rotateLeft(8):x} {x.rotateRight(4):x} {x.byteSwap():x} {x.leadingZeros()} {x.trailingZeros()}")
	y u64 = 0x0123_4567_89AB_CDEF
	print("{y.rotateLeft(4):x} {y.rotateRight(68):x} {y.byteSwap():x} {y.leadingZeros()} {y.trailingZeros()}")
	h u16 = 0xABCD
	print("{h.rotateLeft(4):x} {h.byteSwap():x} {h.leadingZeros()} {h.trailingZeros()}")
	b u8 = 0x81
	print(
		"{b.rotateLeft(1)} {b.rotateRight(1)} {b.byteSwap()} {b.leadingZeros()} {b.trailingZeros()}"
	)
	z u32 = 0
	print("{z.leadingZeros()} {z.trailingZeros()} {u64(0).leadingZeros()}")
	print([-1, 0, 31, 32, 33].map(turned(x, h, b, it)).join(", "))
	prints """
		34567812 81234567 78563412 3 3
		123456789abcdef0 f0123456789abcde efcdab8967452301 7 0
		bcda cdab 0 0
		3 192 129 0 0
		32 32 64
		91a2b3c 579b 192, 12345678 abcd 129, 91a2b3c 579b 192, 12345678 abcd 129, 2468acf0 d5e6 3
		"""

test "a rotation is of unsigned integers" refuses NoMethod:
	x i32 = 5
	print(x.rotateLeft(1))
