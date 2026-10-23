# The cartridge checked before anything is read from it: its header (the title, the game's
# code, the fixed byte and the complement that sums the header) and the SHA-1 of the whole dump.

import digest

pub expectedSha1 = "41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"

# what is wrong with the dump, or none for Pokemon FireRed (USA, revision 0)
pub fn cartridgeProblem(rom u8[]) str?:
	if rom.len != 0x100_0000: return "it is {rom.len} bytes, not 16 MB"
	title = str(rom[0xA0..0xAC])
	code = str(rom[0xAC..0xB0])
	if title != "POKEMON FIRE" or code != "BPRE":
		return "its header names '{title}' ({code}), not POKEMON FIRE (BPRE)"
	if rom[0xB2] != 0x96: return "its header's fixed byte is 0x{rom[0xB2]:X}, not 0x96"
	sum = 0
	for b in rom[0xA0..0xBD]:
		sum += b
	if u8.wrap(-(sum + 0x19)) != rom[0xBD]: return "its header's complement does not match"
	if rom[0xBC] != 0: return "it is revision {rom[0xBC]}, not 0"
	sha = digest.sha1(rom)
	if sha != expectedSha1: return "its SHA-1 is {sha}, not {expectedSha1}"
	none
