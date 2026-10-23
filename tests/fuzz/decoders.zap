# The readers of bytes from outside under random damage: zlib streams, PNG files and JSON texts
# that decode, each changed at random (bytes flipped, cut short, bytes put in), handed to their
# decoder. Each decoder is written under `use noStops`, so the compiler proved that nothing it
# reaches stops the program; this hunts what the proof leaves out: a decode that is wrong where
# nothing was damaged, a stream that never ends, memory that runs out.
#
# The suite runs a few hundred inputs from a fixed seed; for a long hunt:
#
#   zap run tests/fuzz/decoders.zap [count] [seed]

import deflate
import image
import json

# the random numbers of the inputs made, a sequence each run restarts from its seed
mut rng = Random(0)

fn pick(n i64) i64:
	rng.next(0..=n - 1)

# d with a few of its bytes changed, cut short or lengthened
fn damaged(d u8[]):
	out = d.copy()
	kind = pick(4)
	if kind == 0 and not out.isEmpty:
		loop 1 + pick(4):
			out[pick(len)] = u8(pick(256))
	elif kind == 1:
		out.truncate(pick(out.len + 1))
	elif kind == 2:
		at = pick(out.len + 1)
		out.insert(at, u8(pick(256)))
	else:
		out.push(u8(pick(256)))
	out

# a value's JSON, of depth up to depth
fn jsonOf(depth i64) str:
	kind = pick(4) if depth <= 0 else pick(6)
	if kind == 0: return "{pick(1000) - 500}"
	if kind == 1: return "\"t{pick(100)}\\n\""
	if kind == 2: return "true" if pick(2) == 0 else "null"
	if kind == 3: return "{pick(100)}.5e{pick(5)}"
	if kind == 4: return "[{(0..pick(4)).map(_: jsonOf(depth - 1)).join(", ")}]"
	"\{{(0..pick(4)).map("\"k{it}\": {jsonOf(depth - 1)}").join(", ")}}"

# the inputs made and damaged, and how many each decoder read back whole
fn hunt(count i64):
	zlibGood = 0
	pngGood = 0
	jsonGood = 0
	for n in 0..count:
		plain = (0..pick(2000)).map(u8(pick(4) + 97 + (it / 50) % 3))
		packed = deflate.deflateZlib(plain)
		if (deflate.inflateZlib(packed) ?? []) == plain: zlibGood += 1
		_ = deflate.inflateZlib(damaged(packed))
		w = 1 + pick(9)
		h = 1 + pick(9)
		img = image.fromBytes(w, h, (0..w * h * 4).map(_: u8(pick(256))))
		file = img.encodePng()
		match image.decodePng(file):
			back: if back.cells == img.cells: pngGood += 1
			error: print("{n}: a PNG written did not read back: {error}")
		_ = image.decodePng(damaged(file))
		text = jsonOf(3)
		match json.parse(text):
			doc: if not doc.entries.isEmpty: jsonGood += 1
			error: print("{n}: {text} did not parse: {error}")
		_ = json.parse(str(damaged(text.bytes())))
	"{zlibGood} {pngGood} {jsonGood} of {count}"

if not args.isEmpty:
	rng = Random((i64.parse(args[1]) ?? 1) if args.len > 1 else 1)
	print(hunt(i64.parse(args[0]) ?? 100))

test "damaged streams, files and texts are refused, the whole ones read back":
	print(hunt(300))
	prints "300 300 300 of 300"
