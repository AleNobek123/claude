#!/usr/bin/env python3
"""Generates the flat vector-style UI icons (PNG, transparent) used by the game.

Drawn at 4x and downsampled for smooth anti-aliased edges. Output: assets/icons/*.png
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons"
OUT.mkdir(parents=True, exist_ok=True)
S = 1024  # working size
FINAL = 256

HONEY = (255, 190, 40)
HONEY_D = (230, 140, 20)
HONEY_L = (255, 226, 120)
BROWN = (80, 50, 25)
WHITE = (255, 255, 255)
CREAM = (255, 246, 225)
BLUE = (90, 170, 255)
GREEN = (110, 210, 110)
PINK = (255, 120, 170)
PURPLE = (170, 110, 255)
GREY = (120, 120, 130)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def save(img, name):
    img.resize((FINAL, FINAL), Image.LANCZOS).save(OUT / f"{name}.png")


def hexagon(cx, cy, r, rot=90):
    return [(cx + r * math.cos(math.radians(rot + i * 60)), cy + r * math.sin(math.radians(rot + i * 60))) for i in range(6)]


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def drop(d, cx, cy, r, color):
    # teardrop: circle + triangle tip pointing up
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    d.polygon([(cx - r * 0.93, cy - r * 0.35), (cx, cy - r * 2.0), (cx + r * 0.93, cy - r * 0.35)], fill=color)


# --- honey: golden drop with highlight -------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
drop(d, 512, 600, 300, HONEY_D)
drop(d, 512, 585, 280, HONEY)
d.ellipse([360, 470, 460, 600], fill=HONEY_L)
d.ellipse([400, 650, 450, 700], fill=HONEY_L)
save(img, "honey")

# --- pollen: fluffy yellow ball with sparkles -----------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
for a in range(0, 360, 30):
    x = 512 + 250 * math.cos(math.radians(a)); y = 540 + 250 * math.sin(math.radians(a))
    d.ellipse([x - 110, y - 110, x + 110, y + 110], fill=(255, 220, 70))
d.ellipse([262, 290, 762, 790], fill=(255, 210, 50))
d.ellipse([340, 360, 480, 480], fill=(255, 240, 160))
d.polygon(star(800, 230, 110, 35, 4, -90), fill=WHITE)
d.polygon(star(230, 820, 70, 22, 4, -90), fill=WHITE)
save(img, "pollen")

# --- backpack ---------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.rounded_rectangle([300, 160, 724, 300], 70, fill=(150, 95, 50))
d.rounded_rectangle([370, 200, 654, 280], 40, fill=(0, 0, 0, 0))
d.rounded_rectangle([230, 260, 794, 900], 150, fill=(196, 128, 64))
d.rounded_rectangle([230, 260, 794, 520], 150, fill=(170, 105, 50))
d.rounded_rectangle([330, 590, 694, 830], 70, fill=(150, 95, 50))
d.rounded_rectangle([470, 470, 554, 560], 25, fill=HONEY)
save(img, "backpack")

# --- bee --------------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([170, 210, 470, 520], fill=(230, 245, 255, 235))
d.ellipse([554, 210, 854, 520], fill=(230, 245, 255, 235))
d.ellipse([210, 330, 814, 860], fill=HONEY)
body = Image.new("L", (S, S), 0); bd = ImageDraw.Draw(body); bd.ellipse([210, 330, 814, 860], fill=255)
stripes = canvas(); sd = ImageDraw.Draw(stripes)
sd.rectangle([400, 300, 480, 900], fill=BROWN); sd.rectangle([560, 300, 640, 900], fill=BROWN)
img.paste(stripes, (0, 0), Image.composite(stripes, Image.new("RGBA", (S, S)), body).split()[3])
d = ImageDraw.Draw(img)
d.ellipse([250, 500, 360, 640], fill=BROWN)
d.ellipse([275, 520, 310, 560], fill=WHITE)
d.line([(330, 380), (250, 220)], fill=BROWN, width=28); d.ellipse([215, 185, 285, 255], fill=BROWN)
d.line([(420, 350), (400, 190)], fill=BROWN, width=28); d.ellipse([365, 155, 435, 225], fill=BROWN)
d.polygon([(805, 560), (900, 600), (805, 640)], fill=BROWN)
save(img, "bee")

# --- egg --------------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([270, 150, 754, 900], fill=CREAM)
d.ellipse([300, 180, 724, 870], fill=(255, 250, 238))
for (x, y, r) in [(420, 420, 50), (600, 330, 38), (630, 620, 60), (440, 700, 42), (540, 520, 30)]:
    d.ellipse([x - r, y - r, x + r, y + r], fill=HONEY)
d.ellipse([360, 250, 430, 360], fill=WHITE)
save(img, "egg")

# --- hive / home ------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
layers = [(300, 230, 724, 360), (240, 340, 784, 500), (220, 480, 804, 650), (260, 630, 764, 800)]
cols = [HONEY_L, HONEY, (255, 175, 35), HONEY_D]
for (box, c) in zip(layers, cols):
    d.rounded_rectangle(box, 80, fill=c)
d.rounded_rectangle([430, 620, 594, 800], 80, fill=BROWN)
d.rounded_rectangle([200, 790, 824, 860], 30, fill=(150, 95, 50))
save(img, "home")

# --- honeycomb (hive grid) --------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
r = 150
for (cx, cy, c) in [(512, 512, HONEY), (512 - 260, 512, HONEY_D), (512 + 260, 512, HONEY_D), (512 - 130, 512 - 225, HONEY_L), (512 + 130, 512 - 225, HONEY), (512 - 130, 512 + 225, HONEY), (512 + 130, 512 + 225, HONEY_L)]:
    d.polygon(hexagon(cx, cy, r), fill=c)
    d.polygon(hexagon(cx, cy, r * 0.6), fill=tuple(max(0, v - 25) for v in c))
save(img, "honeycomb")

# --- shop bag ---------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.arc([370, 160, 654, 440], 180, 360, fill=(60, 140, 60), width=50)
d.rounded_rectangle([220, 330, 804, 880], 90, fill=GREEN)
d.rounded_rectangle([220, 330, 804, 470], 90, fill=(140, 225, 140))
d.ellipse([380, 380, 430, 430], fill=(60, 140, 60)); d.ellipse([594, 380, 644, 430], fill=(60, 140, 60))
d.polygon(hexagon(512, 650, 120), fill=HONEY)
save(img, "shop")

# --- book (codex) -----------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.rounded_rectangle([200, 180, 830, 860], 70, fill=(70, 120, 220))
d.rounded_rectangle([250, 220, 830, 820], 50, fill=BLUE)
d.rounded_rectangle([200, 780, 830, 880], 40, fill=CREAM)
d.rectangle([200, 180, 300, 860], fill=(55, 95, 190))
d.polygon(hexagon(560, 480, 150), fill=HONEY)
d.polygon(hexagon(560, 480, 80), fill=HONEY_L)
save(img, "book")

# --- gear -------------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
for i in range(8):
    a = math.radians(i * 45)
    cx, cy = 512 + 300 * math.cos(a), 512 + 300 * math.sin(a)
    d.rounded_rectangle([cx - 85, cy - 85, cx + 85, cy + 85], 30, fill=(150, 160, 175))
d.ellipse([200, 200, 824, 824], fill=(170, 180, 195))
d.ellipse([370, 370, 654, 654], fill=(0, 0, 0, 0))
inner = Image.new("L", (S, S), 255); ImageDraw.Draw(inner).ellipse([370, 370, 654, 654], fill=0)
img.putalpha(Image.composite(img.split()[3], Image.new("L", (S, S), 0), inner))
save(img, "gear")

# --- gift (robux store) -----------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.rounded_rectangle([210, 420, 814, 880], 60, fill=(235, 64, 92))
d.rounded_rectangle([170, 320, 854, 470], 50, fill=(255, 120, 140))
d.rectangle([462, 320, 562, 880], fill=HONEY)
d.ellipse([300, 170, 520, 360], outline=HONEY, width=60)
d.ellipse([504, 170, 724, 360], outline=HONEY, width=60)
save(img, "gift")

# --- close X ----------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.line([(300, 300), (724, 724)], fill=WHITE, width=150)
d.line([(724, 300), (300, 724)], fill=WHITE, width=150)
for (x, y) in [(300, 300), (724, 724), (724, 300), (300, 724)]:
    d.ellipse([x - 75, y - 75, x + 75, y + 75], fill=WHITE)
save(img, "close")

# --- lock -------------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.arc([330, 170, 694, 560], 180, 360, fill=(200, 200, 210), width=80)
d.rectangle([330, 360, 410, 470], fill=(200, 200, 210)); d.rectangle([614, 360, 694, 470], fill=(200, 200, 210))
d.rounded_rectangle([250, 440, 774, 870], 80, fill=(240, 240, 245))
d.ellipse([462, 570, 562, 670], fill=GREY); d.rectangle([492, 640, 532, 760], fill=GREY)
save(img, "lock")

# --- treat (cookie) ---------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([190, 190, 834, 834], fill=(210, 150, 80))
d.ellipse([230, 220, 794, 784], fill=(230, 175, 100))
for (x, y, r) in [(380, 380, 50), (600, 330, 40), (650, 560, 55), (420, 620, 45), (540, 480, 35), (330, 520, 30)]:
    d.ellipse([x - r, y - r, x + r, y + r], fill=(110, 65, 35))
save(img, "treat")

# --- serum (potion) ---------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.rounded_rectangle([430, 150, 594, 360], 30, fill=(200, 230, 255))
d.rounded_rectangle([400, 120, 624, 200], 30, fill=(150, 100, 60))
d.ellipse([230, 300, 794, 880], fill=(200, 230, 255))
d.chord([260, 330, 764, 850], 10, 170, fill=PURPLE)
d.ellipse([330, 420, 420, 520], fill=WHITE)
save(img, "serum")

# --- music note -------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([200, 620, 440, 820], fill=WHITE); d.ellipse([560, 560, 800, 760], fill=WHITE)
d.rectangle([380, 230, 440, 720], fill=WHITE); d.rectangle([740, 170, 800, 660], fill=WHITE)
d.polygon([(380, 230), (800, 170), (800, 300), (380, 360)], fill=WHITE)
save(img, "music")

# --- speaker (sfx) ----------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([180, 400, 340, 624], fill=WHITE)
d.polygon([(320, 400), (560, 200), (560, 824), (320, 624)], fill=WHITE)
d.arc([500, 340, 760, 684], -50, 50, fill=WHITE, width=60)
d.arc([520, 230, 900, 794], -50, 50, fill=WHITE, width=60)
save(img, "speaker")

# --- sparkles (graphics) ----------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.polygon(star(450, 560, 330, 90, 4), fill=WHITE)
d.polygon(star(770, 270, 160, 45, 4), fill=WHITE)
d.polygon(star(790, 760, 110, 32, 4), fill=WHITE)
save(img, "sparkles")

# --- ticket (codes) ---------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.rounded_rectangle([150, 300, 874, 724], 60, fill=PINK)
d.ellipse([90, 450, 210, 574], fill=(0, 0, 0, 0))
mask = Image.new("L", (S, S), 255); md = ImageDraw.Draw(mask)
md.ellipse([90, 450, 210, 574], fill=0); md.ellipse([814, 450, 934, 574], fill=0)
img.putalpha(Image.composite(img.split()[3], Image.new("L", (S, S), 0), mask))
d = ImageDraw.Draw(img)
for y in range(340, 700, 60):
    d.rectangle([640, y, 660, y + 30], fill=WHITE)
d.polygon(star(410, 512, 130, 55, 5), fill=WHITE)
save(img, "ticket")

# --- lightning (event) ------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.polygon([(580, 120), (260, 580), (480, 580), (400, 900), (760, 420), (540, 420), (640, 120)], fill=HONEY)
d.polygon([(560, 170), (330, 540), (480, 540), (450, 760)], fill=HONEY_L)
save(img, "lightning")

# --- check ------------------------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.line([(250, 540), (430, 720), (790, 320)], fill=WHITE, width=150, joint="curve")
for (x, y) in [(250, 540), (430, 720), (790, 320)]:
    d.ellipse([x - 75, y - 75, x + 75, y + 75], fill=WHITE)
save(img, "check")

# --- star (rarity / reward) -------------------------------------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.polygon(star(512, 540, 420, 190, 5), fill=HONEY_D)
d.polygon(star(512, 525, 380, 170, 5), fill=HONEY)
save(img, "star")

# --- solid white hexagon (hive grid cells, tinted in-game) --------------------------------------
img = canvas(); d = ImageDraw.Draw(img)
d.polygon(hexagon(512, 512, 500, 90), fill=WHITE)
save(img, "hex")
img = canvas(); d = ImageDraw.Draw(img)
d.polygon(hexagon(512, 512, 500, 90), fill=WHITE)
d.polygon(hexagon(512, 512, 430, 90), fill=(0, 0, 0, 0))
save(img, "hex_ring")

# --- soft round glow / shadow (9-slice friendly) -------------------------------------------------
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([160, 160, 864, 864], 160, fill=(0, 0, 0, 255))
img = img.filter(ImageFilter.GaussianBlur(70))
save(img, "shadow")
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.ellipse([200, 200, 824, 824], fill=(255, 255, 255, 255))
img = img.filter(ImageFilter.GaussianBlur(90))
save(img, "glow")

print("icons:", sorted(p.stem for p in OUT.glob("*.png")))
