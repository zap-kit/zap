# The clutter's knocks: a body that comes to touch the floor or another body faster than
# `impactSpeed` plays its material's impact data set (MATT's HNAM) for the material it meets (the
# scene's triangle's, or the other body's), at the contact. Approximated: the game's speed
# threshold and its limit on how often a body sounds are in the executable, not read; these are
# a meter a second and a quarter of a second.

import game
import engine.physics
import skyrim.esm

impactSpeedMeters f32 = 1.0
quietSeconds f64 = 0.25

pub type Knocks:
	materials {i64: i64}   # the bodies' Havok materials, by body
	touching {i64: bool} = {}   # the contacts of the last frame, by key
	last {i64: f64} = {}   # when each body last sounded

pub fn newKnocks(cw game.CellWorld) Knocks:
	materials {i64: i64} = {}
	for p in cw.placed:
		materials[p.body] = p.material
	Knocks(materials)

# how fast the manifold's points came together, the world's units a second
fn closingSpeed(m physics.Manifold):
	fastest f32 = 0.0
	for c in m.contacts:
		fastest = fastest.max(c.closing.abs())
	fastest

# The contacts new since the last frame that came together fast enough, each sounding once.
# `byHash`: the materials by their Havok hash.
pub fn stepKnocks(mut k Knocks, mut b Book, mut w physics.World, byHash {i64: i64}):
	now {i64: bool} = {}
	threshold = impactSpeedMeters * w.unitsPerMeter
	for m in w.manifolds:
		now[m.key] = true
		if k.touching.get(m.key) != none or m.contacts.isEmpty: continue
		if m.closingSpeed() < threshold: continue
		if b.time - (k.last.get(m.a) ?? -1.0) < quietSeconds: continue
		other = k.materials.get(m.b) ?? 0
		if m.sceneTriangle() is t: other = w.scene.materials[t]
		k.last[m.a] = b.time
		k.knock(b, w.bodies[m.a].name, m.a, other, m.contacts[0].point, byHash)
	k.touching = now

fn knock(mut k Knocks, mut b Book, name str, body i64, other i64, at Vec3, byHash {i64: i64}):
	own = byHash.get(k.materials.get(body) ?? 0) ?? return
	met = byHash.get(other) ?? return
	set = b.plugin.impactSetOf(own)
	impact = b.plugin.impactFor(set, met) ?? return
	b.playDescriptor(b.plugin.impactSound(impact, false), at, "{name} knocks")
