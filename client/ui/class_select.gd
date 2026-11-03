class_name ClassSelect
extends Control
## Экран выбора класса при первом запуске.
##
## Рисуется в буфер 180×320 и увеличивается целочисленно — как заставка и HUD,
## поэтому портреты, рамки и шрифт остаются пиксельными.
## Выбор сохраняется в профиль (user://profile.cfg) и в настройку
## game/player/hero_class — заставка читает её при следующем запуске.

signal class_chosen(id: String)

const GRID_W := 180
const GRID_H := 320

const INK := Color8(5, 7, 14)
const PANEL := Color8(14, 17, 28)
const PANEL_HI := Color8(24, 29, 44)
const GOLD := Color8(212, 172, 84)
const GOLD_HI := Color8(255, 226, 148)
const GOLD_DEEP := Color8(122, 90, 38)
const TEXT := Color8(232, 236, 246)
const TEXT_DIM := Color8(140, 150, 174)
const HP_A := Color8(206, 74, 84)
const HP_B := Color8(136, 34, 50)
const MP_A := Color8(96, 172, 236)
const MP_B := Color8(42, 92, 168)
const ATK_A := Color8(236, 168, 72)
const ATK_B := Color8(150, 92, 34)
const DEF_A := Color8(140, 156, 190)
const DEF_B := Color8(74, 86, 116)

const PROFILE_PATH := "user://profile.cfg"
const HERO_CLASS_SETTING := "game/player/hero_class"

const PORTRAIT_W := 96

# id, имя, роль, описание, hp, mp, atk, def
const CLASSES := [
	["warrior", "ВОИН", "ТАНК", "ДЕРЖИТ УДАР, ЗАКРЫВАЕТ СОЮЗНИКОВ", 140, 20, 12, 16],
	["mage", "МАГ", "УРОН", "БЬЁТ ПО ПЛОЩАДИ, СЛАБ В БЛИЖНЕМ БОЮ", 80, 120, 18, 5],
	["duelist", "ДУЭЛЯНТ", "БЛИЖНИЙ БОЙ", "ДВЕ ШПАГИ, БЫСТРЫЕ СЕРИИ УДАРОВ", 100, 40, 16, 8],
	["rogue", "РАЗБОЙНИК", "КРИТ", "ЗАХОДИТ В СПИНУ И БЬЁТ БОЛЬНО", 90, 40, 19, 6],
	["cleric", "ЖРЕЦ", "ПОДДЕРЖКА", "ЛЕЧИТ СВОИХ И ВЫЖИГАЕТ НЕЖИТЬ", 95, 100, 9, 10],
	["paladin", "ПАЛАДИН", "ГИБРИД", "СВЕТ И СТАЛЬ: ДЕРЖИТ И ЛЕЧИТ", 130, 60, 13, 14],
	["ranger", "СЛЕДОПЫТ", "ДАЛЬНИЙ БОЙ", "ЛУК, ЛОВУШКИ И БЫСТРЫЕ НОГИ", 95, 50, 15, 8],
]

const PORTRAITS := {
	"warrior": preload("res://art/classes/portrait_warrior.png"),
	"mage": preload("res://art/classes/portrait_mage.png"),
	"duelist": preload("res://art/classes/portrait_duelist.png"),
	"rogue": preload("res://art/classes/portrait_rogue.png"),
	"cleric": preload("res://art/classes/portrait_cleric.png"),
	"paladin": preload("res://art/classes/portrait_paladin.png"),
	"ranger": preload("res://art/classes/portrait_ranger.png"),
}

var selected: int = 0
var _image: Image
var _texture: ImageTexture
var _time: float = 0.0
var _frame: int = 0
var _portraits: Dictionary = {}


func _ready() -> void:
	_image = Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	for id: String in PORTRAITS:
		var tex: Texture2D = PORTRAITS[id]
		var src: Image = tex.get_image()
		src.convert(Image.FORMAT_RGBA8)
		_portraits[id] = src
	selected = _saved_index()
	_render()


func _saved_index() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return 0
	var saved := str(cfg.get_value("hero", "class", "")).strip_edges().to_lower()
	if saved.is_empty():
		saved = str(ProjectSettings.get_setting(HERO_CLASS_SETTING, "")).strip_edges().to_lower()
	for i in CLASSES.size():
		if CLASSES[i][0] == saved:
			return i
	return 0


