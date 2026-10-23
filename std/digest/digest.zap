# Digests of bytes: a file's fingerprint, as a dump or a download is named by one, a signature's
# digest, and the CRC-32 a PNG's chunk or a zip's entry carries.

# The SHA-1 of the bytes (FIPS 180-4), as 40 lowercase hexadecimal digits.
pub fn sha1(d u8[]) str:
	h u32[5] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476, 0xC3D2_E1F0]
	tail = paddedTail(d)
	for at in blockStarts(d):
		h = sha1Block(h, d, at)
	for at in blockStarts(tail):
		h = sha1Block(h, tail, at)
	h.map("{it:08x}").join("")

# The SHA-256 of the bytes (FIPS 180-4), its 32 bytes.
pub fn sha256(d u8[]) u8[]:
	h u32[8] = [
		0x6A09_E667,
		0xBB67_AE85,
		0x3C6E_F372,
		0xA54F_F53A,
		0x510E_527F,
		0x9B05_688C,
		0x1F83_D9AB,
		0x5BE0_CD19
	]
	tail = paddedTail(d)
	for at in blockStarts(d):
		h = sha256Block(h, d, at)
	for at in blockStarts(tail):
		h = sha256Block(h, tail, at)
	out = []
	for w in h:
		out.pushU32be(w)
	out

# the bytes after the whole blocks of 64, then the padding and the length in bits that end the
# last block (SHA-1's and SHA-2's)
fn paddedTail(d u8[]):
	tail u8[] = d[len - len % 64..].copy()
	tail.push(0x80)
	while tail.len % 64 != 56:
		tail.push(0)
	tail.pushU64be(d.len * 8)
	tail

# where each whole block of 64 bytes starts
fn blockStarts(d u8[]):
	(0..d.len / 64).map(it * 64)

sha1Keys u32[4] = [0x5A82_7999, 0x6ED9_EBA1, 0x8F1B_BCDC, 0xCA62_C1D6]

# the state after one block of 64 bytes at `at`
fn sha1Block(h u32[5], d u8[], at i64) u32[5]:
	w u32[80] = zeros(80)
	for i in 0..16:
		w[i] = d.u32be(at + 4 * i)
	for i in 16..80:
		w[i] = (w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]).rotateLeft(1)
	a = h[0]
	b = h[1]
	c = h[2]
	e = h[4]
	dd = h[3]
	for i in 0..80:
		f = (b & c) | (~b & dd) if i < 20
			else b ^ c ^ dd if i < 40 or i >= 60
			else (b & c) | (b & dd) | (c & dd)
		k = sha1Keys[i / 20]
		t = a.rotateLeft(5) + f + e + k + w[i]
		e = dd
		dd = c
		c = b.rotateLeft(30)
		b = a
		a = t
	[h[0] + a, h[1] + b, h[2] + c, h[3] + dd, h[4] + e]

# SHA-256's constants: the first 32 bits of the fractional parts of the cube roots of the first
# 64 primes
# long: a table
sha256Keys u32[64] = [
	0x428A_2F98,
	0x7137_4491,
	0xB5C0_FBCF,
	0xE9B5_DBA5,
	0x3956_C25B,
	0x59F1_11F1,
	0x923F_82A4,
	0xAB1C_5ED5,
	0xD807_AA98,
	0x1283_5B01,
	0x2431_85BE,
	0x550C_7DC3,
	0x72BE_5D74,
	0x80DE_B1FE,
	0x9BDC_06A7,
	0xC19B_F174,
	0xE49B_69C1,
	0xEFBE_4786,
	0x0FC1_9DC6,
	0x240C_A1CC,
	0x2DE9_2C6F,
	0x4A74_84AA,
	0x5CB0_A9DC,
	0x76F9_88DA,
	0x983E_5152,
	0xA831_C66D,
	0xB003_27C8,
	0xBF59_7FC7,
	0xC6E0_0BF3,
	0xD5A7_9147,
	0x06CA_6351,
	0x1429_2967,
	0x27B7_0A85,
	0x2E1B_2138,
	0x4D2C_6DFC,
	0x5338_0D13,
	0x650A_7354,
	0x766A_0ABB,
	0x81C2_C92E,
	0x9272_2C85,
	0xA2BF_E8A1,
	0xA81A_664B,
	0xC24B_8B70,
	0xC76C_51A3,
	0xD192_E819,
	0xD699_0624,
	0xF40E_3585,
	0x106A_A070,
	0x19A4_C116,
	0x1E37_6C08,
	0x2748_774C,
	0x34B0_BCB5,
	0x391C_0CB3,
	0x4ED8_AA4A,
	0x5B9C_CA4F,
	0x682E_6FF3,
	0x748F_82EE,
	0x78A5_636F,
	0x84C8_7814,
	0x8CC7_0208,
	0x90BE_FFFA,
	0xA450_6CEB,
	0xBEF9_A3F7,
	0xC671_78F2
]

