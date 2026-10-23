# The hero led by the mouse as the client leads a player: a left click on the ground walks to
# the cell under it (or, past a wall or into the water, as near as the hero can get), a click
# while walking turns the walk there at once, and holding the button keeps walking toward the
# cursor, the destination sent again as it moves (every resendMs at most). The camera's right
# drag takes the mouse, so the left button does nothing while it lasts. Each frame also tells
# which cursor to show and the cell under the mouse.

import ragnarok.gat

pub type Pointer:
	hover Cell? = none   # the cell under the cursor
	sent Cell = Cell(-1, -1)   # the last destination given
	sinceSent i64 = 0   # milliseconds since then

resendMs = 150

# the frame's input applied: the cell under the mouse found, the hero sent walking
pub fn leadHero(
	mut p Pointer,
	mut h Hero,
	gat gat.Gat,
	c Camera,
	i Input,
	w i64,
	ht i64,
	ms i64
):
	p.sinceSent += ms
	p.hover = none if c.dragging else gat.pickCell(c, i.x, i.y, w, ht)
	if c.dragging or i.right: return
	if p.hover is cell:
		again = i.left and p.sinceSent >= resendMs and cell != p.sent
		if i.leftPressed or again:
			h.walkTo(gat, cell.x, cell.y)
			p.sent = cell
			p.sinceSent = 0

# the cursor to show: turning while the camera is dragged, "no" over ground the hero cannot
# walk on, else the arrow
pub fn cursorOf(p Pointer, gat gat.Gat, c Camera) i64:
	if c.dragging: return cursorTurn
	match p.hover:
		Cell(x, y): cursorArrow if gat.walkable(x, y) else cursorNo
		none: cursorArrow

# the cell to mark under the mouse: a walkable one, as the client marks it
pub fn markedCell(p Pointer, gat gat.Gat) (i64, i64)?:
	match p.hover:
		Cell(x, y): (x, y) if gat.walkable(x, y) else none
		none: none
