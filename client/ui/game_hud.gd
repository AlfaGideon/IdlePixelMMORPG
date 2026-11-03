class_name GameHud
extends Control
## Игровой интерфейс после экрана выбора класса.
##
## Рисуется в буфер 240×427 и увеличивается целочисленно — рамки, шрифт и
## портреты остаются пиксельными на любом экране.
## Стиль: чёрный фон, золотые рамки с уголками, белый текст (вариант 6).
## Класс берётся из профиля игрока (user://profile.cfg), поэтому и портрет в
## шапке, и герой на арене — выбранный персонаж.

signal tab_changed(tab: int)

const GRID_W := 240
const GRID_H := 427

const HEADER_H := 46
const FOOTER_Y := 371
const FOOTER_H := 56

const TABS := ["БОЙ", "ТРУД", "СУМКА", "КАРТА", "ЛАВКА"]
const TAB_FIGHT := 0
const TAB_WORK := 1
const TAB_BAG := 2
const TAB_MAP := 3
const TAB_SHOP := 4

# --- палитра: чёрный + золото ---
const INK := Color8(5, 6, 9)
const PANEL := Color8(12, 13, 18)
const PANEL_DEEP := Color8(8, 9, 12)
const PANEL_HI := Color8(24, 26, 34)
const FRAME := Color8(176, 136, 60)
const FRAME_DARK := Color8(92, 70, 34)
const FRAME_HI := Color8(255, 226, 148)

const TEXT := Color8(240, 238, 228)
const TEXT_DIM := Color8(146, 142, 130)
const GOLD := Color8(226, 186, 92)
const GOLD_HI := Color8(255, 226, 148)
const HP_A := Color8(206, 74, 84)
const HP_B := Color8(128, 32, 48)
const XP_A := Color8(226, 186, 92)
const XP_B := Color8(138, 100, 40)
const GREEN := Color8(92, 196, 128)
const GREEN_DEEP := Color8(38, 118, 82)

const ARENA_SKY := Color8(13, 17, 28)
const ARENA_GROUND := Color8(22, 27, 38)
const ARENA_GROUND_HI := Color8(38, 46, 62)
const SLIME_DARK := Color8(40, 104, 70)
const SLIME := Color8(64, 162, 100)
const SLIME_LIT := Color8(132, 220, 148)
const EYE_WHITE := Color8(238, 246, 236)
const EYE_DARK := Color8(16, 24, 22)

const PROFILE_PATH := "user://profile.cfg"
const HERO_CLASS_SETTING := "game/player/hero_class"
const FIGURE_SIZE := 192

const FIGURES := {
	"warrior": preload("res://art/classes/figure_warrior.png"),
	"mage": preload("res://art/classes/figure_mage.png"),
	"duelist": preload("res://art/classes/figure_duelist.png"),
	"rogue": preload("res://art/classes/figure_rogue.png"),
	"cleric": preload("res://art/classes/figure_cleric.png"),
	"paladin": preload("res://art/classes/figure_paladin.png"),
	"ranger": preload("res://art/classes/figure_ranger.png"),
}
const CLASS_NAMES := {
	"warrior": "ВОИН", "mage": "МАГ", "duelist": "ДУЭЛЬ", "rogue": "РОГА",
	"cleric": "ЖРЕЦ", "paladin": "ПАЛАДИН", "ranger": "ЛУЧНИК",
}

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
var _hero_class := ""
var _figure: Image = null
var _time: float = 0.0
var _frame: int = 0
var _floats: Array[Vector4] = []
var _hit_cooldown: float = 0.0


func _ready() -> void:
	_image = Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_hero_class = _read_class()
	_load_figure()
	_log.append("ЛЕС ПРОСНУЛСЯ")
	_log.append("НАЙДЕН СЛИЗЕНЬ")
	_render()


func _read_class() -> String:
	var cfg := ConfigFile.new()
	var id := ""
	if cfg.load(PROFILE_PATH) == OK:
		id = str(cfg.get_value("hero", "class", "")).strip_edges().to_lower()
	if id.is_empty():
		id = str(ProjectSettings.get_setting(HERO_CLASS_SETTING, "")).strip_edges().to_lower()
	if not FIGURES.has(id):
		id = "warrior"
	print("game_hud: класс героя %s" % id)
	return id


func _load_figure() -> void:
	var tex: Texture2D = FIGURES[_hero_class]
	_figure = tex.get_image()
	if _figure == null:
		push_error("game_hud: не удалось прочитать фигуру класса %s" % _hero_class)
		return
	_figure.convert(Image.FORMAT_RGBA8)


