# Expressions over named numbers.

import engine

test "an expression is evaluated in C's order over its names":
	names {str: f32} = {}
	names["speed"] = 7.0
	names["blocked"] = 0.0
	names["w"] = 0.25
	out = [
		engine.evaluate("(speed > 5) && !blocked", names),
		engine.evaluate("speed == 7 || blocked", names),
		engine.evaluate("clamp((1 - 2*w), 0 , 1)", names),
		engine.evaluate("1 + 2 * 3 - 4 / 2", names),
		engine.evaluate("speed <= 6 || missing", names),
		engine.evaluate("", names)
	]
	print(out)
	prints "[1, 1, 0.5, 5, 0, 0]"
