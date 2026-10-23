// raytrace: generated spheres seen from the origin, one ray per pixel of a w by w image, lit by a
// directional light with shadows; prints how many pixels hit a sphere, the sum of the pixels'
// shades and a hash of the image.
use std::ops::{Add, Mul, Sub};

#[derive(Clone, Copy)]
struct Vec3 {
    x: f64,
    y: f64,
    z: f64,
}

impl Add for Vec3 {
    type Output = Vec3;
    fn add(self, b: Vec3) -> Vec3 {
        Vec3 { x: self.x + b.x, y: self.y + b.y, z: self.z + b.z }
    }
}

impl Sub for Vec3 {
    type Output = Vec3;
    fn sub(self, b: Vec3) -> Vec3 {
        Vec3 { x: self.x - b.x, y: self.y - b.y, z: self.z - b.z }
    }
}

impl Mul<f64> for Vec3 {
    type Output = Vec3;
    fn mul(self, k: f64) -> Vec3 {
        Vec3 { x: self.x * k, y: self.y * k, z: self.z * k }
    }
}

impl Vec3 {
    fn dot(self, b: Vec3) -> f64 {
        self.x * b.x + self.y * b.y + self.z * b.z
    }

    fn unit(self) -> Vec3 {
        self * (1.0 / self.dot(self).sqrt())
    }
}

struct Sphere {
    center: Vec3,
    radius: f64,
    albedo: f64,
}

impl Sphere {
    // the distance along the ray to where it enters the sphere, negative when it misses
    fn hit(&self, origin: Vec3, dir: Vec3) -> f64 {
        let oc = origin - self.center;
        let b = oc.dot(dir);
        let disc = b * b - (oc.dot(oc) - self.radius * self.radius);
        if disc < 0.0 {
            return -1.0;
        }
        -b - disc.sqrt()
    }
}

struct Generator(u64);

impl Generator {
    // the next number, 31 bits
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 33
    }
}

fn main() {
    let w: usize = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(64);
    let mut random = Generator(1);
    let spheres: Vec<Sphere> = (0..256)
        .map(|_| {
            let x = (random.next() % 2000) as f64 / 100.0 - 10.0;
            let y = (random.next() % 2000) as f64 / 100.0 - 10.0;
            let z = 10.0 + (random.next() % 3000) as f64 / 100.0;
            let radius = 0.3 + (random.next() % 200) as f64 / 100.0;
            let albedo = 0.3 + (random.next() % 70) as f64 / 100.0;
            Sphere { center: Vec3 { x, y, z }, radius, albedo }
        })
        .collect();
    let light = Vec3 { x: -1.0, y: 1.0, z: -1.0 }.unit();
    let eye = Vec3 { x: 0.0, y: 0.0, z: 0.0 };
    let mut image = vec![0u8; w * w];
    let mut hits = 0;
    for py in 0..w {
        for px in 0..w {
            let u = (px as f64 + 0.5) / w as f64 * 2.0 - 1.0;
            let v = 1.0 - (py as f64 + 0.5) / w as f64 * 2.0;
            let dir = Vec3 { x: u, y: v, z: 1.5 }.unit();
            let mut nearest: Option<&Sphere> = None;
            let mut best = f64::INFINITY;
            for s in &spheres {
                let t = s.hit(eye, dir);
                if t > 1e-9 && t < best {
                    best = t;
                    nearest = Some(s);
                }
            }
            let mut shade = (0.5 + 0.5 * v) * 0.25;
            if let Some(s) = nearest {
                hits += 1;
                let p = eye + dir * best;
                let normal = (p - s.center) * (1.0 / s.radius);
                let mut diffuse = normal.dot(light);
                if diffuse > 0.0 && spheres.iter().any(|o| o.hit(p + normal * 1e-4, light) > 1e-9) {
                    diffuse = 0.0;
                }
                shade = s.albedo * (0.1 + 0.9 * diffuse.max(0.0));
            }
            image[py * w + px] = (shade * 255.0) as u8;
        }
    }
    let sum: u64 = image.iter().map(|&b| b as u64).sum();
    let hash = image.iter().fold(14695981039346656037u64, |h, &b| (h ^ b as u64).wrapping_mul(1099511628211));
    println!("hits {}, shade sum {}, hash {:x}", hits, sum, hash);
}
