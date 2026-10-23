// raytrace: generated spheres seen from the origin, one ray per pixel of a w by w image, lit by a
// directional light with shadows; prints how many pixels hit a sphere, the sum of the pixels'
// shades and a hash of the image.
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

struct Vec {
    double x, y, z;
    Vec operator+(Vec b) const { return {x + b.x, y + b.y, z + b.z}; }
    Vec operator-(Vec b) const { return {x - b.x, y - b.y, z - b.z}; }
    Vec operator*(double k) const { return {x * k, y * k, z * k}; }
    double dot(Vec b) const { return x * b.x + y * b.y + z * b.z; }
    Vec unit() const { return *this * (1.0 / std::sqrt(dot(*this))); }
};

struct Sphere {
    Vec center;
    double radius, albedo;

    // the distance along the ray to where it enters the sphere, negative when it misses
    double hit(Vec origin, Vec dir) const {
        Vec oc = origin - center;
        double b = oc.dot(dir);
        double disc = b * b - (oc.dot(oc) - radius * radius);
        if (disc < 0.0)
            return -1.0;
        return -b - std::sqrt(disc);
    }
};

static uint64_t state = 1;

// the next number, 31 bits
static uint64_t next() {
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return state >> 33;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); // the runner compares bytes: no CRLF translation
#endif
    int w = argc > 1 ? atoi(argv[1]) : 64;
    std::vector<Sphere> spheres(256);
    for (Sphere &s : spheres) {
        s.center.x = (double)(next() % 2000) / 100.0 - 10.0;
        s.center.y = (double)(next() % 2000) / 100.0 - 10.0;
        s.center.z = 10.0 + (double)(next() % 3000) / 100.0;
        s.radius = 0.3 + (double)(next() % 200) / 100.0;
        s.albedo = 0.3 + (double)(next() % 70) / 100.0;
    }
    Vec light = Vec{-1.0, 1.0, -1.0}.unit();
    Vec eye{0.0, 0.0, 0.0};
    std::vector<uint8_t> image((size_t)w * w);
    long long hits = 0;
    for (int py = 0; py < w; py++) {
        for (int px = 0; px < w; px++) {
            double u = (px + 0.5) / w * 2.0 - 1.0;
            double v = 1.0 - (py + 0.5) / w * 2.0;
            Vec dir = Vec{u, v, 1.5}.unit();
            const Sphere *nearest = nullptr;
            double best = std::numeric_limits<double>::infinity();
            for (const Sphere &s : spheres) {
                double t = s.hit(eye, dir);
                if (t > 1e-9 && t < best) {
                    best = t;
                    nearest = &s;
                }
            }
            double shade = (0.5 + 0.5 * v) * 0.25;
            if (nearest) {
                hits++;
                Vec p = eye + dir * best;
                Vec normal = (p - nearest->center) * (1.0 / nearest->radius);
                double diffuse = normal.dot(light);
                if (diffuse > 0.0) {
                    Vec from = p + normal * 1e-4;
                    for (const Sphere &s : spheres) {
                        if (s.hit(from, light) > 1e-9) {
                            diffuse = 0.0;
                            break;
                        }
                    }
                } else {
                    diffuse = 0.0;
                }
                shade = nearest->albedo * (0.1 + 0.9 * diffuse);
            }
            image[(size_t)py * w + px] = (uint8_t)(shade * 255.0);
        }
    }
    uint64_t sum = 0, hash = 14695981039346656037ull;
    for (uint8_t b : image) {
        sum += b;
        hash = (hash ^ b) * 1099511628211ull;
    }
    printf("hits %lld, shade sum %llu, hash %llx\n", hits, (unsigned long long)sum, (unsigned long long)hash);
    return 0;
}
