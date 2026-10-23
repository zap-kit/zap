# The 68000's decoder: words of known instructions and their text.

import m68k

# the instruction of the hex words at the offset
fn decoded(words str, at i64):
	code = fill(at, u8(0))
	for i in 0..words.len / 2:
		code.push(u8(words[2 * i].hexValue() * 16 + words[2 * i + 1].hexValue()))
	inst = m68k.decode(code, at)
	"{inst.text()} ({inst.length})"

cases = [
	("4efa25fe", 4, "jmp $2604(pc) (4)"),
	("2e4d", 0, "movea.l a5,a7 (2)"),
	("223c000000ff", 0, "move.l #$ff,d1 (6)"),
	("7000", 0, "moveq.l #$0,d0 (2)"),
	("70ff", 0, "moveq.l #$ffffffff,d0 (2)"),
	("6000084c", 18, "bra $860 (4)"),
	("101d", 0, "move.b (a5)+,d0 (2)"),
	("323b0018", 38, "move.w $40(pc,d0.w),d1 (4)"),
	("4ebb1014", 42, "jsr $40(pc,d1.w) (4)"),
	("4a1f", 0, "tst.b (a7)+ (2)"),
	("6b02", 52, "bmi $38 (2)"),
	("d4c2", 0, "adda.w d2,a2 (2)"),
	("4ed4", 0, "jmp (a4) (2)"),
	("48e71f3e", 0, "movem.l d3/d4/d5/d6/d7/a2/a3/a4/a5/a6,-(a7) (4)"),
	("4cdf7cf8", 0, "movem.l (a7)+,d3/d4/d5/d6/d7/a2/a3/a4/a5/a6 (4)"),
	("e548", 0, "lsl.w #$2,d0 (2)"),
	("57c8fff6", 0x2778, "dbeq d0,$2770 (4)"),
	("0c9050434f44", 0, "cmpi.l #$50434f44,(a0) (6)"),
	("08c3001e", 0, "bset #$1e,d3 (4)"),
	("a9f0", 0, "aline $a9f0 (2)"),
	("3f3c0001", 0, "move.w #$1,-(a7) (4)"),
	("41fa0856", 0x2604, "lea $2e5c(pc),a0 (4)"),
	("287802aa", 0, "movea.l $2aa.w,a4 (4)"),
	("207900000a50", 0, "movea.l $a50.l,a0 (6)"),
	("317900000a5afffe", 0, "move.w $a5a.l,-$2(a0) (8)"),
	("2c300000", 0, "move.l $0(a0,d0.w),d6 (4)"),
	("4e56fff0", 0, "link.w a6,#$fff0 (4)"),
	("4e5e", 0, "unlk.l a6 (2)"),
	("4e75", 0, "rts (2)"),
	("c340", 0, "exg.l d1,d0 (2)"),
	("d181", 0, "addx.l d1,d0 (2)"),
	("e2a8", 0, "lsr.l d1,d0 (2)"),
	("e0d0", 0, "asr.w (a0) (2)"),
	("4840", 0, "swap.w d0 (2)"),
	("48c0", 0, "ext.l d0 (2)"),
	("80fc000a", 0, "divu.w #$a,d0 (4)"),
	("c1fc0003", 0, "muls.w #$3,d0 (4)"),
	("51c8fffe", 0, "dbf d0,$0 (4)"),
	("56c0", 0, "sne d0 (2)"),
	("4878000a", 0, "pea $a.w (4)"),
	("b3c8", 0, "cmpa.l a0,a1 (2)"),
	("b308", 0, "cmpm.b (a0)+,(a1)+ (2)"),
	("0108fffe", 0, "movep.w -$2(a0),d0 (4)"),
	("46fc2700", 0, "move.w #$2700,sr (4)"),
	("4afc", 0, "illegal (2)"),
	("4848", 0, "dc.w $4848 (2)"),
	("ffff", 0, "fline $ffff (2)")
]

test "known instructions decode to their text" for (words, at, expected) in cases:
	expect decoded(words, at) == expected

test "every word decodes to a row or to none, within the table":
	decoded = 0
	for w in 0..0x10000:
		r = m68k.rowOf(w)
		if r >= 0: decoded += 1
	expect decoded > 50_000 and decoded < 65_536
