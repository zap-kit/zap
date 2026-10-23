# raytrace: generated spheres seen from the origin, one ray per pixel of a w by w image, lit by a
# directional light with shadows; prints how many pixels hit a sphere, the sum of the pixels'
# shades and a hash of the image. Same operation order as the C program (no fused multiply-add).
import sys
from math import sqrt

MASK = (1 << 64) - 1
SPHERES = 256
state = 1


def next_number():
    global state
    state = (state * 6364136223846793005 + 1442695040888963407) & MASK
    return state >> 33


w = int(sys.argv[1]) if len(sys.argv) > 1 else 64
spheres = []
for _ in range(SPHERES):
    cx = (next_number() % 2000) / 100.0 - 10.0
    cy = (next_number() % 2000) / 100.0 - 10.0
    cz = 10.0 + (next_number() % 3000) / 100.0
    radius = 0.3 + (next_number() % 200) / 100.0
    albedo = 0.3 + (next_number() % 70) / 100.0
    spheres.append((cx, cy, cz, radius, albedo))
# for the eye at the origin: oc is minus the center, and dot(oc, oc) - r * r does not depend on the ray
eye_spheres = []
for cx, cy, cz, radius, albedo in spheres:
    ox, oy, oz = 0.0 - cx, 0.0 - cy, 0.0 - cz
    eye_spheres.append((ox, oy, oz, (ox * ox + oy * oy + oz * oz) - radius * radius))

lx, ly, lz = -1.0, 1.0, -1.0
k = 1.0 / sqrt(lx * lx + ly * ly + lz * lz)
lx, ly, lz = lx * k, ly * k, lz * k

image = bytearray(w * w)
hits = 0
for py in range(w):
    v = 1.0 - (py + 0.5) / w * 2.0
    for px in range(w):
        u = (px + 0.5) / w * 2.0 - 1.0
        k = 1.0 / sqrt(u * u + v * v + 1.5 * 1.5)
        dx, dy, dz = u * k, v * k, 1.5 * k
        best = float("inf")
        nearest = -1
        i = 0
        for ox, oy, oz, c in eye_spheres:
            b = ox * dx + oy * dy + oz * dz
            disc = b * b - c
            if disc >= 0.0:
                t = -b - sqrt(disc)
                if 1e-9 < t < best:
                    best = t
                    nearest = i
            i += 1
        shade = (0.5 + 0.5 * v) * 0.25
        if nearest >= 0:
            hits += 1
            cx, cy, cz, radius, albedo = spheres[nearest]
            qx, qy, qz = 0.0 + dx * best, 0.0 + dy * best, 0.0 + dz * best
            r = 1.0 / radius
            nx, ny, nz = (qx - cx) * r, (qy - cy) * r, (qz - cz) * r
            diffuse = nx * lx + ny * ly + nz * lz
            if diffuse > 0.0:
                fx, fy, fz = qx + nx * 1e-4, qy + ny * 1e-4, qz + nz * 1e-4
                for sx, sy, sz, sr, _ in spheres:
                    ox, oy, oz = fx - sx, fy - sy, fz - sz
                    b = ox * lx + oy * ly + oz * lz
                    disc = b * b - ((ox * ox + oy * oy + oz * oz) - sr * sr)
                    if disc >= 0.0 and -b - sqrt(disc) > 1e-9:
                        diffuse = 0.0
                        break
            else:
                diffuse = 0.0
            shade = albedo * (0.1 + 0.9 * diffuse)
        image[py * w + px] = int(shade * 255.0)
h = 14695981039346656037
for p in image:
    h = ((h ^ p) * 1099511628211) & MASK
sys.stdout.buffer.write(b"hits %d, shade sum %d, hash %x\n" % (hits, sum(image), h))
