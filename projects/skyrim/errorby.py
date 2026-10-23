# Where compare.zap's error lies: per pose, the difference of the game's picture and ours split by
# the texture each pixel shows (main.zap --ids pictures, ids-<pose>.png beside, names from
# prepared/<cell>/textures.txt), by tile, by blur radius and by sub-pixel shift. Diagnostics only.
#   python projects/skyrim/errorby.py <ids dir> [pose ...]
import json, sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, shift as nshift, binary_dilation

REF = "projects/skyrim/assets/reference/"
NAMES = "projects/skyrim/assets/prepared/riverwoodsleepinggiantinn/textures.txt"
ids_dir = sys.argv[1]
poses = {p["name"]: p for p in json.load(open(REF + "poses.json"))["poses"]}
wanted = sys.argv[2:] or list(poses)
names = {}
for line in open(NAMES):
    k, _, v = line.strip().partition(" ")
    names.setdefault(int(k), v)

def pic(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(float)

def kept(p, shape):
    m = np.ones(shape[:2], bool)
    k = p["mask"]
    for i in range(0, len(k), 4):
        x, y, w, h = map(int, k[i:i + 4]); m[y:y + h, x:x + w] = False
    return m

for n in wanted:
    p = poses[n]
    g, o = pic(REF + n + ".png"), pic(REF + "out/" + n + ".png")
    m = kept(p, g.shape)
    ident = pic(f"{ids_dir}/ids-{n}.png")
    key = (ident[..., 0] + 256 * ident[..., 1]).astype(int)
    effect = ident[..., 2] > 60
    edge = binary_dilation(np.abs(np.diff(key, axis=0, prepend=0)) + np.abs(np.diff(key, axis=1, prepend=0)) > 0, iterations=1)
    e = np.abs(g - o).mean(2)
    low = np.abs(gaussian_filter(g, (4, 4, 0)) - gaussian_filter(o, (4, 4, 0))).mean(2)
    signed = (o - g).mean(2)
    total = e[m].sum()
    print(f"== {n}: mean error {e[m].mean():.2f}; at edges of parts {100 * e[m & edge].sum() / total:.1f}% of it; "
          f"low-frequency (blur 4) {low[m].mean():.2f}")
    rows = []
    for k in np.unique(key[m]):
        s = m & (key == k)
        rows.append((e[s].sum() / total * 100, k, s.sum(), e[s].mean(), low[s].mean(), signed[s].mean(), effect[s].mean()))
    rows.sort(reverse=True)
    print(f"{'share%':>7} {'px':>7} {'err':>5} {'blur4':>5} {'bias':>6}  texture")
    for sh, k, px, er, lo, bi, ef in rows[:10]:
        print(f"{sh:7.1f} {px:7d} {er:5.1f} {lo:5.1f} {bi:+6.1f}  {names.get(k, '?')}{' (effect)' if ef > 0.5 else ''}")
    for dy, dx in ((0, 0), (-.5, -.5), (-.5, .5), (.5, -.5), (.5, .5)):
        os_ = nshift(o, (dy, dx, 0), order=1, mode="nearest")
        print(f"  shift {dy:+.1f},{dx:+.1f}: {np.abs(g - os_).mean(2)[m].mean():.2f}", end="")
    print()
