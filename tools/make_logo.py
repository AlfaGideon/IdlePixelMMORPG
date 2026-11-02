#!/usr/bin/env python3
"""Собирает игровые ассеты из нарисованного логотипа-исходника.

Исходник: tools/art-src/logo-source.png (широкий баннер: сцена у костра + надпись).

Выход:
  client/art/logo.png         — широкий логотип для загрузочного экрана, с мягкой кромкой
  client/art/logo-square.png  — квадратная эмблема 768×768 (сцена + надпись)
  client/art/icon.png         — иконка приложения 512×512
  tools/preview/boot_compose.png — как логотип ляжет на загрузочный экран

Запуск: python3 tools/make_logo.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
import pixelfont  # noqa: E402

SRC = Path("tools/art-src/logo-source.png")
ART = Path("client/art")
PREVIEW = Path("tools/preview")

NAVY = (11, 16, 40)
CREAM = (242, 238, 216)
EMERALD = (92, 226, 146)
SHADOW = (9, 12, 24)
GLOW_CREAM = (255, 206, 128)


def load_source() -> Image.Image:
    return Image.open(SRC).convert("RGB")


def wide_logo(src: Image.Image) -> Image.Image:
    """Широкий баннер: уменьшаем до разумного размера и гасим кромку в прозрачность."""
    w = 1600
    h = round(src.height * w / src.width)
    img = src.resize((w, h), Image.LANCZOS).convert("RGBA")

    # радиальное растворение: прямоугольник не должен читаться на анимированном небе
    alpha = Image.new("L", (w, h), 255)
    px = alpha.load()
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    for y in range(h):
        for x in range(w):
            nx = abs(x - cx) / cx
            ny = abs(y - cy) / cy
            d = (nx ** 2.6 * 0.62 + ny ** 2.6 * 0.38) ** 0.5
            k = 1.0 - max(0.0, (d - 0.62) / 0.38)
            px[x, y] = int(255 * max(0.0, min(1.0, k)) ** 0.9)
    img.putalpha(alpha)
    return img


def emblem(src: Image.Image) -> Image.Image:
    """Левая часть баннера — сцена с героем и костром."""
    box = (0, 0, int(src.width * 0.35), src.height)
    return src.crop(box)


def square_logo(src: Image.Image) -> Image.Image:
    size = 768
    img = Image.new("RGB", (size, size), NAVY)
    em = emblem(src).resize((size - 48, round((size - 48) * emblem(src).height / emblem(src).width)), Image.LANCZOS)
    img.paste(em, ((size - em.width) // 2, 8))

    put = lambda x, y, c: img.putpixel((x, y), c) if 0 <= x < size and 0 <= y < size else None  # noqa: E731

    def text(text: str, y: int, color, scale: int) -> None:
        w = pixelfont.text_width(text, scale=scale, tracking=1)
        x = (size - w) // 2
        glow = Image.new("RGB", (size, size), NAVY)
        gput = lambda gx, gy, gc: glow.putpixel((gx, gy), gc) if 0 <= gx < size and 0 <= gy < size else None  # noqa: E731
        pixelfont.draw_text(gput, text, x - 4, y, color, scale=scale, tracking=1)
        glow = glow.filter(ImageFilter.GaussianBlur(6))
        img.paste(Image.blend(img, glow, 0.55))
        pixelfont.draw_text(put, text, x, y, SHADOW, scale=scale, tracking=1, shadow_offset=scale)
        pixelfont.draw_text(put, text, x, y, color, scale=scale, tracking=1)

    text("IDLE PIXEL", 560, CREAM, 8)
    text("MMORPG", 668, EMERALD, 8)
    return img.convert("RGBA")


def icon(src: Image.Image) -> Image.Image:
    """Крупный план героя у костра."""
    em = emblem(src)
    # берём нижнюю левую часть, где стоят герой и огонь
    side = int(em.height * 0.78)
    left = int(em.width * 0.06)
    top = int(em.height * 0.16)
    crop = em.crop((left, top, left + side, top + side)).resize((512, 512), Image.LANCZOS)
    return crop.convert("RGBA")


def compose_preview(logo: Image.Image, height: int, name: str) -> None:
    screen = Image.open(PREVIEW / "engine_capture.png").convert("RGB")
    screen = screen.resize((720, 1280), Image.NEAREST)
    lw = round(logo.width * height / logo.height)
    lg = logo.resize((lw, height), Image.LANCZOS)
    screen.paste(lg, ((720 - lw) // 2, 24), lg)
    screen.save(PREVIEW / name)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"нет исходника {SRC}")
    src = load_source()
    ART.mkdir(parents=True, exist_ok=True)

    logo = wide_logo(src)
    logo.save(ART / "logo.png", optimize=True)
    square_logo(src).save(ART / "logo-square.png", optimize=True)
    icon(src).save(ART / "icon.png", optimize=True)

    if (PREVIEW / "engine_capture.png").exists():
        compose_preview(logo, 110, "boot_compose_110.png")
        compose_preview(logo, 150, "boot_compose_150.png")

    print(f"logo.png {logo.width}×{logo.height}, logo-square.png 768×768, icon.png 512×512")


if __name__ == "__main__":
    main()
