#!/usr/bin/env python3
"""Переносит пиксельный шрифт из tools/pixelfont.py в GDScript.

Выход: client/ui/pixel_font.gd  (class_name PixelFont)

Смысл: и логотип (Python/Pillow), и интерфейс в игре рисуют один и тот же
шрифт 5×7 — он описан строками и правится глазами, без бинарных ассетов.

Запуск: python3 tools/make_font_gd.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import pixelfont  # noqa: E402

OUT = Path("client/ui/pixel_font.gd")

HEADER = '''class_name PixelFont
## Пиксельный шрифт 5×7. Сгенерировано tools/make_font_gd.py — не править руками.
##
## Использование:
##   PixelFont.draw(image, "БОЙ", 4, 3, Color.WHITE)
##   var w := PixelFont.width("ЗОЛОТО")

const GLYPH_W := 5
const GLYPH_H := 7
const TRACKING := 1

const GLYPHS := {
'''

FOOTER = '''}


static func width(text: String) -> int:
	var n := text.length()
	if n == 0:
		return 0
	return n * GLYPH_W + (n - 1) * TRACKING


static func draw(image: Image, text: String, x: int, y: int, color: Color) -> void:
	var cursor := x
	var upper := text.to_upper()
	for i in upper.length():
		var glyph: Array = GLYPHS.get(upper[i], [])
		for row in glyph.size():
			var line: String = glyph[row]
			for col in line.length():
				if line[col] == "#":
					var px := cursor + col
					var py := y + row
					if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
						image.set_pixel(px, py, color)
		cursor += GLYPH_W + TRACKING


static func draw_shadow(
	image: Image, text: String, x: int, y: int, color: Color, shadow: Color
) -> void:
	draw(image, text, x + 1, y + 1, shadow)
	draw(image, text, x, y, color)
'''


def main() -> None:
    lines = [HEADER]
    for ch in sorted(pixelfont.FONT):
        glyph = pixelfont.FONT[ch]
        key = ch.replace('"', '\\"')
        rows = ", ".join(f'"{row}"' for row in glyph)
        lines.append(f'\t"{key}": [{rows}],\n')
    lines.append(FOOTER)
    OUT.write_text("".join(lines), encoding="utf-8")
    print(f"глифов: {len(pixelfont.FONT)} -> {OUT}")


if __name__ == "__main__":
    main()
