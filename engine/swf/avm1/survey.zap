# What a movie's ActionScript uses: every block of it (the main timeline's and each sprite's frame
# actions, the init actions, the clip actions) decoded, its actions counted by code.

import engine.swf

# every block of the movie's code: (where it is, its bytes)
pub fn movieBlocks(movie swf.Swf) (str, u8[])[]:
	out = []
	for a in movie.initActions:
		out.push(("init {a.sprite}", a.code.copy()))
	movie.timeline.timelineBlocks("main", out)
	for id in movie.sprites.keys().sorted():
		movie.sprites[id].timeline.timelineBlocks("sprite {id}", out)
	out

fn timelineBlocks(t swf.Timeline, name str, mut out (str, u8[])[]):
	for k, f in t.frames:
		for code in f.actions:
			out.push(("{name} frame {k}", code.copy()))
		for c in f.commands:
			if c is Place(p):
				for a in p.clipActions:
					out.push(
						("{name} frame {k} clip at {p.depth} events {a.events:X}", a.code.copy())
					)

# the codes of the actions the code uses that the machine does not know
pub fn unknownActions(movie swf.Swf) i64[]:
	movie.actionCounts().keys().filter(actionName(it).startsWith("Action")).sorted()

# the actions the code uses, by code, with how many times
pub fn actionCounts(movie swf.Swf) {i64: i64}:
	counts {i64: i64} = {}
	for (_, code) in movie.movieBlocks():
		for a in decodeBlock(code).actions:
			counts.add(a.codeOf(), 1)
	counts
