# The heap collected between frames, when no code runs: a mark from the roots (the globals and
# the built-in prototypes, the objects of the stage's nodes, the classes, the callbacks, the
# timers and the queue) through properties, prototypes, elements, functions' scope chains and
# boxed values, then every object and scope not reached freed for the next ones made. Handles
# stay where they are, so a value never moves. Every call makes an activation object and a scope,
# which this gives back.

# frees what the machine's code can no longer reach
pub fn collect(mut m Machine):
	marked = fill(m.heap.len, false)
	scopesMarked = fill(m.scopes.len, false)
	work = []
	for id in m.roots():
		work.push(id)
	while work.pop() is id:
		if id < 0 or id >= marked.len or marked[id]: continue
		marked[id] = true
		m.reach(id, work, scopesMarked)
	m.freeObjects.clear()
	for k in 0..m.heap.len:
		if not marked[k]:
			if not m.heap[k].props.isEmpty or not m.heap[k].items.isEmpty: m.heap[k] = Obj()
			m.freeObjects.push(k)
	m.freeScopes.clear()
	for k in 0..m.scopes.len:
		if not scopesMarked[k]: m.freeScopes.push(k)
	m.liveAfterCollect = m.heap.len - m.freeObjects.len

fn roots(m Machine):
	out = [m.globals, m.stageObject, m.keyListeners, m.mouseListeners, m.focus]
	p = m.protos
	out.extend([p.object, p.function, p.array, p.string, p.number, p.boolean, p.clip, p.text,
		p.button, p.textFormat, p.rectangle, p.point, p.date, p.error])
	for node in m.stage.nodes:
		if node.alive and node.object >= 0: out.push(node.object)
	out.extend(m.classes.values())
	for c in m.callbacks.values():
		out.pushValue(c.me)
		out.pushValue(c.function)
	for t in m.intervals:
		out.pushValue(t.me)
		out.pushValue(t.function)
		for v in t.args:
			out.pushValue(v)
	out

fn pushValue(mut out i64[], v Value):
	if v is Obj(id): out.push(id)

# the objects and scopes one object holds, queued
fn reach(m Machine, id i64, mut work i64[], mut scopesMarked bool[]):
	o = ref m.heap[id]
	work.push(o.proto)
	for name in o.order:
		p = o.props[name]
		work.pushValue(p.value)
		work.push(p.getter)
		work.push(p.setter)
	for v in o.items:
		work.pushValue(v)
	work.extend(o.interfaces)
	match o.kind:
		Function(f): m.reachScope(f.scope, work, scopesMarked)
		Boxed(v): work.pushValue(v)
		Super(me, base):
			work.push(me)
			work.push(base)
		_: pass

fn reachScope(m Machine, start i64, mut work i64[], mut scopesMarked bool[]):
	s = start
	while s >= 0 and s < scopesMarked.len and not scopesMarked[s]:
		scopesMarked[s] = true
		work.push(m.scopes[s].object)
		s = m.scopes[s].parent