func _process(delta: float) -> void:
	_time += delta
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	enemy_flash = maxf(0.0, enemy_flash - delta)
	_frame += 1
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
		f.y -= 18.0 * dt
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


# --- ввод ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_on_press(_to_grid(mb.position))


func _to_grid(pos: Vector2) -> Vector2i:
	var view := get_viewport_rect().size
	var scale := _screen_scale(view)
	var origin := ((view - Vector2(GRID_W, GRID_H) * scale) / 2.0).floor()
	return Vector2i(((pos - origin) / scale).floor())


func _on_press(p: Vector2i) -> void:
	if p.y >= FOOTER_Y:
		for i in TABS.size():
			if _tab_rect(i).has_point(p):
				tab = i
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
		return
	if _portrait_rect().has_point(p):
		# портрет открывает карточку героя
		tab = TAB_MAP
		_render()


func _attack() -> void:
	if enemy_hp <= 0:
		return
	var dmg := 4 + int(_time * 7.0) % 5
	enemy_hp = maxi(0, enemy_hp - dmg)
	enemy_flash = 0.12
	var enemy_x := _arena_rect().position.x + 156
	_floats.append(Vector4(float(enemy_x), float(_ground_y() - 30), 0.9, float(dmg)))
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


# --- геометрия ----------------------------------------------------------

func _portrait_rect() -> Rect2i:
	return Rect2i(6, 5, 36, 36)


func _enemy_card_rect() -> Rect2i:
	return Rect2i(6, HEADER_H + 4, GRID_W - 12, 34)


func _arena_rect() -> Rect2i:
	return Rect2i(6, HEADER_H + 42, GRID_W - 12, 168)


func _ground_y() -> int:
	return _arena_rect().position.y + 140


func _fight_button_rect() -> Rect2i:
	return Rect2i(8, 262, 140, 34)


func _auto_rect() -> Rect2i:
	return Rect2i(156, 262, 76, 34)


func _log_rect() -> Rect2i:
	return Rect2i(6, 302, GRID_W - 12, FOOTER_Y - 308)


func _rows_area() -> Rect2i:
	return Rect2i(6, HEADER_H + 4, GRID_W - 12, FOOTER_Y - HEADER_H - 10)


func _tab_rect(i: int) -> Rect2i:
	var gap := 2
	var total_w := GRID_W - 12 - gap * (TABS.size() - 1)
	var w := total_w / TABS.size()
	return Rect2i(6 + i * (w + gap), FOOTER_Y + 6, w, FOOTER_H - 12)


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
	if OS.get_environment("GAME_CAPTURE") != "1" or _frame != 60:
		return
	var path := OS.get_environment("GAME_CAPTURE_PATH")
	if path.is_empty():
		path = "user://game_capture.png"
	var err := _image.save_png(path)
	print("game_hud: снимок интерфейса -> %s (%d)" % [path, err])


# --- примитивы ----------------------------------------------------------

func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < GRID_W and y < GRID_H:
		_image.set_pixel(x, y, c)


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			_px(x + i, y + j, c)


func _gold_frame(x: int, y: int, w: int, h: int, fill: Color) -> void:
	"""Золотая рамка: тень, заливка, двойной контур и уголки."""
	_rect(x, y, w, h, fill)
	for i in w:
		_px(x + i, y, FRAME)
		_px(x + i, y + h - 1, FRAME_DARK)
	for j in h:
		_px(x, y + j, FRAME)
		_px(x + w - 1, y + j, FRAME_DARK)
	# внутренняя светлая линия
	for i in range(2, w - 2):
		_px(x + i, y + 2, FRAME_DARK if (i % 4) else PANEL_HI)
		_px(x + i, y + h - 3, FRAME_DARK)
	for j in range(2, h - 2):
		_px(x + 2, y + j, FRAME_DARK)
		_px(x + w - 3, y + j, FRAME_DARK)
	# уголки
	for c: Vector2i in [
		Vector2i(x, y), Vector2i(x + w - 1, y),
		Vector2i(x, y + h - 1), Vector2i(x + w - 1, y + h - 1),
	]:
		_px(c.x, c.y, FRAME_HI)
		for d: int in [1, -1]:
			_px(c.x + d, c.y, FRAME_HI)
			_px(c.x, c.y + d, FRAME_HI)