# the state after one block of 64 bytes at `at`
fn sha256Block(h u32[8], d u8[], at i64) u32[8]:
	w u32[64] = zeros(64)
	for i in 0..16:
		w[i] = d.u32be(at + 4 * i)
	for i in 16..64:
		s0 = w[i - 15].rotateRight(7) ^ w[i - 15].rotateRight(18) ^ (w[i - 15] >> 3)
		s1 = w[i - 2].rotateRight(17) ^ w[i - 2].rotateRight(19) ^ (w[i - 2] >> 10)
		w[i] = w[i - 16] + s0 + w[i - 7] + s1
	v = h
	for i in 0..64:
		e = v[4]
		a = v[0]
		t1 = v[7] + (e.rotateRight(6) ^ e.rotateRight(11) ^ e.rotateRight(25)) +
			((e & v[5]) ^ (~e & v[6])) + sha256Keys[i] + w[i]
		t2 = (a.rotateRight(2) ^ a.rotateRight(13) ^ a.rotateRight(22)) +
			((a & v[1]) ^ (a & v[2]) ^ (v[1] & v[2]))
		v = [t1 + t2, a, v[1], v[2], v[3] + t1, e, v[5], v[6]]
	[
		h[0] + v[0],
		h[1] + v[1],
		h[2] + v[2],
		h[3] + v[3],
		h[4] + v[4],
		h[5] + v[5],
		h[6] + v[6],
		h[7] + v[7]
	]

# The CRC-32 (ISO 3309: PNG's, zip's) of the bytes
pub fn crc32(d u8[]) u32:
	crcOver(0xFFFF_FFFF, d) ^ 0xFFFF_FFFF

# The 32-bit FNV-1a of the bytes carried on from `h` (the offset basis 0x811C_9DC5 at the start):
# a quick hash for telling whether two runs made the same bytes, as emulators' scripts compute it
pub fn fnv1a(d u8[], h u32 = 0x811C_9DC5) u32:
	r = h
	for b in d:
		r = (r ^ b) * 0x0100_0193
	r

# the running CRC-32 c, 0xFFFF_FFFF at the start, carried over the bytes; the CRC is its last
# value with every bit flipped
pub fn crcOver(c u32, d u8[]) u32:
	r = c
	for b in d:
		r = crcTable[(r ^ b) & 255] ^ (r >> 8)
	r

# the CRC-32 remainder of each byte
crcTable = (0..256).map(n:
	c = u32(n)
	loop 8:
		c = 0xEDB8_8320 ^ (c >> 1) if c & 1 == 1 else c >> 1
	c
)

test "sha1 of the standard's messages":
	expect sha1("abc".bytes().copy()) == "a9993e364706816aba3e25717850c26c9cd0d89d"
	expect sha1([]) == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
	expect sha1("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".bytes().copy()) ==
		"84983e441c3bd26ebaae4aa1f95129e5e54670f1"
	expect sha1("a".repeat(1000).bytes().copy()) == "291e9a6c66994949b57ba5e650361e98fc36b1ba"

test "sha256 of the standard's messages" for (text, want) in [
	("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
	("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
	(
		"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
		"248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
	)
]:
	expect sha256(text.bytes().copy()).map("{it:02x}").join("") == want

test "crc32 of the standard's message":
	expect crc32("123456789".bytes().copy()) == 0xcbf4_3926

test "fnv1a of the reference strings":
	expect fnv1a("".bytes().copy()) == 0x811c_9dc5
	expect fnv1a("a".bytes().copy()) == 0xe40c_292c
	expect fnv1a("foobar".bytes().copy()) == 0xbf9c_f968
