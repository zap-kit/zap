# The game settings (GMST) the plugin sets: an editor id whose first letter is the value's type (f
# a float, i an int, b a bool, s a string) and DATA the value. A setting the plugin leaves out keeps
# the default compiled into the executable, which is not read here. Layout after UESP's Skyrim Mod
# File Format/GMST.

fn settingAt(name str, body u8[], at i64):
	match name.lower()[0]:
		'f': f64(body.f32le(at))
		'b': 1.0 if body.u32le(at) != 0 else 0.0
		's': f64(body.u32le(at))
		_: f64(body.i32le(at))

# every game setting of the plugin by its editor id in lower case, as a number: a bool 0 or 1, a
# string its id in the plugin's .STRINGS
pub fn gameSettings(mut e Esm) {str: f64}:
	out {str: f64} = {}
	for id in e.formsOfKind("GMST"):
		r = e.recordOf(id) ?? continue
		name = textOf(r.body, r.fields, "EDID")
		at = dataOf(r.fields, "DATA") ?? continue
		if name.isEmpty: continue
		out[name.lower()] = settingAt(name, r.body, at)
	out
