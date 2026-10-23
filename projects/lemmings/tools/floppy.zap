# A 1.44 MB floppy image (FAT12) holding a dir's files, for the emulator the oracle runs the DOS
# game in: a boot sector, two FATs, the root dir and one cluster a sector, as DOS formats one.

import fs

sectorBytes = 512
totalSectors = 2880
fatSectors = 9
rootEntries = 224
rootSectors = rootEntries * 32 / sectorBytes
firstDataSector = 1 + 2 * fatSectors + rootSectors

fn bootSector():
	b u8[] = zeros(sectorBytes)
	for i, c in [0xEB, 0x3C, 0x90]:
		b[i] = u8(c)
	for i, c in "MSDOS5.0".bytes():
		b[3 + i] = c
	b.setU16le(11, u16(sectorBytes))
	b[13] = 1   # sectors a cluster
	b.setU16le(14, 1)   # reserved sectors
	b[16] = 2   # FATs
	b.setU16le(17, u16(rootEntries))
	b.setU16le(19, u16(totalSectors))
	b[21] = 0xF0   # media: a 3.5" high density disk
	b.setU16le(22, u16(fatSectors))
	b.setU16le(24, 18)   # sectors a track
	b.setU16le(26, 2)   # heads
	b[38] = 0x29
	for i, c in "LEMMINGS   FAT12   ".bytes():
		b[43 + i] = c
	b[510] = 0x55
	b[511] = 0xAA
	b

fn setFatEntry(mut fat u8[], n i64, v i64):
	at = n * 3 / 2
	if n % 2 == 0:
		fat[at] = v & 0xFF
		fat[at + 1] = i64(fat[at + 1]) & 0xF0 | v >> 8 & 0x0F
	else:
		fat[at] = i64(fat[at]) & 0x0F | (v & 0x0F) << 4
		fat[at + 1] = v >> 4 & 0xFF

# "lemvga.com" as a dir entry's 11 bytes ("LEMVGA  COM"); none when it is no 8.3 name
fn shortName(name str) u8[]?:
	parts = name.upper().split(".")
	if parts.len > 2 or parts[0].isEmpty or parts[0].len > 8: return none
	ext = parts[1] if parts.len == 2 else ""
	if ext.len > 3 or " " in name: return none
	out u8[] = fill(11, ' ')
	for i, c in parts[0].bytes():
		out[i] = c
	for i, c in ext.bytes():
		out[8 + i] = c
	out

# the image of every 8.3-named file of dir (others are left out)
pub fn imageOf(dir str) u8[]:
	img u8[] = zeros(totalSectors * sectorBytes)
	boot = bootSector()
	for i, c in boot:
		img[i] = c
	fat u8[] = zeros(fatSectors * sectorBytes)
	setFatEntry(fat, 0, 0xFF0)
	setFatEntry(fat, 1, 0xFFF)
	names = (fs.list(dir) ?? fail("cannot list {dir}: {error}")).sorted()
	entry = 0
	cluster = 2
	for name in names:
		short = shortName(name) ?? continue
		bytes = fs.readBytes("{dir}/{name}") ?? continue
		if entry >= rootEntries: fail("{dir} has more than {rootEntries} files")
		clusters = (bytes.len + sectorBytes - 1) / sectorBytes
		first = cluster if clusters > 0 else 0
		for k in 0..clusters:
			setFatEntry(fat, cluster + k, 0xFFF if k == clusters - 1 else cluster + k + 1)
			at = (firstDataSector + cluster + k - 2) * sectorBytes
			for j in 0..(bytes.len - k * sectorBytes).min(sectorBytes):
				img[at + j] = bytes[k * sectorBytes + j]
		e = (1 + 2 * fatSectors) * sectorBytes + entry * 32
		for i, c in short:
			img[e + i] = c
		img[e + 11] = 0x20   # archive
		img.setU16le(e + 24, u16((1991 - 1980) << 9 | 2 << 5 | 14))   # the game's release date
		img.setU16le(e + 26, u16(first))
		img.setU32le(e + 28, u32(bytes.len))
		cluster += clusters
		entry += 1
	if firstDataSector + cluster - 2 > totalSectors: fail("{dir} does not fit on a floppy")
	for copy in 0..2:
		at = (1 + copy * fatSectors) * sectorBytes
		for i, c in fat:
			img[at + i] = c
	img

test "FAT12 entries pack two to three bytes":
	fat u8[] = zeros(6)
	setFatEntry(fat, 0, 0xFF0)
	setFatEntry(fat, 1, 0xFFF)
	setFatEntry(fat, 2, 0x003)
	setFatEntry(fat, 3, 0xFFF)
	expect fat == [0xF0, 0xFF, 0xFF, 0x03, 0xF0, 0xFF]
	short = shortName("lemvga.com") ?? fail("no short name")
	expect short == "LEMVGA  COM".bytes()
	expect shortName("Recalbox Ready.txt") == none
