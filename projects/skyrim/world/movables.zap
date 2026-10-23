# The cell's movable models (a door posed by its Open and Close sequences) as the scene plays
# them. The game says how a reference stands: the first time it does, the model is put at the end
# of that state's sequence (the load's SetOpenState, 0x1401d9eb0); when it changes, the sequence
# of the new state plays from its start (TESObjectDOOR::Activate, 0x140283210) and holds at its end
# (the sequences clamp).

import world.shaders
import skyrim.nif

# how a movable stands: open or closed, whether the game has said so yet, and the sequence
# playing to it
pub type MovableState:
	open bool = false
	known bool = false
	playing bool = false
	clock f32 = 0.0   # seconds into the playing sequence

# the references of the cell's movables
pub fn movableRefs(sc CellScene) i64[]:
	sc.movables.map(.refId)

# The game's state of the movable of this reference: said for the first time, it stands so; said
# to have changed, the sequence of the new state plays.
pub fn setOpen(mut sc CellScene, refId i64, open bool):
	k = sc.movables.findIndex(.refId == refId) ?? return
	s = sc.movableStates[k]
	if s.known and s.open == open: return
	sc.movableStates[k] = MovableState(open, known = true, playing = s.known)

# the sequence a state plays or holds the end of
fn sequenceOf(m Movable, open bool):
	m.open.copy() if open else m.close.copy()

# the state of a movable `dt` seconds on
pub fn stepped(m Movable, s MovableState, dt f32) MovableState:
	if not s.playing: return s
	q = m.sequenceOf(s.open)
	clock = s.clock + dt
	MovableState(..s, clock, playing = clock * q.frequency < q.stop - q.start)

# the movables' sequences `dt` seconds on
pub fn advanceMovables(mut sc CellScene, dt f32):
	for k, m in sc.movables:
		sc.movableStates[k] = m.stepped(sc.movableStates[k], dt)

# whether the movable of this reference is moving
pub fn isMovableMoving(sc CellScene, refId i64) bool:
	k = sc.movables.findIndex(.refId == refId) ?? return false
	sc.movableStates[k].playing

# The movable's vertices where its nodes are in this state, in the cell's space: the one-sided
# solid parts (opaque and cut out), the two-sided ones, the blended and the added.
pub fn fillMovable(
	m Movable,
	s MovableState,
	mut solid shaders.CellVertex[],
	mut twoSided shaders.CellVertex[],
	mut blended shaders.CellVertex[],
	mut added shaders.CellVertex[]
):
	q = m.sequenceOf(s.open)
	t = q.clockOf(s.clock) if s.playing else q.stop
	poses = m.frames.map(m.place @ .poseAt(q, t))
	for part in m.parts:
		at = poses[part.frame] if part.frame >= 0 else m.place
		for v in part.vertices:
			moved = v.movedBy(at)
			match part.kind:
				Added: added.push(moved)
				Blended: blended.push(moved)
				_:
					if part.twoSided:
						twoSided.push(moved)
					else:
						solid.push(moved)

# every movable's vertices (fillMovable)
pub fn fillMovables(
	sc CellScene,
	mut solid shaders.CellVertex[],
	mut twoSided shaders.CellVertex[],
	mut blended shaders.CellVertex[],
	mut added shaders.CellVertex[]
):
	for k, m in sc.movables:
		m.fillMovable(sc.movableStates[k], solid, twoSided, blended, added)
