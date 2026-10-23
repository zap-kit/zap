# nsieve: primes up to 2^k * 10000 for k = n, n - 1, n - 2, by a sieve of one bit per number.
import problems

fn primesUpTo(m i64):
	candidates u64[] = fill(m / 64 + 1, ~0)
	count = 0
	for i in 2..=m:
		if candidates[i >> 6] & (1 << (i & 63)) != 0:
			count += 1
			for j in i * i..=m step i:
				candidates[j >> 6] &= ~(1 << (j & 63))
	count

n = arg(0, 2)
for k in 0..3:
	m = (1 << (n - k)) * 10_000
	print("Primes up to {m:>8} {primesUpTo(m):>8}")

test "the sieve of bits counts the primes below each bound":
	main()
	prints """
	    Primes up to    40000     4203
	    Primes up to    20000     2262
	    Primes up to    10000     1229
	    """

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("nsieve")
