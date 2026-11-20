"""Cut a clean alpha matte for UI pieces that were sliced from the mockup as opaque rectangles.

A rectangle cut keeps the mockup's wood around the piece. That wood never matches the game background
exactly, so its edges show as a frame and lines next to the plaques. This keeps the piece inside a
measured outline, makes everything around it transparent, pulls wood out of the anti-aliased edge and
optionally bakes a soft contact shadow.

Automatic segmentation (GrabCut, colour distance) fails here: the shaded bottom/right bevel is as dark
as the wood shadow, and a brass rim has the same hue as oak. Measure the outline on the lit top/left
edges instead and describe it with primitives (all coordinates in source pixels, edges at pixel
boundaries, e.g. 10.5 = between pixels 10 and 11):

  {"BestPlaque.png": [{"rect": [x0, y0, x1, y1], "chamfer": 16},
                      {"poly": [[x, y], ...]}],
   "Gear.png":       [{"rect": [x0, y0, x1, y1], "radius": 14}],
   "Booster.png":    [{"circle": [cx, cy, r]}]}

usage: python tools/cut-matte.py <shapes.json> <src_dir> <out_dir>
                                             [--shadow 0] [--blur 3] [--dy 2] [--preview DIR]
       python tools/cut-matte.py --audit <art_dir>
Check every result at 400 % over a flat colour (--preview) before importing it.
--audit lists RGBA sprites whose outer 2 px ring has almost no transparent pixel: rectangle cuts that show a frame.
Expect hits only for pieces that really are full-bleed (tiles inside a grid, panels drawn edge to edge).
Remember the background under a former rectangle cut: if it was inpainted, its patches are exposed now.
"""
import json
import os
import sys

import cv2
import numpy as np

SS = 8  # supersampling for a smooth anti-aliased outline
SHADOW_BGR = np.array([5, 10, 20], np.float32)  # warm black #140A05


def draw(shapes, w, h):
    big = np.zeros((h * SS, w * SS), np.uint8)

    def p(x, y):
        return [int(round(x * SS)), int(round(y * SS))]

    for s in shapes:
        if "circle" in s:
            cx, cy, r = s["circle"]
            cv2.circle(big, tuple(p(cx, cy)), int(round(r * SS)), 255, -1, cv2.LINE_AA)
        elif "poly" in s:
            cv2.fillPoly(big, [np.array([p(x, y) for x, y in s["poly"]], np.int32)], 255, cv2.LINE_AA)
        else:
            x0, y0, x1, y1 = s["rect"]
            c = s.get("chamfer", 0)
            r = s.get("radius", 0)
            if c:
                pts = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
                       (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]
                cv2.fillPoly(big, [np.array([p(*q) for q in pts], np.int32)], 255, cv2.LINE_AA)
            elif r:
                cv2.rectangle(big, tuple(p(x0 + r, y0)), tuple(p(x1 - r, y1)), 255, -1)
                cv2.rectangle(big, tuple(p(x0, y0 + r)), tuple(p(x1, y1 - r)), 255, -1)
                for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)):
                    cv2.circle(big, tuple(p(cx, cy)), int(round(r * SS)), 255, -1, cv2.LINE_AA)
            else:
                cv2.rectangle(big, tuple(p(x0, y0)), tuple(p(x1, y1)), 255, -1)
    return cv2.resize(big, (w, h), interpolation=cv2.INTER_AREA).astype(np.float32) / 255


def matte(img, shapes, strength, blur, dy):
    rgb = np.ascontiguousarray(img[..., :3])
    h, w = rgb.shape[:2]
    a = draw(shapes, w, h)

    # decontaminate the edge: pixels outside the solid core get colours pulled out of the core
    core = cv2.erode((a > 0.999).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    fill = cv2.inpaint(rgb, (~core).astype(np.uint8) * 255, 2, cv2.INPAINT_TELEA).astype(np.float32)
    piece = np.where(core[..., None], rgb.astype(np.float32), fill)

    sh = np.zeros_like(a)
    if strength > 0:
        shifted = np.zeros_like(a)
        shifted[dy:] = a[:h - dy]
        sh = cv2.GaussianBlur(shifted, (0, 0), blur) * strength
    out_a = a + sh * (1 - a)
    out_rgb = (piece * a[..., None] + SHADOW_BGR * (sh * (1 - a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    return np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a * 255, 0, 255)]).astype(np.uint8), a


def preview_tile(src, out):
    rgb = src[..., :3]
    al = out[..., 3:4].astype(np.float32) / 255
    tiles = [rgb]
    for bg in ((40, 70, 110), (200, 200, 200)):
        tiles.append((out[..., :3] * al + np.array(bg, np.float32) * (1 - al)).astype(np.uint8))
    return np.hstack(tiles)


def audit(root):
    hits = 0
    for dirpath, _, files in os.walk(root):
        for f in sorted(files):
            if not f.lower().endswith(".png"):
                continue
            img = cv2.imread(os.path.join(dirpath, f), cv2.IMREAD_UNCHANGED)
            if img is None or img.ndim < 3 or img.shape[2] < 4:
                continue
            a = img[..., 3]
            ring = np.concatenate([a[:2].ravel(), a[-2:].ravel(), a[:, :2].ravel(), a[:, -2:].ravel()])
            if (ring < 8).mean() < 0.05:  # almost no transparent pixel on the border: a rectangle cut
                hits += 1
                print(f"{os.path.join(dirpath, f)}: border alpha mean {ring.mean():.0f}, min alpha {a.min()}")
    print(f"{hits} sprite(s) with an opaque border")


def main():
    argv = sys.argv[1:]
    if argv and argv[0] == "--audit":
        audit(argv[1])
        return

    def opt(name, default):
        if name in argv:
            i = argv.index(name)
            v = argv[i + 1]
            del argv[i:i + 2]
            return v
        return default

    strength = float(opt("--shadow", "0"))
    blur = float(opt("--blur", "3"))
    dy = int(opt("--dy", "2"))
    preview = opt("--preview", "")
    spec_path, src_dir, out_dir = argv[:3]
    spec = json.load(open(spec_path, encoding="utf-8"))
    os.makedirs(out_dir, exist_ok=True)
    for name, shapes in spec.items():
        img = cv2.imread(os.path.join(src_dir, name), cv2.IMREAD_UNCHANGED)
        out, a = matte(img, shapes, strength, blur, dy)
        cv2.imwrite(os.path.join(out_dir, name), out)
        if preview:
            os.makedirs(preview, exist_ok=True)
            cv2.imwrite(os.path.join(preview, name), preview_tile(img, out))
        print(f"{name}: opaque {(a > 0.99).mean() * 100:.1f}%, transparent {(out[..., 3] < 5).mean() * 100:.1f}%")


if __name__ == "__main__":
    main()
