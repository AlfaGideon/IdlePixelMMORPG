#!/usr/bin/env python3
"""Прототип нового арта загрузочной сцены: древо, изба, светлячки, детали земли.

Быстрая итерация без движка: рисуем поверх готового кадра сцены (base.png),
подбираем форму/цвета, затем переносим те же формулы в client/ui/pixel_scene.gd.

Запуск: python3 tools/preview/proto_scene.py [t]
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
W, H = 120, 214
GROUND = 96

TREE = (7, 9, 20)
CANOPY_DARK = (14, 44, 46)
CANOPY = (24, 74, 66)
CANOPY_MID = (38, 104, 78)
CANOPY_LIT = (74, 150, 96)
CANOPY_HI = (126, 200, 128)
BARK_DARK = (18, 20, 34)
BARK = (38, 34, 46)
BARK_LIT = (66, 56, 62)
MOSS = (46, 96, 70)
CABIN_WALL = (58, 44, 44)
CABIN_WALL_LIT = (92, 68, 56)
CABIN_ROOF = (34, 30, 44)
CABIN_ROOF_LIT = (58, 52, 70)
WINDOW = (255, 196, 96)
WINDOW_GLOW = (196, 128, 52)
STONE = (46, 50, 66)
STONE_LIT = (78, 86, 110)
PATH = (26, 30, 48)
PATH_LIT = (36, 42, 62)
FIREFLY = (206, 255, 96)


class Canvas:
    def __init__(self, base: Image.Image) -> None:
        self.img = base.convert("RGB").copy()

    def px(self, x: int, y: int, col) -> None:
        if 0 <= x < W and 0 <= y < H:
            self.img.putpixel((x, y), col)

    def mix(self, x: int, y: int, col, k: float) -> None:
        if not (0 <= x < W and 0 <= y < H):
            return
        a = self.img.getpixel((x, y))
        self.img.putpixel((x, y), tuple(int(a[i] + (col[i] - a[i]) * k) for i in range(3)))


def h01(n: float, salt: float) -> float:
    x = math.sin(n * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


def sway(t: float, y: int, top: int, base: int) -> int:
    """Чем выше — тем сильнее качает; у корней движения нет."""
    k = max(0.0, (base - y) / max(1, base - top))
    return int(round(math.sin(t * 0.55 + y * 0.055) * 2.4 * (k ** 1.3)))


TREE_X = 72
TREE_BASE = 124
TREE_TOP = 28


def clumps() -> list[tuple[int, int, int, int]]:
    """Кластеры листвы: (dx, dy, радиус, слой). Форма — широкая крона."""
    out: list[tuple[int, int, int, int]] = []
    rng = [(0.0, -26, 8), (-14, -22, 9), (14, -22, 9), (-24, -10, 9), (24, -12, 9),
           (-30, 2, 8), (30, 0, 8), (-18, -2, 10), (0, -6, 11), (18, -4, 10),
           (-10, 12, 10), (10, 12, 10), (0, 22, 9), (-26, 14, 8), (26, 14, 8),
           (-34, -20, 6), (34, -22, 6), (-38, -4, 5), (38, -6, 5)]
    for i, (dx, dy, r) in enumerate(rng):
        layer = 0 if dy < -8 else (1 if dy < 10 else 2)
        out.append((TREE_X + dx, 54 + dy, r, layer))
    # мелкие кластеры по краю — рваный силуэт
    for i in range(26):
        a = h01(i, 1.7) * math.tau
        rr = 0.72 + h01(i, 2.9) * 0.38
        dx = int(math.cos(a) * 31 * rr)
        dy = int(math.sin(a) * 23 * rr) - 2
        out.append((TREE_X + dx, 54 + dy, 3 + int(h01(i, 3.1) * 3), 2))
    return out


def draw_tree(c: Canvas, t: float) -> None:
    base_y = TREE_BASE
    top_y = TREE_TOP

    # --- ствол: сужается вверх ---
    for y in range(78, base_y + 1):
        k = (y - 78) / (base_y - 78)
        half = int(2.2 + k * 4.6)
        sx = TREE_X + sway(t, y, top_y, base_y) // 4
        for x in range(sx - half, sx + half + 1):
            col = BARK
            if x <= sx - half:
                col = BARK_DARK
            elif x >= sx + half:
                col = BARK_LIT
            c.px(x, y, col)
        if y % 9 == 0:
            c.px(sx - 1, y, BARK_DARK)
        if y % 13 == 5:
            c.px(sx + 1, y, BARK_DARK)
            c.px(sx + 2, y, BARK_LIT)

    # корни: расходятся по земле
    for side, length, drop in ((-1, 11, 2), (1, 12, 3), (-1, 7, 0), (1, 7, 1)):
        for i in range(length):
            x = TREE_X + side * (i + 2)
            y = base_y - (i * drop) // 3
            c.px(x, y, BARK if i else BARK_DARK)
            c.px(x, y + 1, BARK_DARK)
    # мох у корней
    for i in range(14):
        x = TREE_X - 8 + int(h01(i, 6.1) * 16)
        c.px(x, base_y - 1 + int(h01(i, 7.3) * 3), MOSS)

    # --- ветви, видные сквозь листву ---
    for bx, by, dx, dy in ((TREE_X, 76, -16, -8), (TREE_X, 82, 16, -6), (TREE_X, 70, -6, -10)):
        steps = max(abs(dx), abs(dy))
        for s in range(steps):
            x = bx + dx * s // steps
            y = by + dy * s // steps
            c.px(x, y, BARK_DARK)
            c.px(x + 1, y, BARK)

    # --- крона: слои кластеров ---
    palette = {
        0: ((16, 40, 44), (26, 62, 58)),
        1: ((26, 68, 62), (40, 98, 76)),
        2: ((40, 104, 78), (78, 156, 100)),
    }
    blobs = sorted(clumps(), key=lambda b: b[3])
    for (bx, by, r, layer) in blobs:
        bx, by, r = int(bx), int(by), int(r)
        dark, light = palette[layer]
        for y in range(by - r - 1, by + r + 2):
            if y < top_y:
                continue
            dxs = sway(t, y, top_y, base_y)
            for x in range(bx - r - 1, bx + r + 2):
                nx = (x - bx) / r
                ny = (y - by) / r
                d = nx * nx + ny * ny
                if d > 1.0:
                    if d <= 1.45 and h01(x * 31 + y * 17, 4.7) > 0.62:
                        c.mix(x + dxs, y, dark, 0.6)
                    continue
                if h01(x * 13 + y * 29, 8.3) > 0.955:
                    continue  # просветы в листве
                col = light if (ny < -0.15 or (nx < -0.25 and ny < 0.25)) else dark
                if ny > 0.45:
                    col = dark
                c.px(x + dxs, y, col)

    # блик луны по верхней кромке
    for i in range(18):
        x = TREE_X - 30 + int(h01(i, 11.3) * 60)
        y = top_y + 4 + int(h01(i, 12.7) * 22)
        c.mix(x, y, CANOPY_HI, 0.35)

    # --- лианы ---
    for i, vx in enumerate((TREE_X - 30, TREE_X - 16, TREE_X + 16, TREE_X + 30)):
        length = 8 + int(h01(i, 3.3) * 12)
        for j in range(length):
            y = 76 + j
            x = vx + sway(t, y, top_y, base_y) // 2 + int(math.sin(j * 0.45 + i) * 1.3)
            c.px(x, y, CANOPY_DARK if j % 3 else CANOPY)


def draw_clouds(c: Canvas, t: float) -> None:
    for i, (x0, y0, w) in enumerate(((2, 34, 18), (10, 62, 22), (34, 22, 14), (0, 76, 16))):
        drift = int(round(((t * (1.1 + i * 0.3) + i * 37) % 160) - 20))
        x = (x0 + drift) % 150 - 15
        for j in range(w):
            yy = y0 + int(math.sin(j * 0.5 + i) * 1.6)
            c.mix(x + j, yy, (58, 66, 96), 0.20)
            c.mix(x + j, yy + 1, (44, 50, 74), 0.16)
        for j in range(2, w - 2):
            c.mix(x + j, y0 + 2, (48, 56, 82), 0.12)


def draw_birds(c: Canvas, t: float) -> None:
    for i in range(3):
        x = 16 + int(t * 2.2 + i * 7) % 70
        y = 24 + i * 4 + int(math.sin(t * 1.4 + i) * 2)
        c.mix(x, y, (120, 140, 180), 0.55)
        c.mix(x + 1, y - 1, (120, 140, 180), 0.45)
        c.mix(x + 2, y, (120, 140, 180), 0.55)


def draw_cabin(c: Canvas) -> None:
    x0, y0 = 6, 138
    w, h = 26, 22
    # стены из брёвен
    for j in range(h):
        y = y0 + j
        for i in range(w):
            x = x0 + i
            col = CABIN_WALL
            if j % 3 == 2:
                col = (40, 30, 32)
            if i >= w - 4:
                col = CABIN_WALL_LIT
            c.px(x, y, col)
    # крыша двускатная
    for j in range(9):
        y = y0 - 9 + j
        half = int(w * 0.5 + 3 - j * 1.6)
        for x in range(x0 + w // 2 - half, x0 + w // 2 + half + 1):
            col = CABIN_ROOF
            if j % 3 == 1:
                col = CABIN_ROOF_LIT
            c.px(x, y, col)
    # труба и дым
    for j in range(6):
        c.px(x0 + 19, y0 - 14 + j, (28, 26, 38))
    for j in range(6):
        c.mix(x0 + 20 + (j // 3), y0 - 22 - j, (120, 130, 150), 0.30 - j * 0.03)
    # окно с тёплым светом
    for j in range(5):
        for i in range(5):
            c.px(x0 + 5 + i, y0 + 6 + j, WINDOW if (i + j) % 5 else WINDOW_GLOW)
    for j in range(5):
        c.px(x0 + 7, y0 + 6 + j, (70, 44, 30))
        c.px(x0 + 5 + j if j < 5 else x0, y0 + 8, (70, 44, 30)) if j == 2 else None
    # дверь
    for j in range(9):
        for i in range(4):
            c.px(x0 + 17 + i, y0 + h - 9 + j, (34, 26, 30))


def draw_ground_details(c: Canvas, t: float) -> None:
    # тропинка от избы к костру
    for i in range(52):
        x = 30 + int(i * 0.55)
        y = 160 + int(math.sin(i * 0.18) * 4) + i // 6
        c.mix(x, y, PATH_LIT, 0.55)
        c.mix(x + 1, y, PATH, 0.4)
        if i % 7 == 0:
            c.mix(x, y + 1, PATH, 0.5)
    # камни и грибы
    for i, (x, y) in enumerate(((22, 172), (58, 178), (74, 168), (96, 176), (40, 186))):
        c.px(x, y, STONE)
        c.px(x + 1, y, STONE)
        c.px(x, y - 1, STONE_LIT)
        if i % 2:
            c.px(x + 2, y, STONE)
    for (x, y) in ((16, 165), (88, 160), (104, 170)):
        c.px(x, y, (150, 60, 60))
        c.px(x, y - 1, (196, 96, 82))
    # кусты
    for (bx, by, r) in ((88, 168, 5), (100, 162, 4), (66, 176, 4), (108, 178, 5)):
        for y in range(by - r, by + r + 1):
            for x in range(bx - r, bx + r + 1):
                if (x - bx) ** 2 + (y - by) ** 2 <= r * r and h01(x * 7 + y * 3, 5.5) > 0.15:
                    c.mix(x, y, (18, 46, 40), 0.9 if (x + y) % 3 else 0.6)
        c.px(bx, by - r, (30, 66, 52))

    # трава
    for x in range(4, 118, 3):
        if h01(x, 8.4) > 0.55:
            y = 150 + int(h01(x, 9.1) * 40)
            c.px(x, y, (28, 52, 44))
            c.px(x, y - 1, (36, 66, 52))


def draw_motes(c: Canvas, t: float) -> None:
    """Светлячки вокруг кроны."""
    for i in range(16):
        period = 7.0 + h01(i, 2.2) * 6.0
        a = t / period * 2 * math.pi + h01(i, 5.5) * 6.28
        cx = TREE_X + int(math.cos(a) * (14 + h01(i, 7.7) * 26))
        cy = 58 + int(math.sin(a * 1.3) * (12 + h01(i, 9.9) * 18))
        blink = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 2.4 + i))
        c.mix(cx, cy, FIREFLY, blink)
        if blink > 0.85:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c.mix(cx + dx, cy + dy, FIREFLY, 0.25)


def main() -> None:
    t = float(sys.argv[1]) if len(sys.argv) > 1 else 0.0
    base = Image.open(ROOT / "tools/preview/base.png")
    c = Canvas(base)
    # вернуть сцену без старой палатки/стража невозможно — рисуем поверх
    draw_clouds(c, t)
    draw_birds(c, t)
    draw_tree(c, t)
    draw_cabin(c)
    draw_ground_details(c, t)
    draw_motes(c, t)
    out = c.img.resize((W * 5, H * 5), Image.NEAREST)
    out.save(ROOT / "tools/preview/proto_scene.png")
    print("ok")


if __name__ == "__main__":
    main()
