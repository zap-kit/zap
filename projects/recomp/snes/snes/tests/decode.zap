# The decoder against encodings whose assembly is known, and every opcode in every width read back
# by the assembler to its bytes.

import recomp.snes.snes

decoder = snes.newDecoder()

fn textOf(bytes i64[], m bool, x bool):
	decoder.decode(bytes.map(u8(it)), 0, 0x80_8000, snes.Widths(e = false, m, x)).text()

test "instructions read as their assembly" for (bytes, m, x, text) in [
	([0x18], false, false, "clc"),
	([0xA9, 0x34, 0x12], false, false, "lda #$1234"),
	([0xA9, 0x34, 0x12], true, false, "lda #$34"),
	([0xA2, 0x34, 0x12], true, true, "ldx #$34"),
	([0xC2, 0x30], true, true, "rep #$30"),
	([0xB1, 0x10], false, false, "lda ($10),y"),
	([0xB7, 0x10], false, false, "lda [$10],y"),
	([0x93, 0x03], false, false, "sta ($03,s),y"),
	([0x9F, 0x10, 0x00, 0x7E], false, false, "sta $7E0010,x"),
	([0x7C, 0x00, 0x90], false, false, "jmp ($9000,x)"),
	([0xDC, 0x7A, 0x00], false, false, "jml [$007A]"),
	([0xD0, 0xFE], false, false, "bne $808000"),
	([0x80, 0x02], false, false, "bra $808004"),
	([0x82, 0xFD, 0xFF], false, false, "brl $808000"),
	([0x54, 0x7F, 0x7E], false, false, "mvn $7E,$7F"),
	([0x0A], false, false, "asl a"),
	([0x4C, 0xD8, 0xA8], false, false, "jmp $A8D8")
]:
	expect textOf(bytes, m, x) == text

test "every opcode in every width assembles back to its bytes":
	wrong = []
	for opcode in 0..256:
		for (m, x) in [(false, false), (true, false), (false, true), (true, true)]:
			bytes u8[] = [opcode, 0x9A, 0x8B, 0x7C]
			i = decoder.decode(bytes, 0, 0xBF_FFF0, snes.Widths(e = false, m, x))
			again = decoder.assembler.assemble(i.text(), i.at)
			if again.bytes() != bytes[..i.size]: wrong.push(i.text())
	expect wrong.isEmpty
