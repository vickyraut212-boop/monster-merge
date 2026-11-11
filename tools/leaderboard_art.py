"""Renders the leaderboard's soft rubbery 3D UI pieces and the golden aura.

Run from the repo root:  python3 tools/leaderboard_art.py
Needs numpy and Pillow. Writes PNGs to game/assets/leaderboard/rubber/ and
game/assets/leaderboard/aura/. Everything is drawn from shapes and lighting
(no reference images are copied), at 2x the size shown on screen so it stays
crisp on phones. Re-run after tweaking a colour or size below.

Look: a signed-distance shape gets a rounded bevel (a height map), lit from
the top-left with a broad, low specular (matte rubber, not shiny plastic),
plus a darker extruded side for thickness and a soft drop shadow.
"""

import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "leaderboard")
RUBBER = os.path.join(ROOT, "rubber")
AURA = os.path.join(ROOT, "aura")
SS = 2  # supersampling for smooth edges

LIGHT = np.array([-0.45, -0.75, 0.9])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1.0])
HALF = HALF / np.linalg.norm(HALF)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def sdf_round_rect(w, h, x, y, rw, rh, r):
    """Signed distance (px) to a rounded rect at (x, y) size rw x rh, radius r."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    cx, cy = x + rw / 2.0, y + rh / 2.0
    qx = np.abs(xx - cx) - (rw / 2.0 - r)
    qy = np.abs(yy - cy) - (rh / 2.0 - r)
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return out + inside - r


def coverage(d):
    return np.clip(0.5 - d, 0.0, 1.0)


def shade(d, color, bevel, recessed=False, spec=0.22, ambient=0.62):
    """Lit RGB for a bevelled shape (d = signed distance, negative inside)."""
    t = np.clip(-d / bevel, 0.0, 1.0)
    height = np.sqrt(1.0 - (1.0 - t) ** 2) * bevel
    if recessed:
        height = -height
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    diffuse = np.clip(n @ LIGHT, 0, 1)
    highlight = np.clip(n @ HALF, 0, 1) ** 10 * spec
    rgb = color[None, None, :] * (ambient + 0.5 * diffuse)[..., None] + highlight[..., None]
    return np.clip(rgb, 0, 1)


def over(dst, src_rgb, src_a):
    """Alpha-composite src over dst (both float RGBA arrays)."""
    a = src_a[..., None]
    out_a = a + dst[..., 3:4] * (1 - a)
    rgb = (src_rgb * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-6)
    return np.dstack([rgb, out_a])


def blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float64) / 255.0


def save(arr, path, size):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    img = img.resize(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print(os.path.relpath(path), size)


def rubber(w, h, radius, color, *, pad=24, depth=None, shadow=0.35, glow=None, glow_size=0,
           recess=None, recess_color=None, socket=None, dots=True, bevel=None):
    """A raised rubber slab, w x h (final px), returned at final size.

    depth: extruded side thickness. glow: outer glow colour. recess: inset
    (left, top, right, bottom) for an inner groove. socket: (x, y, w, h, r)
    of a soft hollow (behind an avatar). dots: two soft highlight dots.
    """
    color = hexc(color) if isinstance(color, str) else color
    s = SS * 2  # draw at 2x final * supersampling
    depth = h * 0.08 if depth is None else depth
    bevel = min(h, w) * 0.28 if bevel is None else bevel
    W, H = int((w + pad * 2) * s), int((h + pad * 2) * s)
    x0, y0 = pad * s, pad * s
    canvas = np.zeros((H, W, 4))

    body_h = (h - depth) * s
    # Outer glow.
    if glow is not None:
        d = sdf_round_rect(W, H, x0, y0, w * s, h * s, radius * s)
        g = blur(coverage(d / s), glow_size * s * 0.45) * 2.4
        canvas = over(canvas, np.broadcast_to(hexc(glow), (H, W, 3)), np.clip(g, 0, 1))
    # Drop shadow.
    d = sdf_round_rect(W, H, x0, y0 + depth * s * 0.8, w * s, body_h, radius * s)
    sh = blur(coverage(d / s), 6 * s) * shadow
    canvas = over(canvas, np.zeros((H, W, 3)), sh)
    # Extruded side (thickness).
    d_side = sdf_round_rect(W, H, x0, y0 + depth * s, w * s, body_h, radius * s)
    side = shade(d_side / s, color * 0.62, bevel * 0.6, ambient=0.75)
    canvas = over(canvas, side, coverage(d_side / s))
    # Top face.
    d_top = sdf_round_rect(W, H, x0, y0, w * s, body_h, radius * s)
    face = shade(d_top / s, color, bevel)
    # Soft vertical light falloff (lighter top, deeper bottom).
    yy = np.linspace(0, 1, H)[:, None, None]
    face = np.clip(face * (1.08 - 0.16 * yy), 0, 1)
    canvas = over(canvas, face, coverage(d_top / s))

    if socket is not None:
        sx, sy, sw, shh, sr = socket
        d_s = sdf_round_rect(W, H, x0 + sx * s, y0 + sy * s, sw * s, shh * s, sr * s)
        hollow = shade(d_s / s, color * 1.08, 10, recessed=True, ambient=0.7)
        canvas = over(canvas, hollow, coverage(d_s / s) * 0.85)
    if recess is not None:
        l, t, r, b = recess
        rc = hexc(recess_color) if isinstance(recess_color, str) else (color * 0.7 if recess_color is None else recess_color)
        rr = max(radius - l, 4)
        d_r = sdf_round_rect(W, H, x0 + l * s, y0 + t * s, (w - l - r) * s, (h - depth - t - b) * s, rr * s)
        groove = shade(d_r / s, rc, min(h, w) * 0.16, recessed=True, ambient=0.7)
        canvas = over(canvas, groove, coverage(d_r / s))
    if dots:
        for (dx, dy, dr) in ((0.42, 0.26, 0.09), (0.66, 0.17, 0.05)):
            cx, cy = x0 + radius * dx * 2 * s, y0 + body_h * dy
            yy, xx = np.mgrid[0:H, 0:W]
            r = np.hypot((xx - cx) / 1.6, yy - cy) / (dr * body_h)
            canvas = over(canvas, np.ones((H, W, 3)), np.clip(1.2 - r, 0, 1) ** 1.5 * 0.55)

    img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGBA")
    return img.resize((int((w + pad * 2) * 2), int((h + pad * 2) * 2)), Image.LANCZOS)


def put(img, name, folder=RUBBER):
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name)
    img.save(path, optimize=True)
    print(os.path.relpath(path), img.size)


# --- Rubber UI --------------------------------------------------------------

def make_rubber():
    # Ranking tiles (blue, lilac, and your purple one with a lime glow). The
    # socket is the soft hollow behind the avatar frame; keep its x in sync
    # with ROW_AVATAR_X in leaderboard_popup.gd.
    socket = (78, 8, 92, 64, 24)
    put(rubber(680, 86, 38, "#62a8ff", depth=7, socket=socket), "tile_blue.png")
    put(rubber(680, 86, 38, "#9d83ff", depth=7, socket=socket), "tile_lilac.png")
    put(rubber(680, 86, 38, "#7a3df0", depth=7, socket=socket, pad=30, glow="#d9ff3a", glow_size=16),
        "tile_me.png")
    # Score containers: raised pill in a soft groove.
    put(rubber(176, 56, 28, "#7038e0", depth=5, pad=10, dots=False, recess=(6, 6, 6, 6), recess_color="#4b1fae"),
        "score_pill.png")
    put(rubber(176, 56, 28, "#3d1690", depth=5, pad=10, dots=False, recess=(6, 6, 6, 6), recess_color="#2a0b6a"),
        "score_pill_me.png")
    put(rubber(176, 46, 23, "#fff6e0", depth=5, pad=10, dots=False, recess=(5, 5, 5, 5), recess_color="#f1dfb8"),
        "score_pill_cream.png")
    # Rank discs.
    for name, col in (("rank_disc_blue.png", "#3d7ff0"), ("rank_disc_lilac.png", "#7458e8"),
                      ("rank_disc_me.png", "#5a22c8")):
        put(rubber(62, 62, 31, col, depth=5, pad=10), name)
    # Podium plates (#1 pink, #2 purple, #3 orange).
    for name, col in (("plate_pink.png", "#ec4d92"), ("plate_purple.png", "#7c58ea"), ("plate_orange.png", "#ee7a3c")):
        put(rubber(200, 110, 26, col, depth=8, pad=14), name)
    # Title banner: lilac rim around a deeper purple centre.
    put(rubber(352, 100, 48, "#cf86f5", depth=9, pad=16, recess=(12, 10, 12, 8), recess_color="#8a34d8"),
        "title_banner.png")
    # Buttons.
    put(rubber(380, 86, 43, "#5fd61f", depth=10, pad=18), "button_green.png")
    put(rubber(268, 86, 43, "#ffc928", depth=9, pad=16), "button_yellow.png")
    put(rubber(268, 86, 43, "#7a42e6", depth=9, pad=16), "button_purple.png")
    # Text field: soft hollow.
    put(rubber(528, 72, 24, "#e9e0ff", depth=4, pad=12, dots=False, recess=(5, 5, 5, 5), recess_color="#f6f2ff"),
        "field.png")


# --- Golden aura ------------------------------------------------------------

def make_aura():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    c = n / 2.0
    dx, dy = (xx - c) / c, (yy - c) / c
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)

    # Soft aura: white-hot centre, golden middle, warm orange edge.
    inner = np.exp(-(r / 0.3) ** 2)
    outer = np.exp(-(r / 0.62) ** 2)
    a = np.clip(inner + outer * 0.8, 0, 1) * np.clip((1.0 - r) / 0.25, 0, 1)
    col = np.dstack([np.ones_like(r), 0.58 + 0.42 * inner, 0.12 + 0.7 * inner ** 2])
    save(np.dstack([col, a]), os.path.join(AURA, "aura.png"), (n, n))

    # Light rays: tapered golden beams of different widths and lengths.
    rng = np.random.default_rng(7)
    rays = np.zeros_like(r)
    count = 20
    for i in range(count):
        a0 = i / count * 2 * np.pi + rng.uniform(-0.1, 0.1)
        width = rng.uniform(0.05, 0.13)
        length = rng.uniform(0.72, 1.0)
        da = np.angle(np.exp(1j * (ang - a0)))
        beam = np.exp(-(da / (width * (0.35 + r))) ** 2) * np.clip(1 - r / length, 0, 1) ** 1.1
        rays = np.maximum(rays, beam * rng.uniform(0.6, 1.0))
    rays *= np.clip(r / 0.08, 0, 1)
    col = np.dstack([np.ones_like(r), 0.86 + 0.14 * (1 - r), 0.42 + 0.45 * (1 - r) ** 2])
    save(np.dstack([col, np.clip(rays, 0, 1)]), os.path.join(AURA, "rays.png"), (n, n))

    # Swirl: two thin elliptical arcs of light orbiting the winner.
    mw, mh = 1024, 512
    yy, xx = np.mgrid[0:mh, 0:mw].astype(np.float64)
    ex, ey = (xx - mw / 2) / (mw / 2), (yy - mh / 2) / (mh / 2)
    swirl = np.zeros_like(ex)
    for rad, w, a_from, a_to in ((0.86, 0.028, 0.15, 2.9), (0.94, 0.022, 3.4, 6.1)):
        e = np.hypot(ex, ey * 1.0)
        phi = np.mod(np.arctan2(ey, ex), 2 * np.pi)
        ring = np.exp(-((e - rad) / w) ** 2)
        span = np.clip((phi - a_from) / 0.6, 0, 1) * np.clip((a_to - phi) / 0.6, 0, 1)
        swirl = np.maximum(swirl, ring * span)
    swirl = blur(swirl, 2.0) * 1.4 + blur(swirl, 10.0) * 0.8
    col = np.dstack([np.ones_like(swirl), 0.9 * np.ones_like(swirl), 0.5 * np.ones_like(swirl)])
    save(np.dstack([col, np.clip(swirl, 0, 1)]), os.path.join(AURA, "swirl.png"), (512, 256))

    # Sparkle: a four-point star with a glow.
    k = 128
    yy, xx = np.mgrid[0:k, 0:k].astype(np.float64)
    ux, uy = np.abs(xx - k / 2) / (k / 2), np.abs(yy - k / 2) / (k / 2)
    star = np.clip(1 - (ux ** 0.5 + uy ** 0.5) / 1.0, 0, 1) ** 1.4
    glow = np.exp(-((ux ** 2 + uy ** 2) / 0.05))
    a = np.clip(star * 1.6 + glow * 0.6, 0, 1)
    col = np.dstack([np.ones_like(a), 0.95 + 0.05 * a, 0.7 + 0.3 * a])
    save(np.dstack([col, a]), os.path.join(AURA, "sparkle.png"), (64, 64))


if __name__ == "__main__":
    make_rubber()
    make_aura()
