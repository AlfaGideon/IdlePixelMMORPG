class_name GameHud
extends Control
## Игровой интерфейс после загрузочного экрана.
##
## Рисуется в буфер 180×320 (как заставка) и увеличивается целочисленно —
## поэтому рамки, шрифт и иконки остаются пиксельными на любом экране.
## Разметка: шапка (герой, здоровье, опыт, золото), центр (арена/вкладки),
## футер (пять кнопок-вкладок).

signal tab_changed(tab: int)

const GRID_W := 180
const GRID_H := 320

const HEADER_H := 32
const FOOTER_Y := 276
const FOOTER_H := 44

const TABS := ["БОЙ", "ТРУД", "СУМКА", "КАРТА", "ЛАВКА"]
const TAB_FIGHT := 0
const TAB_WORK := 1
const TAB_BAG := 2
const TAB_MAP := 3
const TAB_SHOP := 4

# --- палитра интерфейса ---
const INK := Color8(6, 8, 16)
const PANEL := Color8(17, 23, 43)
const PANEL_DEEP := Color8(11, 15, 30)
const PANEL_HI := Color8(26, 35, 62)
const FRAME := Color8(74, 92, 132)
const FRAME_DARK := Color8(34, 43, 70)
const TEXT := Color8(226, 234, 248)
const TEXT_DIM := Color8(136, 152, 184)
const GOLD := Color8(255, 204, 102)
const GOLD_DEEP := Color8(176, 122, 46)
const HP_A := Color8(214, 74, 84)
const HP_B := Color8(140, 34, 52)
const XP_A := Color8(110, 196, 255)
const XP_B := Color8(48, 106, 190)
const GREEN := Color8(92, 226, 146)
const GREEN_DEEP := Color8(38, 148, 104)
const DANGER := Color8(232, 112, 96)
const ARENA_SKY := Color8(20, 28, 52)
const ARENA_GROUND := Color8(30, 40, 62)
const ARENA_GROUND_HI := Color8(48, 62, 92)
const SLIME_DARK := Color8(40, 104, 70)
const SLIME := Color8(64, 162, 100)
const SLIME_LIT := Color8(132, 220, 148)
const EYE_WHITE := Color8(238, 246, 236)
const EYE_DARK := Color8(16, 24, 22)

const RUNNER_SHEET: Texture2D = preload("res://art/runner.png")
const RUNNER_W := 20
const RUNNER_H := 24

# --- состояние ---
var tab: int = TAB_FIGHT
var level: int = 1
var hp: int = 100
var max_hp: int = 100
var xp: int = 40
var xp_max: int = 120
var gold: int = 120

var enemy_name: String = "СЛИЗЕНЬ"
var enemy_level: int = 1
var enemy_hp: int = 24
var enemy_max_hp: int = 24
var enemy_flash: float = 0.0
var auto_fight: bool = false
var _auto_cd: float = 0.0
var _log: Array[String] = []

var _image: Image
var _texture: ImageTexture
var _hero: Array[Image] = []
var _time: float = 0.0
var _frame: int = 0
var _floats: Array[Vector4] = []
var _pressed: String = ""
var _hit_cooldown: float = 0.0


func _ready() -> void:
	_image = Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_load_hero()
	_log.append("ЛЕС ПРОСНУЛСЯ")
	_log.append("НАЙДЕН СЛИЗЕНЬ")
	_render()


func _load_hero() -> void:
	var sheet: Image = RUNNER_SHEET.get_image()
	if sheet == null:
		push_error("game_hud: нет res://art/runner.png")
		return
	sheet.convert(Image.FORMAT_RGBA8)
	for i in 6:
		_hero.append(sheet.get_region(Rect2i(i * RUNNER_W, 0, RUNNER_W, RUNNER_H)))


func _process(delta: float) -> void:
	_time += delta
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	enemy_flash = maxf(0.0, enemy_flash - delta)
	_frame += 1
	# 30 кадров в секунду — как у заставки
	if _frame % 2 == 0:
		_tick(delta * 2.0)
		_render()
		_texture.update(_image)
		queue_redraw()
	_maybe_capture()


