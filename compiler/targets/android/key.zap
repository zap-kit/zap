# The key an app is signed with: RSA of 2048 bits, made once per machine (the android-debug-key
# of fs.cacheDir, outside any checkout, so every build of an app on the machine signs alike and
# installs over the last), its self-signed certificate made from it the same every time (Android
# compares an update's certificate with the installed app's byte for byte). A debug key: its
# primes come from the clock's random sequence, not a secure source.

import digest
import fs
import math

type AppKey:
	n math.BigInt   # the modulus
	d math.BigInt   # the private exponent

# the public exponent
keyExponent = 65_537

# the bytes of a signature, of the modulus
keyBytes = 256

# the machine's key, made the first time
fn appKey():
	path = "{fs.cacheDir("zap")}/android-debug-key"
	lines = (fs.readFile(path) ?? "").lines()
	if lines.len >= 2:
		if math.parse(lines[0]) is n and math.parse(lines[1]) is d: return AppKey(n, d)
	key = makeKey()
	_ = fs.createDir(fs.cacheDir("zap"))
	_ = fs.writeFile(path, "{key.n.decimal()}\n{key.d.decimal()}\n")
	key

fn makeKey():
	rng = Random(clockMs() * 1_000_003 + i64(clockSeconds() * 1e9))
	e = math.BigInt.of(keyExponent)
	small = (3..2000).filter(n: (2..n).all(n % it != 0 or it * it > n))   # a candidate's factors looked for first
	loop:
		p = rng.prime(small, 4 * keyBytes)
		q = rng.prime(small, 4 * keyBytes)
		phi = p.minus(math.BigInt.of(1)).times(q.minus(math.BigInt.of(1)))
		if e.inverseMod(phi) is d:
			n = p.times(q)
			if n.bitLength() == 8 * keyBytes: return AppKey(n, d)

# a prime of the bits given, its two top bits set (so two make a modulus of twice the bits)
fn prime(mut rng Random, small i64[], bits i64):
	loop:
		limbs = rng.randomLimbs(bits / 64)
		limbs[len - 1] |= 3 << 62
		limbs[0] |= 1
		candidate = math.BigInt(limbs = move limbs)
		if not small.any(candidate.rem(math.BigInt.of(it)).isZero()) and
			candidate.isProbablyPrime(rng):
			return candidate

fn randomLimbs(mut rng Random, n i64):
	out = []
	loop n:
		out.push(rng.nextBits())
	out

# Miller-Rabin's answer for an odd n, after 24 random witnesses
fn isProbablyPrime(n math.BigInt, mut rng Random):
	one = math.BigInt.of(1)
	less = n.minus(one)
	shifts = 0
	while (less.limbs[shifts / 64] >> (shifts % 64)) & 1 == 0:
		shifts += 1
	odd = less.shiftRight(shifts)
	loop 24:
		x = math.BigInt(limbs = rng.randomLimbs(n.limbs.len))
			.mod(less.minus(one))
			.plus(math.BigInt.of(2))
			.powMod(odd, n)
		if x == one or x == less: continue
		passed = false
		loop shifts - 1:
			x = x.times(x).rem(n)
			if x == less:
				passed = true
				break
		if not passed: return false
	true

# the DER of SHA-256's algorithm, before the digest, in PKCS #1's DigestInfo
digestInfoHead = [
	0x30,
	0x31,
	0x30,
	0x0D,
	0x06,
	0x09,
	0x60,
	0x86,
	0x48,
	0x01,
	0x65,
	0x03,
	0x04,
	0x02,
	0x01,
	0x05,
	0x00,
	0x04,
	0x20
]

# RSASSA-PKCS1-v1_5 of the message's SHA-256
fn sign(key AppKey, message u8[]):
	block u8[] = [0, 1]
	block.extend(fill(keyBytes - 3 - digestInfoHead.len - 32, 0xFF))
	block.push(0)
	block.extend(digestInfoHead.map(u8(it)))
	block.extend(digest.sha256(message))
	math.ofBytes(block).powMod(key.d, key.n).bytes(keyBytes)

# ---------- DER ----------

# a value of the tag: its length (short or long form), then the content
fn der(tag i64, content u8[]):
	out u8[] = [u8(tag)]
	if content.len < 128:
		out.push(u8(content.len))
	else:
		size = math.BigInt.of(content.len)
		lengthBytes = (size.bitLength() + 7) / 8
		out.push(u8(0x80 + lengthBytes))
		out.extend(size.bytes(lengthBytes))
	out.extend(content)
	out

fn derSequence(parts u8[,]):
	content = []
	for part in parts:
		content.extend(part)
	der(0x30, content)

# a non-negative integer: its bytes, a zero first when the top bit is set
fn derInteger(v math.BigInt):
	size = v.bitLength() / 8 + 1
	der(0x02, v.bytes(size))

# sha256WithRSAEncryption (1.2.840.113549.1.1.11) and rsaEncryption (.1), each with its NULL
fn algorithm(last i64):
	derSequence(
		[der(0x06, [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, u8(last)]), der(0x05, [])]
	)

# the key's SubjectPublicKeyInfo
fn publicKeyInfo(key AppKey):
	numbers = derSequence([key.n.derInteger(), math.BigInt.of(keyExponent).derInteger()])
	bits u8[] = [0]
	bits.extend(numbers)
	derSequence([algorithm(1), der(0x03, bits)])

# the X.509 name CN=Zap Debug
fn debugName():
	common = derSequence([der(0x06, [0x55, 0x04, 0x03]), der(0x13, "Zap Debug".bytes().copy())])
	derSequence([der(0x31, common)])

# The key's certificate, signed by itself: version 3, serial 1, valid 2026 to 2049 (UTCTime's
# last year)
fn certificate(key AppKey):
	validity = derSequence(
		[der(0x17, "260101000000Z".bytes().copy()), der(0x17, "491231235959Z".bytes().copy())]
	)
	body = derSequence(
		[
			der(0xA0, math.BigInt.of(2).derInteger()),
			math.BigInt.of(1).derInteger(),
			algorithm(11),
			debugName(),
			validity,
			debugName(),
			key.publicKeyInfo()
		]
	)
	signature u8[] = [0]
	signature.extend(key.sign(body))
	derSequence([body, algorithm(11), der(0x03, signature)])
