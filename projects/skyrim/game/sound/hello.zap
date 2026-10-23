# The actors' hellos: an actor greets the player who comes within fAIMinGreetingDistance of it
# (150 units, the executable's default) with the hello game.dialogue chooses for it (the HELO
# topics, said as the dialogue says a line), its voice played from its FUZ at the actor's head in
# the voices' category (the default objects' DDSC) through the dialogue's 3D output model (DOP2,
# SOMDialogue3DDefault), and its lip track followed while it plays. An actor greets once each time
# the player comes near, its greetings at least fAIGreetingTimer apart. Approximated: the game's
# conditions on who may greet (the actor's state, its package) are in the executable; only the
# first response of a hello plays; the subtitles are the menus'.

import game
import game.sim
import game.dialogue
import world

pub type Greeter:
	talk dialogue.Talk
	distance f32
	timer f64
	near {i64: bool} = {}   # by the cast's NPC: the player within reach last frame
	greeted {i64: f64} = {}   # when each last greeted

# The greeter over the cell's dialogue, its world at the game hour.
pub fn newGreeter(mut b Book, move talk dialogue.Talk, hour f32) Greeter:
	settings = talk.vm.rt.world.settings.copy()
	talk.vm.rt.world.daysPassed = f64(hour) / 24.0
	Greeter(
		talk,
		distance = sim.gmst(settings, "faimingreetingdistance"),
		timer = f64(sim.gmst(settings, "faigreetingtimer"))
	)

# the reference the dialogue knows the cast's NPC by, 0 for none
fn speakerOf(g Greeter, npc world.NpcHead):
	if npc.refId != 0 and g.talk.people.get(npc.refId) != none: return npc.refId
	for refId, p in g.talk.people:
		if p.npc == npc.formId: return refId
	0

# The cast's NPC `k` says its hello at `head`; whether it had one to say.
fn greet(mut g Greeter, mut b Book, mut voices Speaking, npc world.NpcHead, k i64, head Vec3) bool:
	speaker = g.speakerOf(npc)
	if speaker == 0: return false
	line = g.talk.greeting(speaker) ?? return false
	said = g.talk.say(speaker, line.info)
	g.talk.partner = 0
	first = said.lines.find(.voice != "") ?? return false
	voices.speak(b, k, first.voice, first.text, head, "{npc.editorId} greets")

# The hellos one frame on: an actor present that the player has come near greets him.
pub fn stepGreeter(
	mut g Greeter,
	mut b Book,
	mut voices Speaking,
	cast world.CastHead,
	rs game.Residents,
	player Vec3
):
	for r in rs.all:
		if not r.present: continue
		feet = r.body.feetOf()
		inside = (feet - player).length() <= g.distance
		was = g.near.get(r.npc) ?? false
		g.near[r.npc] = inside
		if not inside or was: continue
		if b.time - (g.greeted.get(r.npc) ?? -1.0e9) < g.timer: continue
		if g.greet(b, voices, cast.npcs[r.npc], r.npc, feet + Vec3(0, 0, headHeight)):
			g.greeted[r.npc] = b.time
