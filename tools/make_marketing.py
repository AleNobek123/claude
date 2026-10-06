"""
Marketing art for the Roblox page: game icon, developer product / gamepass icons and thumbnails.
Flat cartoon style drawn with PIL (supersampled 2x for clean edges).

    python3 tools/make_marketing.py <fonts_dir>

Writes PNGs to marketing/ (icon 512, products 512, thumbnails 1920x1080).
"""

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT = Path(__file__).resolve().parent.parent / "marketing"
OUT.mkdir(exist_ok=True)

INK = (60, 34, 14)
HONEY = (255, 190, 40)
HONEY_D = (232, 140, 20)
HONEY_L = (255, 226, 120)
CREAM = (255, 248, 230)
WHITE = (255, 255, 255)


def font(size, kind="title"):
    if kind == "title":
        return ImageFont.truetype(str(FONTS / "LuckiestGuy.ttf"), size)
    f = ImageFont.truetype(str(FONTS / "Fredoka.ttf"), size)
    try:
        f.set_variation_by_name("Bold")
    except Exception:
        pass
    return f


def canvas(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vgradient(w, h, top, bottom):
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)) + (255,))
    return img


def radial(w, h, inner, outer, cx=None, cy=None, r=None):
    cx = w / 2 if cx is None else cx
    cy = h / 2 if cy is None else cy
    r = r or math.hypot(w, h) / 2
    img = Image.new("RGBA", (w, h), outer + (255,))
    d = ImageDraw.Draw(img)
    steps = 120
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * t
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=lerp(inner, outer, t) + (255,))
    return img


def sunburst(img, cx, cy, count, color, alpha=60, r=None, phase=0.0):
    w, h = img.size
    r = r or math.hypot(w, h)
    layer = canvas(w, h)
    d = ImageDraw.Draw(layer)
    for i in range(count):
        a0 = phase + i / count * math.tau
        a1 = a0 + math.tau / count / 2
        d.polygon([(cx, cy), (cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r, cy + math.sin(a1) * r)], fill=color + (alpha,))
    img.alpha_composite(layer)


def hexagon(cx, cy, r, rot=30):
    return [(cx + r * math.cos(math.radians(rot + 60 * i)), cy + r * math.sin(math.radians(rot + 60 * i))) for i in range(6)]


def honeycomb(img, r, fill, line, width, alpha=255, rot=30):
    w, h = img.size
    layer = canvas(w, h)
    d = ImageDraw.Draw(layer)
    dx = r * math.sqrt(3)
    dy = r * 1.5
    row = 0
    y = -r
    while y < h + r:
        x = -dx + (dx / 2 if row % 2 else 0)
        while x < w + dx:
            d.polygon(hexagon(x, y, r * 0.93, rot), fill=fill + (alpha,), outline=line + (alpha,), width=width)
            x += dx
        y += dy
        row += 1
    img.alpha_composite(layer)


def shadow(layer, offset=(0, 14), blur=18, alpha=90):
    """drop shadow of a layer's silhouette"""
    a = layer.split()[3]
    sh = Image.new("RGBA", layer.size, (40, 20, 5, 0))
    sh.putalpha(a.point(lambda v: int(v * alpha / 255)))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = canvas(*layer.size)
    out.alpha_composite(sh, offset)
    out.alpha_composite(layer)
    return out


def outlined_text(img, xy, text, f, fill, stroke=INK, sw=10, anchor="mm", shadow_px=8):
    d = ImageDraw.Draw(img)
    if shadow_px:
        d.text((xy[0], xy[1] + shadow_px), text, font=f, fill=stroke, anchor=anchor, stroke_width=sw, stroke_fill=stroke)
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)


def gradient_text(img, xy, text, f, top, bottom, stroke=INK, sw=10, anchor="mm", shadow_px=10):
    """text filled with a vertical gradient, thick outline + drop"""
    w, h = img.size
    d = ImageDraw.Draw(img)
    if shadow_px:
        d.text((xy[0], xy[1] + shadow_px), text, font=f, fill=stroke, anchor=anchor, stroke_width=sw, stroke_fill=stroke)
    d.text(xy, text, font=f, fill=stroke, anchor=anchor, stroke_width=sw, stroke_fill=stroke)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(xy, text, font=f, fill=255, anchor=anchor)
    box = mask.getbbox()
    if not box:
        return
    grad = vgradient(w, box[3] - box[1] + 2, top, bottom)
    full = canvas(w, h)
    full.paste(grad, (0, box[1]))
    img.paste(full, (0, 0), mask)


# ------------------------------------------------------------------------------------------------
# Characters and props (drawn on their own layer, centred, then placed with rotation)


