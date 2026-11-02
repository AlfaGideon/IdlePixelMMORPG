#!/usr/bin/env python3
"""Рисует спрайт-лист героя (цикл бега) — настоящий PNG-ассет, не символьная сетка.

Выход:
  client/art/runner.png            — лист из 6 кадров, 20×24 на кадр, RGBA
  tools/preview/runner_sheet.png   — увеличенное превью с подписями

Герой — разведчик в капюшоне с плащом и мечом за спиной. Цикл бега:
передняя нога выносится, задняя отталкивается, корпус проседает в проходной
позе, плащ и шарф отстают, руки машут в противофазе.

Запуск: python3 tools/make_runner.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ART = Path("client/art")
PREVIEW = Path("tools/preview")

FRAME_W, FRAME_H = 20, 24
FRAMES = 6

OUTLINE = (5, 7, 14, 255)
CAPE = (26, 74, 60, 255)
CAPE_DARK = (16, 50, 42, 255)
CAPE_HI = (58, 122, 96, 255)
JACKET = (48, 152, 112, 255)
JACKET_DARK = (26, 96, 74, 255)
JACKET_LIT = (132, 226, 176, 255)
HOOD = (54, 168, 126, 255)
HOOD_DARK = (28, 104, 80, 255)
HOOD_LIT = (150, 232, 190, 255)
SKIN = (236, 194, 152, 255)
SKIN_SHADE = (186, 136, 100, 255)
SCARF = (208, 92, 64, 255)
SCARF_DARK = (148, 56, 40, 255)
BELT = (74, 52, 36, 255)
BUCKLE = (216, 184, 98, 255)
PANTS = (52, 56, 78, 255)
PANTS_DARK = (34, 38, 56, 255)
BOOT = (92, 102, 132, 255)
BOOT_HI = (132, 146, 182, 255)
STEEL = (170, 184, 212, 255)
STEEL_DARK = (112, 126, 158, 255)
EYE = (16, 18, 28, 255)

# Позы на 6 кадров: (передняя стопа, задняя стопа, колено передней, колено задней,
#                    просадка корпуса, рука, хвост плаща)
POSES = [
    (3, -3, 1, -1, 0, -2, -3),
    (1, -1, 0, 0, 1, -1, -1),
    (-2, 3, 0, 1, 0, 1, 1),
    (-3, 3, -1, 1, 0, 2, 3),
    (-1, 1, 0, 0, 1, 1, 1),
    (3, -2, 1, -1, 0, -1, -2),
]


class Frame:
    def __init__(self) -> None:
        self.img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))

    def px(self, x: int, y: int, col) -> None:
        if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
            self.img.putpixel((x, y), col)

    def rect(self, x0: int, y0: int, x1: int, y1: int, col) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, col)

    def outline(self) -> None:
        src = self.img.copy()
        for y in range(FRAME_H):
            for x in range(FRAME_W):
                if src.getpixel((x, y))[3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < FRAME_W and 0 <= ny < FRAME_H:
                        if src.getpixel((nx, ny))[3] != 0:
                            self.px(x, y, OUTLINE)
                            break

    def segment(self, x0: int, y0: int, x1: int, y1: int, col) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            t = s / steps
            x = int(round(x0 + (x1 - x0) * t))
            y = int(round(y0 + (y1 - y0) * t))
            self.px(x, y, col)
            self.px(x + 1, y, col)


def draw_frame(idx: int) -> Frame:
    f = Frame()
    front_foot, back_foot, front_knee, back_knee, sink, arm, cape = POSES[idx]
    hip_y = 16 + sink

    # ---------- плащ за спиной (тёмный, чтобы не сливался с курткой) ----------
    for y in range(10 + sink, 21):
        t = (y - 10 - sink) / 10.0
        left = 5 - int(round(t * 2)) + int(round(cape * t))
        right = 7 - int(round(t * 1.2))
        col = CAPE if t < 0.7 else CAPE_DARK
        for x in range(left, right + 1):
            f.px(x, y, col)
    # верхняя кромка плаща ловит лунный свет
    for x in range(5, 8):
        f.px(x, 10 + sink, CAPE_HI)

    # ---------- меч за спиной ----------
    for k in range(8):
        f.px(8 + k // 2, 6 + k, STEEL if k % 2 == 0 else STEEL_DARK)
    f.px(7, 6, BELT)
    f.px(8, 6, BELT)

    # ---------- задняя нога ----------
    f.segment(12, hip_y, 12 + back_knee, 19 + sink, PANTS_DARK)
    f.segment(12 + back_knee, 19 + sink, 11 + back_foot, 22, PANTS_DARK)
    bx = 10 + back_foot
    f.rect(bx, 22, bx + 2, 22, PANTS_DARK)
    f.px(bx + 2, 23, PANTS_DARK)

    # ---------- корпус: куртка ----------
    for y in range(9 + sink, 16 + sink):
        for x in range(8, 14):
            col = JACKET
            if x <= 9:
                col = JACKET_DARK
            elif x >= 13:
                col = JACKET_LIT
            f.px(x, y, col)
    # перевязь через грудь
    for k in range(4):
        f.px(9 + k, 10 + sink + k, BELT)
    # сумка на боку
    f.rect(7, 12 + sink, 8, 14 + sink, BELT)
    f.px(8, 12 + sink, BUCKLE)
    # пояс
    for x in range(8, 14):
        f.px(x, 15 + sink, BELT)
    f.px(11, 15 + sink, BUCKLE)

    # ---------- передняя нога ----------
    f.segment(10, hip_y, 10 + front_knee, 19 + sink, PANTS)
    f.segment(10 + front_knee, 19 + sink, 8 + front_foot, 22, PANTS)
    fx = 7 + front_foot
    f.rect(fx, 22, fx + 3, 22, BOOT)
    f.px(fx + 3, 22, BOOT_HI)
    f.px(fx + 3, 23, BOOT)
    f.px(fx + 2, 23, BOOT_HI)

    # ---------- рука ----------
    sh_x, sh_y = 13, 10 + sink
    hand_x, hand_y = 13 + arm, 14 + sink
    f.segment(sh_x, sh_y, hand_x, hand_y, JACKET_DARK)
    f.px(hand_x, hand_y + 1, SKIN)
    f.px(hand_x + 1, hand_y + 1, SKIN)

    # ---------- шарф ----------
    for x in range(8, 15):
        f.px(x, 8 + sink, SCARF)
    tail = 3 + abs(cape) // 2
    for k in range(tail):
        f.px(7 - k, 8 + sink + (1 if k >= 2 else 0), SCARF if k % 2 == 0 else SCARF_DARK)

    # ---------- голова: капюшон + лицо ----------
    top = sink
    lean = 1 if arm < 0 else 0
    hx = 8 + lean
    f.rect(hx, 1 + top, hx + 7, 7 + top, HOOD)          # купол капюшона
    f.rect(hx, 1 + top, hx + 2, 7 + top, HOOD_DARK)     # затылок в тени
    f.rect(hx + 6, 1 + top, hx + 7, 7 + top, HOOD_LIT)  # освещённый край
    f.rect(hx + 2, 2 + top, hx + 7, 2 + top, HOOD_DARK) # козырёк над лицом
    f.rect(hx + 3, 3 + top, hx + 7, 7 + top, SKIN)      # лицо
    f.px(hx + 4, 4 + top, EYE)                          # глаза
    f.px(hx + 6, 4 + top, EYE)
    f.px(hx + 7, 5 + top, SKIN_SHADE)                   # скула
    for x in range(hx + 3, hx + 7):                      # подбородок в тени
        f.px(x, 7 + top, SKIN_SHADE)

    f.outline()
    return f


def main() -> None:
    frames = [draw_frame(i) for i in range(FRAMES)]
    sheet = Image.new("RGBA", (FRAME_W * FRAMES, FRAME_H), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.img, (i * FRAME_W, 0))

    ART.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    sheet.save(ART / "runner.png")

    scale = 8
    pad = 12
    big = Image.new("RGBA", (sheet.width * scale + pad, sheet.height * scale + 30), (26, 30, 46, 255))
    d = ImageDraw.Draw(big)
    for y in range(0, sheet.height * scale, 8):
        for x in range(0, sheet.width * scale, 8):
            if (x // 8 + y // 8) % 2 == 0:
                d.rectangle([x + pad // 2, y, x + pad // 2 + 7, y + 7], fill=(34, 40, 60, 255))
    big.alpha_composite(sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST), (pad // 2, 0))
    d = ImageDraw.Draw(big)
    for i in range(FRAMES):
        cx = pad // 2 + i * FRAME_W * scale + FRAME_W * scale // 2
        d.text((cx - 4, sheet.height * scale + 8), str(i + 1), fill=(206, 222, 255, 255))
    big.save(PREVIEW / "runner_sheet.png")
    print(f"кадров: {FRAMES}, лист {sheet.width}×{sheet.height} -> {ART / 'runner.png'}")


if __name__ == "__main__":
    main()
