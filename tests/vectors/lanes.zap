# Loops that only assign f64 elements from elements of the same step and fixed numbers run four
# steps at a time, then the steps left one by one: every length, every operator, a list read
# where it is written, and loops that must stay one step at a time (a list read at another
# index than it is written) give what the steps one by one give.

fn ramp(n i64, scale f64):
	xs f64[] = zeros(n)
	for i in 0..n:
		xs[i] = (i + 1) * scale
	xs

fn axpy(n i64):
	a = ramp(n, 0.5)
	b = ramp(n, 2.0)
	c = ramp(n, 1.0)
	k = 3.0
	for j in 0..n:
		c[j] += k * a[j] - b[j] / 4.0
	c

fn operators(n i64):
	a = ramp(n, 1.5)
	c = ramp(n, 1.0)
	for j in 0..n:
		c[j] -= a[j]
		c[j] *= 2.0
		c[j] /= a[j] + 1.0
		c[j] += 1.0 / a[j]
	c

# row i of a flat n by n matrix scaled into another, from column 1 on
fn rows(n i64):
	m = ramp(n * n, 0.25)
	out f64[] = zeros(n * n)
	for i in 0..n:
		f = f64(i + 1)
		for j in 1..n:
			out[i * n + j] = m[i * n + j] * f + m[j]
	out

# a shift reads what an earlier step wrote: one step at a time
fn shifted(n i64):
	xs = ramp(n, 1.0)
	for j in 0..n - 1:
		xs[j + 1] = xs[j] * 2.0
	xs

fn total(xs f64[]):
	t = 0.0
	for x in xs:
		t += x
	t

test "four steps at a time give what one at a time gives":
	for n in [1, 3, 4, 5, 9]:
		print("{n} {total(axpy(n))}")
	for n in [1, 7, 12]:
		print("{n} {total(operators(n))}")
	for n in [3, 6]:
		print("{n} {total(rows(n))}")
	for n in [1, 9]:
		print("{n} {total(shifted(n))}")
	prints """
		1 2
		3 12
		4 20
		5 30
		9 90
		1 0.2666666666666666
		7 -2.0852426346032487
		12 -4.866231590864437
		3 23.25
		6 660
		1 1
		9 511
		"""
