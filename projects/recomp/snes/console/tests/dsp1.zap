# The DSP-1 driven through its ports as the 65816 drives it: a command byte, its parameters, the
# results read back, each transfer waiting on the status register's RQM. Each transfer's line
# names the master cycle RQM rose at, so a run is the chip's timing as well as its results: the
# rewrite (console/dsp1.zap) is held to the firmware's on both.
#   needs: projects/recomp/snes/rom/dsp1b.rom (the player's dump of the DSP-1B firmware, never committed)

import fs
import recomp.snes.cartridge
import recomp.snes.console

firmware = "projects/recomp/snes/rom/dsp1b.rom"
dataPort u32 = 0x00_6000
statusPort u32 = 0x00_7000
pollStep = 2   # master cycles between two looks at the status
mut lastRead = 0

# the cycle RQM is up at, looked at every pollStep cycles from now
fn waitRqm():
	loop:
		if console.read8(statusPort) & 0x80 != 0: return console.cycles
		console.cycles += pollStep

fn writeWord(v i64):
	at = waitRqm()
	console.write8(dataPort, u8.wrap(v))
	console.write8(dataPort + 1, u8.wrap(v >> 8))
	at

fn readWord():
	at = waitRqm()
	lo = i64(console.read8(dataPort))
	hi = i64(console.read8(dataPort + 1))
	lastRead = lo | (hi << 8)
	(at, lastRead)

# One command run: its byte, its parameters, `results` words read; the byte's line, then one per
# transfer, "w at" for a parameter written, "r at value" for a result read, at the cycle counted
# from the command's.
fn run(command u8, parameters i64[], results i64):
	start = waitRqm()
	console.write8(dataPort, command)
	lines = ["{command:02X}"]
	for p in parameters:
		lines.push("w {writeWord(p) - start}")
	loop results:
		at, v = readWord()
		lines.push("r {at - start} {v:04X}")
	lines

fn powered(rewritten bool):
	console.powerOn()
	cartridge.hirom = true
	if rewritten:
		console.rewriteNec("dsp1b")
	else:
		console.loadNec("dsp1b", firmware)

# a parameter: now and then one at an edge of the range
fn parameter(mut rng Random):
	edges = [0, 1, -1, 0x7FFF, -0x8000, 0x4000]
	edge = rng.nextInt(0, 12)
	v = edges[edge] if edge < edges.len else rng.nextInt(-0x8000, 0x8000)
	v

# Commands at random, as many as `rounds`, with Parameter first so the view is set; Raster for a
# few lines, stopped by a word written into DR; the data ROM's dump now and then, it is long.
fn session(rewritten bool, rounds i64):
	powered(rewritten)
	rng = Random(7)
	lines = []
	loop rounds:
		kind = commands.len if lines.isEmpty else rng.nextInt(0, commands.len + 2)
		if kind == commands.len - 1 and rng.nextInt(0, 10) != 0: kind = commands.len
		lines.push(command(kind, rng).join(" | "))
	lines

# The commands but Parameter and Raster: the bytes that reach the same code, the parameters
# written and the results read.
commands = [
	([0x00, 0x20], 2, 1),
	([0x04, 0x24], 2, 2),
	([0x0C, 0x2C], 3, 2),
	([0x28], 3, 1),
	([0x06, 0x16], 3, 3),
	([0x10, 0x30], 2, 2),
	([0x08], 3, 2),
	([0x18, 0x38], 4, 1),
	([0x14, 0x34], 6, 3),
	([0x1C, 0x3C], 6, 3),
	([0x0E, 0x1E, 0x2E, 0x3E], 2, 2),
	([0x01, 0x05, 0x11, 0x15, 0x21, 0x25, 0x31, 0x35], 4, 0),
	([0x09, 0x0D, 0x19, 0x1D, 0x29, 0x2D, 0x39, 0x3D], 3, 3),
	([0x03, 0x13, 0x23, 0x33], 3, 3),
	([0x0B, 0x1B, 0x2B, 0x3B], 3, 1),
	([0x07, 0x0F], 1, 1),
	([0x27, 0x2F], 1, 1),
	([0x17, 0x1F, 0x37, 0x3F], 1, 0x400)
]

# one command of the kind's: its byte, parameters and results; past the table's, Parameter and Raster
fn command(kind i64, mut rng Random):
	if kind == commands.len: return run(0x02, rng.parameters(7), 4)
	if kind == commands.len + 1:
		raster u8 = 0x1A if rng.nextInt(0, 3) == 0 else 0x0A
		lines = run(raster, [rng.nextInt(-0x80, 0x80)], 4 * rng.nextInt(1, 4))
		console.write8(dataPort, 0x81 if lastRead == 0x80 else 0x80)   # a word other than the last result
		console.write8(dataPort + 1, 0)
		return lines
	bytes, count, results = commands[kind]
	run(u8(bytes[rng.nextInt(0, len)]), rng.parameters(count), results)

fn parameters(mut rng Random, count i64):
	out = []
	loop count:
		out.push(rng.parameter())
	out

test "the rewrite answers as the firmware, to the cycle":
	firmwareLines = session(false, 10_000)
	rewriteLines = session(true, 10_000)
	for i, line in firmwareLines:
		if rewriteLines[i] != line:
			print("{i}: firmware {line}")
			print("{i}: rewrite  {rewriteLines[i]}")
			break
	print("{firmwareLines.len} commands")
	prints "10000 commands"

test "the computed data ROM is the firmware's":
	bytes = fs.readBytes(firmware) ?? fail("cannot read {firmware}: {error}")
	rom = console.dsp1Rom()
	differing = []
	for i, v in rom:
		dumped = bytes[0x1800 + 2 * i] | (u16(bytes[0x1800 + 2 * i + 1]) << 8)
		if dumped != v: differing.push("{i:03X} {v:04X}/{dumped:04X}")
	print("{differing.len} words differ: {differing.join(", ")}")
	prints "0 words differ: "
