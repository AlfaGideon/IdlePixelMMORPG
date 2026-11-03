#!/usr/bin/env python3
"""Готовит портреты классов для экрана выбора.

Из больших концепт-артов 1024×1024 делает плотные портреты 96×96: обрезает по
фигуре, уменьшает и слегка поднимает контраст, чтобы мелкие детали не смылись.

Выход:
  client/art/classes/portrait_<класс>.png   — 96×96, RGB
  tools/preview/classes/portraits_sheet.png — превью всех портретов крупно

Запуск: python3 tools/make_class_portraits.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance

ART = Path("client/art/classes")
PREVIEW = Path("tools/preview/classes")
SIZE = 96

CLASSES = ["warrior", "mage", "duelist", "rogue", "cleric", "paladin", "ranger"]

# кадрирование: фигура занимает центр, поля обрезаем
CROP = (150, 70, 890, 810)


def make_portrait(src: Image.Image) -> Image.Image:
    img = src.convert("RGB").crop(CROP)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.12)
    img = ImageEnhance.Brightness(img).enhance(1.06)
    return img


def make_alpha_portrait(src: Image.Image, size: int = 192) -> Image.Image:
    """Портрет без фона: чтобы ставить фигуру на сцену и в рамки."""
    img = src.convert("RGB").crop(CROP).resize((size, size), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.1)
    px = img.load()
    alpha = Image.new("L", (size, size), 255)
    ap = alpha.load()
    for y in range(size):
        for x in range(size):
            r, g, b = px[x, y]
            if max(r, g, b) < 26:                      # чёрный фон
                ap[x, y] = 0
            elif max(r, g, b) < 46:                    # кромка — полупрозрачная
                ap[x, y] = 120
    out = img.convert("RGBA")
    out.putalpha(alpha)
    return out


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    made = []
    for name in CLASSES:
        src = Image.open(ART / f"{name}.png")
        img = make_portrait(src)
        img.save(ART / f"portrait_{name}.png")
        make_alpha_portrait(src).save(ART / f"figure_{name}.png")
        made.append((name, img))
        print(f"{name}: {img.width}×{img.height}")

    zoom = 2
    pad = 8
    label = 16
    cw = SIZE * zoom
    sheet = Image.new("RGB", (len(made) * (cw + pad) + pad, cw + label + pad * 2), (16, 18, 26))
    for i, (_, img) in enumerate(made):
        sheet.paste(img.resize((cw, cw), Image.NEAREST), (pad + i * (cw + pad), pad))
    sheet.save(PREVIEW / "portraits_sheet.png")
    print(f"превью -> {PREVIEW / 'portraits_sheet.png'}")


if __name__ == "__main__":
    main()
