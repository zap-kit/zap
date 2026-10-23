# Programs the type checker refuses: mismatched types, literals out of range, missing arms.

test "values of two types in one operation are refused" refuses MixedTypes:
	a u32 = 1
	b i32 = 2
	print(a + b)
