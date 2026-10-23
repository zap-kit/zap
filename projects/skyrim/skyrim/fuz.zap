# FUZ, the voices' container (UESP's Skyrim Mod:File Format/FUZ): the magic "FUZE", a u32 version
# (1), the u32 size of the lip data, the lip data (a .lip file: the mouth's movements over the
# line), then the line itself as an xWMA file to the end. And where a sound a record names lies:
# the records name .wav files, which the archives hold as such or as .xwm (music) or .fuz (voices).

pub type Fuz:
	version i64
	lip u8[]
	sound u8[]   # an xWMA file

# The lip data and the sound of a FUZ file, or why the bytes are none.
pub fn readFuz(b ref u8[]) Fuz ? str:
	if b.len < 12 or not b.startsWith("FUZE"): return "no FUZE header"
	lipSize = i64(b.u32le(8))
	if 12 + lipSize > b.len: return "the lip data ({lipSize} bytes) runs past the file's end"
	Fuz(version = b.u32le(4), lip = b[12..12 + lipSize].copy(), sound = b[12 + lipSize..].copy())

# The key under which the install holds the sound `key` (esm.soundKey's): itself, or its .xwm or
# .fuz; none when it holds none of them.
pub fn installSound(i Install, key str) str?:
	if i.installHas(key): return key.copy()
	if not key.endsWith(".wav"): return none
	stem = key[..key.len - 4]
	for ext in [".xwm", ".fuz"]:
		if i.installHas("{stem}{ext}"): return "{stem}{ext}"
	none