func _tick(dt: float) -> void:
	var i := _floats.size() - 1
	while i >= 0:
		var f: Vector4 = _floats[i]
		f.z -= dt
		f.y -= 14.0 * dt
		if f.z <= 0.0:
			_floats.remove_at(i)
		else:
			_floats[i] = f
		i -= 1
	if auto_fight:
		_auto_cd -= dt
		if _auto_cd <= 0.0:
			_auto_cd = 1.1
			_attack()


# --- ввод -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		var view := get_viewport_rect().size
		var scale := _screen_scale(view)
		var origin := ((view - Vector2(GRID_W, GRID_H) * scale) / 2.0).floor()
		var grid := Vector2i(((pos - origin) / scale).floor())
		_on_press(grid)


func _on_press(p: Vector2i) -> void:
	# футер: вкладки
	if p.y >= FOOTER_Y:
		for i in TABS.size():
			if _tab_rect(i).has_point(p):
				tab = i
				_pressed = TABS[i]
				tab_changed.emit(tab)
				_render()
				return
	if tab == TAB_FIGHT and _fight_button_rect().has_point(p) and _hit_cooldown == 0.0:
		_hit_cooldown = 0.12
		_attack()
		return
	if tab == TAB_FIGHT and _auto_rect().has_point(p):
		auto_fight = not auto_fight
		_log.append("АВТОБОЙ ВКЛ" if auto_fight else "АВТОБОЙ ВЫКЛ")
		_render()


func _attack() -> void:
	if enemy_hp <= 0:
		return
	var dmg := 4 + int(_time * 7.0) % 5
	enemy_hp = maxi(0, enemy_hp - dmg)
	enemy_flash = 0.12
	_floats.append(Vector4(126.0, 132.0, 0.9, float(dmg)))
	if enemy_hp == 0:
		gold += 5 + enemy_level * 2
		xp += 12
		_log.append("%s ПОВЕРЖЕН" % enemy_name)
		if xp >= xp_max:
			xp -= xp_max
			level += 1
			xp_max += 30
			max_hp += 12
			hp = max_hp
			_log.append("НОВЫЙ УРОВЕНЬ %d" % level)
		enemy_level += 1
		enemy_max_hp = 24 + enemy_level * 8
		enemy_hp = enemy_max_hp
		enemy_name = _enemy_name(enemy_level)
	_render()


func _enemy_name(lvl: int) -> String:
	var names := ["СЛИЗЕНЬ", "ГРЫЗУН", "ПАУК", "ВОЛК", "ГОБЛИН"]
	return names[mini(names.size() - 1, (lvl - 1) / 2)]


# --- отрисовка на экране --------------------------------------------------

func _screen_scale(view: Vector2) -> float:
	var s := floorf(minf(view.x / GRID_W, view.y / GRID_H))
	if s < 1.0:
		s = minf(view.x / GRID_W, view.y / GRID_H)
	return s


func _draw() -> void:
	if _texture == null:
		return
	var view := get_viewport_rect().size
	var scale := _screen_scale(view)
	var drawn := Vector2(GRID_W, GRID_H) * scale
	var offset := ((view - drawn) / 2.0).floor()
	draw_texture_rect(_texture, Rect2(offset, drawn), false)


func _maybe_capture() -> void:
	if OS.get_environment("GAME_CAPTURE") != "1" or _frame != 50:
		return
	var path := OS.get_environment("GAME_CAPTURE_PATH")
	if path.is_empty():
		path = "user://game_capture.png"
	var err := _image.save_png(path)
	print("game_hud: снимок интерфейса -> %s (%d)" % [path, err])


# --- примитивы -----------------------------------------------------------

func _hash01(n: int, salt: float) -> float:
	var x := sin(n * 12.9898 + salt * 78.233) * 43758.5453
	return x - floorf(x)


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < GRID_W and y < GRID_H:
		_image.set_pixel(x, y, c)


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			_px(x + i, y + j, c)


func _panel(x: int, y: int, w: int, h: int, fill: Color = PANEL) -> void:
	# пиксельная рамка: тёмный контур, светлая фаска сверху-слева, тень снизу-справа
	_rect(x, y, w, h, fill)
	for i in w:
		_px(x + i, y, FRAME)
		_px(x + i, y + h - 1, FRAME_DARK)
	for j in h:
		_px(x, y + j, FRAME)
		_px(x + w - 1, y + j, FRAME_DARK)
	for i in range(1, w - 1):
		_px(x + i, y + 1, PANEL_HI)
	for j in range(1, h - 1):
		_px(x + 1, y + j, PANEL_HI)
	for j in range(1, h):
		_px(x + w - 1, y + j, FRAME_DARK)
	# срезанные углы — читается как пиксель, а не как мыло
	_px(x, y, INK)
	_px(x + w - 1, y, INK)
	_px(x, y + h - 1, INK)
	_px(x + w - 1, y + h - 1, INK)