func _text(s: String, x: int, y: int, c: Color) -> void:
	PixelFont.draw(_image, s, x, y, c)


func _text_center(s: String, cx: int, y: int, c: Color) -> void:
	_text(s, cx - PixelFont.width(s) / 2, y, c)


func _text_right(s: String, rx: int, y: int, c: Color) -> void:
	_text(s, rx - PixelFont.width(s), y, c)


func _bar(x: int, y: int, w: int, h: int, frac: float, c0: Color, c1: Color) -> void:
	_rect(x, y, w, h, INK)
	for i in w:
		_px(x + i, y, FRAME_DARK)
		_px(x + i, y + h - 1, FRAME_DARK)
	var fill := int(clampf(frac, 0.0, 1.0) * float(w - 2))
	for i in fill:
		for j in range(1, h - 1):
			var k := float(j) / maxf(1.0, float(h - 2))
			_px(x + 1 + i, y + j, c0.lerp(c1, k))


func _blit_scaled(src: Image, x: int, y: int, size: int, tint: Color = Color.WHITE) -> void:
	var ratio := float(src.get_width()) / float(size)
	for j in size:
		for i in size:
			var c := src.get_pixel(int(i * ratio), int(j * ratio))
			if c.a < 0.4:
				continue
			_px(x + i, y + j, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, 1.0))


# --- шапка --------------------------------------------------------------

func _draw_header() -> void:
	_rect(0, 0, GRID_W, HEADER_H, PANEL_DEEP)
	var p := _portrait_rect()
	_gold_frame(p.position.x, p.position.y, p.size.x, p.size.y, PANEL)
	if _figure != null:
		_blit_scaled(_figure, p.position.x + 3, p.position.y + 3, p.size.x - 6)

	_text(CLASS_NAMES.get(_hero_class, "ГЕРОЙ"), 50, 8, GOLD_HI)
	_text("УР %d" % level, 50, 20, GOLD)
	_text("%d ЗОЛОТА" % gold, 50, 32, TEXT_DIM)

	# здоровье
	_text_right("ЗД", GRID_W - 96, 8, TEXT_DIM)
	_bar(GRID_W - 88, 8, 76, 9, float(hp) / float(maxi(1, max_hp)), HP_A, HP_B)
	_text_right("%d/%d" % [hp, max_hp], GRID_W - 14, 10, TEXT)
	# опыт
	_text_right("ОП", GRID_W - 96, 21, TEXT_DIM)
	_bar(GRID_W - 88, 21, 76, 5, float(xp) / float(maxi(1, xp_max)), XP_A, XP_B)
	_text_right("%d/%d" % [xp, xp_max], GRID_W - 14, 30, TEXT_DIM)


# --- бой ----------------------------------------------------------------

