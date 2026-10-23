# The machine started as the BIOS leaves it for the cartridge (mGBA's start without a BIOS): the
# stacks of the modes set, the cartridge's data read from the prepared assets, the save from
# its file. Code the game copies into memory and calls there is its copy's in the cartridge.

import cpu
import fs

pub cartridgePath = "projects/firered/assets/cartridge.bin"
pub saveFile = "projects/firered/save/firered.sav"

mut spans u32[] = []
mut copies {u32: u32} = {}

pub fn start(functionSpans u32[]):
	rom = fs.readBytes(cartridgePath) ??
		fail("no {cartridgePath}: run zap run projects/firered/prepare.zap first ({error})")
	spans = functionSpans.copy()
	cpu.hooks.stop = stop
	cpu.setControl(cpu.modeSupervisor)
	cpu.r13 = 0x0300_7FE0
	cpu.setControl(cpu.modeIrq)
	cpu.r13 = 0x0300_7FA0
	cpu.setControl(cpu.modeSystem)
	cpu.r13 = 0x0300_7F00
	io.setU16le(0x000, 0x80)
	io.setU16le(0x300, 1)
	io.setU16le(0x088, 0x200)
	keysUp = 0x3FF
	if not args.hasFlag("--frames"):
		savePath = saveFile
		_ = fs.createDir(fs.dirOf(saveFile))
		if fs.readBytes(saveFile) is saved and saved.len == flash.len: flash = saved
	openScreen()
	line = 126   # where the BIOS's start leaves the screen (mGBA's start without it too)
	scheduleEvents()

# The function of the cartridge whose code the memory at `at` holds (its key's bit 0 the
# state): the bytes from there compared with each function's, the answer kept; 0 for none.
pub fn romCopyOf(at u32) u32:
	if copies.get(at) is known: return known
	region = at >> 24
	if region != 2 and region != 3: return 0
	fkey = copiedFunction(at) ?? 0
	copies[at] = fkey
	fkey

fn copiedFunction(at u32) u32?:
	start = at & ~u32(1)
	k = 0
	while k < spans.len:
		fkey = spans[k]
		span = spans[k + 1].min(256)
		k += 2
		if fkey & 1 != at & 1 or span == 0: continue
		from = i64((fkey & ~u32(1)) - 0x0800_0000)
		same = true
		i u32 = 0
		while same and i < span:
			same = load8(start + i) == rom[from + i]
			i += 1
		if same: return fkey
	none