def bee_layer(size, body=HONEY, stripe=INK, extra=None, wing_alpha=235, mood="happy"):
    """cute round bee facing the viewer, size = body width"""
    S = int(size * 2.4)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2 + size * 0.08
    bw, bh = size, size * 0.86
    ow = max(4, int(size * 0.045))
    # wings (behind)
    for sx in (-1, 1):
        wx = cx + sx * bw * 0.36
        wy = cy - bh * 0.62
        box = [wx - bw * 0.3, wy - bh * 0.42, wx + bw * 0.3, wy + bh * 0.12]
        wing = canvas(S, S)
        wd = ImageDraw.Draw(wing)
        wd.ellipse(box, fill=(238, 249, 255, wing_alpha), outline=INK + (255,), width=ow)
        wd.arc([box[0] + bw * 0.08, box[1] + bh * 0.1, box[2] - bw * 0.08, box[3] - bh * 0.05], 200, 300, fill=(255, 255, 255, 255), width=max(2, ow // 2))
        wing = wing.rotate(sx * -22, center=(wx, wy + bh * 0.1), resample=Image.BICUBIC)
        img.alpha_composite(wing)
    # stinger
    d.polygon([(cx - bw * 0.06, cy + bh * 0.45), (cx + bw * 0.06, cy + bh * 0.45), (cx, cy + bh * 0.62)], fill=INK)
    # body
    body_box = [cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2]
    d.ellipse(body_box, fill=body)
    # stripes clipped to the body
    stripes = canvas(S, S)
    sd = ImageDraw.Draw(stripes)
    for k in (0.25, 0.42):
        y = cy + bh * k
        sd.rectangle([0, y - bh * 0.06, S, y + bh * 0.06], fill=stripe + (255,))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse(body_box, fill=255)
    img.paste(stripes, (0, 0), Image.composite(stripes.split()[3], Image.new("L", (S, S), 0), mask))
    # shine
    hl(img, "ellipse", [cx - bw * 0.34, cy - bh * 0.4, cx - bw * 0.1, cy - bh * 0.24], (255, 255, 255, 120))
    d.ellipse(body_box, outline=INK, width=ow)
    # antennae
    for sx in (-1, 1):
        x0, y0 = cx + sx * bw * 0.14, cy - bh * 0.44
        x1, y1 = cx + sx * bw * 0.3, cy - bh * 0.78
        d.line([(x0, y0), ((x0 + x1) / 2 + sx * bw * 0.04, (y0 + y1) / 2), (x1, y1)], fill=INK, width=ow, joint="curve")
        r = bw * 0.07
        d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=INK)
    # face
    ey = cy - bh * 0.1
    for sx in (-1, 1):
        ex = cx + sx * bw * 0.18
        rx, ry = bw * 0.11, bh * 0.15
        d.ellipse([ex - rx, ey - ry, ex + rx, ey + ry], fill=(30, 22, 18))
        d.ellipse([ex - rx * 0.5, ey - ry * 0.7, ex + rx * 0.1, ey - ry * 0.1], fill=WHITE)
        d.ellipse([ex + rx * 0.15, ey + ry * 0.2, ex + rx * 0.45, ey + ry * 0.5], fill=WHITE)
        hl(img, "ellipse", [cx + sx * bw * 0.33 - bw * 0.07, ey + bh * 0.1, cx + sx * bw * 0.33 + bw * 0.07, ey + bh * 0.18], (255, 120, 130, 170))
    if mood == "happy":
        d.arc([cx - bw * 0.1, ey + bh * 0.04, cx + bw * 0.1, ey + bh * 0.2], 15, 165, fill=INK, width=ow)
    else:
        d.ellipse([cx - bw * 0.05, ey + bh * 0.1, cx + bw * 0.05, ey + bh * 0.2], fill=INK)
    if extra:
        extra(img, d, cx, cy, bw, bh, ow)
    return img


def crown(img, d, cx, cy, bw, bh, ow):
    top = cy - bh * 0.5
    pts = [(cx - bw * 0.22, top + bh * 0.02), (cx - bw * 0.25, top - bh * 0.26), (cx - bw * 0.1, top - bh * 0.1), (cx, top - bh * 0.32),
           (cx + bw * 0.1, top - bh * 0.1), (cx + bw * 0.25, top - bh * 0.26), (cx + bw * 0.22, top + bh * 0.02)]
    d.polygon(pts, fill=(255, 210, 60), outline=INK)
    d.line(pts + [pts[0]], fill=INK, width=ow)
    for x in (-0.13, 0, 0.13):
        r = bw * 0.035
        d.ellipse([cx + bw * x - r, top - bh * 0.06 - r, cx + bw * x + r, top - bh * 0.06 + r], fill=(230, 60, 90))


def halo(img, d, cx, cy, bw, bh, ow):
    y = cy - bh * 0.78
    d.ellipse([cx - bw * 0.28, y - bh * 0.07, cx + bw * 0.28, y + bh * 0.07], outline=(255, 240, 150), width=int(ow * 1.8))
    d.ellipse([cx - bw * 0.28, y - bh * 0.07, cx + bw * 0.28, y + bh * 0.07], outline=INK, width=max(2, ow // 3))


def shades(img, d, cx, cy, bw, bh, ow):
    ey = cy - bh * 0.08
    for sx in (-1, 1):
        ex = cx + sx * bw * 0.18
        d.rounded_rectangle([ex - bw * 0.15, ey - bh * 0.1, ex + bw * 0.15, ey + bh * 0.1], radius=bw * 0.06, fill=(25, 25, 35), outline=INK, width=ow)
        d.line([(ex - bw * 0.09, ey - bh * 0.04), (ex - bw * 0.02, ey - bh * 0.07)], fill=(255, 255, 255), width=ow)
    d.line([(cx - bw * 0.03, ey - bh * 0.03), (cx + bw * 0.03, ey - bh * 0.03)], fill=INK, width=ow)


def honey_drop(size, color=HONEY):
    S = int(size * 1.6)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S * 0.58
    r = size * 0.42
    ow = max(4, int(size * 0.05))
    pts = []
    for i in range(80):
        a = i / 80 * math.tau
        x = math.sin(a)
        y = -math.cos(a)
        if y < 0:  # top half pulls into a tip
            k = (-y) ** 1.6
            x *= 1 - k * 0.85
            y *= 1 + 0.9 * k
        pts.append((cx + x * r, cy + y * r))
    d.polygon(pts, fill=color)
    d.line(pts + [pts[0]], fill=INK, width=ow)
    hl(img, "ellipse", [cx - r * 0.55, cy - r * 0.35, cx - r * 0.15, cy + r * 0.15], (255, 255, 255, 150))
    return img


def egg_layer(size, base=(255, 230, 140), spots=(255, 170, 40), gold=False):
    S = int(size * 1.6)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2
    w, h = size * 0.78, size
    ow = max(4, int(size * 0.045))
    box = [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]
    pts = []
    for i in range(100):
        a = i / 100 * math.tau
        x = math.sin(a) * w / 2
        y = -math.cos(a) * h / 2
        if y < 0:
            x *= 1 - 0.18 * (-y / (h / 2))
        pts.append((cx + x, cy + y + h * 0.04))
    d.polygon(pts, fill=base)
    spot_layer = canvas(S, S)
    sd = ImageDraw.Draw(spot_layer)
    rng = random.Random(3)
    for (fx, fy, fr) in [(-0.2, 0.05, 0.1), (0.18, -0.12, 0.08), (0.05, 0.28, 0.11), (-0.12, -0.28, 0.06), (0.24, 0.18, 0.07)]:
        sx = cx + fx * w
        sy = cy + fy * h
        r = fr * size
        sd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=spots + (255,))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(spot_layer, (0, 0), Image.composite(spot_layer.split()[3], Image.new("L", (S, S), 0), mask))
    hl(img, "ellipse", [cx - w * 0.3, cy - h * 0.32, cx - w * 0.08, cy - h * 0.08], (255, 255, 255, 140))
    d.line(pts + [pts[0]], fill=INK, width=ow)
    if gold:
        crown(img, d, cx, cy - h * 0.02, w * 1.1, h * 0.6, ow)
    return img


def hl(img, kind, box, fill):
    """semi-transparent highlight blended onto img (drawing alpha directly would punch a hole)"""
    layer = canvas(*img.size)
    d = ImageDraw.Draw(layer)
    getattr(d, kind)(box, fill=fill)
    img.alpha_composite(layer)


def place(dst, layer, cx, cy, rot=0, scale=1.0, with_shadow=True):
    if scale != 1.0:
        layer = layer.resize((int(layer.width * scale), int(layer.height * scale)), Image.LANCZOS)
    if rot:
        layer = layer.rotate(rot, resample=Image.BICUBIC, expand=True)
    if with_shadow:
        layer = shadow(layer, offset=(0, int(layer.height * 0.03)), blur=max(4, int(layer.height * 0.025)))
    dst.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


def sparkles(img, count, area, color=(255, 255, 230), size=(10, 26), seed=1):
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = area
    for _ in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        s = rng.uniform(*size)
        d.polygon([(x, y - s), (x + s * 0.25, y - s * 0.25), (x + s, y), (x + s * 0.25, y + s * 0.25), (x, y + s), (x - s * 0.25, y + s * 0.25), (x - s, y), (x - s * 0.25, y - s * 0.25)], fill=color + (230,))


def finish(img, size, name):
    img = img.resize(size, Image.LANCZOS)
    img.convert("RGB").save(OUT / name)
    return OUT / name


# ------------------------------------------------------------------------------------------------
# Square product art


def product_base(c1, c2, rays=(255, 255, 255)):
    S = 1024
    img = radial(S, S, c1, c2)
    sunburst(img, S / 2, S / 2, 18, rays, alpha=38)
    honeycomb(img, 70, (255, 255, 255), (255, 255, 255), 4, alpha=18)
    return img


def frame(img, color=(255, 255, 255)):
    d = ImageDraw.Draw(img)
    S = img.width
    d.rounded_rectangle([14, 14, S - 14, S - 14], radius=110, outline=color, width=22)


def label(img, text, y, size=150, top=(255, 255, 255), bottom=(255, 225, 120)):
    gradient_text(img, (img.width / 2, y), text, font(size), top, bottom, sw=16, shadow_px=12)


def icon_game():
    S = 1024
    img = radial(S, S, (255, 214, 90), (232, 120, 20), cy=S * 0.42)
    sunburst(img, S / 2, S * 0.42, 20, (255, 255, 255), alpha=45)
    honeycomb(img, 80, (255, 200, 60), (200, 110, 20), 5, alpha=60)
    # honey drips from the top
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, S, 70], fill=HONEY_D)
    for x, L in [(70, 150), (190, 90), (300, 210), (430, 120), (560, 170), (690, 100), (800, 230), (930, 130)]:
        d.rounded_rectangle([x - 28, 20, x + 28, 70 + L], radius=28, fill=HONEY_D)
        d.ellipse([x - 40, 40 + L, x + 40, 120 + L], fill=HONEY_D)
    d.rectangle([0, 0, S, 22], fill=(200, 100, 10))
    # honey pot
    pot = canvas(700, 700)
    pd = ImageDraw.Draw(pot)
    pd.rounded_rectangle([110, 230, 590, 640], radius=170, fill=(200, 120, 50), outline=INK, width=16)
    pd.rounded_rectangle([150, 170, 550, 280], radius=50, fill=(170, 95, 40), outline=INK, width=16)
    pd.rounded_rectangle([170, 380, 530, 500], radius=40, fill=CREAM, outline=INK, width=12)
    pd.text((350, 442), "HONEY", font=font(88), fill=HONEY_D, anchor="mm", stroke_width=6, stroke_fill=INK)
    for x, L in [(220, 110), (330, 160), (450, 90)]:
        pd.rounded_rectangle([x - 26, 230, x + 26, 230 + L], radius=26, fill=HONEY)
        pd.ellipse([x - 34, 200 + L, x + 34, 268 + L], fill=HONEY, outline=INK, width=8)
    pd.ellipse([150, 120, 550, 230], fill=HONEY, outline=INK, width=14)
    place(img, pot, S * 0.64, S * 0.74, rot=-6, scale=0.85)
    # hero bee with a crown
    place(img, bee_layer(390, extra=crown), S * 0.4, S * 0.5, rot=8)
    place(img, bee_layer(150, body=(120, 200, 255), stripe=(30, 50, 80)), S * 0.83, S * 0.33, rot=-14)
    place(img, bee_layer(130, body=(240, 90, 70), stripe=(60, 20, 10)), S * 0.15, S * 0.85, rot=12)
    sparkles(img, 14, (40, 120, S - 40, S - 40), seed=4)
    return finish(img, (512, 512), "icon_game.png")