func _draw_fight() -> void:
	var card := _enemy_card_rect()
	_gold_frame(card.position.x, card.position.y, card.size.x, card.size.y, PANEL)
	_text(enemy_name, card.position.x + 8, card.position.y + 7, TEXT)
	var lvl := "УР %d" % enemy_level
	_text_right(lvl, card.end.x - 8, card.position.y + 7, GOLD)
	_bar(card.position.x + 8, card.position.y + 22, card.size.x - 16, 9,
		float(enemy_hp) / float(maxi(1, enemy_max_hp)), HP_A, HP_B)
	var hp_label := "%d/%d" % [enemy_hp, enemy_max_hp]
	_text_center(hp_label, card.position.x + card.size.x / 2, card.position.y + 23, TEXT)

	var arena := _arena_rect()
	_gold_frame(arena.position.x, arena.position.y, arena.size.x, arena.size.y, ARENA_SKY)
	var ground := _ground_y()
	for y in range(ground, arena.end.y - 3):
		var k := float(y - ground) / float(maxi(1, arena.end.y - ground))
		_rect(arena.position.x + 3, y, arena.size.x - 6, 1, ARENA_GROUND.lerp(ARENA_GROUND_HI, k))

	# луна и звёзды
	var mx := arena.position.x + 168
	var my := arena.position.y + 30
	for j in range(-8, 9):
		for i in range(-8, 9):
			if i * i + j * j <= 46:
				_px(mx + i, my + j, Color8(238, 236, 214))
	for i in 30:
		var sx := arena.position.x + 6 + int(_hash01(i, 3.7) * float(arena.size.x - 12))
		var sy := arena.position.y + 6 + int(_hash01(i, 5.1) * 92.0)
		_px(sx, sy, Color8(140, 152, 186) if i % 3 else Color8(212, 220, 240))

	# дальний лес
	for i in range(0, arena.size.x - 6, 6):
		var hh := 7 + (i * 7) % 9
		var tx := arena.position.x + 3 + i
		for j in hh:
			var half := (j * 3) / hh
			for dx in range(-half, half + 1):
				_px(tx + dx, ground - 1 - j, Color8(15, 22, 32))
	for i in range(arena.position.x + 3, arena.end.x - 3):
		if (i * 7) % 5 == 0:
			_px(i, ground - 1, Color8(58, 82, 68))

	# тени
	_blob(arena.position.x + 56, ground, 15)
	_blob(arena.position.x + 172, ground, 17)

	# герой — фигура выбранного класса, покачивается
	if _figure != null:
		var bob := int(round(sin(_time * 2.2) * 1.0))
		var hh := 96
		var hx := arena.position.x + 10 + (34 - hh) / 2
		_blit_scaled(_figure, hx, ground - hh + 2 + bob, hh)

	# враг
	_draw_slime(arena.position.x + 172, ground)

	# числа урона
	for f in _floats:
		var a := clampf(f.z / 0.9, 0.0, 1.0)
		var c := GOLD_HI.lerp(TEXT_DIM, 1.0 - a)
		_text("%d" % int(f.w), int(f.x), int(f.y), c)

	var hit := _fight_button_rect()
	var gold_light := 0.6 + 0.4 * sin(_time * 3.0)
	_gold_frame(hit.position.x, hit.position.y, hit.size.x, hit.size.y,
		Color8(int(150 + 40 * gold_light), int(116 + 30 * gold_light), 48))
	_text_center("УДАР", hit.position.x + hit.size.x / 2, hit.position.y + 14, INK)

	var auto_r := _auto_rect()
	_gold_frame(auto_r.position.x, auto_r.position.y, auto_r.size.x, auto_r.size.y,
		PANEL_HI if auto_fight else PANEL)
	_text_center("АВТО", auto_r.position.x + auto_r.size.x / 2, auto_r.position.y + 14,
		GREEN if auto_fight else TEXT_DIM)

	_draw_log()


func _blob(cx: int, cy: int, r: int) -> void:
	for i in range(-r, r + 1):
		for j in range(0, 4):
			if (float(i * i) / float(r * r) + float(j * j) / 16.0) <= 1.0:
				_px(cx + i, cy - 1 + j, Color8(10, 14, 22))


func _draw_slime(x: int, y: int) -> void:
	var squash := 1.0 + 0.08 * sin(_time * 3.0)
	var rx := int(13 * squash)
	var ry := int(10 / squash)
	var body := SLIME if enemy_flash <= 0.0 else Color8(240, 246, 236)
	var body_dark := SLIME_DARK if enemy_flash <= 0.0 else Color8(200, 210, 200)
	for j in range(-ry, 2):
		var k := float(j + ry) / float(ry + 1)
		var half := int(rx * sqrt(maxf(0.0, 1.0 - pow(k - 1.0, 2.0))))
		for i in range(-half, half + 1):
			var nx := float(i) / float(maxi(1, half))
			_px(x + i, y + j, body_dark if (nx > 0.45 or j > -1) else body)
	for i in range(-6, -1):
		_px(x + i, y - ry + 3, SLIME_LIT if enemy_flash <= 0.0 else body)
	_px(x - 6, y - 6, EYE_WHITE)
	_px(x - 5, y - 6, EYE_WHITE)
	_px(x - 6, y - 5, EYE_DARK)
	_px(x + 4, y - 6, EYE_WHITE)
	_px(x + 5, y - 6, EYE_WHITE)
	_px(x + 5, y - 5, EYE_DARK)
	_px(x, y - 1, EYE_DARK)


func _draw_log() -> void:
	var r := _log_rect()
	_gold_frame(r.position.x, r.position.y, r.size.x, r.size.y, PANEL_DEEP)
	var shown: int = mini(3, _log.size())
	for i in shown:
		_text(_log[_log.size() - shown + i], r.position.x + 8, r.position.y + 7 + i * 11, TEXT_DIM)


# --- остальные вкладки --------------------------------------------------

