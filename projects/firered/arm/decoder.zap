# Both tables, read by the one decoder.

pub type Decoder:
	thumb Row[]
	arm Row[]
	assembler Assembler

	fn lowered(text str, at i64, isThumb bool, size i64):
		assembler.assemble(text, at, isThumb, size)

	# The Thumb instruction of the halfword `first` (and `second`, the one after it, for a bl).
	pub fn decodeThumb(first u16, second u16, at i64) Instr:
		pair = (u32(first) << 16) | second
		for r in thumb:
			word = pair if r.wide else first
			if (word ^ r.value) & r.mask == 0:
				return self.lowered(r.expand(word, at, true), at, true, 4 if r.wide else 2)
		Instr(at, size = 2, thumb = true, cond = always, op = .Undefined)

	pub fn decodeArm(word u32, at i64) Instr:
		for r in arm:
			if (word ^ r.value) & r.mask == 0:
				return self.lowered(r.expand(word, at, false), at, false, 4)
		Instr(at, size = 4, thumb = false, cond = always, op = .Undefined)

pub fn newDecoder() Decoder:
	Decoder(thumb = thumbRows(), arm = armRows(), assembler = newAssembler())