func _text(s: String, x: int, y: int, c: Color) -> void:
	PixelFont.draw(_image, s, x, y, c)


func _text_shadow(s: String, x: int, y: int, c: Color) -> void:
	PixelFont.draw(_image, s, x + 1, y + 1, INK)
	PixelFont.draw(_image, s, x, y, c)


func _text_tiny(s: String, x: int, y: int, c: Color) -> void:
	# сжатый по горизонтали шрифт: каждый второй столбец глифа
	var cursor := x
	var upper := s.to_upper()
	for i in upper.length():
		var glyph: Array = PixelFont.GLYPHS.get(upper[i], [])
		for row in glyph.size():
			var line: String = glyph[row]
			for col in range(0, line.length(), 2):
				if line[col] == "#":
					_px(cursor + col / 2, y + row, c)
		cursor += 3


func _text_tiny_width(s: String) -> int:
	return maxi(0, s.length() * 3 - 1)


func _text_tiny_center(s: String, cx: int, y: int, c: Color) -> void:
	_text_tiny(s, cx - _text_tiny_width(s) / 2, y, c)


func _text_center(s: String, cx: int, y: int, c: Color) -> void:
	_text_shadow(s, cx - PixelFont.width(s) / 2, y, c)


func _text_right(s: String, rx: int, y: int, c: Color) -> void:
	_text_shadow(s, rx - PixelFont.width(s), y, c)


func _bar(x: int, y: int, w: int, h: int, frac: float, c0: Color, c1: Color) -> void:
	_rect(x - 1, y - 1, w + 2, h + 2, INK)
	_rect(x, y, w, h, PANEL_DEEP)
	var fill := int(clampf(frac, 0.0, 1.0) * float(w))
	for i in fill:
		for j in h:
			var k := float(j) / maxf(1.0, float(h - 1))
			_px(x + i, y + j, c0.lerp(c1, k))
	if fill > 0 and fill < w:
		for j in h:
			_px(x + fill, y + j, Color8(240, 246, 255))


# --- шапка ---------------------------------------------------------------

func _draw_header() -> void:
	_rect(0, 0, GRID_W, HEADER_H, PANEL_DEEP)
	for i in GRID_W:
		_px(i, HEADER_H - 1, FRAME_DARK)
	_rect(0, HEADER_H - 2, GRID_W, 1, PANEL_HI)

	# аватар
	_panel(4, 4, 22, 22, PANEL)
	_draw_hero_face(6, 6)

	_text_shadow("ГЕРОЙ", 30, 5, TEXT)
	var lvl := "УР %d" % level
	_text(lvl, 30, 15, GOLD)
	_panel(30 + PixelFont.width(lvl) + 3, 14, 2, 2, PANEL)

	# здоровье
	_bar(74, 6, 100, 8, float(hp) / float(maxi(1, max_hp)), HP_A, HP_B)
	_text_center("%d/%d" % [hp, max_hp], 124, 7, TEXT)

	# опыт
	_bar(74, 17, 100, 4, float(xp) / float(maxi(1, xp_max)), XP_A, XP_B)

	# золото
	_draw_coin(77, 24)
	_text_shadow("%d" % gold, 86, 24, GOLD)


func _draw_hero_face(x: int, y: int) -> void:
	var face := [
		"..######..",
		".########.",
		"#........#",
		"#..####..#",
		"#.##..##.#",
		"#.##..##.#",
		"#..####..#",
		"#........#",
		".########.",
		"..######..",
	]
	var hood := Color8(54, 168, 126)
	var hood_lit := Color8(126, 226, 172)
	var skin := Color8(236, 194, 152)
	for j in face.size():
		var row: String = face[j]
		for i in row.length():
			if row[i] != "#":
				continue
			var c := hood
			if j >= 3 and j <= 6 and i >= 3 and i <= 6:
				c = skin
			if i >= 7:
				c = hood_lit
			_px(x + i, y + j, c)