func _draw_list(title: String, rows: Array, foot: String) -> void:
	var area := _rows_area()
	_gold_frame(area.position.x, area.position.y, area.size.x, area.size.y, PANEL)
	_text(title, area.position.x + 10, area.position.y + 8, GOLD_HI)
	for i in rows.size():
		var row: Array = rows[i]
		var y := area.position.y + 24 + i * 34
		_gold_frame(area.position.x + 6, y, area.size.x - 12, 30, PANEL_DEEP)
		_text(str(row[0]), area.position.x + 12, y + 5, TEXT)
		_text(str(row[1]), area.position.x + 12, y + 16, TEXT_DIM)
		if row.size() > 2:
			_bar(area.position.x + 128, y + 12, 84, 7, float(row[2]), GREEN, GREEN_DEEP)
			_text_right(str(row[3]), area.end.x - 12, y + 5, GOLD)
	_text(foot, area.position.x + 10, area.end.y - 14, TEXT_DIM)


func _draw_work() -> void:
	var jobs := [
		["ЛЕСОРУБ", "ДРЕВЕСИНА", 0.4, "10/25"],
		["РУДОКОП", "РУДА", 0.15, "3/20"],
		["РЫБАК", "РЫБА", 0.0, "0/15"],
	]
	_draw_list("РЕМЁСЛА", jobs, "РАБОТА ИДЁТ, ПОКА ТЫ ОФФЛАЙН")


func _draw_bag() -> void:
	var area := _rows_area()
	_gold_frame(area.position.x, area.position.y, area.size.x, area.size.y, PANEL)
	_text("СНАРЯЖЕНИЕ", area.position.x + 10, area.position.y + 8, GOLD_HI)
	var labels := ["МЕЧ", "ПЛАЩ", "", "", "", "", "", "", "", ""]
	var colors := [GOLD, GREEN, TEXT_DIM, TEXT_DIM, TEXT_DIM, TEXT_DIM, TEXT_DIM, TEXT_DIM,
		TEXT_DIM, TEXT_DIM]
	for i in 10:
		var cx := area.position.x + 10 + (i % 5) * 44
		var cy := area.position.y + 26 + (i / 5) * 44
		_gold_frame(cx, cy, 40, 40, PANEL_DEEP)
		if not str(labels[i]).is_empty():
			_text_center(labels[i], cx + 20, cy + 16, colors[i])
	_gold_frame(area.position.x + 6, area.position.y + 122, area.size.x - 12, 44, PANEL_DEEP)
	_text("МЕЧ СТРАЖА", area.position.x + 14, area.position.y + 130, TEXT)
	_text("УРОН 4-8", area.position.x + 14, area.position.y + 142, TEXT_DIM)
	_text("РЕДКОСТЬ: ОБЫЧНЫЙ", area.position.x + 14, area.position.y + 152, TEXT_DIM)
	_text("ВЫБЕРИ СЛОТ", area.position.x + 10, area.end.y - 14, TEXT_DIM)


func _draw_map() -> void:
	var area := _rows_area()
	_gold_frame(area.position.x, area.position.y, area.size.x, area.size.y, PANEL)
	_text("КАРТА МИРА", area.position.x + 10, area.position.y + 8, GOLD_HI)

	# карта: тёмный пергамент, река, ели, маркер
	var mx := area.position.x + 8
	var my := area.position.y + 22
	var mw := area.size.x - 16
	var mh := 132
	_gold_frame(mx, my, mw, mh, Color8(26, 24, 20))
	for i in mw - 6:
		var rx := mx + 3 + i
		var ry := my + 70 + int(sin(i * 0.12) * 12.0)
		for j in range(0, 6):
			_px(rx, ry + j, Color8(38, 52, 66))
	for i in range(10, mw - 10, 9):
		for j in range(14, 40, 7):
			var tx := mx + i + (j % 3)
			var ty := my + j
			_px(tx, ty, Color8(30, 42, 32))
			_px(tx, ty + 1, Color8(24, 34, 26))
			_px(tx + 1, ty, Color8(24, 34, 26))
	# маркер зоны
	var px := mx + 46
	var py := my + 44
	for j in range(0, 9):
		_px(px, py + j, GOLD_HI)
	_px(px - 1, py + 9, GOLD)
	_px(px + 1, py + 9, GOLD)
	for j in range(0, 3):
		for i in range(-3, 4):
			if absi(i) + j < 4:
				_px(px + i, py - 1 + j, GOLD)

	var zones := [
		["ТЁМНЫЙ ЛЕС", "УР 1-3", GREEN, "ОТКРЫТО"],
		["КАМЕННЫЙ БРОД", "УР 4-6", FRAME, "ЗАКРЫТО"],
		["ПЕПЕЛЬНАЯ ПУСТОШЬ", "УР 7-9", FRAME, "ЗАКРЫТО"],
	]
	for i in zones.size():
		var z: Array = zones[i]
		var y := my + mh + 8 + i * 32
		_gold_frame(area.position.x + 6, y, area.size.x - 12, 28, PANEL_DEEP)
		_text(str(z[0]), area.position.x + 12, y + 5, TEXT)
		_text(str(z[1]), area.position.x + 12, y + 16, TEXT_DIM)
		_text_right(str(z[3]), area.end.x - 12, y + 5, z[2])


