# util module: plain helpers. Only `pub` items are visible to importers.

pub fn clamp(v i64, lo i64, hi i64) i64:
	if v < lo: return lo
	if v > hi: return hi
	v

pub fn manhattan(ax i64, ay i64, bx i64, by i64) i64:
	(ax - bx).abs() + (ay - by).abs()

fn secret():
	42

pub fn revealed() i64:
	secret()

# a module variable of the same name as one of the main module: each module keeps its own
mut total = 0

pub fn addToTotal(n i64) i64:
	total += n
	total

# a local whose name is a module variable of the main module only: a new binding here
pub fn tripled(n i64) i64:
	count = n * 3
	count
