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


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    made = []
    for name in CLASSES:
        img = make_portrait(Image.open(ART / f"{name}.png"))
        img.save(ART / f"portrait_{name}.png")
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