func _draw_shop() -> void:
	var area := _rows_area()
	_gold_frame(area.position.x, area.position.y, area.size.x, area.size.y, PANEL)
	_text("ЛАВКА", area.position.x + 10, area.position.y + 8, GOLD_HI)
	var goods := [
		["ЗЕЛЬЕ ЛЕЧЕНИЯ", "+30 ЗДОРОВЬЯ", 25],
		["ТОЧИЛЬНЫЙ КАМЕНЬ", "+1 К УРОНУ", 60],
		["ФАКЕЛ", "СВЕТ В ПЕЩЕРЕ", 15],
		["КОЖАНЫЙ ДОСПЕХ", "+4 К ЗАЩИТЕ", 140],
	]
	for i in goods.size():
		var g: Array = goods[i]
		var y := area.position.y + 24 + i * 38
		_gold_frame(area.position.x + 6, y, area.size.x - 12, 34, PANEL_DEEP)
		_text(str(g[0]), area.position.x + 12, y + 6, TEXT)
		_text(str(g[1]), area.position.x + 12, y + 18, TEXT_DIM)
		_text_right("%d" % int(g[2]), area.end.x - 30, y + 10, GOLD)
		_px(area.end.x - 22, y + 12, GOLD)
		_px(area.end.x - 21, y + 11, GOLD_HI)
		_px(area.end.x - 20, y + 12, GOLD)


# --- футер --------------------------------------------------------------

func _draw_footer() -> void:
	_rect(0, FOOTER_Y, GRID_W, FOOTER_H, PANEL_DEEP)
	for i in GRID_W:
		_px(i, FOOTER_Y, FRAME_DARK)
	for i in TABS.size():
		var r := _tab_rect(i)
		var active := i == tab
		_gold_frame(r.position.x, r.position.y, r.size.x, r.size.y,
			PANEL_HI if active else PANEL)
		_draw_tab_icon(i, r.position.x + r.size.x / 2, r.position.y + 8, active)
		_text_center(TABS[i], r.position.x + r.size.x / 2, r.position.y + r.size.y - 13,
			GOLD_HI if active else TEXT_DIM)


func _draw_tab_icon(i: int, cx: int, y: int, active: bool) -> void:
	var c := GOLD_HI if active else TEXT_DIM
	match i:
		TAB_FIGHT:
			for k in 10:
				_px(cx + 4 - k, y + k, c)
			_px(cx - 2, y + 9, c)
			_px(cx + 1, y + 9, c)
			_px(cx + 2, y + 10, c)
		TAB_WORK:
			for k in 11:
				_px(cx, y + k, c)
			for k in range(-4, 5):
				_px(cx + k, y + 1 + absi(k) / 2, c)
		TAB_BAG:
			for j in 9:
				for k in 9:
					if j == 0 and (k == 0 or k == 8):
						continue
					_px(cx - 4 + k, y + 2 + j, c)
			for k in range(-2, 3):
				_px(cx + k, y, c)
		TAB_MAP:
			for j in 9:
				for k in 11:
					if (j + k) % 4 == 0:
						continue
					_px(cx - 5 + k, y + 1 + j, c)
			_px(cx + 2, y + 5, GOLD_HI if active else PANEL_DEEP)
		TAB_SHOP:
			for j in range(-4, 5):
				for k in range(-4, 5):
					var d := k * k + j * j
					if d <= 17 and d >= 5:
						_px(cx + k, y + 5 + j, c)
			_px(cx, y + 5, c)


# --- кадр ---------------------------------------------------------------

func _render() -> void:
	_rect(0, 0, GRID_W, GRID_H, PANEL)
	_draw_header()
	match tab:
		TAB_FIGHT:
			_draw_fight()
		TAB_WORK:
			_draw_work()
		TAB_BAG:
			_draw_bag()
		TAB_MAP:
			_draw_map()
		TAB_SHOP:
			_draw_shop()
	_draw_footer()
