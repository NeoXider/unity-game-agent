"""Pixel comparison of a game screenshot against the approved design mockup.

usage: python design-diff.py <shot.png> --ref <approved.png> [--regions regions.json] [--size 900x1600]
                              [--out Docs/Screenshots/Restyle/diff] [--skip name1,name2]

regions.json: [["best_plaque", 100, 25, 435, 200], ...]  (name, x0, y0, x1, y1 in --size coordinates).
Without --regions the built-in block-puzzle layout below is used. Both images are brought to --size. For every region it reports:
  shift  - offset of the region content found by phase correlation (px, dx/dy); misplaced elements show up here
  mae    - mean absolute RGB difference after aligning (0..255); wrong colors/materials show up here
  ssim   - structural similarity of the aligned grayscale (0..1); wrong shapes/textures/fonts show up here
A region passes when |shift| <= 3 px, mae <= MAE_MAX and ssim >= SSIM_MIN. Exit code 1 when any region fails.
Writes <out>/<shot>_blend.png (50/50 overlay), _heat.png (difference heatmap) and _crops.png (reference | shot per region).
"""
import os
import sys

import cv2
import numpy as np

W, H = 900, 1600
# Default regions (name, x0, y0, x1, y1): portrait block-puzzle layout at 900x1600. Override with --regions.
REGIONS = [
    ("best_plaque", 100, 25, 435, 200),
    ("score_plaque", 470, 75, 780, 200),
    ("settings", 800, 70, 885, 155),
    ("progress", 25, 200, 860, 260),
    ("board_frame_top", 15, 255, 885, 305),
    ("board_frame_left", 15, 255, 60, 1115),
    ("board_cells", 50, 295, 850, 1080),
    ("board_frame_bottom", 15, 1070, 885, 1115),
    ("boosters", 285, 1120, 620, 1255),
    ("tray", 120, 1285, 760, 1455),
    ("bg_bottom", 0, 1460, 900, 1600),
    ("bg_left", 0, 255, 15, 1115),
    ("bg_top", 0, 0, 100, 200),
]
MAE_MAX = 14.0
SSIM_MIN = 0.80
SHIFT_MAX = 3.0


def load(path):
    im = cv2.imread(path, cv2.IMREAD_COLOR)
    if im is None:
        raise SystemExit("cannot read " + path)
    return cv2.resize(im, (W, H), interpolation=cv2.INTER_AREA)


def ssim(a, b):
    a = a.astype(np.float64)
    b = b.astype(np.float64)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    blur = lambda x: cv2.GaussianBlur(x, (11, 11), 1.5)
    mu_a, mu_b = blur(a), blur(b)
    va = blur(a * a) - mu_a ** 2
    vb = blur(b * b) - mu_b ** 2
    cov = blur(a * b) - mu_a * mu_b
    m = ((2 * mu_a * mu_b + c1) * (2 * cov + c2)) / ((mu_a ** 2 + mu_b ** 2 + c1) * (va + vb + c2))
    return float(m.mean())


def region_shift(ref_g, shot_g, box):
    x0, y0, x1, y1 = box
    pad = 60
    a = ref_g[y0:y1, x0:x1].astype(np.float32)
    # search window a little larger than the region in the shot
    X0, Y0, X1, Y1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
    b = shot_g[Y0:Y1, X0:X1].astype(np.float32)
    if a.std() < 2 or b.std() < 2:
        return 0, 0
    res = cv2.matchTemplate(b, a, cv2.TM_CCOEFF_NORMED)
    _, _, _, loc = cv2.minMaxLoc(res)
    dx = loc[0] - (x0 - X0)
    dy = loc[1] - (y0 - Y0)
    return int(dx), int(dy)


def main():
    argv = sys.argv[1:]

    def opt(name, default):
        if name in argv:
            i = argv.index(name)
            v = argv[i + 1]
            del argv[i:i + 2]
            return v
        return default

    global W, H, REGIONS
    ref_path = opt("--ref", "Docs/Screenshots/MVPDesign/approved-game.png")
    size = opt("--size", "")
    if size:
        W, H = (int(v) for v in size.lower().split("x"))
    regions_path = opt("--regions", "")
    if regions_path:
        import json
        REGIONS = [tuple(r) for r in json.load(open(regions_path, encoding="utf-8"))]
    out = opt("--out", "Docs/Screenshots/Restyle/diff")
    skip = set(filter(None, opt("--skip", "").split(",")))
    shot_path = argv[0]
    os.makedirs(out, exist_ok=True)
    ref, shot = load(ref_path), load(shot_path)
    ref_g = cv2.cvtColor(ref, cv2.COLOR_BGR2GRAY)
    shot_g = cv2.cvtColor(shot, cv2.COLOR_BGR2GRAY)
    stem = os.path.splitext(os.path.basename(shot_path))[0]

    failed = []
    crops = []
    print("%-20s %8s %7s %6s  %s" % ("region", "shift", "mae", "ssim", "result"))
    for name, x0, y0, x1, y1 in REGIONS:
        if name in skip:
            print("%-20s %8s %7s %6s  %s" % (name, "-", "-", "-", "skipped"))
            continue
        dx, dy = region_shift(ref_g, shot_g, (x0, y0, x1, y1))
        sx0, sy0 = min(max(0, x0 + dx), W - (x1 - x0)), min(max(0, y0 + dy), H - (y1 - y0))
        a = ref[y0:y1, x0:x1]
        b = shot[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)]
        mae = float(np.abs(a.astype(np.int16) - b.astype(np.int16)).mean())
        s = ssim(cv2.cvtColor(a, cv2.COLOR_BGR2GRAY), cv2.cvtColor(b, cv2.COLOR_BGR2GRAY))
        ok = abs(dx) <= SHIFT_MAX and abs(dy) <= SHIFT_MAX and mae <= MAE_MAX and s >= SSIM_MIN
        if not ok:
            failed.append(name)
        print("%-20s %8s %7.1f %6.3f  %s" % (name, "%+d,%+d" % (dx, dy), mae, s, "ok" if ok else "FAIL"))
        crop = np.hstack([a, np.full((y1 - y0, 6, 3), (255, 0, 255), np.uint8), shot[y0:y1, x0:x1]])
        crops.append(cv2.copyMakeBorder(crop, 22, 4, 0, 0, cv2.BORDER_CONSTANT, value=(30, 30, 30)))
        cv2.putText(crops[-1], "%s  ref | shot  shift %+d,%+d  mae %.1f  ssim %.3f" % (name, dx, dy, mae, s),
                    (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (220, 220, 220), 1, cv2.LINE_AA)

    blend = cv2.addWeighted(ref, 0.5, shot, 0.5, 0)
    heat = cv2.applyColorMap(np.clip(np.abs(ref.astype(np.int16) - shot.astype(np.int16)).mean(axis=2) * 3, 0, 255).astype(np.uint8), cv2.COLORMAP_INFERNO)
    cv2.imwrite(os.path.join(out, stem + "_blend.png"), blend)
    cv2.imwrite(os.path.join(out, stem + "_heat.png"), heat)
    if crops:
        width = max(c.shape[1] for c in crops)
        crops = [cv2.copyMakeBorder(c, 0, 0, 0, width - c.shape[1], cv2.BORDER_CONSTANT, value=(30, 30, 30)) for c in crops]
        cv2.imwrite(os.path.join(out, stem + "_crops.png"), np.vstack(crops))
    print("RESULT", "PASS" if not failed else "FAIL " + ",".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
