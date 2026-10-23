# raytrace: generated spheres seen from the origin, one ray per pixel of a w by w image, lit by a
# directional light with shadows; prints how many pixels hit a sphere, the sum of the pixels'
# shades and a hash of the image.
import problems

type Vec3:
	x f64
	y f64
	z f64

	fn dot(b Vec3):
		x * b.x + y * b.y + z * b.z

	fn unit():
		self * (1.0 / dot(self).sqrt())

type Sphere:
	center Vec3
	radius f64
	albedo f64

	# the distance along the ray to where it enters the sphere, negative when it misses
	fn hit(origin Vec3, dir Vec3):
		oc = origin - center
		b = oc @ dir
		disc = b * b - (oc @ oc - radius * radius)
		if disc < 0.0: return -1.0
		-b - disc.sqrt()

type Generator:
	state u64

	# the next number, 31 bits
	fn next():
		state = state * 6_364_136_223_846_793_005 + 1_442_695_040_888_963_407
		state >> 33

w = arg(0, 64)
mut random = Generator(state = 1)
mut spheres = []
loop 256:
	x = (random.next() % 2000) / 100.0 - 10.0
	y = (random.next() % 2000) / 100.0 - 10.0
	z = 10.0 + (random.next() % 3000) / 100.0
	radius = 0.3 + (random.next() % 200) / 100.0
	albedo = 0.3 + (random.next() % 70) / 100.0
	spheres.push(Sphere(center = Vec3(x, y, z), radius, albedo))
light = Vec3(-1.0, 1.0, -1.0).unit()
eye = Vec3(0.0, 0.0, 0.0)
mut image = []
mut hits = 0
for py in 0..w:
	for px in 0..w:
		u = (px + 0.5) / w * 2.0 - 1.0
		v = 1.0 - (py + 0.5) / w * 2.0
		dir = Vec3(u, v, 1.5).unit()
		nearest = -1
		best = 1e300
		for i, s in spheres:
			t = s.hit(eye, dir)
			if t > 1e-9 and t < best:
				best = t
				nearest = i
		shade = (0.5 + 0.5 * v) * 0.25
		if nearest >= 0:
			s = spheres[nearest]
			hits += 1
			p = eye + dir * best
			normal = (p - s.center) * (1.0 / s.radius)
			diffuse = normal @ light
			from = p + normal * 1e-4
			if diffuse > 0.0 and spheres.any(.hit(from, light) > 1e-9):
				diffuse = 0.0
			shade = s.albedo * (0.1 + 0.9 * diffuse.max(0.0))
		image.push(u8(shade * 255.0))
mut sum u64 = 0
mut hash u64 = 14_695_981_039_346_656_037
for b in image:
	sum += b
	hash = (hash ^ b) * 1_099_511_628_211
print("hits {hits}, shade sum {sum}, hash {hash:x}")

test "the traced image's hits, shades and hash are the known ones":
	main()
	prints """
		hits 3477, shade sum 262167, hash ad14f4d989dbed54
		"""

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("raytrace")
