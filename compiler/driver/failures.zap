# Where a program stops on an error: the shared stubs a failed check calls (rt.failAt with
# the kind) and the stubs that stop with a message.

fn failCall(mut g Gen, msg str):
	tmp = g.allocSlot(24)
	g.genStrLiteral(msg, frameDest(tmp))
	g.leaRaxRbp(tmp)
	g.a.pushRax()
	g.callRtNamed("fail", 8)

# a conditional jump (cc) taken when a check fails: to an exit of the expression's own, which
# calls the shared stub
fn failJump(mut g Gen, cc i64, stub i64):
	site = g.a.asmNewLabel()
	g.a.jccLabel(cc, site)
	g.f.failSites.push(
		FailSite(
			label = site,
			stub,
			line = g.curLine,
			col = g.curCol,
			file = g.curFile,
			framed = g.f.framed or not g.f.area
		)
	)

# the exits of the function's checks made with the frame (or without it), after its code: each a
# call to its stub, noted with the place of the expression it checks; an int3 after the last
# keeps its return address inside the function for the unwinder
fn emitFailSites(mut g Gen, framed bool):
	sites = g.f.failSites.filter(.framed == framed)
	for site in sites:
		g.a.asmPlace(site.label)
		g.noteDebugLine(site.line, site.col, site.file)
		g.a.callLabel(site.stub)
	if not sites.isEmpty:
		g.a.em1(0xCC)
	g.f.failSites = g.f.failSites.filter(.framed != framed)

# a stub that stops the program with the message (rt.fail)
fn genMessageStub(mut g Gen, label i64, msg str):
	g.a.asmPlace(label)
	g.f.frameSize = 0
	g.f.maxFrame = 0
	g.emitPrologue()
	g.failCall(msg)
	g.a.em1(0xCC)
	patch32(g.a.code, g.f.frameFixPos, 64)

# the kinds of failure a check stops with: the kind rt's failKind (runtime/core/errors.zap) is given
failKindDivZero = 0

failKindShift = 1

failKindStep = 2

failKindBounds = 3

failKindOldCpu = 4

failKindOverflow = 5

failKindConversion = 6

# A shared failure stub: rt.failAt with the kind of failure; the return address the site's
# exit left (failJump) tells it where.
fn genFailStub(mut g Gen, label i64, kind i64):
	if onArm():
		g.a64FailStub(label, kind)
		return
	g.a.asmPlace(label)
	g.f.frameSize = 0
	g.f.maxFrame = 0
	g.emitPrologue()
	g.a.movRaxImm(kind)
	g.a.pushRax()
	g.callRtNamed("failAt", 8)
	g.a.em1(0xCC)
	patch32(g.a.code, g.f.frameFixPos, 64)
