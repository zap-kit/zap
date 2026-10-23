# Recursion that builds results: permutations, fibonacci memo (towers of hanoi: puzzles.zap).
fn permutations(move items i64[]) i64[,]:
	if items.len <= 1: return [items]
	result = []
	for i in 0..items.len:
		rest = []
		for j, item in items:
			if j != i:
				rest.push(item)
		for p in permutations(rest):
			full = [items[i]]
			for x in p:
				full.push(x)
			result.push(full)
	result
fn fibMemo(n i64, mut memo {i64: i64}) i64:
	if n < 2: return n
	match memo.get(n):
		v: return v
		none:
			v = fibMemo(n - 1, memo) + fibMemo(n - 2, memo)
			memo[n] = v
			return v
perms = permutations([1, 2, 3])
print(perms.len)
for p in perms:
	print(p)
mut memo {i64: i64} = {}
print(fibMemo(80, memo))

test "permutations and memo":
	main()
	prints """
	    6
	    [1, 2, 3]
	    [1, 3, 2]
	    [2, 1, 3]
	    [2, 3, 1]
	    [3, 1, 2]
	    [3, 2, 1]
	    23416728348467685
	    """
