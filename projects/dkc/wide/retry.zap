# The widened placed-object scan's retry of a type-$05 group (scene.zap): a parent the
# widened window made active early may have lost its children to the pool, so while the group is
# still in the window the children's loop (BD:FBF5) runs again for them, entered as the scanner
# enters it: the parent's index on the stack, $A4 at the first child's bookmark, Y at its record.
# Only while the scene is drawn wide; native play never enters it.

import recomp.snes.console
import recomp.snes.cpu

fn word(addr i64) i64:
	console.read16((u32(cpu.dbr) << 16) | u32(addr & 0xFFFF))

# whether the retry is taken for the parent record at Y
pub fn type5Retry() bool:
	if not console.growsLogic(): return false
	parentIndex = i64(console.read16(cpu.direct(0xA4)))
	if word(0x192B + parentIndex) & 0xFF == 0: return false
	parent = i64(cpu.y)
	firstChild = (word(parent + 6) + 8) & 0xFFFF
	cameraX = word(0x088B)
	if (cameraX + console.widenLeft(0x120)) & 0xFFFF < word(firstChild + 2): return false
	lastChild = firstChild
	for child in 0..0x100:
		if word(lastChild + 8) == 0: break
		lastChild = (lastChild + 8) & 0xFFFF
		if child == 0xFF: return false
	left = (cameraX - console.widenLeft(0x20)) & 0xFFFF
	lastX = word(lastChild + 2)
	if left & 0x8000 == 0 or left < 0xFC00:
		if left >= lastX: return false
	elif left < lastX:
		return false
	console.write16(cpu.direct(0x76), parent)
	console.write16(cpu.direct(0x78), firstChild)
	cpu.push16(parentIndex)
	childIndex = (parentIndex + (((firstChild - parent) & 0xFFFF) >> 3)) & 0xFFFF
	console.write16(cpu.direct(0xA4), childIndex)
	cpu.y = firstChild
	true
