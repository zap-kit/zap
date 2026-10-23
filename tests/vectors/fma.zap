# x * y + z, x * y - z and z - x * y of Simd<4, f64> under `use fusedMultiplyAdd`, each rounded once (spec 3.1)
use fusedMultiplyAdd
xs f64[] = [1.0, 2.0, 3.0, 4.0]
ys f64[] = [2.0, 2.0, 2.0, 2.0]
zs f64[] = [1.0, 1.0, 1.0, 1.0]
x = xs.load4(0)
y = ys.load4(0)
z = zs.load4(0)
a = x * y + z
b = x * y - z
c = z - x * y
mut out f64[] = zeros(12)
out.store4(0, a)
out.store4(4, b)
out.store4(8, c)
print("{out}")
mut acc = z
loop 3:
	acc += x * y
out.store4(0, acc)
print("{out[..4]}")

test "a fused multiply-add rounds once":
	main()
	prints """
	    [3, 5, 7, 9, 1, 3, 5, 7, -1, -3, -5, -7]
	    [7, 13, 19, 25]
	    """
