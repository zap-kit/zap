# The overlay's menu: the frame darkened, the program's items as a column of pills in its middle;
# a finger landing on one chooses it, anywhere else closes the menu.

# the item's pill in the frame
fn itemShape(o Overlay, i i64):
	fh = f64(o.frame.height)
	gap = fh * 0.17
	top = fh / 2.0 - gap * (o.items.len - 1) / 2.0
	Capsule(x = o.frame.width / 2.0, y = top + gap * i, half = fh * 0.22, r = fh * 0.06)

fn readMenu(mut o Overlay, fingers Vec2[]):
	for b in 0..o.held.len:
		o.held[b] = false
	if fingers.isEmpty or o.fingers > 0: return   # acts as a finger lands
	f = fingers[0]
	for i in 0..o.items.len:
		if o.itemShape(i).edgeDistance(f64(f.x), f64(f.y)) < 0.0:
			o.chosen = i
	o.menuOpen = false
	o.touched = []

fn paintMenu(mut o Overlay):
	for y in 0..o.frame.height:
		for x in 0..o.frame.width:
			o.frame.blend(x, y, 0.0, 0.6)
	for i, item in o.items:
		shape = o.itemShape(i)
		o.frame.paintCapsule(shape, 0.35, 0.7, shape.r * 0.08, false)
		o.frame.paintText(item.upper(), shape.x, shape.y, shape.r * 0.6, 0.9)
