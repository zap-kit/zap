# Libraries loaded while a program runs, on Linux: a function of the C library, of its math library
# and one found by name (dlopen and dlsym through win), called by the System V or AAPCS64
# convention, a library that is missing stopping the program only at the call that needs it.
# host: linux (the libraries are Linux's)

import win

extern "libm.so.6" fn cos(x f64) f64
extern "libm.so.6" fn powf(x f32, y f32) f32
extern "libc.so.6" fn strlen(text str) i64
extern "libc.so.6" fn abs(x i32) i32
extern "libc.so.6" fn snprintf(
	into u8[],
	size i64,
	format str,
	a i64,
	b i64,
	c i64,
	d i64,
	e i64,
	f i64,
	g i64
) i32
extern "libmissing.so.9" fn nothing() i64
extern loaded fn sine(x f64) f64
extern loaded fn square(x f64) f64

test "a function of a library is found at its first call and takes floats, ints and text":
	expect cos(0.0) == 1.0
	expect powf(2.0, 10.0) == 1024.0
	expect strlen("hello\0") == 5
	expect abs(-5) == 5

test "arguments past the registers go on the stack":
	into u8[] = zeros(64)
	n = snprintf(into, 64, "%d %d %d %d %d %d %d\0", 1, 2, 3, 4, 5, 6, 7)
	expect str(into[..n]) == "1 2 3 4 5 6 7"

test "a function loaded by name is bound and called":
	library = win.LoadLibraryA("libm.so.6\0")
	expect library != 0
	bindExtern(sine, win.GetProcAddress(library, "sin\0"))
	expect sine(0.0) == 0.0
	expect win.GetProcAddress(library, "nothing_in_libm\0") == 0

test "threads call a library one at a time, the first call finding the function":
	jobs = []
	for k in 0..8:
		jobs.push(background((): strlen("hello world\0") + i64(cos(0.0)) + k))
	total = 0
	for job in 0..jobs.len:
		loop:
			match jobs[job].tryReceive():
				value:
					total += value
					break
				none:
					sleepMs(1)
	expect total == 8 * 12 + 28

test "a library that is missing stops the program at the call" stops Failure("extern fn nothing is a function of libmissing.so.9, which this machine does not have"):
	print(nothing())

test "an extern loaded fn without an address stops the program at the call" stops Failure("extern fn square has no address: bindExtern or bindExterns did not give it one"):
	print(square(2.0))
