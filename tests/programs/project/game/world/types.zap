# game.world module, file 1: types. Imports util by its qualified name.
import util

pub type Kind:
	Player
	Monster

pub type Entity:
	id i64
	kind Kind
	name str
	x i64
	y i64
	hp i64

	pub fn describe() str:
		"{name}#{id} at {x},{y} hp={hp}"

	pub mut fn walk(dx i64, dy i64):
		x = util.clamp(x + dx, 0, width)
		y = util.clamp(y + dy, 0, height)

# a Tag of this module, with a name util's Tag has too
pub type Tag:
	id i64
	x f32
	label str

pub fn tags() Tag[]:
	[Tag(id = 1, x = 2.0, label = "c".repeat(4))]