def icon_instant():
    img = product_base((120, 220, 255), (40, 90, 220))
    d = ImageDraw.Draw(img)
    bolt = [(560, 120), (300, 560), (480, 560), (400, 900), (720, 420), (540, 420), (640, 120)]
    lay = canvas(1024, 1024)
    ld = ImageDraw.Draw(lay)
    ld.polygon(bolt, fill=(255, 235, 80))
    ld.line(bolt + [bolt[0]], fill=INK, width=24, joint="curve")
    place(img, lay, 512, 512)
    place(img, honey_drop(300), 760, 700, rot=-12)
    place(img, honey_drop(220), 250, 300, rot=14)
    label(img, "INSTANT!", 900, 150)
    frame(img)
    return finish(img, (512, 512), "product_instant_convert.png")


def flower_layer(size, petal=(255, 120, 170), center=(255, 200, 40)):
    S = int(size * 1.4)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx = cy = S / 2
    ow = max(4, int(size * 0.04))
    for i in range(6):
        a = i / 6 * math.tau
        px, py = cx + math.cos(a) * size * 0.32, cy + math.sin(a) * size * 0.32
        r = size * 0.22
        d.ellipse([px - r, py - r, px + r, py + r], fill=petal, outline=INK, width=ow)
    r = size * 0.2
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=center, outline=INK, width=ow)
    return img


