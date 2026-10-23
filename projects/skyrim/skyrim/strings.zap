# The localized strings of a plugin whose texts are ids (Skyrim.esm's FULL, DESC): Strings/
# <plugin>_<language>.STRINGS (names, a topic's and a response's prompt), .DLSTRINGS (descriptions)
# and .ILSTRINGS (the lines the actors say, an INFO's NAM1). A count,
# the data's size, then each string's id and offset into the data that follows the directory; a
# .STRINGS text ends with a NUL, the other two start with their length (UESP, String Table File
# Format).

import skyrim.esm

pub type Strings:
	texts {i64: str}

# the strings table's bytes read, `counted` for the .DLSTRINGS and .ILSTRINGS layout
pub fn readStrings(d u8[], counted bool) Strings ? str:
	if d.len < 8: return "a strings table is cut short"
	count = i64(d.u32le(0))
	data = 8 + count * 8
	if data > d.len: return "a strings table's directory is cut short"
	texts {i64: str} = {}
	for k in 0..count:
		at = data + d.u32le(8 + k * 8 + 4)
		if at >= d.len: continue
		texts[i64(d.u32le(8 + k * 8))] = d.cStringAt(at + 4) if counted else d.cStringAt(at)
	Strings(texts)

# the plugin's ("Skyrim.esm") English strings table of this extension, or why it cannot be read
fn readTable(i Install, plugin str, extension str) Strings ? str:
	stem = plugin.lower().replace(".esm", "").replace(".esp", "")
	key = "strings/{stem}_english.{extension}"
	bytes = i.installRead(key) ?? return "{key} is in no archive"
	readStrings(bytes, extension != "strings") ?? return "{key}: {error}"

# the names table (.STRINGS) of the plugin ("Skyrim.esm") in English, or why it cannot be read
pub fn readNames(i Install, plugin str) Strings ? str:
	i.readTable(plugin, "strings")

# the descriptions table (.DLSTRINGS: DESC, a book's text) of the plugin in English
pub fn readDescriptions(i Install, plugin str) Strings ? str:
	i.readTable(plugin, "dlstrings")

# the dialogue table (.ILSTRINGS: the lines an INFO's responses say) of the plugin in English
pub fn readLines(i Install, plugin str) Strings ? str:
	i.readTable(plugin, "ilstrings")

# the text of a localized field (its u32 string id) of the record, "" when it has none
pub fn localText(s Strings, r esm.Record, tag str) str:
	at = esm.dataOf(r.fields, tag) ?? return ""
	(s.texts.get(i64(r.body.u32le(at))) ?? "").copy()
