# Pipelines: a block lambda as a step, lists typed by the place, and a named f32 function as a step.

test "a block lambda may end with a choice":
	xs = [1, 2, 3]
	print(xs.map(x:
		t = x * 2
		"big" if t > 2 else "small"
	))
	print(xs.map(x:
		t = x * 2
		("four" if t % 4 == 0 else "even") if t > 2 else "?"
	).join(", "))
	f = (x i64):
		y = x * x
		y if y > 3 else x
	print([f(1), f(2)])
	prints """
	    ["small", "big", "big"]
	    ?, four, even
	    [1, 4]
	    """

fn halfByte(v f32) u8:
	u8(v * 254.0)

test "a named function of an f32 as a step takes the element as a call written out does":
	xs f32[] = [0.5, 1.0]
	expect xs.map(halfByte) == [127, 254]
	expect xs.map(halfByte) == [127, 254]
