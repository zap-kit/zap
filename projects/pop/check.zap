# Plays the DOS game headless along a scripted route and prints each frame's state, for an
# oracle (SDLPoP, or the original in DOSBox) to be compared with frame by frame:
#   zap run projects/pop/check.zap [--level -1..14] [--frames n] [--keys right@10-40,shift@50]
#     [--seed n] [--shots dir] [--show title|ending|expired|cutscene2..12] [--record file.p1r]
#     [--replay file.p1r] [--save-dir dir/] [--ini dir] [--cheats]
# A line a frame: the frame #, the room drawn, the kid's and the guard's char_type (frame x y
# direction col row action fall_x fall_y room repeat charid sword alive seq), the sounds started
# and a hash of the screen; with --shots each frame's screen as a PNG too.

import dos.pop
import fs
import game
import image

startLevel = (i64.parse(args.option("--level") ?? "1") ?? 1).clamp(-1, 14)
frames = i64.parse(args.option("--frames") ?? "100") ?? 100
route = game.parseKeyRoute(args.option("--keys") ?? "")
shots = args.option("--shots") ?? ""
if shots != "":
	_ = fs.createDir(shots)

fn charText(c game.CharType):
	"{c.frame} {c.x} {c.y} {c.direction} {c.currCol} {c.currRow} {c.action} {c.fallX} {c.fallY} {c.room} {c.repeat} {c.charid} {c.sword} {c.alive} {c.currSeq:04x}"

# FNV-1a of the screen's pixels
fn screenHash(p image.Image):
	h u64 = 14_695_981_039_346_656_037
	for (_, _), c in p:
		h = (h ^ c.r) * 1_099_511_628_211
		h = (h ^ c.g) * 1_099_511_628_211
		h = (h ^ c.b) * 1_099_511_628_211
	h

g = game.newGame(args.option("--install") ?? pop.defaultInstall)
g.saveDir = args.option("--save-dir") ?? ""
if args.option("--ini") != none:
	g.settingsDir = args.option("--ini") ?? "."
	g.useOptions(game.loadOptions(g.settingsDir))
g.cheatsEnabled = args.option("--cheats") != none
replayFile = args.option("--replay") ?? ""
recordFile = args.option("--record") ?? ""
if replayFile != "":
	bytes = fs.readBytes(replayFile) ?? fail("cannot read {replayFile}")
	rep = game.readReplay(bytes) ?? fail("{replayFile} is not a replay this reads")
	g.startReplay(rep)
else:
	g.startGame(i64.parse(args.option("--seed") ?? "0") ?? 0, startLevel)
	if recordFile != "":
		g.startRecording()
# a show started at once: a frame of it a tick
show = args.option("--show") ?? ""
if show == "title":
	g.startTitle()
elif show == "ending":
	g.endSequence()
elif show == "expired":
	g.expiredShow()
elif show.startsWith("cutscene"):
	n = i64.parse(show[8..]) ?? 2
	g.currentLevel = -1
	g.playLevel(n)
print("level {startLevel}: frame room | kid | guard | sounds | screen")
if shots != "":
	_ = g.screen.onscreen.savePng("{shots}/start.png")
for n in 0..frames:
	running = g.runFrame(route.inputAt(n))
	sounds = g.soundsPlayed.map("{it}:{g.sounds.ticks(it)}").join(" ")
	print("{n} {g.drawnRoom} | {g.kid.charText()} | {g.guard.charText()} | {sounds} | {g.screen.onscreen.screenHash():016x}")
	if shots != "":
		_ = g.screen.onscreen.savePng("{shots}/{n:04}.png")
	if not running:
		print("the game ended at frame {n}")
		break
if recordFile != "":
	_ = fs.writeBytes(recordFile, g.recordedReplay())
