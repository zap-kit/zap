# Papyrus's arrays: handles into Runtime.arrays, none until created, of 1 to 128 elements.

# the items of the array an operand holds (none for none)
pub fn arrayItems(rt Runtime, t i64, o Operand) Value[]:
	match rt.read(t, o):
		Array(id): rt.arrays[id].items.copy()
		_: []

fn arrayId(rt Runtime, t i64, o Operand):
	match rt.read(t, o):
		Array(id): id
		_: -1

# the type of an array's elements ("int" of "int[]")
pub fn elementType(typeName str) str:
	if typeName.endsWith("[]"): return typeName[..typeName.len - 2].copy()
	typeName.copy()

# a new array of n values, each the default of the element type
pub fn newArray(mut rt Runtime, elementType str, n i64) Value:
	items = []
	loop n:
		items.push(defaultOf(elementType))
	.Array(rt.arrays.push(ArrayData(items)))

# array_create dest size
fn arrayCreate(mut rt Runtime, lib Library, t i64, a Operand[]):
	typeName = rt.declaredType(lib, t, a[0].identOf())
	n = rt.int(t, a[1])
	if n < 0 or n > 128:
		rt.note("error: an array of {n} elements (Papyrus allows 1 to 128)")
		rt.setDest(t, a[0], .None)
		return
	element = elementType(typeName)
	v = rt.newArray(element, n)
	rt.setDest(t, a[0], v)

# array_getelement dest array index
fn arrayGet(mut rt Runtime, t i64, a Operand[]):
	id = rt.arrayId(t, a[1])
	i = rt.int(t, a[2])
	if id < 0 or i < 0 or i >= rt.arrays[id].items.len:
		rt.note("error: array index {i} out of range")
		rt.setDest(t, a[0], .None)
		return
	v = rt.arrays[id].items[i].copy()
	rt.setDest(t, a[0], v)

# array_setelement array index value
fn arraySet(mut rt Runtime, t i64, a Operand[]):
	id = rt.arrayId(t, a[0])
	i = rt.int(t, a[1])
	if id < 0 or i < 0 or i >= rt.arrays[id].items.len:
		rt.note("error: array index {i} out of range")
		return
	rt.arrays[id].items[i] = rt.read(t, a[2])

# array_findelement array dest value start, or array_rfindelement (from start down, -1 the last)
fn arrayFind(mut rt Runtime, t i64, a Operand[], backwards bool):
	items = rt.arrayItems(t, a[0])
	want = rt.read(t, a[2])
	start = rt.int(t, a[3])
	found = -1
	if backwards:
		k = items.len - 1 if start < 0 else start
		while k >= 0 and found < 0:
			if items[k].valuesEqual(want): found = k
			k -= 1
	else:
		k = start
		while k < items.len and found < 0:
			if items[k].valuesEqual(want): found = k
			k += 1
	rt.setDest(t, a[1], .Int(found))
