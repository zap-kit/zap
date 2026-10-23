# The C runtime functions an executable imports, run for it: the math of api-ms-win-crt-math
# called in this machine's ucrtbase.dll, so a result is the bits the platform gives the game, and
# the memory functions of vcruntime140 on the emulated memory. Any other import stops the run with
# its name, unless the caller stubs it (machine.zap's Stub).

extern "ucrtbase.dll" fn sinf(x f32) f32
extern "ucrtbase.dll" fn cosf(x f32) f32
extern "ucrtbase.dll" fn tanf(x f32) f32
extern "ucrtbase.dll" fn asinf(x f32) f32
extern "ucrtbase.dll" fn acosf(x f32) f32
extern "ucrtbase.dll" fn atanf(x f32) f32
extern "ucrtbase.dll" fn atan2f(y f32, x f32) f32
extern "ucrtbase.dll" fn expf(x f32) f32
extern "ucrtbase.dll" fn logf(x f32) f32
extern "ucrtbase.dll" fn log10f(x f32) f32
extern "ucrtbase.dll" fn powf(x f32, y f32) f32
extern "ucrtbase.dll" fn sqrtf(x f32) f32
extern "ucrtbase.dll" fn fmodf(x f32, y f32) f32
extern "ucrtbase.dll" fn floorf(x f32) f32
extern "ucrtbase.dll" fn ceilf(x f32) f32
extern "ucrtbase.dll" fn fminf(x f32, y f32) f32
extern "ucrtbase.dll" fn sin(x f64) f64
extern "ucrtbase.dll" fn cos(x f64) f64
extern "ucrtbase.dll" fn tan(x f64) f64
extern "ucrtbase.dll" fn asin(x f64) f64
extern "ucrtbase.dll" fn acos(x f64) f64
extern "ucrtbase.dll" fn atan(x f64) f64
extern "ucrtbase.dll" fn atan2(y f64, x f64) f64
extern "ucrtbase.dll" fn exp(x f64) f64
extern "ucrtbase.dll" fn log(x f64) f64
extern "ucrtbase.dll" fn log2(x f64) f64
extern "ucrtbase.dll" fn pow(x f64, y f64) f64
extern "ucrtbase.dll" fn sqrt(x f64) f64
extern "ucrtbase.dll" fn fmod(x f64, y f64) f64
extern "ucrtbase.dll" fn floor(x f64) f64
extern "ucrtbase.dll" fn ceil(x f64) f64

fn single(m Machine, k i64):
	f32.fromBits(u32.wrap(m.lo(k)))

fn double(m Machine, k i64):
	f64.fromBits(m.lo(k))

# the C runtime function `name` run on the arguments in the registers, its result set; false for
# one not run here
pub fn runCrt(mut m Machine, name str) bool:
	x = m.single(0)
	y = m.single(1)
	a = m.double(0)
	b = m.double(1)
	f f32? = match name:
		"sinf": sinf(x)
		"cosf": cosf(x)
		"tanf": tanf(x)
		"asinf": asinf(x)
		"acosf": acosf(x)
		"atanf": atanf(x)
		"atan2f": atan2f(x, y)
		"expf": expf(x)
		"logf": logf(x)
		"log10f": log10f(x)
		"powf": powf(x, y)
		"sqrtf": sqrtf(x)
		"fmodf": fmodf(x, y)
		"floorf": floorf(x)
		"ceilf": ceilf(x)
		"fminf": fminf(x, y)
		_: none
	if f is v:
		m.setXmm(0, v.toBits(), 0)
		return true
	g f64? = match name:
		"sin": sin(a)
		"cos": cos(a)
		"tan": tan(a)
		"asin": asin(a)
		"acos": acos(a)
		"atan": atan(a)
		"atan2": atan2(a, b)
		"exp": exp(a)
		"log": log(a)
		"log2": log2(a)
		"pow": pow(a, b)
		"sqrt": sqrt(a)
		"fmod": fmod(a, b)
		"floor": floor(a)
		"ceil": ceil(a)
		_: none
	if g is v:
		m.setXmm(0, v.toBits(), 0)
		return true
	m.runMemoryCrt(name)

# memset, memcpy, memmove, memcmp on the emulated memory
fn runMemoryCrt(mut m Machine, name str):
	dst = m.regs[1]
	src = m.regs[2]
	n = i64(m.regs[8])
	match name:
		"memset":
			for k in 0..n:
				m.mem.write(dst + u64(k), 1, src)
			m.regs[0] = dst
		"memcpy", "memmove":
			copied = m.mem.bytes(src, n)
			m.mem.put(dst, copied)
			m.regs[0] = dst
		"memcmp":
			m.regs[0] = 0
			for k in 0..n:
				p = m.mem.read(dst + u64(k), 1)
				q = m.mem.read(src + u64(k), 1)
				if p != q:
					m.regs[0] = 1 if p > q else ~u64(0)
					break
		_: return false
	true
