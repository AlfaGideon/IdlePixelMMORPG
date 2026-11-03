#!/usr/bin/env python3
"""Спрайты классов для полоски загрузки: 7 бойцов, один цикл бега.

Каждый класс рисуется кодом по общим правилам (поза, шаг, обводка), но со
своими приметами: шлем, шляпа, посох, две шпаги, лук, кадило. Так силуэт
остаётся чистым в 22×26 и не «шумит», как уменьшенный портрет.

Выход:
  client/art/classes/runner_<класс>.png   — лист 6 кадров, RGBA
  tools/preview/classes/runners_sheet.png — превью крупно

Запуск: python3 tools/make_class_runner.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ART = Path("client/art/classes")
PREVIEW = Path("tools/preview/classes")

FRAME_W, FRAME_H = 24, 28
FRAMES = 6
OUTLINE = (7, 9, 15, 255)

CLASSES = ["warrior", "mage", "duelist", "rogue", "cleric", "paladin", "ranger"]

# (тень, основа, свет, металл/акцент, кожа)
PALETTES = {
    "warrior": ((28, 54, 44), (52, 150, 108), (128, 214, 168), (196, 204, 224), (232, 190, 148)),
    "mage": ((40, 26, 62), (94, 62, 148), (156, 126, 214), (110, 226, 176), (226, 186, 150)),
    "duelist": ((20, 52, 38), (54, 156, 104), (140, 226, 176), (226, 210, 160), (232, 190, 148)),
    "rogue": ((18, 34, 26), (48, 92, 66), (104, 146, 108), (170, 176, 190), (226, 184, 146)),
    "cleric": ((38, 42, 34), (86, 100, 72), (188, 190, 160), (232, 204, 116), (228, 188, 150)),
    "paladin": ((34, 46, 62), (140, 154, 182), (216, 226, 242), (214, 178, 92), (232, 190, 148)),
    "ranger": ((20, 40, 26), (56, 108, 58), (128, 184, 100), (196, 168, 112), (226, 184, 146)),
}


class Canvas:
    def __init__(self) -> None:
        self.img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))

    def px(self, x: int, y: int, col) -> None:
        if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
            self.img.putpixel((x, y), col)

    def rect(self, x0: int, y0: int, x1: int, y1: int, col) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, col)

    def seg(self, x0: int, y0: int, x1: int, y1: int, col, thick: int = 2) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            t = s / steps
            x = round(x0 + (x1 - x0) * t)
            y = round(y0 + (y1 - y0) * t)
            for k in range(thick):
                self.px(x + k, y, col)

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


def draw_body(c: Canvas, name: str, idx: int) -> None:
    dark, base, light, metal, skin = PALETTES[name]
    phase = idx / FRAMES * 2.0 * math.pi
    stride = math.sin(phase)
    bob = 1 if abs(stride) < 0.45 else 0
    hip = 15 + bob

    # --- ноги ---
    front_x = 10 + round(stride * 2)
    back_x = 8 - round(stride * 2)
    for lx, col in ((back_x, dark), (front_x, base)):
        c.rect(lx, hip, lx + 1, 22, col)
        c.rect(lx - 1, 23, lx + 2, 23, (96, 104, 132, 255))
        c.rect(lx - 1, 24, lx + 2, 24, (58, 62, 86, 255))

    # --- плащ за спиной ---
    cape_x = 6 - round(stride * 1.2)
    for y in range(9 + bob, 21):
        t = (y - 9 - bob) / 11.0
        left = cape_x - round(t * 2)
        for x in range(left, 9):
            c.px(x, y, dark)

    # --- корпус ---
    for y in range(10 + bob, hip):
        for x in range(8, 14):
            col = base
            if x <= 8:
                col = dark
            elif x >= 13:
                col = light
            c.px(x, y, col)
    for x in range(8, 14):
        c.px(x, hip - 1, dark)          # пояс

    # --- рука ---
    arm_x = 13 + round(stride * 1.5)
    c.rect(arm_x, 10 + bob, arm_x + 1, 13 + bob, dark)
    c.px(arm_x, 14 + bob, skin)

    draw_weapon(c, name, idx, arm_x, 12 + bob, metal, dark, base)
    draw_head(c, name, bob, dark, base, light, metal, skin)


def draw_head(c: Canvas, name: str, bob: int, dark, base, light, metal, skin) -> None:
    y0 = bob
    # плечи шире головы — так силуэт читается бойцом, а не столбиком
    c.rect(7, 8 + y0, 15, 9 + y0, base)
    c.rect(7, 8 + y0, 8, 9 + y0, dark)
    c.rect(14, 8 + y0, 15, 9 + y0, light)

    if name == "warrior":
        c.rect(8, 1 + y0, 14, 7 + y0, metal)          # глухой шлем
        c.rect(8, 1 + y0, 9, 7 + y0, (140, 150, 176, 255))
        c.rect(9, 4 + y0, 13, 4 + y0, OUTLINE)         # прорезь
        c.rect(10, 0 + y0, 12, 0 + y0, (214, 178, 92, 255))  # гребень
    elif name == "mage":
        c.rect(8, 2 + y0, 14, 7 + y0, dark)            # тень под полями
        c.rect(9, 3 + y0, 13, 6 + y0, (18, 14, 30, 255))
        c.rect(6, 2 + y0, 16, 2 + y0, base)            # поля шляпы
        c.rect(7, 3 + y0, 15, 3 + y0, dark)
        for k in range(4):                              # конус
            c.rect(10 - k // 2, y0 - k, 12 + k // 2, y0 - k, base if k % 2 else light)
        c.px(11, 0 + y0, (110, 226, 176, 255))
    elif name == "duelist":
        c.rect(9, 3 + y0, 13, 7 + y0, (16, 28, 22, 255))  # лицо в тени
        c.rect(6, 2 + y0, 16, 2 + y0, base)               # широкие поля
        c.rect(8, 0 + y0, 14, 1 + y0, base)
        c.rect(9, -1 + y0, 13, -1 + y0, light)
        c.seg(15, 1 + y0, 18, -2 + y0, (234, 224, 196, 255), 1)  # плюмаж
        c.seg(16, 2 + y0, 19, 0 + y0, (206, 196, 170, 255), 1)
    elif name == "rogue":
        c.rect(9, 3 + y0, 13, 6 + y0, (14, 22, 18, 255))  # тень лица
        c.rect(8, 2 + y0, 14, 2 + y0, dark)
        c.rect(9, 3 + y0, 13, 5 + y0, base)
        c.rect(10, 6 + y0, 13, 7 + y0, dark)               # маска
        c.px(12, 4 + y0, (226, 184, 146, 255))
        c.px(11, 4 + y0, (226, 184, 146, 255))
    elif name == "cleric":
        c.rect(9, 3 + y0, 13, 6 + y0, (14, 16, 12, 255))
        c.rect(8, 2 + y0, 14, 6 + y0, base)                # капюшон
        c.rect(9, 5 + y0, 13, 7 + y0, base)
        c.rect(10, 6 + y0, 12, 7 + y0, dark)
        for x in range(9, 14):                              # нимб
            c.px(x, y0, (232, 204, 116, 255))
    elif name == "paladin":
        c.rect(8, 1 + y0, 14, 7 + y0, metal)
        c.rect(8, 1 + y0, 9, 7 + y0, (170, 182, 206, 255))
        c.rect(11, 1 + y0, 11, 6 + y0, (214, 178, 92, 255))  # крест
        c.rect(10, 3 + y0, 12, 3 + y0, (214, 178, 92, 255))
        c.rect(10, 0 + y0, 12, 0 + y0, (216, 226, 242, 255))
    elif name == "ranger":
        c.rect(9, 3 + y0, 13, 6 + y0, (14, 20, 14, 255))
        c.rect(8, 2 + y0, 14, 5 + y0, base)
        c.rect(9, 6 + y0, 13, 7 + y0, (196, 168, 112, 255))  # шарф
        for x in range(8, 15):                                # листва на капюшоне
            if x % 2 == 0:
                c.px(x, 1 + y0, light)


def draw_weapon(c: Canvas, name: str, idx: int, hand_x: int, hand_y: int, metal, dark, base) -> None:
    steel = (198, 208, 228, 255)
    gold = (214, 178, 92, 255)
    wood = (104, 74, 50, 255)

    if name == "warrior":
        # меч в правой руке, остриём вниз-вперёд
        c.seg(hand_x + 1, hand_y + 1, hand_x + 4, 6, steel, 1)
        c.px(hand_x + 1, hand_y + 1, gold)
        # щит
        c.rect(4, 11, 8, 16, (104, 74, 50, 255))
        c.rect(5, 12, 7, 15, (150, 112, 74, 255))
        c.px(6, 13, gold)
    elif name == "mage":
        c.seg(hand_x + 2, 4, hand_x + 2, 21, wood, 1)      # посох
        c.rect(hand_x + 1, 2, hand_x + 3, 4, (110, 226, 176, 255))
        c.px(hand_x + 2, 1, (170, 250, 210, 255))
    elif name == "duelist":
        # две шпаги: одна вперёд, другая назад
        c.seg(hand_x + 1, hand_y + 2, hand_x + 7, 20, steel, 1)
        c.px(hand_x + 1, hand_y + 2, gold)
        c.seg(3, hand_y + 2, -2, 19, (176, 188, 212, 255), 1)
        c.px(3, hand_y + 2, gold)
    elif name == "rogue":
        c.seg(hand_x + 1, hand_y + 2, hand_x + 4, hand_y + 5, steel, 1)
        c.seg(4, hand_y + 2, 1, hand_y + 5, steel, 1)
    elif name == "cleric":
        c.seg(hand_x + 2, 4, hand_x + 2, 20, gold, 1)
        c.rect(hand_x + 1, 2, hand_x + 3, 3, (255, 236, 168, 255))
        c.seg(4, hand_y + 6, 4, hand_y + 8, gold, 1)       # кадило на цепи
        c.rect(3, hand_y + 9, 5, hand_y + 10, (188, 190, 160, 255))
    elif name == "paladin":
        c.seg(hand_x + 1, hand_y, hand_x + 3, 19, wood, 1)
        c.rect(hand_x + 1, hand_y - 2, hand_x + 4, hand_y - 1, (240, 226, 170, 255))
        c.rect(4, 10, 8, 17, (170, 182, 206, 255))          # щит
        c.rect(6, 10, 6, 17, gold)
        c.rect(4, 13, 8, 13, gold)
    elif name == "ranger":
        # лук: дуга слева от фигуры
        for k in range(12):
            t = k / 11.0
            x = 3 + round(math.sin(t * math.pi) * 2.2)
            c.px(x, 6 + k, wood)
        c.seg(5, 6, 6, 18, (230, 220, 190, 255), 1)          # тетива
        c.seg(hand_x + 1, hand_y + 2, hand_x + 3, hand_y + 6, steel, 1)


def render(name: str) -> Image.Image:
    frames = []
    for i in range(FRAMES):
        canvas = Canvas()
        draw_body(canvas, name, i)
        canvas.outline()
        frames.append(canvas.img)

    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    return sheet


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    sheets = []
    for name in CLASSES:
        sheet = render(name)
        sheet.save(ART / f"runner_{name}.png")
        sheets.append((name, sheet))
        print(f"{name}: кадр {sheet.width // FRAMES}×{sheet.height}")

    zoom = 4
    pad = 10
    label_h = 16
    cw = max(s.width for _, s in sheets) * zoom
    ch = max(s.height for _, s in sheets) * zoom
    big = Image.new("RGBA", (cw + pad * 2, (ch + label_h + pad) * len(sheets) + pad), (20, 24, 38, 255))
    y = pad
    d = ImageDraw.Draw(big)
    for name, sheet in sheets:
        big.alpha_composite(sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST), (pad, y))
        d.text((pad, y + ch + 2), name.upper(), fill=(238, 224, 184, 255))
        y += ch + label_h + pad
    big.save(PREVIEW / "runners_sheet.png")
    print(f"превью -> {PREVIEW / 'runners_sheet.png'}")


if __name__ == "__main__":
    main()
