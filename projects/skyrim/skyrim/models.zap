# The models a cell shows: its references' base records' models, read from the install's archives.

import skyrim.bsa
import skyrim.esm
import skyrim.nif

# the archive key of a base record's model (a path under meshes/)
pub fn modelKey(model str) str:
	bsa.bsaKey("meshes/{model}".bytes())

# the archive keys of the models the cell's references show, each once, in the references' order
pub fn cellModels(mut plugin esm.Esm, cell esm.Cell) str[]:
	seen {str: bool} = {}
	out = []
	for r in cell.refs:
		b = plugin.baseRecord(r.base) ?? continue
		if b.model.isEmpty: continue
		key = modelKey(b.model)
		if key in seen: continue
		seen[key.copy()] = true
		out.push(key)
	out

# the model with this archive key, read, or why it cannot be
pub fn readModel(i Install, key str) nif.Nif ? str:
	bytes = i.installRead(key) ?? return "{key} is in no archive"
	nif.readNif(bytes) ?? return "{key}: {error}"