func _draw_coin(x: int, y: int) -> void:
	var coin := [".####.", "######", "#.##.#", "#.##.#", "######", ".####."]
	for j in coin.size():
		var row: String = coin[j]
		for i in row.length():
			if row[i] == "#":
				_px(x + i, y + j, GOLD if (i + j) % 3 else GOLD_DEEP)


# --- центр: арена --------------------------------------------------------

func _enemy_card_rect() -> Rect2i:
	return Rect2i(4, HEADER_H + 2, GRID_W - 8, 26)


func _arena_rect() -> Rect2i:
	return Rect2i(4, HEADER_H + 30, GRID_W - 8, 128)


func _fight_button_rect() -> Rect2i:
	return Rect2i(6, 194, 106, 24)


func _auto_rect() -> Rect2i:
	return Rect2i(116, 194, 58, 24)


func _log_rect() -> Rect2i:
	return Rect2i(4, 222, GRID_W - 8, FOOTER_Y - 226)


func _draw_fight() -> void:
	var card := _enemy_card_rect()
	_panel(card.position.x, card.position.y, card.size.x, card.size.y)
	_text_shadow(enemy_name, card.position.x + 5, card.position.y + 5, TEXT)
	var lvl := "УР %d" % enemy_level
	_text_right(lvl, card.end.x - 5, card.position.y + 5, TEXT_DIM)
	_bar(card.position.x + 5, card.position.y + 15, card.size.x - 10, 7,
		float(enemy_hp) / float(maxi(1, enemy_max_hp)), DANGER, HP_B)
	_text_center("%d/%d" % [enemy_hp, enemy_max_hp], card.position.x + card.size.x / 2,
		card.position.y + 15, TEXT)

	var arena := _arena_rect()
	_panel(arena.position.x, arena.position.y, arena.size.x, arena.size.y, ARENA_SKY)
	var ground_y := arena.position.y + 96
	for y in range(ground_y, arena.end.y - 1):
		var k := float(y - ground_y) / float(maxi(1, arena.end.y - ground_y))
		_rect(arena.position.x + 1, y, arena.size.x - 2, 1, ARENA_GROUND.lerp(ARENA_GROUND_HI, k))
	# небо арены: луна и звёзды
	var mx := arena.position.x + 112
	var my := arena.position.y + 22
	for j in range(-6, 7):
		for i in range(-6, 7):
			if i * i + j * j <= 30:
				_px(mx + i, my + j, Color8(238, 236, 214))
	for i in 22:
		var sx := arena.position.x + 4 + int(_hash01(i, 3.7) * float(arena.size.x - 8))
		var sy := arena.position.y + 4 + int(_hash01(i, 5.1) * 60.0)
		_px(sx, sy, Color8(150, 170, 210) if i % 3 else Color8(220, 230, 250))

	# дальний лес: короткие силуэты елей вдоль горизонта
	for i in range(0, arena.size.x - 2, 5):
		var h := 5 + (i * 7) % 6
		var tx := arena.position.x + 1 + i
		for j in h:
			var half := (j * 2) / h
			for dx in range(-half, half + 1):
				_px(tx + dx, ground_y - 1 - j, Color8(16, 26, 38))
	# кромка травы по горизонту
	for i in range(arena.position.x + 1, arena.end.x - 1):
		if (i * 7) % 5 == 0:
			_px(i, ground_y - 1, Color8(66, 96, 84))
	# точки на земле
	for i in range(arena.position.x + 3, arena.end.x - 3, 6):
		_px(i, ground_y + 6 + (i % 5), Color8(40, 52, 76))

	# герой
	if not _hero.is_empty():
		var bob := int(round(sin(_time * 2.4) * 0.6))
		var hx := arena.position.x + 22
		var hy := ground_y - RUNNER_H + 1 + bob
		_image.blend_rect(_hero[0], Rect2i(0, 0, RUNNER_W, RUNNER_H), Vector2i(hx, hy))
	_draw_shadow_blob(arena.position.x + 32, ground_y)

	# враг
	var ex := arena.position.x + 100
	var ey := ground_y
	_draw_shadow_blob(ex + 8, ground_y)
	_draw_slime(ex, ey)

	# всплывающие числа урона
	for f in _floats:
		var tx := int(f.x)
		var ty := int(f.y)
		var a := clampf(f.z / 0.9, 0.0, 1.0)
		var c := Color8(255, 240, 180).lerp(TEXT_DIM, 1.0 - a)
		_text_shadow("%d" % int(f.w), tx - 4, ty, c)

	# кнопки боя
	var hit := _fight_button_rect()
	_button(hit, "УДАР", GOLD, true)
	var auto_r := _auto_rect()
	_button(auto_r, "АВТО", GREEN if auto_fight else TEXT_DIM, auto_fight)


