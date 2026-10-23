/* raytrace: generated spheres seen from the origin, one ray per pixel of a w by w image, lit by a
 * directional light with shadows; prints how many pixels hit a sphere, the sum of the pixels'
 * shades and a hash of the image. */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

typedef struct {
    double x, y, z;
} Vec;

typedef struct {
    Vec center;
    double radius, albedo;
} Sphere;

enum { SPHERES = 256 };

static uint64_t state = 1;

/* the next number, 31 bits */
static uint64_t next(void) {
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return state >> 33;
}

static Vec add(Vec a, Vec b) { return (Vec){a.x + b.x, a.y + b.y, a.z + b.z}; }
static Vec sub(Vec a, Vec b) { return (Vec){a.x - b.x, a.y - b.y, a.z - b.z}; }
static Vec scale(Vec a, double k) { return (Vec){a.x * k, a.y * k, a.z * k}; }
static double dot(Vec a, Vec b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static Vec unit(Vec a) { return scale(a, 1.0 / sqrt(dot(a, a))); }

/* the distance along the ray to where it enters the sphere, negative when it misses */
static double hit(Vec origin, Vec dir, const Sphere *s) {
    Vec oc = sub(origin, s->center);
    double b = dot(oc, dir);
    double disc = b * b - (dot(oc, oc) - s->radius * s->radius);
    if (disc < 0.0)
        return -1.0;
    return -b - sqrt(disc);
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); /* the runner compares bytes: no CRLF translation */
#endif
    int w = argc > 1 ? atoi(argv[1]) : 64;
    Sphere spheres[SPHERES];
    for (int i = 0; i < SPHERES; i++) {
        Sphere *s = &spheres[i];
        s->center.x = (double)(next() % 2000) / 100.0 - 10.0;
        s->center.y = (double)(next() % 2000) / 100.0 - 10.0;
        s->center.z = 10.0 + (double)(next() % 3000) / 100.0;
        s->radius = 0.3 + (double)(next() % 200) / 100.0;
        s->albedo = 0.3 + (double)(next() % 70) / 100.0;
    }
    Vec light = unit((Vec){-1.0, 1.0, -1.0});
    Vec eye = {0.0, 0.0, 0.0};
    uint8_t *image = malloc((size_t)w * w);
    long long hits = 0;
    for (int py = 0; py < w; py++) {
        for (int px = 0; px < w; px++) {
            double u = (px + 0.5) / w * 2.0 - 1.0;
            double v = 1.0 - (py + 0.5) / w * 2.0;
            Vec dir = unit((Vec){u, v, 1.5});
            const Sphere *nearest = NULL;
            double best = INFINITY;
            for (int i = 0; i < SPHERES; i++) {
                double t = hit(eye, dir, &spheres[i]);
                if (t > 1e-9 && t < best) {
                    best = t;
                    nearest = &spheres[i];
                }
            }
            double shade = (0.5 + 0.5 * v) * 0.25;
            if (nearest) {
                hits++;
                Vec p = add(eye, scale(dir, best));
                Vec normal = scale(sub(p, nearest->center), 1.0 / nearest->radius);
                double diffuse = dot(normal, light);
                if (diffuse > 0.0) {
                    Vec from = add(p, scale(normal, 1e-4));
                    for (int i = 0; i < SPHERES; i++) {
                        if (hit(from, light, &spheres[i]) > 1e-9) {
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
    for (size_t i = 0; i < (size_t)w * w; i++) {
        sum += image[i];
        hash = (hash ^ image[i]) * 1099511628211ull;
    }
    printf("hits %lld, shade sum %llu, hash %llx\n", hits, (unsigned long long)sum, (unsigned long long)hash);
    free(image);
    return 0;
}
