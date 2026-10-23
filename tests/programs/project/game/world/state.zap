# game.world module, file 2: the world state. Shares the module with types.zap.
import util

pub width = 7
pub height = 7

pub type World:
	entities {i64: Entity} = {}
	nextId i64 = 1

	pub mut fn add(kind Kind, move name str, x i64, y i64) i64:
		id = nextId
		nextId += 1
		entities[id] = Entity(id, kind, name, x, y, hp = 10)
		id

	pub fn distance(a i64, b i64) i64?:
		ea = try entities.get(a)
		eb = try entities.get(b)
		util.manhattan(ea.x, ea.y, eb.x, eb.y)
