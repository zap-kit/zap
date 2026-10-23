
# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
#
# contributed by Joerg Baumann

from contextlib import closing
from itertools import islice
from os import cpu_count
from sys import argv, stdout

def pixels(y, n, abs):
    range7 = bytearray(range(7))
    pixel_bits = bytearray(128 >> pos for pos in range(8))
    ci = 2.0 * y / n - 1.0
    x = 0
    while True:
        pixel = 0
        for pixel_bit in pixel_bits:
            c = complex(2.0 * x / n - 1.5, ci)
            x += 1
            z = c
            for _ in range7:
                for _ in range7:
                    z = z * z + c
                if z.real * z.real + z.imag * z.imag > 4.0: break
            else:
                pixel += pixel_bit
        yield pixel

def compute_row(p):
    y, n = p

    result = bytearray(islice(pixels(y, n, abs), (n + 7) // 8))
    result[-1] &= 0xff << (-n % 8) & 0xff
    return y, result

def ordered_rows(rows, n):
    order = [None] * n
    i = 0
    j = n
    while i < len(order):
        if j > 0:
            row = next(rows)
            order[row[0]] = row
            j -= 1

        if order[i]:
            yield order[i]
            order[i] = None
            i += 1

def compute_rows(n, f):
    row_jobs = ((y, n) for y in range(n))

    if cpu_count() < 2:
        yield from map(f, row_jobs)
    else:
        from multiprocessing import Pool
        with Pool() as pool:
            unordered_rows = pool.imap_unordered(f, row_jobs)
            yield from ordered_rows(unordered_rows, n)

def mandelbrot(n):
    write = stdout.buffer.write

    with closing(compute_rows(n, compute_row)) as rows:
        write("P4\n{0} {0}\n".format(n).encode())
        for row in rows:
            write(row[1])

if __name__ == '__main__':
    mandelbrot(int(argv[1]))
    