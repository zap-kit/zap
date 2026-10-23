# arg(i, default): the i-th argument as the default's type; spec/modules.zap states it.

test "every number type reads its argument, a literal default taking the type of its place":
	args.set(["-5", "250", "70000", "1.25", "0x10"])
	a i8 = arg(0, 1)
	b u8 = arg(1, 1)
	c u32 = arg(2, 1)
	d f32 = arg(3, 1)
	e = arg(4, 1)
	print("{a} {b} {c} {d} {e}")
	prints "-5 250 70000 1.25 16"

test "a missing argument gives the default, whatever its position":
	args.set([])
	expect arg == {(0, 7): 7, (3, -1.5): -1.5, (-1, "none"): "none", (2, ""): ""}

test "an argument that does not fit its type stops the program" stops Failure("argument 0 is not a number: 300"):
	args.set(["300"])
	x u8 = arg(0, 1)
	print(x)

test "an empty argument given is not the default" stops Failure("argument 0 is not a number: "):
	args.set([""])
	print(arg(0, 5))
