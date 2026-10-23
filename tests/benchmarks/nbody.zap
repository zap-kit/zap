# n-body: the Jovian planets integrated with a symplectic step; prints the energy before and after
# n steps. Positions and velocities are Simd<4, f64> lanes (0, x, y, z) in registers; the ten pairs'
# 1/sqrt come four at a time (sums4, the hardware estimate refined to double precision); updates
# are fused multiply-adds.
import problems

use fusedMultiplyAdd

solarMass = 39.47841760435743
daysPerYear = 365.24

# the total energy: kinetic, less the potential of every pair
fn energy(p Simd<4, f64>[], v Simd<4, f64>[], ms f64[]):
	e = 0.0
	for i in 0..5:
		e += 0.5 * ms[i] * (v[i] * v[i]).sum()
		for j in 0..i:
			r = p[i] - p[j]
			e -= ms[i] * ms[j] / (r * r).sum().sqrt()
	e

n = arg(0, 1000)
ms f64[] = [solarMass, 9.54791938424326609e-04 * solarMass, 2.85885980666130812e-04 * solarMass,
	4.36624404335156298e-05 * solarMass, 5.15138902046611451e-05 * solarMass]
mut p Simd<4, f64>[5] = [
	Simd<4>(0.0),
	Simd<4>(0.0, 4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01),
	Simd<4>(0.0, 8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01),
	Simd<4>(0.0, 1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01),
	Simd<4>(0.0, 1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01)]
mut v Simd<4, f64>[5] = [
	Simd<4>(0.0),
	Simd<4>(0.0, 1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05) * daysPerYear,
	Simd<4>(0.0, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05) * daysPerYear,
	Simd<4>(0.0, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05) * daysPerYear,
	Simd<4>(0.0, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05) *
		daysPerYear]
m Simd<4, f64>[5] = [Simd<4>(ms[0]), Simd<4>(ms[1]), Simd<4>(ms[2]), Simd<4>(ms[3]), Simd<4>(ms[4])]
# offset momentum
v[0] = (m[1] * v[1] + m[2] * v[2] + m[3] * v[3] + m[4] * v[4]) * (-1.0 / solarMass)
print("{energy([p[0], p[1], p[2], p[3], p[4]], [v[0], v[1], v[2], v[3], v[4]], ms):.9}")
dt = Simd<4>(0.01)
c375 = Simd<4>(0.375)
c125 = Simd<4>(1.25)
c1875 = Simd<4>(1.875)
# the ten pairs (i, j), j < i
pairI i64[10] = [1, 2, 2, 3, 3, 3, 4, 4, 4, 4]
pairJ i64[10] = [0, 0, 1, 0, 1, 2, 0, 1, 2, 3]
one = Simd<4>(1.0)
loop n:
	# w = dt / d^3 for four pairs at a time: their squared distances summed lane by lane
	# (the last group padded with ones), 1/sqrt from the hardware estimate refined once
	w Simd<4, f64>[3]
	for q in 0..3:
		s Simd<4, f64>[4]
		for g in 0..4:
			k = 4 * q + g
			if k < 10:
				r = p[pairI[k]] - p[pairJ[k]]
				s[g] = r * r
			else:
				s[g] = one
		d = s[0].sums4(s[1], s[2], s[3])
		x = d.rsqrtEstimate()
		y = d * x * x
		z = x * (y * c375 * y - (y * c125 - c1875))
		w[q] = z * z * (z * dt)
	for k in 0..10:
		i = pairI[k]
		j = pairJ[k]
		t = (p[i] - p[j]) * w[k / 4].spread(k % 4)
		v[i] -= t * m[j]
		v[j] += t * m[i]
	for i in 0..5:
		p[i] += v[i] * dt
print("{energy([p[0], p[1], p[2], p[3], p[4]], [v[0], v[1], v[2], v[3], v[4]], ms):.9}")

test "the planets' energy before and after the steps is the reference's":
	main()
	prints """
	    -0.169075164
	    -0.169087605
	    """

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("nbody")