func _process(delta: float) -> void:
	_time += delta
	_frame += 1
	if _frame % 3 == 0:
		_render()
		_texture.update(_image)
		queue_redraw()
	_maybe_capture()


func _maybe_capture() -> void:
	if OS.get_environment("CLASS_CAPTURE") != "1" or _frame != 60:
		return
	var path := OS.get_environment("CLASS_CAPTURE_PATH")
	if path.is_empty():
		path = "user://class_select.png"
	var err := _image.save_png(path)
	print("class_select: снимок экрана выбора -> %s (%d)" % [path, err])


# --- ввод ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var grid := _to_grid(mb.position)
	for i in CLASSES.size():
		if _cell_rect(i).has_point(grid):
			if selected == i:
				_confirm()
			else:
				selected = i
				_render()
			return
	if _confirm_rect().has_point(grid):
		_confirm()


func _to_grid(pos: Vector2) -> Vector2i:
	var view := get_viewport_rect().size
	var scale := _screen_scale(view)
	var origin := ((view - Vector2(GRID_W, GRID_H) * scale) / 2.0).floor()
	return Vector2i(((pos - origin) / scale).floor())


func _confirm() -> void:
	var id: String = CLASSES[selected][0]
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("hero", "class", id)
	cfg.set_value("hero", "created", true)
	cfg.save(PROFILE_PATH)
	ProjectSettings.set_setting(HERO_CLASS_SETTING, id)
	ProjectSettings.save()
	print("class_select: выбран класс %s" % id)
	class_chosen.emit(id)
	get_tree().change_scene_to_file("res://main.tscn")


# --- геометрия ----------------------------------------------------------

func _cell_rect(i: int) -> Rect2i:
	var col := i % 2
	var row := i / 2
	return Rect2i(6 + col * 85, 42 + row * 62, 83, 58)


func _confirm_rect() -> Rect2i:
	return Rect2i(20, 262, 140, 26)


func _detail_rect() -> Rect2i:
	return Rect2i(6, 240, 168, 18)


# --- отрисовка ----------------------------------------------------------

func _screen_scale(view: Vector2) -> float:
	var s := floorf(minf(view.x / GRID_W, view.y / GRID_H))
	if s < 1.0:
		s = minf(view.x / GRID_W, view.y / GRID_H)
	return s


func _draw() -> void:
	var view := get_viewport_rect().size
	var scale := _screen_scale(view)
	var drawn := Vector2(GRID_W, GRID_H) * scale
	var offset := ((view - drawn) / 2.0).floor()
	draw_texture_rect(_texture, Rect2(offset, drawn), false)


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < GRID_W and y < GRID_H:
		_image.set_pixel(x, y, c)


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			_px(x + i, y + j, c)


func _frame_box(x: int, y: int, w: int, h: int, fill: Color, edge: Color, edge_hi: Color) -> void:
	_rect(x, y, w, h, fill)
	for i in w:
		_px(x + i, y, edge_hi)
		_px(x + i, y + h - 1, edge)
	for j in h:
		_px(x, y + j, edge_hi)
		_px(x + w - 1, y + j, edge)
	# золотые уголки: рамка читается как «дорогая», а не как обычная панель
	var corners := [
		Vector2i(x, y), Vector2i(x + w - 1, y),
		Vector2i(x, y + h - 1), Vector2i(x + w - 1, y + h - 1),
	]
	for c: Vector2i in corners:
		_px(c.x, c.y, GOLD_HI)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			_px(c.x + d.x, c.y + d.y, GOLD)


func _text(s: String, x: int, y: int, c: Color) -> void:
	PixelFont.draw(_image, s, x, y, c)


func _text_center(s: String, cx: int, y: int, c: Color) -> void:
	_text(s, cx - PixelFont.width(s) / 2, y, c)


func _blit(portrait: Image, x: int, y: int, size: int, tint: Color) -> void:
	var ratio := float(portrait.get_width()) / float(size)
	for j in size:
		for i in size:
			var sx := int(i * ratio)
			var sy := int(j * ratio)
			var c := portrait.get_pixel(sx, sy)
			if c.a < 0.5:
				continue
			_px(x + i, y + j, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, 1.0))


