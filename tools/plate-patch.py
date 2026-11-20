"""Remove inpaint ghosts from a background plate that was cut from a design mockup.

When a game background is the approved mockup with its UI erased, the erased spots under DYNAMIC content
(tray pieces, counters) show up as rectangles once the content differs from the mockup state. This replaces
only those footprints with clean, tone-matched texture and keeps the mockup's large-scale shading.

usage: python plate-patch.py <plate.png> <clean_texture.png> <rects.json> <out.png>
                             [--pad 20] [--feather 7] [--shadow 4,6] [--ref-band y0,y1]

rects.json   [[x0, y0, x1, y1], ...] boxes of the mockup's dynamic items in plate pixels.
clean        any image of the same material without UI (another screen's plate, a generated texture);
             it is resized to the plate size.
--pad        margin around each box (sweep it: bigger hides ghosts, smaller keeps more mockup grain).
--shadow     extra right/bottom growth for the item's drop shadow.
--ref-band   rows of the plate that are clean mockup texture, used for tone matching (default: bottom 8 %).

Check the result on a capture with DIFFERENT dynamic content and boosted contrast, then rerun the
design diff on the mockup-state capture (the patched area must not drop its region below the pass line).
"""
import json
import sys

import cv2
import numpy as np


def main():
    argv = sys.argv[1:]

    def opt(name, default):
        if name in argv:
            i = argv.index(name)
            v = argv[i + 1]
            del argv[i:i + 2]
            return v
        return default

    pad = int(opt("--pad", "20"))
    feather = float(opt("--feather", "7"))
    sx, sy = (int(v) for v in opt("--shadow", "4,6").split(","))
    band = opt("--ref-band", "")
    plate_path, clean_path, rects_path, out_path = argv[:4]

    plate = cv2.imread(plate_path).astype(np.float32)
    h, w = plate.shape[:2]
    clean = cv2.resize(cv2.imread(clean_path), (w, h), interpolation=cv2.INTER_AREA).astype(np.float32)
    y0, y1 = (int(v) for v in band.split(",")) if band else (int(h * 0.92), h)

    mask = np.zeros((h, w), np.uint8)
    for x0, ry0, x1, ry1 in json.load(open(rects_path, encoding="utf-8")):
        cv2.rectangle(mask, (x0 - pad, ry0 - pad), (x1 + pad + sx, ry1 + pad + sy), 255, -1)
    alpha = cv2.GaussianBlur(mask.astype(np.float32) / 255, (0, 0), feather)[..., None]

    # tone-match the clean texture to clean rows of the plate
    ref, src = plate[y0:y1], clean[y0:y1]
    fill = clean.copy()
    for c in range(3):
        fill[..., c] = (fill[..., c] - src[..., c].mean()) / (src[..., c].std() + 1e-6) * ref[..., c].std() + ref[..., c].mean()
    # keep the plate's low-frequency shading, estimated from outside the patched area
    keep = 1 - alpha[..., 0]
    low = cv2.GaussianBlur(plate * keep[..., None], (0, 0), 30) / (cv2.GaussianBlur(keep, (0, 0), 30)[..., None] + 1e-6)
    fill = fill - cv2.GaussianBlur(fill, (0, 0), 30) + low

    out = np.clip(plate * (1 - alpha) + fill * alpha, 0, 255).astype(np.uint8)
    cv2.imwrite(out_path, out)
    print("patched", int((mask > 0).sum()), "px ->", out_path)


if __name__ == "__main__":
    main()
