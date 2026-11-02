#!/usr/bin/env python3
"""Рендер кадров загрузочного экрана в PNG — превью без Godot.

Математика и спрайты совпадают с client/ui/pixel_scene.gd, поэтому картинка
здесь = картинка в игре. Правим композицию, не собирая APK.

Запуск: python3 tools/preview_boot.py
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))

GRID = (120, 214)

SKY = [(8, 11, 24), (13, 18, 38), (21, 27, 54), (31, 35, 68), (45, 43, 84)]
MOON = (242, 238, 216)
MOON_SHADE = (206, 202, 178)
STAR = [(255, 255, 255), (196, 214, 255), (255, 236, 176)]
RIDGE_FAR = (25, 32, 60)
RIDGE_NEAR = (15, 20, 40)
TREE = (8, 11, 24)
GROUND = (9, 12, 24)
GROUND_HI = (16, 21, 38)
GRASS = (17, 25, 42)
STONE = (46, 50, 66)
LOG = (62, 40, 26)
LOG_DARK = (34, 22, 15)
FIRE = [(188, 52, 18), (238, 118, 30), (255, 186, 62), (255, 246, 190)]
EMBER = (255, 158, 64)
FLY = (206, 255, 96)
TENT = (33, 29, 48)
TENT_SHADE = (21, 18, 34)
GUARD = (28, 32, 50)
GUARD_LIT = (168, 96, 44)
BAR_TROUGH = (13, 17, 32)
BAR_TROUGH_HI = (21, 27, 48)
BAR_EDGE = (74, 92, 132)
BAR_EDGE_DARK = (26, 33, 52)
FILL_A = (92, 226, 146)
FILL_B = (52, 178, 166)
FILL_HI = (198, 255, 216)
HERO = (6, 9, 13)
HERO_LIT = (150, 90, 44)
HERO_HI = (196, 214, 168)
CLOAK = (44, 164, 116)
CLOAK_DARK = (26, 104, 78)
CLOAK_LIT = (120, 226, 172)
SKIN = (233, 191, 150)
SKIN_SHADE = (188, 140, 104)
BOOT = (28, 32, 44)
BOOT_HI = (74, 82, 104)
OUTLINE = (4, 6, 10)
DUST = (96, 124, 164)

BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

# --- спрайты -------------------------------------------------------------

# бегун по полоске загрузки: 10x14, 4 кадра
RUNNER_FRAMES = [
    [  # шаг левой
        "...DDDD.....",
        "..DDDDDD....",
        "..DDSSDD....",
        "..DDSSDD....",
        "...DDDD.....",
        "..CCCCCC....",
        ".CCCCCCCC...",
        ".CCCCCCCCL..",
        ".CCCCCCCCL..",
        "..CCCCCCC...",
        "..CCCCCC....",
        "..CC..CC....",
        ".BBB..BBB...",
        ".BB....BB...",
    ],
    [  # ноги вместе, подскок
        "...DDDD.....",
        "..DDDDDD....",
        "..DDSSDD....",
        "..DDSSDD....",
        "...DDDD.....",
        "..CCCCCC....",
        ".CCCCCCCC...",
        ".CCCCCCCCL..",
        ".CCCCCCCCL..",
        "..CCCCCCC...",
        "..CCCCCC....",
        "...CCCC.....",
        "...BBBB.....",
        "..BB..BB....",
    ],
    [  # шаг правой
        "...DDDD.....",
        "..DDDDDD....",
        "..DDSSDD....",
        "..DDSSDD....",
        "...DDDD.....",
        "..CCCCCC....",
        ".CCCCCCCC...",
        "LCCCCCCCC...",
        "LCCCCCCCC...",
        "..CCCCCCC...",
        "..CCCCCC....",
        "..CC..CC....",
        ".BBB..BBB...",
        "..BB..BB....",
    ],
    [  # выпад вперёд
        "...DDDD.....",
        "..DDDDDD....",
        "..DDSSDD....",
        "..DDSSDD....",
        "...DDDD.....",
        "..CCCCCC....",
        ".CCCCCCCC...",
        ".CCCCCCCCL..",
        ".CCCCCCCCL..",
        "..CCCCCCC...",
        "..CCCCCC....",
        "..CC.CC.....",
        ".BBB.BBB....",
        ".BB...BB....",
    ],
]

# страж у костра: 8x13
GUARD_FRAME = [
    "..####..",
    ".#....#.",
    ".#.##.#.",
    ".#....#.",
    "..####..",
    ".######.",
    "########",
    "########",
    "########",
    ".######.",
    "..####..",
    "..#..#..",
    ".##..##.",
]

# палатка: 13x8
TENT_FRAME = [
    "......#......",
    ".....#.#.....",
    "....#...#....",
    "...#.....#...",
    "..#...#...#..",
    ".#....#....#.",
    "#.....#.....#",
    "#############",
]


def mix(a, b, k):
    k = 0.0 if k < 0 else (1.0 if k > 1 else k)
    return (int(a[0] + (b[0] - a[0]) * k), int(a[1] + (b[1] - a[1]) * k), int(a[2] + (b[2] - a[2]) * k))


def h01(n, salt=0.0):
    x = math.sin(n * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


class Canvas:
    def __init__(self, size):
        self.w, self.h = size
        self.img = Image.new("RGB", size, SKY[0])

    def put(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (color[0], color[1], color[2]))

    def get(self, x, y):
        return self.img.getpixel((x, y))

    def rect(self, x0, y0, x1, y1, color):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, color)

    def gradient(self, y0, y1, colors):
        steps = len(colors) - 1
        for y in range(y0, y1):
            k = (y - y0) / max(1, (y1 - y0 - 1)) * steps
            lo = min(steps - 1, int(k))
            frac = k - lo
            for x in range(self.w):
                thr = (BAYER[y % 4][x % 4] + 0.5) / 16.0
                self.put(x, y, colors[lo] if frac <= thr else colors[lo + 1])


def horizon(g):
    return int(g[1] * 0.545)


def ground_line(g):
    return int(g[1] * 0.605)


def camp_xy(g):
    return int(g[0] * 0.30), int(g[1] * 0.757)


def bar_rect(g):
    w = int(g[0] * 0.84)
    x = (g[0] - w) // 2
    h = max(7, int(g[1] * 0.033))
    y = int(g[1] * 0.884)
    return x, y, w, h


# --- небо и земля --------------------------------------------------------

def draw_sky(c, g):
    hz = horizon(g)
    c.gradient(0, hz, SKY)


def draw_moon(c, g):
    cx, cy = int(g[0] * 0.775), int(g[1] * 0.118)
    r = max(7, int(g[0] * 0.082))
    for y in range(cy - r - 2, cy + r + 3):
        for x in range(cx - r - 2, cx + r + 3):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                c.put(x, y, MOON)
            elif d <= r + 1 and h01(x * 13 + y * 7) > 0.55:
                c.put(x, y, mix(SKY[4], MOON, 0.28))
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = (x - cx) / r, (y - cy) / r
            if dx * dx + dy * dy > 1.0:
                continue
            if dx * 0.80 + dy * 0.45 > 0.74:
                c.put(x, y, MOON_SHADE)
    for ox, oy, rr in ((-0.30, -0.16, 0.22), (0.16, 0.30, 0.16)):
        pcx, pcy, pr = cx + ox * r, cy + oy * r, max(1.0, rr * r)
        for y in range(int(pcy - pr) - 1, int(pcy + pr) + 2):
            for x in range(int(pcx - pr) - 1, int(pcx + pr) + 2):
                if (x - pcx) ** 2 + (y - pcy) ** 2 <= pr * pr:
                    c.put(x, y, MOON_SHADE)


def stars(g, count=96):
    out = []
    for i in range(count):
        x = int(h01(i, 1.3) * g[0])
        y = int(h01(i, 2.7) * horizon(g) * 0.94)
        out.append((x, y, STAR[i % 3], h01(i, 4.1) * math.tau, 0.5 + h01(i, 5.9) * 2.2))
    return out


def draw_stars(c, star_list, t):
    for x, y, col, phase, speed in star_list:
        k = 0.30 + 0.70 * (0.5 + 0.5 * math.sin(t * speed + phase))
        c.put(x, y, mix(mix(SKY[2], SKY[3], 0.6), col, k))
        if k > 0.88:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c.put(x + dx, y + dy, mix(SKY[3], col, 0.28))


def draw_shooting_star(c, t):
    period = 11.0
    u = (t % period) / period
    if u > 0.14:
        return
    k = u / 0.14
    x0 = int(c.w * 0.15 + k * c.w * 0.6)
    y0 = int(c.h * 0.09 + k * c.h * 0.11)
    for i in range(8):
        alpha = (1.0 - k * 0.75) * (1.0 - i / 8.0)
        c.put(x0 - i, y0 - i // 2, mix(SKY[2], (255, 255, 255), alpha))


def draw_ridges(c, g):
    hz = horizon(g)
    gl = ground_line(g)
    for x in range(c.w):
        u = x / c.w
        peak = (0.55 + 0.5 * math.sin(u * 6.1 + 0.9)) * (0.55 + 0.45 * math.sin(u * 2.1 + 2.4))
        top = hz - int(peak * g[1] * 0.095)
        for y in range(max(0, top), hz + 1):
            c.put(x, y, RIDGE_FAR)
    for x in range(c.w):
        u = x / c.w
        top = hz + int((0.45 + 0.35 * math.sin(u * 3.7 + 1.2)) * (gl - hz) * 0.75)
        for y in range(top, gl + 1):
            c.put(x, y, RIDGE_NEAR)


def draw_treeline(c, g):
    gl = ground_line(g)
    i = -3
    while i < c.w + 3:
        h = 4 + int(h01(i, 6.2) * 8)
        cx = i + int(h01(i, 7.4) * 3)
        for level in range(h):
            y = gl - level
            half = 0 if level < h * 0.5 else int((level - h * 0.5) / (h * 0.5) * (1 + h * 0.16))
            for x in range(cx - half, cx + half + 1):
                c.put(x, y, TREE)
        c.put(cx, gl + 1, TREE)
        i += 2 + int(h01(i, 9.1) * 3)


def draw_ground(c, g):
    gl = ground_line(g)
    for y in range(gl, c.h):
        k = (y - gl) / max(1, c.h - gl)
        for x in range(c.w):
            c.put(x, y, mix(GROUND, (6, 8, 18), k * 0.75))
    for x in range(c.w):
        if h01(x, 10.4) > 0.45:
            c.put(x, gl, GRASS)
            if h01(x, 11.2) > 0.8:
                c.put(x, gl - 1, GRASS)
    for i in range(90):
        x = int(h01(i, 12.5) * c.w)
        y = gl + 3 + int(h01(i, 13.7) * (c.h - gl - 4))
        if h01(i, 14.9) > 0.72:
            c.put(x, y, GROUND_HI)


# --- лагерь --------------------------------------------------------------

def draw_camp_light(c, g, t):
    cx, cy = camp_xy(g)
    flicker = 0.95 + 0.05 * math.sin(t * 5.7) + 0.025 * math.sin(t * 12.3)
    for y in range(cy - 10, min(c.h, cy + 6)):
        for x in range(cx - 26, cx + 27):
            d = math.hypot((x - cx) * 0.85, (y - cy) * 2.0) / (26 * flicker)
            if d >= 1.0:
                continue
            k = (1.0 - d) ** 2.0
            band = 0.0 if k < 0.12 else (0.26 if k < 0.42 else (0.48 if k < 0.72 else 0.66))
            if band <= 0.0:
                continue
            c.put(x, y, mix(c.get(x, y), (146, 84, 40), band))


def draw_camp(c, g, t):
    cx, cy = camp_xy(g)

    # палатка слева от костра
    tx, ty = cx - 27, cy - len(TENT_FRAME) + 3
    for j, row in enumerate(TENT_FRAME):
        for i, ch in enumerate(row):
            if ch != "#":
                continue
            px, py = tx + i, ty + j
            if i >= len(row) - 5:
                col = mix(TENT, (150, 92, 46), 0.42)
            elif j >= len(TENT_FRAME) - 2:
                col = TENT_SHADE
            else:
                col = TENT
            c.put(px, py, col)
    for j in range(4, len(TENT_FRAME) - 1):
        c.put(tx + 6, ty + j, mix(TENT_SHADE, OUTLINE, 0.5))

    # камни вокруг костра
    for dx in (-9, -7, -5, 5, 7, 9):
        c.put(cx + dx, cy + 2, STONE)
        if abs(dx) <= 7:
            c.put(cx + dx, cy + 1, mix(STONE, GROUND, 0.35))

    # поленья
    for i in range(-5, 6):
        c.put(cx + i, cy, LOG if i % 3 else mix(LOG, (255, 150, 60), 0.15))
        c.put(cx - i, cy - 1, LOG)
    for i in (-6, 6):
        c.put(cx + i, cy - 1, LOG_DARK)
        c.put(cx + i, cy, LOG_DARK)

    # страж справа, подсвечен костром
    hx, hy = cx + 11, cy - len(GUARD_FRAME) + 3 + (1 if math.sin(t * 1.4) > 0.7 else 0)
    for j, row in enumerate(GUARD_FRAME):
        for i, ch in enumerate(row):
            if ch != "#":
                continue
            if i <= 2:
                col = mix(GUARD, GUARD_LIT, 0.5)
            elif i <= 4:
                col = GUARD
            else:
                col = mix(GUARD, OUTLINE, 0.5)
            c.put(hx + i, hy + j, col)
    for j in range(-2, len(GUARD_FRAME) + 2):
        c.put(hx + len(GUARD_FRAME[0]) + 1, hy + j, mix(OUTLINE, LOG, 0.7))
    c.put(hx + len(GUARD_FRAME[0]) + 1, hy - 3, mix(GUARD, (206, 216, 236), 0.7))


def draw_fire(c, g, t):
    cx, cy = camp_xy(g)
    tongues = [(-4, 8, 1.4), (0, 12, 1.1), (4, 7, 1.5), (-7, 5, 0.9), (7, 4, 0.85)]
    for dx, h0, wf in tongues:
        flick = 0.62 + 0.38 * math.sin(t * (5.5 + abs(dx) * 0.7) + dx * 1.9)
        h = max(1, int(h0 * flick))
        for y in range(h):
            k = y / max(1, h - 1)
            half = int((1.0 - k) * wf * 1.5)
            for x in range(-half, half + 1):
                if k > 0.88:
                    col = FIRE[3]
                elif k > 0.60:
                    col = FIRE[2]
                elif k > 0.30:
                    col = FIRE[1]
                else:
                    col = FIRE[0]
                c.put(cx + dx + x, cy - 1 - y, col)


def draw_sparks(c, g, t):
    cx, cy = camp_xy(g)
    for i in range(9):
        period = 1.5 + h01(i, 16.1) * 1.9
        u = ((t / period) + h01(i, 17.3)) % 1.0
        x = cx + int((h01(i, 18.7) - 0.5) * 8 * u)
        y = cy - 5 - int(u * 24)
        col = mix(EMBER, FIRE[0], u)
        c.put(x, y, mix(GROUND, col, 1.0 - u * 0.6))


def draw_fireflies(c, g, t):
    gl = ground_line(g)
    for i in range(10):
        bx = int(g[0] * (0.06 + h01(i, 19.3) * 0.88))
        by = gl + int(h01(i, 20.9) * (c.h - gl) * 0.42)
        x = bx + int(math.sin(t * (0.6 + h01(i, 21.7)) + i) * 6)
        y = by + int(math.cos(t * (0.45 + h01(i, 22.3)) + i * 1.7) * 3)
        k = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * 1.7 + i * 1.31))
        c.put(x, y, mix(GROUND, FLY, k))
        if k > 0.82:
            c.put(x, y - 1, mix(GROUND, FLY, k * 0.3))


# --- полоска загрузки ----------------------------------------------------

def draw_bar(c, g, progress, t):
    x, y, w, h = bar_rect(g)
    c.rect(x - 2, y - 2, x + w + 1, y + h + 1, BAR_EDGE_DARK)
    c.rect(x - 1, y - 1, x + w, y + h, BAR_EDGE)
    for yy in range(y, y + h):
        k = (yy - y) / max(1, h - 1)
        c.rect(x, yy, x + w - 1, yy, mix(BAR_TROUGH_HI, BAR_TROUGH, k))
    fill_w = int((w - 2) * max(0.0, min(1.0, progress)))
    for i in range(fill_w):
        base = mix(FILL_A, FILL_B, i / max(1, w - 3))
        for yy in range(y + 1, y + h - 1):
            v = (yy - (y + 1)) / max(1, h - 3)
            c.put(x + 1 + i, yy, mix(base, (255, 255, 255), 0.20 * (1.0 - v) ** 2))
    if fill_w > 8:
        phase = int((t * 34) % (fill_w + 16)) - 8
        for off in range(5):
            bx = x + 1 + phase - off
            if x + 1 <= bx < x + 1 + fill_w:
                for yy in range(y + 1, y + h - 1):
                    c.put(bx, yy, mix(FILL_HI, FILL_A, off / 5.0))
    if 0 < fill_w < w - 2:
        for yy in range(y + 1, y + h - 1):
            c.put(x + 1 + fill_w, yy, FILL_HI)


def draw_runner(c, g, progress, t):
    x, y, w, h = bar_rect(g)
    fill_w = int((w - 2) * max(0.0, min(1.0, progress)))
    moving = progress < 0.999
    frame = int(t * 9) % 4 if moving else 0
    sprite = RUNNER_FRAMES[frame]
    sw, sh = len(sprite[0]), len(sprite)
    bob = 1 if (moving and frame in (0, 2)) else 0
    px0 = x + 1 + fill_w - sw // 2
    py0 = y - sh + 2 + bob

    for i in range(3):
        k = h01(int(t * 9) + i, 23.1)
        c.put(px0 - 2 - i * 2 - int(k * 3), y - 1 - int(k * 2), mix(GROUND, DUST, 0.45 - i * 0.1))

    for j, row in enumerate(sprite):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                c.put(px0 + i + dx, py0 + j + dy, OUTLINE)
    for j, row in enumerate(sprite):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            if ch == "D":
                col = CLOAK_DARK
            elif ch == "S":
                col = SKIN
            elif ch == "C":
                col = CLOAK_LIT if i <= 4 else CLOAK
            elif ch == "L":
                col = SKIN_SHADE
            else:
                col = BOOT_HI
            c.put(px0 + i, py0 + j, col)


def vignette(c):
    for y in range(c.h):
        for x in range(c.w):
            dx = abs(x - c.w / 2) / (c.w / 2)
            dy = abs(y - c.h / 2) / (c.h / 2)
            d = min(1.0, (dx * dx * 0.55 + dy * dy * 0.45) ** 1.4)
            if d < 0.6:
                continue
            c.put(x, y, mix(c.get(x, y), (2, 3, 7), (d - 0.6) / 0.4 * 0.5))


def render(t=1.0, progress=0.4):
    g = GRID
    c = Canvas(g)
    draw_sky(c, g)
    draw_moon(c, g)
    draw_stars(c, stars(g), t)
    draw_shooting_star(c, t)
    draw_ridges(c, g)
    draw_treeline(c, g)
    draw_ground(c, g)
    draw_camp_light(c, g, t)
    draw_camp(c, g, t)
    draw_fireflies(c, g, t)
    draw_fire(c, g, t)
    draw_sparks(c, g, t)
    draw_bar(c, g, progress, t)
    draw_runner(c, g, progress, t)
    vignette(c)
    return c.img


def main():
    out = Path("tools/preview")
    out.mkdir(parents=True, exist_ok=True)
    frames = [(0.5, 0.06, "01-start"), (1.6, 0.38, "02-mid"), (2.7, 0.72, "03-late"), (3.4, 1.0, "04-done")]
    for t, p, name in frames:
        img = render(t, p)
        img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(out / f"{name}.png")
    img = render(1.6, 0.38)
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(out / "05-zoom.png")
    print("saved to", out)


if __name__ == "__main__":
    sys.exit(main())
