# Sorting and searching: a deterministic LCG, bubble sort, quicksort, merge sort, binary search;
# and the same sorts in place, over a mutable list.
fn lcg(seed i64):
	(seed * 1_103_515_245 + 12_345) % 2_147_483_648

fn bubble(xs0 i64[]):
	xs = xs0.copy()
	n = xs.len
	swapped = true
	while swapped:
		swapped = false
		for i in 1..n:
			if xs[i - 1] > xs[i]:
				t = xs[i - 1]
				xs[i - 1] = xs[i]
				xs[i] = t
				swapped = true
	xs

fn quick(xs i64[]) i64[]:
	if xs.len <= 1: return xs.copy()
	pivot = xs[len / 2]
	less = xs.filter(it < pivot)
	equal = xs.filter(it == pivot)
	greater = xs.filter(it > pivot)
	out = quick(less)
	for x in equal:
		out.push(x)
	for x in quick(greater):
		out.push(x)
	out

fn merge(a i64[], b i64[]):
	out = []
	i = 0
	j = 0
	while i < a.len and j < b.len:
		if a[i] <= b[j]:
			out.push(a[i])
			i += 1
		else:
			out.push(b[j])
			j += 1
	while i < a.len:
		out.push(a[i])
		i += 1
	while j < b.len:
		out.push(b[j])
		j += 1
	out

fn mergeSort(xs i64[]) i64[]:
	if xs.len <= 1: return xs.copy()
	mid = xs.len / 2
	merge(mergeSort(xs[..mid]), mergeSort(xs[mid..]))

fn binarySearch(xs i64[], target i64):
	lo = 0
	hi = xs.len - 1
	while lo <= hi:
		mid = (lo + hi) / 2
		if xs[mid] == target: return mid
		if xs[mid] < target:
			lo = mid + 1
		else:
			hi = mid - 1
	-1

fn show(xs i64[]):
	xs.map("{it}").join(" ")

mut seed i64 = 42
mut xs i64[] = []
loop 20:
	seed = lcg(seed)
	xs.push(seed % 1000)
print("input:   {show(xs)}")
print("bubble:  {show(bubble(xs))}")
print("quick:   {show(quick(xs))}")
print("merge:   {show(mergeSort(xs))}")
print("builtin: {show(xs.sorted())}")
sorted = xs.sorted()
for t in [sorted[0], sorted[7], sorted[19], 500]:
	print("search {t}: {binarySearch(sorted, t)}")
mut big i64[] = []
loop 5000:
	seed = lcg(seed)
	big.push(seed % 100_000)
s = mergeSort(big)
q = quick(big)
mut same = true
mut sum i64 = 0
for i in 0..s.len:
	if s[i] != q[i]:
		same = false
	sum += s[i]
print("5000 elements: min {s[0]} max {s[4999]} sum {sum} agree {same}")

test "the sorts and the binary search order and find as the reference does":
	main()
	prints """
	    input:   27 264 753 806 735 532 333 266 459 752 865 142 703 436 613 914 219 0 153 758
	    bubble:  0 27 142 153 219 264 266 333 436 459 532 613 703 735 752 753 758 806 865 914
	    quick:   0 27 142 153 219 264 266 333 436 459 532 613 703 735 752 753 758 806 865 914
	    merge:   0 27 142 153 219 264 266 333 436 459 532 613 703 735 752 753 758 806 865 914
	    builtin: 0 27 142 153 219 264 266 333 436 459 532 613 703 735 752 753 758 806 865 914
	    search 0: 0
	    search 333: 7
	    search 914: 19
	    search 500: -1
	    5000 elements: min 31 max 99980 sum 249956132 agree true
	    """

fn swap(mut xs i64[], i i64, j i64):
	t = xs[i]
	xs[i] = xs[j]
	xs[j] = t

fn bubbleInPlace(mut xs i64[]):
	n = xs.len
	for i in 0..n:
		for j in 0..n - i - 1:
			if xs[j] > xs[j + 1]:
				swap(xs, j, j + 1)

fn quickInPlace(mut xs i64[], lo i64, hi i64):
	if lo >= hi: return
	pivot = xs[hi]
	i = lo
	for j in lo..hi:
		if xs[j] < pivot:
			swap(xs, i, j)
			i += 1
	swap(xs, i, hi)
	quickInPlace(xs, lo, i - 1)
	quickInPlace(xs, i + 1, hi)

test "sorting in place":
	a = [5, 3, 9, 1, 7, 2]
	bubbleInPlace(a)
	print(a)
	b = [5, 3, 9, 1, 7, 2, 8, 6, 4]
	quickInPlace(b, 0, b.len - 1)
	print(b)
	print(b.reversed())
	print(b.sortedBy(-it))
	print("{b.indexOf(9)} {b.max() ?? 0} {b.min() ?? 0}")
	print(b[2..5])
	prints """
	    [1, 2, 3, 5, 7, 9]
	    [1, 2, 3, 4, 5, 6, 7, 8, 9]
	    [9, 8, 7, 6, 5, 4, 3, 2, 1]
	    [9, 8, 7, 6, 5, 4, 3, 2, 1]
	    some(8) 9 1
	    [3, 4, 5]
	    """
