# The floppy drives and the .Sony driver (reference number -5) that reads them. Drive n holds the
# n-th prepared volume as its head reads it: the bits of each track of the user's capture
# (projects/excel1/assets/<volume>.tracks), every sector as it lies on the disk, a damaged or
# non-standard one included. The disk turns under the head as the drive reads it and with the
# clock (Ticks), and the disk controller (the IWM) gathers its bits into nibbles: a byte is done
# when its top bit is in, the zeros before it skipped. Where a track holds no flux transition for
# more than three cells the drive's amplifier raises its gain until it reads noise, so those
# cells read random bits, a different nibble on each turn, as the real drive reads them.
#
# The driver works as the ROM's does: it moves the head to the block's track, reads address
# fields (D5 AA 96, the track, sector, side, format and checksum, then the bit-slip marks DE AA)
# until the block's sector comes, then reads the data field that follows through the routine the
# low-memory vector JRdData names. A program that points JRdData at its own code (Excel's
# copy-protection check reads the raw nibbles after a sector's address field) has that code run
# against the IWM's registers as the Mac's would be: A4 the IWM's data register, A5 the VIA's
# register A (bit 7 set: the serial chip waits on nothing), A6 the serial chip's data register.

import cpu
import disk
import fs

sonyRefNum = -5
pub jRdAddrAt u32 = 0x22A
pub jRdDataAt u32 = 0x22E
pub tagDataAt u32 = 0x2FA
pub rdAddrRom u32 = romBase + 0x1_E000   # the ROM's routines the vectors start at
pub rdDataRom u32 = romBase + 0x1_E004
iwmBase = 0xDF_E1FF
iwmEnd = 0xE0_0000
pub viaBufA u32 = 0xEF_E1FE
pub sccAData u32 = 0x9F_FFFE
bitsPerTick = 8160   # cells of 2.04 us in a sixtieth of a second

offLinErr = -65
noAdrMkErr = -67
badCksmErr = -69
badBtSlpErr = -70
noDtaMkErr = -71
badDCksum = -72
sectNFErr = -81
nsDrvErr = -56
wPrErr = -44
controlErr = -17

pub type Drive:
	tracks disk.Track[]
	track i64   # under the head
	at i64   # the cell under the head
	zeros i64   # cells read in a row with no transition

pub mut drives {i64: Drive} = {}
mut tagBuffer u32 = 0
mut lastTicks u32 = 0
mut noise = 1   # the amplifier's noise: a linear congruential sequence
# the IWM's state lines (0-7 the drive's phases, 8 the motor, 10 the external drive, 12 Q6, 14
# Q7), its shift register and the drive it reads
mut lines = fill(16, false)
mut shift = 0
mut selected = 1

# whether drive n holds a disk, its tracks read in when it is first used
fn hasDisk(n i64):
	if n in drives: return true
	v = volumes()
	bytes = fs.readBytes("{assetsDir}/{v[n - 1]}.tracks") ?? return false
	drives[n] = Drive(tracks = disk.readTracks(bytes), track = 0, at = 0, zeros = 0)
	true

pub fn initSony():
	cpu.write32(jRdAddrAt, rdAddrRom)
	cpu.write32(jRdDataAt, rdDataRom)

# the disk under drive n turned on by the clock's ticks since it last read
fn turnWithClock(n i64):
	now = cpu.read32(ticksAt)
	elapsed = i64(now - lastTicks) if now >= lastTicks else 0
	lastTicks = now
	count = drives[n].tracks[drives[n].track].count
	drives[n].at = (drives[n].at + elapsed * bitsPerTick) % count

fn randomBit():
	noise = (noise * 1_103_515_245 + 12_345) & 0x7FFF_FFFF
	1 if noise >> 16 & 1023 < 307 else 0

# the next cell under drive n's head, read by the drive's amplifier
fn nextBit(n i64):
	t = drives[n].tracks[drives[n].track]
	at = drives[n].at
	bit = i64(t.bits[at >> 3]) >> (7 - (at & 7)) & 1
	drives[n].at = (at + 1) % t.count
	if bit == 1:
		drives[n].zeros = 0
		return 1
	drives[n].zeros += 1
	if drives[n].zeros > 3: return randomBit()
	0

# the next nibble the IWM gathers from drive n
fn nextNibble(n i64):
	while shift & 0x80 == 0:
		shift = (shift << 1 | nextBit(n)) & 0xFF
	nibble = shift
	shift = 0
	nibble

# moves drive n's head to the track, the disk's turn kept
fn seek(n i64, track i64):
	old = drives[n].tracks[drives[n].track].count
	new = drives[n].tracks[track].count
	drives[n].at = drives[n].at * new / old
	drives[n].track = track

# the track and sector of a block of a 400 KB disk
fn placeOf(block i64) (i64, i64)?:
	b = block
	for t in 0..80:
		count = disk.sectorsOfTrack(t)
		if b < count: return (t, b)
		b -= count
	none

# the six-bit values of the next count nibbles under drive n's head, -1 for a nibble no code writes
fn nibbleValues(n i64, count i64, table i64[]):
	out = []
	loop count:
		out.push(table[nextNibble(n)])
	out

