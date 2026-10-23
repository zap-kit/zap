k = 7
low = -3
half = 0.5
h = 2

fn narrow(x i32):
	x

fn single(x f32):
	x

test "a number constant with no type takes the type the place asks for":
	expect narrow(k) == 7
	expect narrow(low) == -3
	expect single(half) == 0.5
	expect h == 2
