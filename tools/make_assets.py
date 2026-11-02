#!/usr/bin/env python3
"""Генерирует логотипы и иконку из тех же пиксельных спрайтов, что и игра.

Выход:
  client/art/logo.png         — широкий сплэш-логотип (для загрузочного экрана)
  client/art/logo-square.png  — квадратный логотип (эмблема + надпись)
  client/art/icon.png         — иконка приложения 512×512

Запуск: python3 tools/make_assets.py
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import pixelfont  # noqa: E402
import preview_boot as pb  # noqa: E402

ART = Path("client/art")
SCALE = 8


class Pic:
    def __init__(self, w, h, base=None):
        self.w, self.h = w, h
        self.img = Image.new("RGB", (w, h), base or pb.SKY[1])

    def put(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (col[0], col[1], col[2]))

    def sky(self):
        for y in range(self.h):
            k = y / max(1, self.h - 1)
            base = pb.mix(pb.SKY[2], pb.SKY[0], k * 0.9)
            for x in range(self.w):
                self.put(x, y, base)

    def stars(self, count=90, seed=7):
        rnd = random.Random(seed)
        for _ in range(count):
            x, y = rnd.randrange(self.w), rnd.randrange(self.h)
            self.put(x, y, pb.mix(pb.SKY[3], pb.STAR[rnd.randrange(3)], 0.35 + rnd.random() * 0.5))

    def ground(self, top):
        for y in range(top, self.h):
            k = (y - top) / max(1, self.h - top)
            for x in range(self.w):
                self.put(x, y, pb.mix(pb.GROUND, (6, 8, 18), k))

    def campfire(self, cx, cy, big=1.0):
        for i in range(-int(7 * big), int(7 * big) + 1):
            self.put(cx + i, cy, pb.LOG if i % 3 else pb.mix(pb.LOG, (255, 150, 60), 0.2))
            self.put(cx - i, cy - 1, pb.LOG)
        tongues = ((-4, 8, 1.4), (0, 12, 1.1), (4, 7, 1.5))
        for dx, hh, wf in tongues:
            hh = int(hh * big)
            for y in range(hh):
                k = y / max(1, hh - 1)
                half = max(0, int((1.0 - k) * wf * 1.4 * big))
                for x in range(-half, half + 1):
                    if k > 0.88:
                        col = pb.FIRE[3]
                    elif k > 0.6:
                        col = pb.FIRE[2]
                    elif k > 0.3:
                        col = pb.FIRE[1]
                    else:
                        col = pb.FIRE[0]
                    self.put(cx + dx + x, cy - 1 - y, col)

    def hero(self, hx, hy, frame=1, scale=1):
        sprite = pb.RUNNER_FRAMES[frame]
        for j, row in enumerate(sprite):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                if ch == "D":
                    col = pb.CLOAK_DARK
                elif ch == "S":
                    col = pb.SKIN
                elif ch == "C":
                    col = pb.CLOAK_LIT if i <= 4 else pb.CLOAK
                elif ch == "L":
                    col = pb.SKIN_SHADE
                else:
                    col = pb.BOOT_HI
                for sy in range(scale):
                    for sx in range(scale):
                        self.put(hx + i * scale + sx, hy + j * scale + sy, col)

    def text(self, s, x, y, col, scale=1, tracking=1, shadow=True):
        if shadow:
            pixelfont.draw_text(self.put, s, x + 1, y + 1, (9, 12, 24), scale, tracking)
        pixelfont.draw_text(self.put, s, x, y, col, scale, tracking)

    def save(self, path, factor=SCALE):
        ART.mkdir(parents=True, exist_ok=True)
        out = self.img.resize((self.w * factor, self.h * factor), Image.NEAREST)
        out.save(path)
        return out


def make_logo() -> Image.Image:
    title = "IDLE PIXEL"
    scale, tracking = 4, 1
    text_w = pixelfont.text_width(title, scale, tracking)
    w = max(200, text_w + 52)
    h = 76
    p = Pic(w, h)
    p.sky()
    p.stars(140, seed=11)

    p.ground(h - 22)
    p.campfire(16, h - 23, big=1.3)
    p.hero(31, h - 38, frame=1)

    tx = 46
    ty = 8
    p.text(title, tx, ty, (247, 233, 198), scale, tracking)

    sub = "MMORPG"
    sw = pixelfont.text_width(sub, 2, 2)
    p.text(sub, tx + (text_w - sw) // 2, ty + 7 * scale + 8, (110, 231, 168), 2, 2)
    return p.save(ART / "logo.png")


def make_logo_square() -> Image.Image:
    w = h = 96
    p = Pic(w, h)
    p.sky()
    p.stars(70, seed=5)
    p.ground(h - 26)

    # луна
    for y in range(6, 22):
        for x in range(w - 26, w - 10):
            if ((x - (w - 18)) ** 2 + (y - 14) ** 2) <= 36:
                p.put(x, y, pb.MOON)

    p.campfire(22, h - 27, big=1.25)
    p.hero(36, h - 40, frame=1)

    p.text("IDLE", 6, 8, (247, 233, 198), 2, 1)
    p.text("PIXEL", 6, 26, (247, 233, 198), 2, 1)
    p.text("MMORPG", 6, 46, (110, 231, 168), 1, 1)
    return p.save(ART / "logo-square.png")


def make_icon() -> Image.Image:
    size = 64
    p = Pic(size, size)
    p.sky()
    p.stars(40, seed=3)
    p.ground(44)

    for y in range(6, 26):
        for x in range(38, 58):
            if ((x - 48) ** 2 + (y - 16) ** 2) <= 64:
                p.put(x, y, pb.MOON)

    p.campfire(22, 46, big=1.6)
    p.hero(36, 28, frame=1)
    return p.save(ART / "icon.png", factor=8)


def main():
    make_logo()
    make_logo_square()
    make_icon()
    print("assets →", ART)


if __name__ == "__main__":
    sys.exit(main())
