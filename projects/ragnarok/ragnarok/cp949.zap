# CP949, the Korean code page the client's file names are written in.

import ragnarok.grf

# The Korean syllables of the paths Ragnarok names itself (sprites, the water's dir), as the
# archives spell them (CP949). Only these are needed; a path with another one is a mistake in
# the caller.
type Cp949Char:
	code i64   # the code point
	bytes i64   # its two bytes

cp949 = [
	Cp949Char(0xC778, 0xC0CE),
	Cp949Char(0xAC04, 0xB0A3),
	Cp949Char(0xC871, 0xC1B7),
	Cp949Char(0xBAB8, 0xB8F6),
	Cp949Char(0xD1B5, 0xC5EB),
	Cp949Char(0xBA38, 0xB8D3),
	Cp949Char(0xB9AC, 0xB8AE),
	Cp949Char(0xB0A8, 0xB3B2),
	Cp949Char(0xC5EC, 0xBFA9),
	Cp949Char(0xBAAC, 0xB8F3),
	Cp949Char(0xC2A4, 0xBDBA),
	Cp949Char(0xD130, 0xC5CD),
	Cp949Char(0xAE30, 0xB1E2),
	Cp949Char(0xC0AC, 0xBBE7),
	Cp949Char(0xD5CC, 0xC7E5),
	Cp949Char(0xC704, 0xC0A7),
	Cp949Char(0xC800, 0xC0FA),
	Cp949Char(0xB4DC, 0xB5E5),
	Cp949Char(0xD504, 0xC7C1),
	Cp949Char(0xD2B8, 0xC6AE),
	Cp949Char(0xAC80, 0xB0CB),
	Cp949Char(0xD65C, 0xC8B0),
	Cp949Char(0xB86F, 0xB7D4),
	Cp949Char(0xD074, 0xC5AC),
	Cp949Char(0xB7FD, 0xB7B4),
	Cp949Char(0xAD11, 0xB1A4),
	Cp949Char(0xC6CC, 0xBFF6),
	Cp949Char(0xCD08, 0xC3CA),
	Cp949Char(0xBCF4, 0xBAB8),
	Cp949Char(0xC790, 0xC0DA)
]

# a path written in UTF-8 as the archives spell it: CP949 bytes
pub fn cp949Path(path str) u8[]:
	out = []
	for c in path.chars():
		code = c.charCode()
		if code < 128:
			out.push(u8(code))
			continue
		bytes = (cp949.find(.code == code) ??
				fail("no CP949 spelling of '{c}' in projects/ragnarok/cp949.zap")).bytes
		out.push(u8(bytes >> 8))
		out.push(u8(bytes & 255))
	out

# a path written in UTF-8 as an archive key: CP949 bytes, backslashes, lower case
pub fn grfPath(path str) str:
	grf.grfKey(cp949Path(path))
