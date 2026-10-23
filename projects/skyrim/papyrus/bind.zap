# Scripts bound to forms as the game binds them when a cell loads: an object per script with the
# VMAD's property values in its auto properties' variables, then OnInit sent to each.

# a VMAD value as a Papyrus value of the property's type (an object: the form seen as that type)
import game.sim

fn vmadToValue(mut vm Vm, x VmadValue, typeName str) Value:
	match x:
		Object(formId, alias):
			vm.ensureScript(typeName)
			.Object(vm.lib.objectFor(vm.rt, formId, typeName))
		Text(text): .Str(text.copy())
		Int(n): .Int(n)
		Float(f): .Float(f)
		Bool(b): .Bool(b)

fn propertyValue(mut vm Vm, p VmadProperty, typeName str):
	if not p.isArray(): return vm.vmadToValue(p.values[0], typeName)
	element = elementType(typeName)
	items = []
	for x in p.values:
		items.push(vm.vmadToValue(x, element))
	.Array(vm.rt.arrays.push(ArrayData(items)))

# Binds the script `name` to the form with these property values: the new object, none when the
# install has no such script.
pub fn bindScript(mut vm Vm, form i64, name str, properties VmadProperty[]) i64?:
	if not vm.ensureScript(name): return none
	id = vm.lib.newObject(vm.rt, form, name)
	vm.setProperties(id, properties)
	id

# sets the object's auto properties to these VMAD values
pub fn setProperties(mut vm Vm, id i64, properties VmadProperty[]):
	name = vm.rt.objects[id].script.copy()
	for p in properties:
		if p.status == 3: continue   # removed
		c = vm.lib.findProperty(name, p.name) ?? continue
		typeName = vm.lib.propertyAt(c).typeName.copy()
		autoVar = vm.lib.propertyAt(c).autoVar.lower()
		if autoVar.isEmpty:
			vm.rt.note("error: property {p.name} of {name} is not an auto property")
			continue
		v = vm.propertyValue(p, typeName)
		vm.rt.objects[id].vars[autoVar] = v

# the scripts each placed reference runs, its own VMAD's properties over its base's
fn mergedScripts(bindings Binding[], placed i64):
	out BoundScript[] = []
	for b in bindings:
		if b.placed != placed: continue
		for s in b.vmad.scripts:
			at = -1
			for k, o in out:
				if o.name.lower() == s.name.lower(): at = k
			if at < 0:
				out.push(s.copy())
				continue
			for p in s.properties:
				if not out[at].properties.any(.name.lower() == p.name.lower()):
					out[at].properties.push(p.copy())
	out

# Binds the scripts of a cell's bindings (bindings.zap) and sends each object OnInit; the objects.
pub fn bindCell(mut vm Vm, bindings Binding[]) i64[]:
	ids = []
	seen {i64: bool} = {}
	for b in bindings:
		if seen.get(b.placed) != none: continue
		seen[b.placed] = true
		vm.rt.world.addForm(b.placed)
		if b.record != b.placed: vm.rt.world.forms[b.placed].base = b.record
		for s in mergedScripts(bindings, b.placed):
			if s.status == 3: continue
			if vm.bindScript(b.placed, s.name, s.properties) is id: ids.push(id)
	for id in ids:
		vm.sendEvent(id, "OnInit", [])
	ids