func _draw_shadow_blob(cx: int, cy: int) -> void:
	for i in range(-6, 7):
		for j in range(0, 3):
			var d := (i * i) / 36.0 + (j * j) / 4.0
			if d <= 1.0:
				_px(cx + i, cy - 1 + j, Color8(16, 22, 38))


func _draw_slime(x: int, y: int) -> void:
	var squash := 1.0 + 0.08 * sin(_time * 3.0)
	var rx := int(9 * squash)
	var ry := int(7 / squash)
	var body := SLIME if enemy_flash <= 0.0 else Color8(240, 246, 236)
	var body_dark := SLIME_DARK if enemy_flash <= 0.0 else Color8(200, 210, 200)
	for j in range(-ry, 2):
		var k := float(j + ry) / float(ry + 1)
		var half := int(rx * sqrt(maxf(0.0, 1.0 - pow((k - 1.0), 2.0))))
		for i in range(-half, half + 1):
			var nx := float(i) / float(maxi(1, half))
			var c := body
			if nx > 0.45 or j > -1:
				c = body_dark
			_px(x + i, y + j, c)
	# блик и глаза
	for i in range(-4, 0):
		_px(x + i, y - ry + 2, SLIME_LIT if enemy_flash <= 0.0 else body)
	_px(x - 4, y - 4, EYE_WHITE)
	_px(x - 3, y - 4, EYE_WHITE)
	_px(x - 4, y - 3, EYE_DARK)
	_px(x + 3, y - 4, EYE_WHITE)
	_px(x + 4, y - 4, EYE_WHITE)
	_px(x + 4, y - 3, EYE_DARK)
	_px(x, y - 1, EYE_DARK)


func _draw_log() -> void:
	var log_r := _log_rect()
	_panel(log_r.position.x, log_r.position.y, log_r.size.x, log_r.size.y, PANEL_DEEP)
	var shown: int = mini(3, _log.size())
	for i in shown:
		var line: String = _log[_log.size() - shown + i]
		_text(line, log_r.position.x + 5, log_r.position.y + 5 + i * 10, TEXT_DIM)


# --- центр: остальные вкладки -------------------------------------------

func _rows_area() -> Rect2i:
	return Rect2i(4, HEADER_H + 2, GRID_W - 8, FOOTER_Y - HEADER_H - 6)


func _draw_list(title: String, rows: Array, foot: String) -> void:
	var area := _rows_area()
	_panel(area.position.x, area.position.y, area.size.x, area.size.y)
	_text_shadow(title, area.position.x + 6, area.position.y + 6, GOLD)
	for i in rows.size():
		var row: Array = rows[i]
		var y := area.position.y + 18 + i * 26
		_panel(area.position.x + 4, y, area.size.x - 8, 23, PANEL_DEEP)
		_text(str(row[0]), area.position.x + 9, y + 4, TEXT)
		_text(str(row[1]), area.position.x + 9, y + 13, TEXT_DIM)
		if row.size() > 2:
			_bar(area.position.x + 96, y + 9, 70, 6, float(row[2]), GREEN, GREEN_DEEP)
			_text_right(str(row[3]), area.end.x - 9, y + 4, GOLD)
	_text(foot, area.position.x + 6, area.end.y - 12, TEXT_DIM)


