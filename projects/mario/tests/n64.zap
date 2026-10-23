# The cartridge's pieces that need no cartridge: MIO0 blocks made by hand.

import n64

test "a MIO0 block: literal bytes, then a copy of what came before":
	# "abc" taken as literals (flags 1 1 1), then 6 bytes copied from 3 back (flag 0, word 0x3002)
	block = [
		u8(0x4D),
		0x49,
		0x4F,
		0x30,
		0,
		0,
		0,
		9,
		0,
		0,
		0,
		20,
		0,
		0,
		0,
		22,
		0xE0,
		0,
		0,
		0,
		0x30,
		0x02,
		'a',
		'b',
		'c'
	]
	match n64.decodeMio0(block):
		made:
			bytes = made
			print(str(move bytes))
		error: print(error)
	match n64.decodeMio0(zeros(16)):
		made: print(made.len)
		error: print(error)
	prints """
	    abcabcabc
	    not a MIO0 block
	    """
