// nsieve: primes up to 2^k * 10000 for k = n, n - 1, n - 2, by a sieve of one bit per number.
use std::io::Write;

fn primes_up_to(m: usize) -> usize {
    let mut candidates = vec![u64::MAX; m / 64 + 1];
    let mut count = 0;
    for i in 2..=m {
        if candidates[i >> 6] & (1u64 << (i & 63)) != 0 {
            count += 1;
            let mut j = i * i;
            while j <= m {
                candidates[j >> 6] &= !(1u64 << (j & 63));
                j += i;
            }
        }
    }
    count
}

fn main() {
    let n: usize = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(2);
    let mut out = std::io::stdout().lock();
    for k in 0..3 {
        let m = (1usize << (n - k)) * 10000;
        writeln!(out, "Primes up to {:>8} {:>8}", m, primes_up_to(m)).unwrap();
    }
}