func _draw_bag() -> void:
	var area := _rows_area()
	_panel(area.position.x, area.position.y, area.size.x, area.size.y)
	_text_shadow("СНАРЯЖЕНИЕ", area.position.x + 6, area.position.y + 6, GOLD)
	var cells := [
		["МЕЧ", GOLD], ["ПЛАЩ", GREEN], ["", TEXT_DIM], ["", TEXT_DIM], ["", TEXT_DIM],
		["", TEXT_DIM], ["", TEXT_DIM], ["", TEXT_DIM], ["", TEXT_DIM], ["", TEXT_DIM],
	]
	for i in cells.size():
		var cx := area.position.x + 7 + (i % 5) * 33
		var cy := area.position.y + 20 + (i / 5) * 33
		_panel(cx, cy, 31, 31, PANEL_DEEP)
		var label: String = cells[i][0]
		if not label.is_empty():
			_text_center(label, cx + 15, cy + 12, cells[i][1])
	# описание выбранного
	_panel(area.position.x + 4, area.position.y + 96, area.size.x - 8, 40, PANEL_DEEP)
	_text("МЕЧ СТРАЖА", area.position.x + 10, area.position.y + 102, TEXT)
	_text("УРОН 4-8", area.position.x + 10, area.position.y + 114, TEXT_DIM)
	_text("РЕДКОСТЬ: ОБЫЧНЫЙ", area.position.x + 10, area.position.y + 124, TEXT_DIM)
	_text("ВЫБЕРИ СЛОТ", area.position.x + 6, area.end.y - 12, TEXT_DIM)


func _draw_map() -> void:
	var area := _rows_area()
	_panel(area.position.x, area.position.y, area.size.x, area.size.y)
	_text_shadow("КАРТА МИРА", area.position.x + 6, area.position.y + 6, GOLD)
	var zones := [
		["ТЁМНЫЙ ЛЕС", "УР 1-3", GREEN, "ОТКРЫТО"],
		["КАМЕННЫЙ БРОД", "УР 4-6", FRAME, "ЗАКРЫТО"],
		["ПЕПЕЛЬНАЯ ПУСТОШЬ", "УР 7-9", FRAME, "ЗАКРЫТО"],
	]
	for i in zones.size():
		var z: Array = zones[i]
		var y := area.position.y + 20 + i * 34
		_panel(area.position.x + 4, y, area.size.x - 8, 30, PANEL_DEEP)
		_text(str(z[0]), area.position.x + 10, y + 5, TEXT)
		_text(str(z[1]), area.position.x + 10, y + 16, TEXT_DIM)
		_text_right(str(z[3]), area.end.x - 10, y + 5, z[2])
		if str(z[3]) == "ОТКРЫТО":
			_bar(area.position.x + 10, y + 24, area.size.x - 24, 3, 1.0, GREEN, GREEN_DEEP)
	_text("ВЫБЕРИ ЗОНУ", area.position.x + 6, area.end.y - 12, TEXT_DIM)


func _draw_shop() -> void:
	var area := _rows_area()
	_panel(area.position.x, area.position.y, area.size.x, area.size.y)
	_text_shadow("ЛАВКА ТОРГОВЦА", area.position.x + 6, area.position.y + 6, GOLD)
	var goods := [
		["ЗЕЛЬЕ ЛЕЧЕНИЯ", "+30 ЗДОРОВЬЯ", "25"],
		["ТОЧИЛЬНЫЙ КАМЕНЬ", "+1 К УРОНУ", "60"],
		["ФАКЕЛ", "СВЕТ В ПЕЩЕРЕ", "15"],
	]
	for i in goods.size():
		var g: Array = goods[i]
		var y := area.position.y + 20 + i * 30
		_panel(area.position.x + 4, y, area.size.x - 8, 26, PANEL_DEEP)
		_text(str(g[0]), area.position.x + 10, y + 5, TEXT)
		_text(str(g[1]), area.position.x + 10, y + 15, TEXT_DIM)
		_draw_coin(area.end.x - 54, y + 8)
		_text_right(str(g[2]), area.end.x - 12, y + 8, GOLD)
	_text("ЦЕНЫ В ЗОЛОТЕ", area.position.x + 6, area.end.y - 12, TEXT_DIM)


# --- футер ---------------------------------------------------------------

func _tab_rect(i: int) -> Rect2i:
	var w := 35
	var gap := 0
	var total := w * TABS.size() + gap * (TABS.size() - 1)
	var x0 := (GRID_W - total) / 2
	return Rect2i(x0 + i * (w + gap), FOOTER_Y + 5, w, FOOTER_H - 10)