func _stat_bar(x: int, y: int, w: int, value: float, a: Color, b: Color) -> void:
	_rect(x, y, w, 3, INK)
	var fill := int(clampf(value, 0.0, 1.0) * float(w - 2))
	for i in fill:
		_px(x + 1 + i, y + 1, a.lerp(b, float(i) / maxf(1.0, float(w - 2))))


func _render() -> void:
	_rect(0, 0, GRID_W, GRID_H, PANEL)
	# мягкий градиент фона сверху вниз, чтобы не было плоского пятна
	for y in GRID_H:
		var k := float(y) / float(GRID_H)
		var shade := PANEL.lerp(INK, k * 0.55)
		for x in GRID_W:
			_px(x, y, shade)

	_text_center("ВЫБЕРИ КЛАСС", GRID_W / 2, 10, GOLD_HI)
	_text_center("ЛИЦО СКРЫТО ПОД ШЛЕМОМ ИЛИ КАПЮШОНОМ", GRID_W / 2, 22, TEXT_DIM)
	for i in 40:
		_px(GRID_W / 2 - 20 + i, 34, GOLD_DEEP)

	for i in CLASSES.size():
		_draw_cell(i)

	var info: Array = CLASSES[selected]
	_draw_detail(info)

	var r := _confirm_rect()
	var pulse := 0.75 + 0.25 * sin(_time * 3.0)
	_frame_box(r.position.x, r.position.y, r.size.x, r.size.y,
		PANEL_HI.lerp(GOLD_DEEP, 0.25 + 0.25 * pulse), GOLD, PANEL_HI)
	_text_center("НАЧАТЬ ИГРУ", GRID_W / 2, r.position.y + 10, GOLD_HI)


func _draw_cell(i: int) -> void:
	var info: Array = CLASSES[i]
	var r := _cell_rect(i)
	var is_sel := i == selected
	var fill: Color = PANEL_HI if is_sel else PANEL
	var edge: Color = GOLD if is_sel else Color8(52, 60, 84)
	var edge_hi: Color = GOLD_HI if is_sel else Color8(76, 86, 114)
	_frame_box(r.position.x, r.position.y, r.size.x, r.size.y, fill, edge, edge_hi)

	# портрет 40×40 слева в клетке
	var px := r.position.x + 3
	var py := r.position.y + 5
	var portrait: Image = _portraits.get(info[0])
	if portrait != null:
		var tint: Color = Color.WHITE if is_sel else Color8(196, 202, 220)
		_blit(portrait, px, py, 40, tint)
		if is_sel:
			for k in 40:
				_px(px + k, py - 1, GOLD_HI)
				_px(px + k, py + 40, GOLD_HI)
			for k in 40:
				_px(px - 1, py + k, GOLD_HI)
				_px(px + 40, py + k, GOLD_HI)

	_text(str(info[1]), px + 45, py + 1, GOLD_HI if is_sel else TEXT)
	_text(str(info[2]), px + 45, py + 10, TEXT_DIM)
	var hp_val := float(info[4]) / 140.0
	var atk_val := float(info[6]) / 19.0
	_text("ЗД", px + 45, py + 21, TEXT_DIM)
	_stat_bar(px + 56, py + 22, 24, hp_val, HP_A, HP_B)
	_text("АТ", px + 45, py + 29, TEXT_DIM)
	_stat_bar(px + 56, py + 30, 24, atk_val, ATK_A, ATK_B)

	if is_sel:
		var mark_y := r.end.y - 7
		_text_center("ВЫБРАН", r.position.x + r.size.x / 2, mark_y, GOLD_HI)
		for k in r.size.x - 8:
			_px(r.position.x + 4 + k, r.end.y - 1, GOLD_HI)


func _draw_detail(info: Array) -> void:
	var r := _detail_rect()
	_frame_box(r.position.x, r.position.y, r.size.x, r.size.y, PANEL, Color8(52, 60, 84),
		Color8(76, 86, 114))
	_text(str(info[3]), r.position.x + 5, r.position.y + 6, TEXT_DIM)
