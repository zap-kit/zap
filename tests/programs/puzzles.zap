# Classic puzzles: N-queens, Towers of Hanoi, Sieve of Eratosthenes, Fibonacci, Pascal's triangle,
# Roman numerals, matrix multiplication, Dijkstra on a small graph.

import fs

fn queens(n i64, row i64, mut cols i64[]) i64:
	if row == n: return 1
	count = 0
	for c in 0..n:
		ok = true
		for r in 0..row:
			d = cols[r] - c
			if d in [0, row - r, r - row]:
				ok = false
		if ok:
			cols.push(c)
			count += queens(n, row + 1, cols)
			cols.pop()
	count

fn hanoi(n i64, src str, dst str, via str, mut moves str[]):
	if n == 0: return
	hanoi(n - 1, src, via, dst, moves)
	moves.push("{src}>{dst}")
	hanoi(n - 1, via, dst, src, moves)

fn sieve(limit i64):
	composite = []
	loop (limit + 1):
		composite.push(false)
	primes = []
	for i in 2..=(limit):
		if not composite[i]:
			primes.push(i)
			j = i + i
			while j <= limit:
				composite[j] = true
				j += i
	primes

fn fibRec(n i64) i64:
	if n < 2: return n
	fibRec(n - 1) + fibRec(n - 2)

fn roman(n0 i64):
	values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	symbols = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	n = n0
	out = ""
	for i, value in values:
		while n >= value:
			out += symbols[i]
			n -= value
	out

fn matMul(a i64[,], b i64[,]):
	out = []
	for i in 0..a.len:
		row = []
		for j in 0..b[0].len:
			s = 0
			for k in 0..b.len:
				s += a[i][k] * b[k][j]
			row.push(s)
		out.push(row)
	out

fn dijkstra(n i64, edges i64[,], source i64):
	inf = 1_000_000
	dist = []
	done = []
	loop n:
		dist.push(inf)
		done.push(false)
	dist[source] = 0
	loop n:
		u = -1
		for v in 0..n:
			if not done[v] and (u < 0 or dist[v] < dist[u]):
				u = v
		if u < 0 or dist[u] == inf: break
		done[u] = true
		for e in edges:
			if e[0] == u and dist[u] + e[2] < dist[e[1]]:
				dist[e[1]] = dist[u] + e[2]
	dist

for n in [4, 5, 6, 8]:
	cols = []
	print("{n}-queens: {queens(n, 0, cols)} solutions")
mut moves = []
hanoi(4, "A", "C", "B", moves)
print(
	"hanoi 4: {moves.len} moves, first {moves[..5].join(" ")}, last {moves[len - 1]}"
)
mut big = []
hanoi(16, "A", "C", "B", big)
print("hanoi 16: {big.len} moves")
primes = sieve(100)
print("primes to 100: {primes.map("{it}").join(" ")}")
print("primes below 100000: {sieve(100000).len}")
mut fibs = []
mut a i64 = 0
mut b i64 = 1
for i in 0..92:
	fibs.push(a)
	if i < 91:
		t = a + b
		a = b
		b = t
print("fib(91) = {fibs[91]}, fibRec(25) = {fibRec(25)}")
mut row = [1]
loop 8:
	print(row.map("{it}").join(" "))
	next = [1]
	for j in 1..row.len:
		next.push(row[j - 1] + row[j])
	next.push(1)
	row = next
for n in [1, 4, 9, 14, 40, 90, 400, 1994, 2024, 3999]:
	print("{n} = {roman(n)}")
m = matMul([[1, 2, 3], [4, 5, 6]], [[7, 8], [9, 10], [11, 12]])
print("matrix: {m.map(.map("{it}").join(",")).join(" | ")}")
mut p i64[,] = [[1, 1], [1, 0]]
loop 30:
	p = matMul(p, [[1, 1], [1, 0]])
print("fib via matrix power: {p[0][1]}")
edges = [
	[0, 1, 7],
	[0, 2, 9],
	[0, 5, 14],
	[1, 2, 10],
	[1, 3, 15],
	[2, 3, 11],
	[2, 5, 2],
	[3, 4, 6],
	[5, 4, 9]
]
mut both = []
for e in edges:
	both.push([e[0], e[1], e[2]])
	both.push([e[1], e[0], e[2]])
print("dijkstra: {dijkstra(6, both, 0).map("{it}").join(" ")}")

test "the classic puzzles print their known answers":
	main()
	prints fs.readFile("tests/programs/puzzles.expected") ?? ""