func _button(r: Rect2i, label: String, accent: Color, active: bool) -> void:
	var fill := PANEL if not active else PANEL_HI
	_panel(r.position.x, r.position.y, r.size.x, r.size.y, fill)
	if active:
		for i in range(2, r.size.x - 2):
			_px(r.position.x + i, r.position.y + r.size.y - 2, accent)
	_text_center(label, r.position.x + r.size.x / 2, r.position.y + r.size.y - 11,
		accent if active else TEXT)


func _draw_footer() -> void:
	_rect(0, FOOTER_Y, GRID_W, FOOTER_H, PANEL_DEEP)
	for i in GRID_W:
		_px(i, FOOTER_Y, FRAME_DARK)
		_px(i, FOOTER_Y + 1, PANEL_HI)
	for i in TABS.size():
		var r := _tab_rect(i)
		var active := i == tab
		_panel(r.position.x, r.position.y, r.size.x, r.size.y, PANEL_HI if active else PANEL)
		if i > 0:
			for j in range(r.position.y + 2, r.position.y + r.size.y - 2):
				_px(r.position.x - 1, j, FRAME_DARK)
		if active:
			for k in range(3, r.size.x - 3):
				_px(r.position.x + k, r.position.y + r.size.y - 2, GOLD)
		_draw_tab_icon(i, r.position.x + r.size.x / 2, r.position.y + 7, active)
		var label: String = TABS[i]
		if PixelFont.width(label) > r.size.x - 10:
			_text_tiny_center(label, r.position.x + r.size.x / 2, r.position.y + r.size.y - 10,
				GOLD if active else TEXT_DIM)
		else:
			_text_center(label, r.position.x + r.size.x / 2, r.position.y + r.size.y - 11,
				GOLD if active else TEXT_DIM)


func _draw_tab_icon(i: int, cx: int, y: int, active: bool) -> void:
	var c := GOLD if active else TEXT_DIM
	match i:
		TAB_FIGHT:  # меч
			for k in 7:
				_px(cx + 3 - k, y + k, c)
			_px(cx - 1, y + 6, c)
			_px(cx + 1, y + 6, c)
			_px(cx + 2, y + 7, c)
		TAB_WORK:  # кирка
			for k in 7:
				_px(cx, y + k, c)
			_px(cx - 3, y + 1, c)
			_px(cx - 2, y + 1, c)
			_px(cx - 1, y + 1, c)
			_px(cx + 1, y + 1, c)
			_px(cx + 2, y + 1, c)
			_px(cx + 3, y + 2, c)
		TAB_BAG:  # сумка
			for j in 6:
				for k in 7:
					if j == 0 and (k == 0 or k == 6):
						continue
					_px(cx - 3 + k, y + 1 + j, c)
			_px(cx - 1, y, c)
			_px(cx, y, c)
			_px(cx + 1, y, c)
		TAB_MAP:  # карта
			for j in 6:
				for k in 7:
					if (j + k) % 4 == 0:
						continue
					_px(cx - 3 + k, y + 1 + j, c)
			_px(cx + 1, y + 3, GOLD if not active else PANEL_DEEP)
		TAB_SHOP:  # монета
			for j in 6:
				for k in 6:
					var d := (k - 2.5) * (k - 2.5) + (j - 2.5) * (j - 2.5)
					if d <= 7.0 and d >= 2.0:
						_px(cx - 3 + k, y + 1 + j, c)


# --- кадр ---------------------------------------------------------------

func _render() -> void:
	_rect(0, 0, GRID_W, GRID_H, PANEL_DEEP)
	_draw_header()
	match tab:
		TAB_FIGHT:
			_draw_fight()
			_draw_log()
		TAB_WORK:
			_draw_work()
		TAB_BAG:
			_draw_bag()
		TAB_MAP:
			_draw_map()
		TAB_SHOP:
			_draw_shop()
	_draw_footer()


func _draw_work() -> void:
	var jobs := [
		["ЛЕСОРУБ", "ДРЕВЕСИНА", 0.4, "10/25"],
		["РУДОКОП", "РУДА", 0.15, "3/20"],
		["РЫБАК", "РЫБА", 0.0, "0/15"],
	]
	_draw_list("РЕМЁСЛА", jobs, "РАБОТА ИДЁТ, ПОКА ТЫ ОФФЛАЙН")
