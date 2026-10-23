# The game's API: the functions its scripts declare `native` (Debug.psc, Math.psc, Utility.psc,
# Form.psc, ObjectReference.psc, Game.psc, Quest.psc, GlobalVariable.psc...), each a Zap function
# here keyed by "script.function" in lower case. Those not written yet are stubs: the call is
# logged and the function's return type's default given back. Papyrus's trigonometry is in degrees.

pub type NativeCall:
	key str
	me i64   # the object it is called on, 0 for a global
	args Value[]
	thread i64
	returnType str

fn arg(c NativeCall, k i64) Value:
	c.args[k].copy() if k < c.args.len else .None

fn argFloat(c NativeCall, k i64) f64:
	f64(c.arg(k).asFloat())

fn degrees(x f64) Value:
	.Float(f32(x.degrees()))

# a latent call: thread t sleeps for seconds of real time
fn sleep(mut rt Runtime, t i64, seconds f64) Value:
	rt.threads[t].wakeAt = rt.time + seconds.max(0.0)
	.None

fn trace(mut rt Runtime, c NativeCall) Value:
	line = rt.valueText(c.arg(0))
	print("[papyrus] {line}")
	rt.note("trace: {line}")
	.Bool(true) if c.returnType.lower() == "bool" else .None

fn notify(mut rt Runtime, c NativeCall) Value:
	line = rt.valueText(c.arg(0))
	rt.world.notifications.push(line.copy())
	rt.note("notification: {line}")
	.Int(0) if c.returnType.lower() == "int" else .None

# Utility.GameTimeToString: "MM/DD/YYYY HH:MM" of a game time in days (the game starts 17/8/201)
fn gameTimeText(days f64) Value:
	whole = i64(days.floor())
	minutes = i64((days - whole) * 1440.0)
	.Str("08/{(17 + whole) % 30:02}/0201 {minutes / 60:02}:{minutes % 60:02}")

fn randomInt(mut rt Runtime, c NativeCall) Value:
	lo = c.arg(0).asInt()
	hi = c.arg(1).asInt() if c.args.len > 1 else 100
	.Int(rt.rng.nextInt(lo.min(hi), lo.max(hi) + 1))

fn randomFloat(mut rt Runtime, c NativeCall) Value:
	lo = c.argFloat(0)
	hi = c.argFloat(1) if c.args.len > 1 else 1.0
	if hi <= lo: return .Float(f32(lo))
	.Float(f32(rt.rng.nextFloat(lo, hi)))

# the native's default answer: the call logged, its return type's zero given back
fn stub(mut rt Runtime, c NativeCall) Value:
	args = c.args.map(rt.valueText(it)).join(", ")
	rt.note("stub: {c.key}({args})")
	if c.returnType.endsWith("[]"): return .None
	defaultOf(c.returnType)

# long: the table of natives, one arm per function
# the native function c names, run on the runtime
pub fn callNative(lib Library, mut rt Runtime, move c NativeCall) Value:
	match c.key:
		"debug.trace", "debug.tracestack", "debug.traceuser", "debug.traceconditional": rt.trace(c)
		"debug.notification", "debug.messagebox", "debug.traceandbox": rt.notify(c)
		"math.abs": .Float(c.arg(0).asFloat().abs())
		"math.acos": degrees(c.argFloat(0).acos())
		"math.asin": degrees(c.argFloat(0).asin())
		"math.atan": degrees(c.argFloat(0).atan())
		"math.ceiling": .Int(i64(c.argFloat(0).ceil()))
		"math.floor": .Int(i64(c.argFloat(0).floor()))
		"math.cos": .Float(f32(c.argFloat(0).radians().cos()))
		"math.sin": .Float(f32(c.argFloat(0).radians().sin()))
		"math.tan": .Float(f32(c.argFloat(0).radians().tan()))
		"math.degreestoradians": .Float(f32(c.argFloat(0).radians()))
		"math.radianstodegrees": degrees(c.argFloat(0))
		"math.pow": .Float(f32(c.argFloat(0).pow(c.argFloat(1))))
		"math.sqrt": .Float(f32(c.argFloat(0).sqrt()))
		"utility.wait", "utility.waitmenumode": rt.sleep(c.thread, c.argFloat(0))
		"utility.waitgametime": rt.sleep(c.thread, c.argFloat(0) * 3600.0 / rt.world.timeScale)
		"utility.randomint": rt.randomInt(c)
		"utility.randomfloat": rt.randomFloat(c)
		"utility.getcurrentrealtime": .Float(f32(rt.time))
		"utility.getcurrentgametime": .Float(f32(rt.world.daysPassed))
		"utility.isinmenumode": .Bool(false)
		"utility.gametimetostring": gameTimeText(c.argFloat(0))
		_: lib.formNative(rt, c)
