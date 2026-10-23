# Animation curves: sampled between their keys and played by their timing.

import engine

fn rising(interpolation i64):
	engine.Curve(interpolation, times = [0.0, 1.0],
		values = [Vec4(0.0, 0.0, 0.0, 0.0), Vec4(10.0, 0.0, 0.0, 0.0)])

test "a curve is straight, held or along its tangents between keys, and held past its ends":
	linear = rising(engine.curveLinear)
	held = rising(engine.curveConstant)
	flat = rising(engine.curveTbc)
	flat.tbcTangents([Vec3(1.0, 0.0, 0.0), Vec3(1.0, 0.0, 0.0)])
	print("{linear.sampleCurve(0.25).x} {held.sampleCurve(0.75).x} {flat.sampleCurve(0.5).x} {linear.sampleCurve(-1.0).x} {linear.sampleCurve(2.0).x}")
	prints "2.5 0 5 0 10"

test "a timing loops, goes back and forth, or holds its ends":
	out = []
	for cycle in [0, 1, 2]:
		out.push(engine.CurveTiming(start = 0.0, stop = 2.0, cycle).curveTime(2.5))
	print(out)
	prints "[0.5, 1.5, 2]"