def icon_booster():
    img = product_base((140, 235, 120), (30, 140, 70))
    place(img, flower_layer(560), 512, 470)
    place(img, bee_layer(250), 790, 300, rot=-14)
    label(img, "2X POLLEN", 880, 140)
    frame(img)
    return finish(img, (512, 512), "product_field_booster.png")


def honey_pile(img, cx, cy, count, size, seed=2):
    rng = random.Random(seed)
    for i in range(count):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, size * 0.9)
        place(img, honey_drop(size * rng.uniform(0.7, 1.0)), cx + math.cos(a) * r * 1.3, cy + math.sin(a) * r * 0.55, rot=rng.uniform(-25, 25))


def jar_layer(size, fill=HONEY):
    S = int(size * 1.4)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2
    ow = max(5, int(size * 0.035))
    w, h = size * 0.7, size * 0.8
    d.rounded_rectangle([cx - w / 2, cy - h / 2 + size * 0.08, cx + w / 2, cy + h / 2], radius=size * 0.18, fill=(220, 240, 255, 230), outline=INK, width=ow)
    d.rounded_rectangle([cx - w / 2 + ow * 2, cy - h * 0.1, cx + w / 2 - ow * 2, cy + h / 2 - ow * 2], radius=size * 0.14, fill=fill)
    d.rounded_rectangle([cx - w * 0.42, cy - h / 2 - size * 0.02, cx + w * 0.42, cy - h / 2 + size * 0.12], radius=size * 0.05, fill=(180, 110, 60), outline=INK, width=ow)
    d.rectangle([cx - w * 0.36, cy - h / 2 + size * 0.1, cx + w * 0.36, cy - h / 2 + size * 0.16], fill=(230, 60, 80), outline=INK, width=max(3, ow // 2))
    hl(img, "ellipse", [cx - w * 0.38, cy - h * 0.05, cx - w * 0.22, cy + h * 0.25], (255, 255, 255, 120))
    return img


def icon_pack_s():
    img = product_base((255, 220, 110), (230, 130, 30))
    place(img, jar_layer(560), 512, 450)
    honey_pile(img, 512, 760, 4, 150, seed=5)
    label(img, "HONEY PACK", 900, 130)
    frame(img)
    return finish(img, (512, 512), "product_honey_pack_s.png")


def icon_pack_l():
    img = product_base((255, 210, 80), (200, 90, 20))
    place(img, jar_layer(440), 330, 430, rot=8)
    place(img, jar_layer(500), 640, 410, rot=-6)
    honey_pile(img, 512, 720, 9, 170, seed=8)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([600, 90, 960, 230], radius=60, fill=(240, 60, 80), outline=INK, width=14)
    d.text((780, 162), "BEST VALUE", font=font(64), fill=WHITE, anchor="mm", stroke_width=5, stroke_fill=INK)
    label(img, "MEGA HONEY", 910, 130)
    frame(img, (255, 240, 170))
    return finish(img, (512, 512), "product_honey_pack_l.png")


def icon_royal_egg():
    img = product_base((200, 140, 255), (90, 30, 170), rays=(255, 230, 150))
    place(img, egg_layer(560, base=(255, 215, 80), spots=(255, 160, 30), gold=True), 512, 470)
    sparkles(img, 16, (100, 100, 924, 800), seed=9)
    label(img, "ROYAL EGG", 900, 140, bottom=(255, 210, 90))
    frame(img, (255, 220, 110))
    return finish(img, (512, 512), "product_royal_egg.png")


def flask_layer(size, liquid=(170, 90, 255)):
    S = int(size * 1.4)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2
    ow = max(5, int(size * 0.035))
    r = size * 0.36
    d.rectangle([cx - size * 0.1, cy - size * 0.5, cx + size * 0.1, cy - r * 0.6], fill=(220, 240, 255, 230), outline=INK, width=ow)
    d.ellipse([cx - r, cy - r * 0.75, cx + r, cy + r * 1.25], fill=(220, 240, 255, 230), outline=INK, width=ow)
    d.chord([cx - r + ow * 1.5, cy - r * 0.75 + ow * 1.5, cx + r - ow * 1.5, cy + r * 1.25 - ow * 1.5], 10, 170, fill=liquid)
    d.rounded_rectangle([cx - size * 0.13, cy - size * 0.6, cx + size * 0.13, cy - size * 0.48], radius=size * 0.03, fill=(170, 100, 50), outline=INK, width=ow)
    for (bx, by, br) in [(-0.12, 0.25, 0.05), (0.08, 0.1, 0.035), (0.0, 0.35, 0.03)]:
        hl(img, "ellipse", [cx + size * bx - size * br, cy + size * by - size * br, cx + size * bx + size * br, cy + size * by + size * br], (255, 255, 255, 170))
    hl(img, "ellipse", [cx - r * 0.7, cy - r * 0.45, cx - r * 0.35, cy + r * 0.05], (255, 255, 255, 140))
    return img


def icon_serum():
    img = product_base((120, 255, 220), (40, 60, 160), rays=(190, 255, 240))
    glow = canvas(1024, 1024)
    ImageDraw.Draw(glow).ellipse([250, 250, 774, 774], fill=(170, 120, 255, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
    place(img, flask_layer(600, liquid=(160, 90, 255)), 512, 470, rot=-8)
    sparkles(img, 14, (120, 120, 904, 760), color=(220, 255, 250), seed=12)
    label(img, "MUTATION", 900, 140, bottom=(190, 255, 240))
    frame(img, (200, 255, 240))
    return finish(img, (512, 512), "product_mutation_serum.png")


def icon_ladder(mult, name):
    img = product_base((255, 120, 190), (200, 40, 110), rays=(255, 230, 150))
    place(img, honey_drop(560), 512, 420)
    gradient_text(img, (512, 450), f"x{mult}", font(260 if mult < 100 else 210), (255, 255, 255), (255, 230, 120), sw=20, shadow_px=14)
    label(img, "HONEY FOREVER", 880, 112)
    frame(img, (255, 230, 150))
    return finish(img, (512, 512), name)


def icon_extra_slots():
    img = product_base((255, 200, 80), (210, 110, 20))
    lay = canvas(1024, 1024)
    d = ImageDraw.Draw(lay)
    for (x, y, c) in [(380, 360, (255, 236, 170)), (640, 360, (255, 236, 170)), (510, 585, HONEY), (250, 585, HONEY), (770, 585, HONEY), (380, 810, HONEY), (640, 810, HONEY)]:
        d.polygon(hexagon(x, y, 140, 30), fill=c, outline=INK, width=16)
    img.alpha_composite(lay)
    place(img, bee_layer(220), 380, 360, with_shadow=False)
    place(img, bee_layer(220, body=(120, 200, 255), stripe=(30, 50, 80)), 640, 360, with_shadow=False)
    gradient_text(img, (512, 640), "+2", font(300), (255, 255, 255), (255, 225, 110), sw=20, shadow_px=14)
    label(img, "HIVE SLOTS", 920, 130)
    frame(img)
    return finish(img, (512, 512), "pass_extra_slots.png")


def icon_vip():
    img = product_base((255, 230, 120), (190, 120, 10), rays=(255, 255, 220))
    lay = canvas(1024, 1024)
    d = ImageDraw.Draw(lay)
    pts = [(220, 600), (180, 260), (360, 420), (512, 200), (664, 420), (844, 260), (804, 600)]
    d.polygon(pts, fill=(255, 210, 50))
    d.line(pts + [pts[0]], fill=INK, width=22, joint="curve")
    d.rounded_rectangle([200, 580, 824, 700], radius=30, fill=(240, 180, 30), outline=INK, width=20)
    for x, c in [(330, (80, 200, 255)), (512, (240, 60, 90)), (694, (90, 220, 120))]:
        d.ellipse([x - 42, 598, x + 42, 682], fill=c, outline=INK, width=10)
    img.alpha_composite(shadow(lay))
    label(img, "VIP", 830, 230, bottom=(255, 220, 80))
    frame(img, (255, 240, 170))
    return finish(img, (512, 512), "pass_vip_field.png")


def icon_auto_convert():
    img = product_base((140, 230, 255), (50, 120, 200))
    def goggles(img, d, cx, cy, bw, bh, ow):
        shades(img, d, cx, cy, bw, bh, ow)
        y = cy - bh * 0.5
        d.rounded_rectangle([cx - bw * 0.2, y - bh * 0.12, cx + bw * 0.2, y + bh * 0.02], radius=bw * 0.04, fill=(200, 205, 215), outline=INK, width=ow)
    place(img, bee_layer(480, extra=goggles), 420, 470, rot=8)
    # converting arrows: pollen -> honey
    lay = canvas(1024, 1024)
    d = ImageDraw.Draw(lay)
    d.arc([560, 280, 900, 620], 300, 60, fill=WHITE, width=34)
    d.polygon([(860, 560), (930, 470), (820, 470)], fill=WHITE)
    img.alpha_composite(shadow(lay))
    place(img, honey_drop(220), 790, 690, rot=-10)
    label(img, "AUTO CONVERT", 900, 120)
    frame(img)
    return finish(img, (512, 512), "pass_auto_convert.png")


def pencil_layer(length):
    """chunky cartoon pencil lying along +X (eraser on the left, tip on the right)"""
    S = int(length * 1.2)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cy = S / 2
    w = length * 0.16
    x0 = (S - length) / 2
    ow = max(5, int(length * 0.025))
    er = x0 + length * 0.14
    band = er + length * 0.07
    body_end = x0 + length * 0.78
    d.rounded_rectangle([x0, cy - w / 2, er + 10, cy + w / 2], radius=w * 0.35, fill=(255, 140, 170), outline=INK, width=ow)
    d.rectangle([er, cy - w / 2, band, cy + w / 2], fill=(200, 205, 215), outline=INK, width=ow)
    d.rectangle([band, cy - w / 2, body_end, cy + w / 2], fill=(255, 200, 40), outline=INK, width=ow)
    d.line([(band, cy), (body_end, cy)], fill=(235, 160, 20), width=int(w * 0.28))
    tip = x0 + length
    d.polygon([(body_end, cy - w / 2), (tip, cy), (body_end, cy + w / 2)], fill=(240, 200, 150), outline=INK)
    d.line([(body_end, cy - w / 2), (tip, cy), (body_end, cy + w / 2)], fill=INK, width=ow)
    gx = body_end + (tip - body_end) * 0.62
    d.polygon([(gx, cy - w * 0.19), (tip, cy), (gx, cy + w * 0.19)], fill=(60, 60, 70))
    hl(img, "rectangle", [band + 10, cy - w * 0.38, body_end - 10, cy - w * 0.22], (255, 255, 255, 110))
    return img


def icon_group():
    """studio emblem: honey badge, mascot bee with a pencil (no text, works with any group name)"""
    S = 1024
    img = radial(S, S, (255, 225, 110), (235, 120, 20))
    sunburst(img, S / 2, S / 2, 20, (255, 255, 255), alpha=40)
    badge = canvas(S, S)
    d = ImageDraw.Draw(badge)
    d.polygon(hexagon(512, 512, 430, 30), fill=INK)
    d.polygon(hexagon(512, 512, 400, 30), fill=(255, 196, 46))
    d.polygon(hexagon(512, 512, 330, 30), fill=(255, 226, 120))
    inner = canvas(S, S)
    honeycomb(inner, 60, (255, 210, 80), (235, 170, 40), 5, alpha=255)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(hexagon(512, 512, 330, 30), fill=255)
    badge.paste(inner, (0, 0), mask)
    d.polygon(hexagon(512, 512, 330, 30), outline=INK, width=14)
    img.alpha_composite(shadow(badge, offset=(0, 16), blur=20))
    place(img, pencil_layer(620), 520, 650, rot=28)
    place(img, bee_layer(400), 512, 470, rot=-6)
    sparkles(img, 12, (80, 80, 944, 944), seed=17)
    return finish(img, (512, 512), "group_icon.png")


# ------------------------------------------------------------------------------------------------
# Thumbnails 1920x1080 (drawn at 2x)

W, H = 3840, 2160


def landscape(top=(120, 200, 255), bottom=(210, 240, 255), hills=((120, 200, 90), (90, 170, 70)), seed=1):
    img = vgradient(W, H, top, bottom)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    for k, col in enumerate(hills):
        base = H * (0.62 + 0.1 * k)
        pts = [(0, H)]
        for i in range(0, 33):
            x = i / 32 * W
            y = base - math.sin(i * 0.5 + k * 1.7) * 90 - rng.uniform(0, 40)
            pts.append((x, y))
        pts.append((W, H))
        d.polygon(pts, fill=col)
    # clouds
    for _ in range(6):
        cx, cy = rng.uniform(0, W), rng.uniform(150, H * 0.35)
        for j in range(5):
            r = rng.uniform(80, 160)
            d.ellipse([cx + j * 110 - r, cy - r * 0.6, cx + j * 110 + r, cy + r * 0.6], fill=(255, 255, 255, 230))
    return img


def flower_field(img, y0, y1, count, seed=3):
    rng = random.Random(seed)
    colors = [(255, 120, 170), (255, 255, 255), (120, 170, 255), (255, 90, 80), (255, 210, 60)]
    items = sorted([(rng.uniform(y0, y1), rng.uniform(0, W)) for _ in range(count)])
    for y, x in items:
        s = 70 + (y - y0) / (y1 - y0) * 120
        place(img, flower_layer(s, petal=rng.choice(colors)), x, y, with_shadow=False)


def logo(img, cx, cy, scale=1.0):
    gradient_text(img, (cx, cy - 150 * scale), "BEE TYCOON", font(int(330 * scale)), (255, 250, 210), (255, 180, 30), sw=int(30 * scale), shadow_px=int(22 * scale))
    gradient_text(img, (cx, cy + 170 * scale), "HONEY EMPIRE", font(int(210 * scale)), (255, 255, 255), (255, 220, 120), sw=int(24 * scale), shadow_px=int(18 * scale))


def banner(img, cx, cy, text, size=200, color=(240, 60, 80)):
    f = font(size)
    d = ImageDraw.Draw(img)
    w = d.textlength(text, font=f) + size
    d.rounded_rectangle([cx - w / 2, cy - size * 0.75, cx + w / 2, cy + size * 0.75], radius=size * 0.6, fill=color, outline=INK, width=int(size * 0.12))
    outlined_text(img, (cx, cy + size * 0.06), text, f, WHITE, sw=int(size * 0.07), shadow_px=int(size * 0.05))


def hive_house(size):
    S = int(size * 1.3)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2 + size * 0.05
    ow = max(6, int(size * 0.025))
    for sx in (-1, 1):
        d.rectangle([cx + sx * size * 0.42 - size * 0.04, cy - size * 0.4, cx + sx * size * 0.42 + size * 0.04, cy + size * 0.5], fill=(140, 90, 50), outline=INK, width=ow)
    hexr = size * 0.42
    d.polygon(hexagon(cx, cy, hexr, 0), fill=(200, 130, 60), outline=INK, width=ow)
    for i, (x, y) in enumerate([(0, 0), (-0.17, -0.1), (0.17, -0.1), (-0.17, 0.1), (0.17, 0.1), (0, -0.2), (0, 0.2)]):
        col = HONEY if i % 3 else (255, 236, 170)
        d.polygon(hexagon(cx + x * size, cy + y * size, size * 0.1, 0), fill=col, outline=INK, width=max(3, ow // 2))
    d.polygon([(cx - size * 0.58, cy - size * 0.38), (cx, cy - size * 0.68), (cx + size * 0.58, cy - size * 0.38), (cx + size * 0.5, cy - size * 0.3), (cx, cy - size * 0.56), (cx - size * 0.5, cy - size * 0.3)], fill=(220, 70, 50), outline=INK, width=ow)
    return img


def thumb_title():
    img = landscape(seed=2)
    sunburst(img, W / 2, H * 0.45, 26, (255, 255, 230), alpha=40)
    flower_field(img, H * 0.74, H * 1.02, 70, seed=4)
    place(img, hive_house(900), W * 0.85, H * 0.64)
    place(img, bee_layer(700, extra=crown), W * 0.17, H * 0.64, rot=10)
    rng = random.Random(7)
    looks = [(HONEY, INK, None), ((120, 200, 255), (30, 50, 80), shades), ((240, 90, 70), (60, 20, 10), None), ((255, 240, 150), (255, 150, 40), halo), ((150, 230, 60), (90, 30, 110), None)]
    for i in range(9):
        body, stripe, ex = looks[i % len(looks)]
        place(img, bee_layer(rng.uniform(170, 260), body=body, stripe=stripe, extra=ex), rng.uniform(W * 0.35, W * 0.7), rng.uniform(H * 0.62, H * 0.9), rot=rng.uniform(-20, 20))
    logo(img, W * 0.5, H * 0.28, 1.25)
    return finish(img, (1920, 1080), "thumb_1_title.png")


def thumb_hatch():
    img = radial(W, H, (255, 220, 120), (200, 90, 30))
    sunburst(img, W / 2, H * 0.55, 30, (255, 255, 230), alpha=45)
    honeycomb(img, 160, (255, 255, 255), (255, 255, 255), 6, alpha=14)
    eggs = [((255, 240, 200), (255, 190, 90), False), ((220, 225, 235), (150, 170, 200), False), ((255, 215, 80), (255, 160, 30), True)]
    for i, (base, spots, gold) in enumerate(eggs):
        place(img, egg_layer(520 if not gold else 640, base=base, spots=spots, gold=gold), W * (0.3 + 0.2 * i), H * 0.78, rot=(i - 1) * -6)
    looks = [(HONEY, INK, None), ((110, 140, 230), (30, 30, 50), None), ((240, 80, 50), (60, 20, 10), None), ((90, 170, 255), (230, 245, 255), shades),
             ((255, 90, 30), (255, 220, 80), crown), ((40, 20, 70), (170, 80, 255), halo), ((255, 140, 200), (255, 250, 250), None), ((220, 245, 255), (120, 200, 255), halo)]
    for i, (body, stripe, ex) in enumerate(looks):
        x = W * (0.08 + i * 0.12)
        y = H * (0.44 if i % 2 == 0 else 0.5)
        place(img, bee_layer(300, body=body, stripe=stripe, extra=ex), x, y, rot=(-8 if i % 2 == 0 else 8))
    banner(img, W / 2, H * 0.16, "HATCH 30 BEES!", 230)
    sparkles(img, 30, (0, 0, W, H), seed=13)
    return finish(img, (1920, 1080), "thumb_2_hatch.png")


def thumb_mutations():
    img = vgradient(W, H, (40, 20, 80), (110, 40, 160))
    sunburst(img, W / 2, H * 0.55, 30, (255, 255, 255), alpha=20)
    trio = [("GIFTED", (255, 215, 90), (255, 200, 40), INK), ("NEON", (90, 255, 220), (90, 255, 220), (20, 80, 90)), ("SHADOW", (170, 80, 255), (70, 40, 110), (200, 140, 255))]
    for i, (name, glow_c, body, stripe) in enumerate(trio):
        x = W * (0.2 + 0.3 * i)
        glow = canvas(W, H)
        ImageDraw.Draw(glow).ellipse([x - 520, H * 0.56 - 520, x + 520, H * 0.56 + 520], fill=glow_c + (150,))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
        place(img, bee_layer(620, body=body, stripe=stripe, extra=crown if i == 0 else (halo if i == 2 else shades)), x, H * 0.55, rot=(i - 1) * 8)
        outlined_text(img, (x, H * 0.86), name, font(190), glow_c, sw=16, shadow_px=12)
    sparkles(img, 50, (0, 0, W, H), color=(255, 255, 255), seed=21)
    banner(img, W / 2, H * 0.14, "RARE MUTATIONS", 220, color=(150, 60, 230))
    return finish(img, (1920, 1080), "thumb_3_mutations.png")


def beetle_layer(size):
    S = int(size * 1.5)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2
    ow = max(8, int(size * 0.025))
    for sx in (-1, 1):
        for k in range(3):
            y = cy + (k - 1) * size * 0.2
            d.line([(cx + sx * size * 0.3, y), (cx + sx * size * 0.55, y + size * 0.12)], fill=INK, width=ow * 2)
    d.ellipse([cx - size * 0.45, cy - size * 0.35, cx + size * 0.45, cy + size * 0.45], fill=(80, 50, 150), outline=INK, width=ow)
    d.line([(cx, cy - size * 0.3), (cx, cy + size * 0.45)], fill=INK, width=ow)
    d.ellipse([cx - size * 0.25, cy - size * 0.6, cx + size * 0.25, cy - size * 0.22], fill=(50, 30, 90), outline=INK, width=ow)
    for sx in (-1, 1):
        d.ellipse([cx + sx * size * 0.1 - size * 0.06, cy - size * 0.5, cx + sx * size * 0.1 + size * 0.06, cy - size * 0.38], fill=(255, 60, 60))
        d.line([(cx + sx * size * 0.1, cy - size * 0.58), (cx + sx * size * 0.32, cy - size * 0.8)], fill=INK, width=ow)
    d.polygon([(cx - size * 0.1, cy - size * 0.72), (cx, cy - size * 1.0), (cx + size * 0.1, cy - size * 0.72)], fill=(255, 210, 60), outline=INK)
    for (sx2, sy2, sr) in [(-0.22, 0.05, 0.08), (0.2, 0.15, 0.1), (-0.12, 0.3, 0.07), (0.25, -0.1, 0.06)]:
        d.ellipse([cx + size * (sx2 - sr), cy + size * (sy2 - sr), cx + size * (sx2 + sr), cy + size * (sy2 + sr)], fill=(255, 210, 60), outline=INK, width=ow)
    hl(img, "ellipse", [cx - size * 0.32, cy - size * 0.28, cx - size * 0.14, cy - size * 0.12], (255, 255, 255, 110))
    return img


def thumb_fields_boss():
    img = landscape(top=(255, 150, 90), bottom=(255, 220, 160), hills=((110, 180, 80), (80, 150, 60)), seed=5)
    flower_field(img, H * 0.72, H * 1.02, 90, seed=9)
    place(img, beetle_layer(1100), W * 0.7, H * 0.5)
    d = ImageDraw.Draw(img)
    # boss health bar
    d.rounded_rectangle([W * 0.5, H * 0.08, W * 0.92, H * 0.15], radius=40, fill=(40, 20, 20), outline=INK, width=14)
    d.rounded_rectangle([W * 0.5 + 16, H * 0.08 + 16, W * 0.5 + (W * 0.42 - 32) * 0.62, H * 0.15 - 16], radius=30, fill=(240, 60, 60))
    outlined_text(img, (W * 0.71, H * 0.115), "KING BEETLE", font(110), WHITE, sw=10, shadow_px=6)
    rng = random.Random(3)
    for i in range(7):
        place(img, bee_layer(rng.uniform(220, 320), body=rng.choice([HONEY, (240, 90, 70), (120, 200, 255)]), stripe=INK, mood="fight"), rng.uniform(W * 0.08, W * 0.45), rng.uniform(H * 0.35, H * 0.75), rot=rng.uniform(-25, 25))
    banner(img, W * 0.27, H * 0.16, "10 FIELDS", 200, color=(70, 170, 70))
    banner(img, W * 0.27, H * 0.88, "WORLD BOSSES!", 190, color=(220, 50, 60))
    return finish(img, (1920, 1080), "thumb_4_fields_bosses.png")


def gift_layer(size, box=(240, 60, 90), ribbon=(255, 210, 60)):
    S = int(size * 1.5)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2 + size * 0.1
    ow = max(6, int(size * 0.035))
    d.rectangle([cx - size * 0.4, cy - size * 0.2, cx + size * 0.4, cy + size * 0.45], fill=box, outline=INK, width=ow)
    d.rectangle([cx - size * 0.47, cy - size * 0.38, cx + size * 0.47, cy - size * 0.18], fill=lerp(box, (255, 255, 255), 0.25), outline=INK, width=ow)
    d.rectangle([cx - size * 0.08, cy - size * 0.38, cx + size * 0.08, cy + size * 0.45], fill=ribbon, outline=INK, width=ow)
    for sx in (-1, 1):
        d.ellipse([cx + sx * size * 0.16 - size * 0.17, cy - size * 0.62, cx + sx * size * 0.16 + size * 0.17, cy - size * 0.36], outline=ribbon, width=int(size * 0.07))
    return img


def thumb_rewards():
    img = radial(W, H, (140, 230, 255), (40, 100, 210))
    sunburst(img, W / 2, H * 0.55, 30, (255, 255, 255), alpha=35)
    place(img, gift_layer(700), W * 0.5, H * 0.6)
    place(img, gift_layer(420, box=(90, 200, 110), ribbon=(255, 255, 255)), W * 0.25, H * 0.72, rot=10)
    place(img, gift_layer(420, box=(160, 90, 240), ribbon=(255, 210, 60)), W * 0.75, H * 0.72, rot=-10)
    honey_pile(img, W * 0.5, H * 0.86, 10, 200, seed=4)
    place(img, bee_layer(300), W * 0.15, H * 0.32, rot=-12)
    place(img, bee_layer(260, body=(255, 240, 150), stripe=(255, 150, 40), extra=halo), W * 0.86, H * 0.3, rot=12)
    banner(img, W / 2, H * 0.15, "FREE DAILY REWARDS", 200, color=(240, 140, 30))
    sparkles(img, 40, (0, 0, W, H), seed=31)
    return finish(img, (1920, 1080), "thumb_5_rewards.png")


if __name__ == "__main__":
    made = [
        icon_game(), icon_group(),
        icon_instant(), icon_booster(), icon_pack_s(), icon_pack_l(), icon_royal_egg(), icon_serum(),
        icon_extra_slots(), icon_vip(), icon_auto_convert(),
    ]
    for tier in range(1, 11):
        made.append(icon_ladder(2 ** tier, f"product_honey_forever_x{2 ** tier}.png"))
    made += [thumb_title(), thumb_hatch(), thumb_mutations(), thumb_fields_boss(), thumb_rewards()]
    for p in made:
        print(p.name)
