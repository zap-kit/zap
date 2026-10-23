# Who takes whose side, and the crimes of a fight. Ties: two actors are allies when their
# relationship (RELA) is lover or ally, or a faction of one is an ally (XNAM reaction 2) of a
# faction of the other, the same faction counting as its own ally only when its XNAM says so (the
# Blades); friends when their relationship is at most friend, they share a faction, or a reaction
# says friend. AIDT's assistance: 0 helps nobody, 1 helps its allies, 2 its friends and allies.
# AIDT's aggression: an unaggressive actor attacks no one on its own, an aggressive one its
# enemies on sight (a relationship of enemy or worse, or an enemy reaction), a very aggressive
# one anyone who is no friend, a frenzied one anyone. Confidence: a cowardly actor flees from any
# fight.
#
# The crimes (CRVA of the victim's crime faction, CRIF): hitting an actor who was not hostile is
# an assault (40 for CrimeFactionWhiterun), once a victim, and killing one a murder (1000); a hit
# that kills at once is only a murder (UESP's Skyrim:Crime). A crime counts only when a witness
# sees it: any living actor of the cell other than the criminal (the victim too, for an assault)
# within fSneakMaxDistance (2500 units); the game also asks for a line of sight through the
# cell's geometry, which a headless fight does not have, and for the actor's detection of the
# criminal (sneaking), which it does not model either. The bounty is the sum of the crimes reported
# to the faction; guards (none inside the inn) would then arrest or attack on sight (CRVA's flags).

import game.sim

pub type Ties:
	relationships Relationship[]
	reactions {i64: {i64: i64}}   # by faction, its reaction to each faction it names

# the relationship's rank between two actor bases, none when they have none
fn rankBetween(t Ties, a i64, b i64) i64?:
	for r in t.relationships:
		if (r.parent == a and r.child == b) or (r.parent == b and r.child == a): return r.rank
	none

fn factionsIn(a sim.ActorState):
	a.factions.filter(.rank >= 0).map(.faction)

# the reactions between the two actors' factions
fn reactionsBetween(t Ties, a sim.ActorState, b sim.ActorState):
	out = []
	for fa in a.factionsIn():
		for fb in b.factionsIn():
			if t.reactions.get(fa) is r:
				if r.get(fb) is reaction: out.push(reaction)
	out

fn sharesFaction(a sim.ActorState, b sim.ActorState):
	a.factionsIn().any(it in b.factionsIn())

pub fn isAlly(w sim.GameWorld, t Ties, a i64, b i64) bool:
	x = w.actors.get(a) ?? return false
	y = w.actors.get(b) ?? return false
	if (t.rankBetween(x.npc, y.npc) ?? 99) <= allyRank: return true
	reactionAlly in t.reactionsBetween(x, y)

pub fn isFriend(w sim.GameWorld, t Ties, a i64, b i64) bool:
	x = w.actors.get(a) ?? return false
	y = w.actors.get(b) ?? return false
	if (t.rankBetween(x.npc, y.npc) ?? 99) <= friendRank or sharesFaction(x, y): return true
	t.reactionsBetween(x, y).any(it == reactionAlly or it == reactionFriend)

pub fn isEnemy(w sim.GameWorld, t Ties, a i64, b i64) bool:
	x = w.actors.get(a) ?? return false
	y = w.actors.get(b) ?? return false
	if (t.rankBetween(x.npc, y.npc) ?? 0) >= enemyRank: return true
	reactionEnemy in t.reactionsBetween(x, y)

# whether the helper's assistance takes it to the side of the one attacked
pub fn helps(w sim.GameWorld, t Ties, helper Fighter, victim i64) bool:
	match helper.ai.assistance:
		0: false
		1: w.isAlly(t, helper.refId, victim)
		_: w.isAlly(t, helper.refId, victim) or w.isFriend(t, helper.refId, victim)

# whether the actor's aggression makes it attack the other on sight
pub fn attacksOnSight(w sim.GameWorld, t Ties, a Fighter, b i64) bool:
	if a.refId == b: return false
	match a.ai.aggression:
		0: false
		1: w.isEnemy(t, a.refId, b)
		2: not (w.isAlly(t, a.refId, b) or w.isFriend(t, a.refId, b))
		_: true

# the bounty the crimes reported to the faction add up to
pub fn bountyOf(w sim.GameWorld, faction i64) i64:
	w.crimes.filter(.faction == faction).map(.bounty).sum()