# the next address field of the track under drive n's head, its values (track, sector, side,
# format) or the error that stops reading it
fn readAddress(n i64) i64[] ? i64:
	table = disk.gcrValues()
	seen = 0
	while true:
		seen += 1
		if seen > 2 * 6400: return noAdrMkErr
		if nextNibble(n) != 0xD5 or nextNibble(n) != 0xAA or nextNibble(n) != 0x96: continue
		v = nibbleValues(n, 5, table)
		if v.any(it < 0) or v[0] ^ v[1] ^ v[2] ^ v[3] != v[4]: return badCksmErr
		if nextNibble(n) != 0xDE or nextNibble(n) != 0xAA: return badBtSlpErr
		return [v[0] | (v[2] & 1) << 6, v[1], v[2] >> 5 & 1, v[3]]
	noAdrMkErr

# the ROM's RdData: the data field that follows the address field just read, its 512 bytes to
# `buffer` and its 12 tag bytes to the tag buffer (and TagData)
fn readData(n i64, buffer u32):
	table = disk.gcrValues()
	seen = 0
	while true:
		seen += 1
		if seen > 48: return noDtaMkErr
		if nextNibble(n) != 0xD5 or nextNibble(n) != 0xAA or nextNibble(n) != 0xAD: continue
		nextNibble(n)
		v = nibbleValues(n, disk.dataNibbles + 4, table)
		if v.any(it < 0): return badDCksum
		bytes = disk.decodeDataField(v) ?? return badDCksum
		if nextNibble(n) != 0xDE or nextNibble(n) != 0xAA: return badBtSlpErr
		for i in 0..disk.tagBytes:
			cpu.write8(tagDataAt + 2 + u32(i), bytes[i])
			if tagBuffer != 0: cpu.write8(tagBuffer + u32(i), bytes[i])
		moveIn(buffer, bytes[disk.tagBytes..].copy())
		return 0
	noDtaMkErr

# the routine JRdData names run on drive n: the ROM's, or the program's own code, called as the
# ROM calls it, the registers it does not return in kept
fn runRdData(n i64, buffer u32):
	at = cpu.read32(jRdDataAt)
	if at == rdDataRom: return readData(n, buffer)
	saved = (0..17).map(cpu.register(it))
	selected = n
	for i in 0..16:
		lines[i] = false
	lines[8] = true
	cpu.a0 = buffer
	cpu.a4 = u32(iwmBase + 12 * 0x200)
	cpu.a5 = viaBufA
	cpu.a6 = sccAData
	callCode(at)
	e = i64(i16.wrap(i64(cpu.d0 & 0xFFFF)))
	for i in 0..17:
		cpu.setRegister(i, saved[i])
	e

# reads the block on drive n into buffer: 0 or the error the drive gave
fn readBlock(n i64, block i64, buffer u32):
	track, sector = placeOf(block) ?? return sectNFErr
	if cpu.read32(jRdAddrAt) != rdAddrRom:
		cpu.stop("JRdAddr points at the program's own code, which the drive does not model")
	seek(n, track)
	e = 0
	loop 3:
		tries = 0
		while true:
			tries += 1
			if tries > 2 * disk.sectorsOfTrack(track): return sectNFErr
			address = readAddress(n) ?? return error
			if address[0] == track and address[1] == sector and address[2] == 0: break
		e = runRdData(n, buffer)
		if e == 0: return 0
	e

# a Read of the .Sony driver: whole blocks from the block ioPosOffset names
fn sonyRead(pb u32):
	n = word(pb + 22)
	if n < 1 or n > volumes().len: return nsDrvErr
	if not hasDisk(n): return offLinErr
	turnWithClock(n)
	buffer = cpu.read32(pb + 32)
	count = i64(cpu.read32(pb + 36))
	first = cpu.read32(pb + 46) / disk.sectorBytes
	done = 0
	while done < count:
		e = readBlock(n, first + done / disk.sectorBytes, buffer + u32(done))
		if traceTraps: eprint("  drive {n} block {first + done / disk.sectorBytes}: {e}")
		if e != 0:
			cpu.write32(pb + 40, u32(done))
			return e
		done += disk.sectorBytes
	cpu.write32(pb + 40, u32(done))
	cpu.write32(pb + 46, u32((first * disk.sectorBytes) + done))
	0

fn sonyControl(pb u32):
	match word(pb + 26):
		1, 9: 0
		8:
			tagBuffer = cpu.read32(pb + 28)
			0
		_: controlErr

# A call of a device driver (trap index 2-6: Read, Write, Control, Status, KillIO): the .Sony
# driver's result, the drive's error for the others' (no other driver is there).
pub fn driverCall(index i64, pb u32) i64:
	if word(pb + 24) != sonyRefNum: return ioErr
	e = match index:
		2: sonyRead(pb)
		3: wPrErr
		4: sonyControl(pb)
		_: controlErr
	cpu.write16(dskErrAt, u32.wrap(e))
	e

# an access of the IWM's address `at` (a read or a write): its state line set or cleared
pub fn iwmSwitch(at i64):
	reg = (at - iwmBase) >> 9 & 15
	lines[reg & 14] = reg & 1 == 1

# a read of the IWM at `at`: its line switched, then the data register (Q6 and Q7 clear, the motor
# on: the next nibble), the status (Q6 set) or the handshake (Q7 set)
pub fn iwmRead(at i64) u32:
	iwmSwitch(at)
	if lines[8] and not lines[12] and not lines[14]: return u32(nextNibble(selected))
	if lines[12] and not lines[14]: return 0x20 if lines[8] else 0
	if lines[14] and not lines[12]: return 0x80
	0

pub fn isIwm(at i64) bool:
	at >= 0xDF_E000 and at < iwmEnd
