#!/usr/bin/env python3
"""Generate eyelid blink frames for Tier 6 and Tier 7.

Tier 6 and 7 are vicky's supplied art and must stay exactly as supplied. This
script leaves tier_N.png untouched and writes tier_N_blink_1..3.png next to
it: copies of the sprite with soft skin-coloured eyelids painted over each eye
(half-closed, closed, half-open), in the same style as the other tiers' blink
frames. Nothing outside the eyes is changed.

Run from the repo root:  python3 tools/blink_frames.py
Needs Pillow and numpy.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

MONSTERS = Path(__file__).resolve().parent.parent / "game" / "assets" / "monsters"

# Each eye: centre x, centre y, radius x, radius y (pixels in tier_N.png),
# measured on the outer edge of the white eyeball.
EYES = {
    6: [(714, 619, 194, 197), (1029, 483, 102, 108), (359, 561, 75, 79)],
    7: [(655, 512, 93, 90), (915, 512, 93, 90), (575, 799, 187, 187), (997, 802, 188, 187)],
}
# How far down each frame's eyelid comes (0 = open, 1 = fully closed):
# half-closed, closed, half-open, like the other tiers.
FRAMES = [0.55, 1.0, 0.35]
SS = 3  # supersampling for smooth edges


def skin_colour(img, cx, cy, rx, ry):
    """Median colour of the skin in a ring just outside the eye."""
    h, w = img.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    d = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2
    ring = (d > 1.25 ** 2) & (d < 1.45 ** 2) & (img[..., 3] > 250)
    px = img[ring][:, :3].astype(float)
    # Drop dark bits (brows, lashes) and very bright highlights.
    lum = px.mean(axis=1)
    keep = (lum > np.percentile(lum, 25)) & (lum < np.percentile(lum, 85))
    return np.median(px[keep], axis=0)


def paint_lid(out, cx, cy, rx, ry, cover, skin):
    """Paints one eyelid onto `out` (float RGBA array, modified in place)."""
    # Lid is a touch bigger than the eyeball so no white peeks round the rim.
    lrx, lry = rx * 1.04, ry * 1.04
    x0, x1 = int(cx - lrx - 4), int(cx + lrx + 5)
    y0, y1 = int(cy - lry - 4), int(cy + lry + 5)
    # Supersampled coordinates of this patch.
    ys, xs = np.mgrid[y0 * SS:y1 * SS, x0 * SS:x1 * SS].astype(float)
    xs = (xs + 0.5) / SS
    ys = (ys + 0.5) / SS
    nx = (xs - cx) / lrx
    ny = (ys - cy) / lry
    d = np.sqrt(nx ** 2 + ny ** 2)
    disc = d <= 1.0
    # Lid edge: comes down from the top, bowed slightly downwards in the middle.
    edge = -1.0 + 2.0 * cover + 0.12 * (1.0 - np.clip(nx ** 2, 0, 1)) * min(cover * 2.0, 1.0)
    lid = disc & ((ny <= edge) if cover < 1.0 else np.ones_like(disc))

    # Rubbery sphere shading: lighter up top-left, darker towards the rim.
    shade = 1.06 - 0.16 * np.clip(ny * 0.7 + nx * 0.3 + 0.3, 0, 1.3)
    shade -= 0.22 * np.clip((d - 0.82) / 0.18, 0, 1) ** 2
    col = np.clip(skin[None, None, :] * shade[..., None], 0, 255)
    # Soft gloss spot.
    gloss = np.exp(-(((nx + 0.35) / 0.32) ** 2 + ((ny + 0.5) / 0.18) ** 2)) * 0.28
    col = col + (255 - col) * gloss[..., None]

    alpha = lid.astype(float)
    rgb = col

    # Shadow the lid casts on the eyeball just under its edge (open frames).
    shadow = np.zeros_like(alpha)
    if cover < 1.0:
        below = disc & (ny > edge) & (ny < edge + 0.22)
        shadow = below * (1.0 - (ny - edge) / 0.22) * 0.45

    # Lash line: along the lid edge, or a gentle "smile" curve when closed.
    if cover < 1.0:
        line_y = edge
    else:
        line_y = 0.12 + 0.16 * (1.0 - np.clip(nx ** 2, 0, 1))
    thick = 0.055 if cover >= 1.0 else 0.07
    lash = (np.abs(ny - line_y) < thick / 2) & (np.abs(nx) < (0.86 if cover >= 1.0 else 0.98)) & disc
    lash_col = np.clip(skin * 0.28, 0, 255)

    # Downsample everything to pixels.
    def down(a):
        if a.ndim == 2:
            return a.reshape(a.shape[0] // SS, SS, a.shape[1] // SS, SS).mean(axis=(1, 3))
        return a.reshape(a.shape[0] // SS, SS, a.shape[1] // SS, SS, a.shape[2]).mean(axis=(1, 3))

    a_lid = down(alpha)
    c_lid = down(rgb * alpha[..., None]) / np.maximum(a_lid[..., None], 1e-6)
    a_sh = down(shadow)
    a_lash = down(lash.astype(float))

    patch = out[y0:y1, x0:x1]
    base = patch[..., :3]
    base[:] = base * (1 - a_sh[..., None] * 0.6)
    base[:] = base * (1 - a_lid[..., None]) + c_lid * a_lid[..., None]
    base[:] = base * (1 - a_lash[..., None]) + lash_col * a_lash[..., None]


def make(tier):
    src = MONSTERS / f"tier_{tier}.png"
    img = np.array(Image.open(src).convert("RGBA")).astype(float)
    eyes = EYES[tier]
    skins = [skin_colour(img, *e) for e in eyes]
    for i, cover in enumerate(FRAMES, start=1):
        out = img.copy()
        for eye, skin in zip(eyes, skins):
            paint_lid(out, *eye, cover, skin)
        dest = MONSTERS / f"tier_{tier}_blink_{i}.png"
        Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA").save(dest, optimize=True)
        print("wrote", dest.name)


if __name__ == "__main__":
    for t in (int(a) for a in sys.argv[1:]) if len(sys.argv) > 1 else EYES:
        make(t)
