class_name PixelScene
extends Control
## Живой пиксельный загрузочный экран.
##
## Сцена рисуется в низком разрешении (120×214) попиксельно и растягивается
## nearest-фильтром, поэтому получается настоящий пиксель-арт, а не мыло.
## Каждый кадр перерисовывается: мерцают звёзды, дышит огонь, летят искры.
##
## Палитра и геометрия совпадают с tools/preview_boot.py — это превью
## генерируется той же математикой, поэтому картинку можно проверить без сборки.

signal finished_loading

const GRID_WIDTH := 120
const GRID_HEIGHT := 214

# --- палитра -------------------------------------------------------------
const SKY := [
	Color8(8, 11, 24), Color8(13, 18, 38), Color8(21, 27, 54),
	Color8(31, 35, 68), Color8(45, 43, 84),
]
const MOON := Color8(242, 238, 216)
const MOON_SHADE := Color8(206, 202, 178)
const STAR := [Color8(255, 255, 255), Color8(196, 214, 255), Color8(255, 236, 176)]
const RIDGE_FAR := Color8(25, 32, 60)
const RIDGE_NEAR := Color8(15, 20, 40)
const TREE := Color8(7, 9, 20)
const TREE_TIP := Color8(30, 40, 66)
const GROUND := Color8(9, 12, 24)
const GROUND_HI := Color8(16, 21, 38)
const GRASS := Color8(17, 25, 42)
const STONE := Color8(46, 50, 66)
const LOG_COL := Color8(62, 40, 26)
const LOG_DARK := Color8(34, 22, 15)
const FIRE := [
	Color8(188, 52, 18), Color8(238, 118, 30), Color8(255, 186, 62), Color8(255, 246, 190),
]
const EMBER := Color8(255, 158, 64)
const FLY := Color8(206, 255, 96)
const BAR_TROUGH := Color8(13, 17, 32)
const BAR_TROUGH_HI := Color8(21, 27, 48)
const BAR_EDGE := Color8(74, 92, 132)
const BAR_EDGE_DARK := Color8(26, 33, 52)
const FILL_A := Color8(92, 226, 146)
const FILL_B := Color8(52, 178, 166)
const FILL_HI := Color8(198, 255, 216)
const OUTLINE := Color8(4, 6, 10)

# --- древо и изба ---
const TREE_X := 72
const TREE_BASE := 124
const TREE_TOP := 28
const CANOPY_DARK := Color8(16, 40, 44)
const CANOPY := Color8(26, 68, 62)
const CANOPY_MID := Color8(40, 98, 76)
const CANOPY_LIT := Color8(78, 156, 100)
const CANOPY_HI := Color8(126, 200, 128)
const BARK_DARK := Color8(18, 20, 34)
const BARK := Color8(38, 34, 46)
const BARK_LIT := Color8(66, 56, 62)
const MOSS := Color8(46, 96, 70)
const CABIN_WALL := Color8(58, 44, 44)
const CABIN_WALL_LIT := Color8(92, 68, 56)
const CABIN_ROOF := Color8(34, 30, 44)
const CABIN_ROOF_LIT := Color8(58, 52, 70)
const WINDOW := Color8(255, 196, 96)
const WINDOW_GLOW := Color8(196, 128, 52)
const DUST := Color8(96, 124, 164)

const BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

# --- спрайты -------------------------------------------------------------

const RUNNER_SHEET: Texture2D = preload("res://art/runner.png")
const RUNNER_W := 20
const RUNNER_H := 24
const RUNNER_FRAMES := 6

# Класс героя. Пусто — обычный герой; иначе runner_<класс>.png из art/classes.
const HERO_CLASS_SETTING := "game/player/hero_class"
const CLASS_FRAME_W := 24
const CLASS_FRAME_H := 28
const CLASS_FRAMES := 6



var progress := 0.0
var loading := true
## Дошла ли анимация «финиш» до конца (бегун у края, полоска полная).
var animation_finished := false

var _image: Image
var _texture: ImageTexture
var _star_x: PackedInt32Array = PackedInt32Array()
var _star_y: PackedInt32Array = PackedInt32Array()
var _star_colors: Array[Color] = []
var _star_phase: PackedFloat32Array = PackedFloat32Array()
var _star_speed: PackedFloat32Array = PackedFloat32Array()
var _runner_frames: Array[Image] = []
var _runner_w := RUNNER_W
var _runner_h := RUNNER_H
var _runner_count := RUNNER_FRAMES
var _hero_class := ""
var _canopy: Array[Vector4i] = []
var _time := 0.0
var _done_at := -1.0
var _frame := 0
var _elapsed_since_frame := 0.0


var _diag_frames := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_image = Image.create_empty(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_generate_stars()
	_build_canopy()
	_load_runner()
	print("pixel_scene: палитра %d цветов, звёзд %d" % [SKY.size(), _star_x.size()])
	_render(0.0)


func _generate_stars() -> void:
	_star_x = PackedInt32Array()
	_star_y = PackedInt32Array()
	_star_colors = []
	_star_phase = PackedFloat32Array()
	_star_speed = PackedFloat32Array()
	for i in 96:
		_star_x.append(int(_hash01(i, 1.3) * GRID_WIDTH))
		_star_y.append(int(_hash01(i, 2.7) * _horizon() * 0.94))
		_star_colors.append(STAR[i % STAR.size()])
		_star_phase.append(_hash01(i, 4.1) * TAU)
		_star_speed.append(0.5 + _hash01(i, 5.9) * 2.2)


func _load_runner() -> void:
	_hero_class = str(ProjectSettings.get_setting(HERO_CLASS_SETTING, "")).strip_edges().to_lower()
	if not _hero_class.is_empty():
		var class_path := "res://art/classes/runner_%s.png" % _hero_class
		if ResourceLoader.exists(class_path):
			var class_sheet: Image = (load(class_path) as Texture2D).get_image()
			if class_sheet != null:
				class_sheet.convert(Image.FORMAT_RGBA8)
				_runner_w = CLASS_FRAME_W
				_runner_h = CLASS_FRAME_H
				_runner_count = CLASS_FRAMES
				for i in _runner_count:
					_runner_frames.append(
						class_sheet.get_region(Rect2i(i * _runner_w, 0, _runner_w, _runner_h))
					)
				print("pixel_scene: герой класса %s, %d кадров %dx%d" % [
					_hero_class, _runner_frames.size(), _runner_w, _runner_h
				])
				return
		push_warning("pixel_scene: нет спрайта класса %s, беру обычного героя" % _hero_class)

	var sheet: Image = RUNNER_SHEET.get_image()
	if sheet == null:
		push_error("pixel_scene: не удалось прочитать res://art/runner.png")
		return
	sheet.convert(Image.FORMAT_RGBA8)
	for i in RUNNER_FRAMES:
		_runner_frames.append(sheet.get_region(Rect2i(i * RUNNER_W, 0, RUNNER_W, RUNNER_H)))
	print("pixel_scene: спрайт героя %d кадров %dx%d" % [_runner_frames.size(), RUNNER_W, RUNNER_H])


func _process(delta: float) -> void:
	_time += delta
	_elapsed_since_frame += delta
	# 30 кадров в секунду: анимация плавная, а CPU не грузится
	if _elapsed_since_frame >= 1.0 / 30.0:
		_elapsed_since_frame = 0.0
		_frame += 1
		_render(_time)
		_texture.update(_image)
		queue_redraw()

	if not loading and _done_at < 0.0:
		_done_at = _time
	if _done_at > 0.0 and _time - _done_at > 0.45:
		_done_at = -1.0
		animation_finished = true
		finished_loading.emit()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if progress >= 0.999:
		loading = false


# --- геометрия -----------------------------------------------------------

func _horizon() -> int:
	return int(GRID_HEIGHT * 0.545)


func _ground_line() -> int:
	return int(GRID_HEIGHT * 0.605)


func _camp_xy() -> Vector2i:
	return Vector2i(int(GRID_WIDTH * 0.30), int(GRID_HEIGHT * 0.757))


func _bar_rect() -> Rect2i:
	var w := int(GRID_WIDTH * 0.84)
	var x := (GRID_WIDTH - w) / 2
	var h := maxi(7, int(GRID_HEIGHT * 0.033))
	var y := int(GRID_HEIGHT * 0.884)
	return Rect2i(x, y, w, h)


# --- утилиты -------------------------------------------------------------

func _hash01(n: int, salt: float) -> float:
	var x := sin(n * 12.9898 + salt * 78.233) * 43758.5453
	return x - floorf(x)


func _mix(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, clampf(k, 0.0, 1.0))


func _put(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
		return
	# буфер RGBA, чтобы в него можно было накладывать спрайт с прозрачностью
	_image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))


func _at(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
		return GROUND
	return _image.get_pixel(x, y)


func _rect(x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(x, y, color)


func _gradient(y0: int, y1: int, colors: Array) -> void:
	var steps := colors.size() - 1
	for y in range(y0, y1):
		var k: float = float(y - y0) / float(maxi(1, y1 - y0 - 1)) * float(steps)
		var lo := mini(steps - 1, int(k))
		var frac: float = k - float(lo)
		for x in GRID_WIDTH:
			var threshold: float = (float(BAYER[y % 4][x % 4]) + 0.5) / 16.0
			var c: Color = colors[lo] if frac <= threshold else colors[lo + 1]
			_put(x, y, c)


# --- отрисовка кадра -----------------------------------------------------

func _render(t: float) -> void:
	_diag_frames += 1
	if _diag_frames == 1:
		print("pixel_scene: первый кадр, сетка %dx%d" % [GRID_WIDTH, GRID_HEIGHT])
	_draw_sky()
	_draw_moon()
	_draw_stars(t)
	_draw_shooting_star(t)
	_draw_clouds(t)
	_draw_birds(t)
	_draw_ridges()
	_draw_treeline()
	_draw_ground()
	_draw_ground_details()
	_draw_yggdrasil(t)
	_draw_cabin()
	_draw_lantern()
	_draw_camp_light(t)
	_draw_camp(t)
	_draw_motes(t)
	_draw_fire(t)
	_draw_sparks(t)
	_draw_bar(t)
	_draw_runner(t)
	_draw_vignette()
	_maybe_capture()


func _draw_sky() -> void:
	_gradient(0, _horizon(), SKY)


func _draw_moon() -> void:
	var cx := int(GRID_WIDTH * 0.155)
	var cy := int(GRID_HEIGHT * 0.185)
	var r := maxi(7, int(GRID_WIDTH * 0.082))
	for y in range(cy - r - 2, cy + r + 3):
		for x in range(cx - r - 2, cx + r + 3):
			var d := sqrt(pow(x - cx, 2) + pow(y - cy, 2))
			if d <= r:
				_put(x, y, MOON)
			elif d <= r + 1 and _hash01(x * 13 + y * 7, 0.0) > 0.55:
				_put(x, y, _mix(SKY[4], MOON, 0.28))
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := float(x - cx) / r
			var dy := float(y - cy) / r
			if dx * dx + dy * dy > 1.0:
				continue
			if dx * 0.80 + dy * 0.45 > 0.74:
				_put(x, y, MOON_SHADE)
	for crater: Vector3 in [Vector3(-0.30, -0.16, 0.22), Vector3(0.16, 0.30, 0.16)]:
		var pcx: float = float(cx) + crater.x * r
		var pcy: float = float(cy) + crater.y * r
		var pr := maxf(1.0, crater.z * r)
		for y in range(int(pcy - pr) - 1, int(pcy + pr) + 2):
			for x in range(int(pcx - pr) - 1, int(pcx + pr) + 2):
				if pow(x - pcx, 2) + pow(y - pcy, 2) <= pr * pr:
					_put(x, y, MOON_SHADE)


func _draw_stars(t: float) -> void:
	for i in _star_x.size():
		var sx: int = _star_x[i]
		var sy: int = _star_y[i]
		var color: Color = _star_colors[i]
		var k: float = 0.30 + 0.70 * (0.5 + 0.5 * sin(t * _star_speed[i] + _star_phase[i]))
		_put(sx, sy, _mix(_mix(SKY[2], SKY[3], 0.6), color, k))
		if k > 0.88:
			_put(sx + 1, sy, _mix(SKY[3], color, 0.28))
			_put(sx - 1, sy, _mix(SKY[3], color, 0.28))
			_put(sx, sy + 1, _mix(SKY[3], color, 0.28))
			_put(sx, sy - 1, _mix(SKY[3], color, 0.28))


func _draw_shooting_star(t: float) -> void:
	var period := 11.0
	var u := fmod(t, period) / period
	if u > 0.14:
		return
	var k := u / 0.14
	var x0 := int(GRID_WIDTH * 0.15 + k * GRID_WIDTH * 0.6)
	var y0 := int(GRID_HEIGHT * 0.09 + k * GRID_HEIGHT * 0.11)
	for i in 8:
		var alpha := (1.0 - k * 0.75) * (1.0 - i / 8.0)
		_put(x0 - i, y0 - i / 2, _mix(SKY[2], Color.WHITE, alpha))


func _draw_ridges() -> void:
	var hz := _horizon()
	var gl := _ground_line()
	for x in GRID_WIDTH:
		var u := float(x) / GRID_WIDTH
		var peak := (0.55 + 0.5 * sin(u * 6.1 + 0.9)) * (0.55 + 0.45 * sin(u * 2.1 + 2.4))
		var top := hz - int(peak * GRID_HEIGHT * 0.095)
		for y in range(maxi(0, top), hz + 1):
			_put(x, y, RIDGE_FAR)
	for x in GRID_WIDTH:
		var u := float(x) / GRID_WIDTH
		var top := hz + int((0.45 + 0.35 * sin(u * 3.7 + 1.2)) * (gl - hz) * 0.75)
		for y in range(top, gl + 1):
			_put(x, y, RIDGE_NEAR)


func _draw_treeline() -> void:
	var gl := _ground_line()
	var i := -3
	while i < GRID_WIDTH + 3:
		var h := 8 + int(_hash01(i, 6.2) * 10)
		var cx := i + int(_hash01(i, 7.4) * 3)
		var max_half := 1.0 + h * 0.17
		for level in h:
			var y := gl - level
			var u := float(level) / float(h)
			var half := int((1.0 - u) * max_half)
			if level % 3 == 1 and half >= 1:
				half += 1  # лапы ярусами
			var col: Color = TREE
			if level % 3 == 1:
				col = TREE_TIP
			for x in range(cx - half, cx + half + 1):
				_put(x, y, col)
		_put(cx, gl + 1, _mix(TREE, LOG_DARK, 0.55))
		i += 5 + int(_hash01(i, 9.1) * 4)


func _draw_ground() -> void:
	var gl := _ground_line()
	for y in range(gl, GRID_HEIGHT):
		var k: float = float(y - gl) / float(maxi(1, GRID_HEIGHT - gl))
		for x in GRID_WIDTH:
			_put(x, y, _mix(GROUND, Color8(6, 8, 18), k * 0.75))
	for x in GRID_WIDTH:
		if _hash01(x, 10.4) > 0.45:
			_put(x, gl, GRASS)
			if _hash01(x, 11.2) > 0.8:
				_put(x, gl - 1, GRASS)
	for i in 90:
		var x := int(_hash01(i, 12.5) * GRID_WIDTH)
		var y := gl + 3 + int(_hash01(i, 13.7) * (GRID_HEIGHT - gl - 4))
		if _hash01(i, 14.9) > 0.72:
			_put(x, y, GROUND_HI)



# --- большое древо (Иггдрасиль) -----------------------------------------


func _sway(t: float, y: int, top: int, base: int) -> int:
	# у корней движения нет, макушку качает сильнее
	var k := maxf(0.0, float(base - y) / float(maxi(1, base - top)))
	return int(round(sin(t * 0.55 + y * 0.055) * 2.4 * pow(k, 1.3)))


func _build_canopy() -> void:
	_canopy = []
	var cores := [
		Vector3i(0, -26, 8), Vector3i(-14, -22, 9), Vector3i(14, -22, 9),
		Vector3i(-24, -10, 9), Vector3i(24, -12, 9), Vector3i(-30, 2, 8),
		Vector3i(30, 0, 8), Vector3i(-18, -2, 10), Vector3i(0, -6, 11),
		Vector3i(18, -4, 10), Vector3i(-10, 12, 10), Vector3i(10, 12, 10),
		Vector3i(0, 22, 9), Vector3i(-26, 14, 8), Vector3i(26, 14, 8),
		Vector3i(-34, -20, 6), Vector3i(34, -22, 6), Vector3i(-38, -4, 5),
		Vector3i(38, -6, 5),
	]
	for core in cores:
		var layer := 0
		if core.y >= 10:
			layer = 2
		elif core.y >= -8:
			layer = 1
		_canopy.append(Vector4i(TREE_X + core.x, 54 + core.y, core.z, layer))
	# мелкие кластеры по краю — рваный силуэт
	for i in 26:
		var a: float = _hash01(i, 1.7) * TAU
		var rr: float = 0.72 + _hash01(i, 2.9) * 0.38
		var dx: int = int(cos(a) * 31.0 * rr)
		var dy: int = int(sin(a) * 23.0 * rr) - 2
		_canopy.append(Vector4i(TREE_X + dx, 54 + dy, 3 + int(_hash01(i, 3.1) * 3.0), 2))


func _draw_yggdrasil(t: float) -> void:
	# --- ствол ---
	for y in range(78, TREE_BASE + 1):
		var k := float(y - 78) / float(TREE_BASE - 78)
		var half := int(2.2 + k * 4.6)
		var sx: int = TREE_X + _sway(t, y, TREE_TOP, TREE_BASE) / 4
		for x in range(sx - half, sx + half + 1):
			var col: Color = BARK
			if x <= sx - half:
				col = BARK_DARK
			elif x >= sx + half:
				col = BARK_LIT
			_put(x, y, col)
		if y % 9 == 0:
			_put(sx - 1, y, BARK_DARK)
		if y % 13 == 5:
			_put(sx + 1, y, BARK_DARK)
			_put(sx + 2, y, BARK_LIT)

	# --- корни ---
	for root: Vector2i in [Vector2i(-1, 11), Vector2i(1, 12), Vector2i(-1, 7), Vector2i(1, 7)]:
		for i in root.y:
			var x := TREE_X + root.x * (i + 2)
			var y := TREE_BASE - i / 3
			_put(x, y, BARK if i > 0 else BARK_DARK)
			_put(x, y + 1, BARK_DARK)
	for i in 14:
		var mx := TREE_X - 8 + int(_hash01(i, 6.1) * 16.0)
		var my := TREE_BASE - 1 + int(_hash01(i, 7.3) * 3.0)
		_put(mx, my, MOSS)

	# --- ветви, видные сквозь листву ---
	var branches: Array[Vector4i] = [
		Vector4i(0, 76, -16, -8), Vector4i(0, 82, 16, -6), Vector4i(0, 70, -6, -10),
	]
	for branch: Vector4i in branches:
		var steps: int = maxi(absi(branch.z), absi(branch.w))
		for s in steps:
			var x := TREE_X + branch.x + branch.z * s / steps
			var y := branch.y + branch.w * s / steps
			_put(x, y, BARK_DARK)
			_put(x + 1, y, BARK)

	# --- крона ---
	for layer in 3:
		var dark: Color = CANOPY_DARK
		var light: Color = CANOPY
		if layer == 1:
			dark = CANOPY
			light = CANOPY_MID
		elif layer == 2:
			dark = CANOPY_MID
			light = CANOPY_LIT
		for clump in _canopy:
			if clump.w != layer:
				continue
			var bx := clump.x
			var by := clump.y
			var r := clump.z
			for y in range(by - r - 1, by + r + 2):
				if y < TREE_TOP:
					continue
				var dxs := _sway(t, y, TREE_TOP, TREE_BASE)
				for x in range(bx - r - 1, bx + r + 2):
					var nx := float(x - bx) / float(r)
					var ny := float(y - by) / float(r)
					var d := nx * nx + ny * ny
					if d > 1.0:
						if d <= 1.45 and _hash01(x * 31 + y * 17, 4.7) > 0.62:
							_put(x + dxs, y, _mix(_at(x + dxs, y), dark, 0.6))
						continue
					if _hash01(x * 13 + y * 29, 8.3) > 0.955:
						continue  # просветы в листве
					var col: Color = dark
					if ny < -0.15 or (nx < -0.25 and ny < 0.25):
						col = light
					_put(x + dxs, y, col)

	# блики луны по листве
	for i in 18:
		var x := TREE_X - 30 + int(_hash01(i, 11.3) * 60.0)
		var y := TREE_TOP + 4 + int(_hash01(i, 12.7) * 22.0)
		_put(x, y, _mix(_at(x, y), CANOPY_HI, 0.35))

	# --- лианы ---
	for i in 4:
		var vx: int = [TREE_X - 30, TREE_X - 16, TREE_X + 16, TREE_X + 30][i]
		var length := 8 + int(_hash01(i + 40, 3.3) * 12.0)
		for j in length:
			var y := 76 + j
			var x := vx + _sway(t, y, TREE_TOP, TREE_BASE) / 2 + int(sin(j * 0.45 + i) * 1.3)
			_put(x, y, CANOPY_DARK if j % 3 else CANOPY)


func _draw_cabin() -> void:
	var x0 := 6
	var y0 := 138
	var w := 26
	var h := 22
	# брёвна
	for j in h:
		var y := y0 + j
		for i in w:
			var x := x0 + i
			var col: Color = CABIN_WALL
			if j % 3 == 2:
				col = Color8(40, 30, 32)
			if i >= w - 4:
				col = CABIN_WALL_LIT
			_put(x, y, col)
	# двускатная крыша
	for j in 9:
		var y := y0 - 9 + j
		var half := int(3.0 + j * 1.6)
		for x in range(x0 + w / 2 - half, x0 + w / 2 + half + 1):
			_put(x, y, CABIN_ROOF_LIT if j % 3 == 1 else CABIN_ROOF)
	for i in range(-3, 4):
		_put(x0 + w / 2 + i, y0 - 10, CABIN_ROOF_LIT)
	# труба и дым
	for j in 6:
		_put(x0 + 19, y0 - 14 + j, Color8(28, 26, 38))
	for j in 6:
		var sx := x0 + 20 + j / 3
		var sy := y0 - 22 - j
		_put(sx, sy, _mix(_at(sx, sy), Color8(120, 130, 150), 0.30 - j * 0.03))
	# окно
	for j in 5:
		for i in 5:
			_put(x0 + 5 + i, y0 + 6 + j, WINDOW if (i + j) % 5 else WINDOW_GLOW)
	for j in 5:
		_put(x0 + 7, y0 + 6 + j, Color8(70, 44, 30))
	_put(x0 + 5, y0 + 8, Color8(70, 44, 30))
	_put(x0 + 9, y0 + 8, Color8(70, 44, 30))
	# дверь
	for j in 9:
		for i in 4:
			_put(x0 + 17 + i, y0 + h - 9 + j, Color8(34, 26, 30))


func _draw_lantern() -> void:
	var x := 52
	for y in range(147, 160):
		_put(x, y, BARK_DARK)
		_put(x + 1, y, BARK)
	_put(x + 2, 147, BARK_DARK)
	_put(x + 2, 148, BARK_DARK)
	for j in 3:
		for i in 3:
			_put(x + 3 + i, 149 + j, WINDOW if (i + j) % 2 == 0 else WINDOW_GLOW)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				var gx := x + 4 + dx
				var gy := 150 + dy
				_put(gx, gy, _mix(_at(gx, gy), WINDOW, 0.09))


func _draw_clouds(t: float) -> void:
	for i in 4:
		var w: int = [18, 22, 14, 16][i]
		var x0: int = [2, 10, 34, 0][i]
		var y0: int = [34, 62, 22, 76][i]
		var drift := int(round(fmod(t * (1.1 + i * 0.3) + i * 37.0, 160.0))) - 20
		var x := (x0 + drift) % 150 - 15
		for j in w:
			var yy := y0 + int(sin(j * 0.5 + i) * 1.6)
			_put(x + j, yy, _mix(_at(x + j, yy), Color8(58, 66, 96), 0.20))
			_put(x + j, yy + 1, _mix(_at(x + j, yy + 1), Color8(44, 50, 74), 0.16))
		for j in range(2, w - 2):
			_put(x + j, y0 + 2, _mix(_at(x + j, y0 + 2), Color8(48, 56, 82), 0.12))


func _draw_birds(t: float) -> void:
	for i in 3:
		var x := 16 + int(fmod(t * 2.2 + i * 7.0, 70.0))
		var y := 24 + i * 4 + int(sin(t * 1.4 + i) * 2.0)
		_put(x, y, _mix(_at(x, y), Color8(120, 140, 180), 0.55))
		_put(x + 1, y - 1, _mix(_at(x + 1, y - 1), Color8(120, 140, 180), 0.45))
		_put(x + 2, y, _mix(_at(x + 2, y), Color8(120, 140, 180), 0.55))


func _draw_motes(t: float) -> void:
	for i in 16:
		var period := 7.0 + _hash01(i, 2.2) * 6.0
		var a := t / period * TAU + _hash01(i, 5.5) * TAU
		var cx := TREE_X + int(cos(a) * (14.0 + _hash01(i, 7.7) * 26.0))
		var cy := 58 + int(sin(a * 1.3) * (12.0 + _hash01(i, 9.9) * 18.0))
		var blink := 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.4 + i))
		_put(cx, cy, _mix(_at(cx, cy), FLY, blink))
		if blink > 0.85:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_put(cx + d.x, cy + d.y, _mix(_at(cx + d.x, cy + d.y), FLY, 0.25))


func _draw_ground_details() -> void:
	# тропинка от избы к костру
	for i in 52:
		var x := 30 + int(i * 0.55)
		var y := 160 + int(sin(i * 0.18) * 4.0) + i / 6
		_put(x, y, _mix(_at(x, y), Color8(36, 42, 62), 0.55))
		_put(x + 1, y, _mix(_at(x + 1, y), Color8(26, 30, 48), 0.40))
		if i % 7 == 0:
			_put(x, y + 1, _mix(_at(x, y + 1), Color8(26, 30, 48), 0.5))
	# камни
	var stones: Array[Vector2i] = [
		Vector2i(22, 172), Vector2i(58, 178), Vector2i(74, 168), Vector2i(96, 176), Vector2i(40, 186),
	]
	for stone: Vector2i in stones:
		_put(stone.x, stone.y, STONE)
		_put(stone.x + 1, stone.y, STONE)
		_put(stone.x, stone.y - 1, Color8(78, 86, 110))
	# грибы
	for mushroom: Vector2i in [Vector2i(16, 165), Vector2i(88, 160), Vector2i(104, 170)]:
		_put(mushroom.x, mushroom.y, Color8(150, 60, 60))
		_put(mushroom.x, mushroom.y - 1, Color8(196, 96, 82))
	# кусты
	var bushes: Array[Vector3i] = [
		Vector3i(88, 168, 5), Vector3i(100, 162, 4), Vector3i(66, 176, 4), Vector3i(108, 178, 5),
	]
	for bush: Vector3i in bushes:
		for y in range(bush.y - bush.z, bush.y + bush.z + 1):
			for x in range(bush.x - bush.z, bush.x + bush.z + 1):
				var dx := x - bush.x
				var dy := y - bush.y
				if dx * dx + dy * dy <= bush.z * bush.z and _hash01(x * 7 + y * 3, 5.5) > 0.15:
					_put(x, y, _mix(_at(x, y), Color8(18, 46, 40), 0.9 if (x + y) % 3 else 0.6))
		_put(bush.x, bush.y - bush.z, Color8(30, 66, 52))
	# трава
	for x in range(4, 118, 3):
		if _hash01(x, 8.4) > 0.55:
			var y := 150 + int(_hash01(x, 9.1) * 40.0)
			_put(x, y, Color8(28, 52, 44))
			_put(x, y - 1, Color8(36, 66, 52))


func _draw_camp_light(t: float) -> void:
	var camp := _camp_xy()
	var flicker := 0.95 + 0.05 * sin(t * 5.7) + 0.025 * sin(t * 12.3)
	for y in range(camp.y - 10, mini(GRID_HEIGHT, camp.y + 6)):
		for x in range(camp.x - 26, camp.x + 27):
			var d := sqrt(pow((x - camp.x) * 0.85, 2) + pow((y - camp.y) * 2.0, 2)) / (26.0 * flicker)
			if d >= 1.0:
				continue
			var k := pow(1.0 - d, 2.0)
			var band := 0.0
			if k >= 0.72:
				band = 0.66
			elif k >= 0.42:
				band = 0.48
			elif k >= 0.12:
				band = 0.26
			if band <= 0.0:
				continue
			_put(x, y, _mix(_at(x, y), Color8(146, 84, 40), band))


func _draw_camp(t: float) -> void:
	var camp := _camp_xy()

	var flicker := 0.5 + 0.5 * sin(t * 3.1)  # лёгкое дрожание света на камнях
	# камни вокруг костра
	for dx in [-9, -7, -5, 5, 7, 9]:
		_put(camp.x + dx, camp.y + 2, STONE)
		if absi(dx) <= 7:
			_put(camp.x + dx, camp.y + 1, _mix(STONE, Color8(146, 84, 40), 0.10 + 0.12 * flicker))

	# поленья
	for i in range(-5, 6):
		var log_col: Color = LOG_COL if i % 3 else _mix(LOG_COL, Color8(255, 150, 60), 0.15)
		_put(camp.x + i, camp.y, log_col)
		_put(camp.x - i, camp.y - 1, LOG_COL)
	for i in [-6, 6]:
		_put(camp.x + i, camp.y - 1, LOG_DARK)
		_put(camp.x + i, camp.y, LOG_DARK)


func _draw_fire(t: float) -> void:
	var camp := _camp_xy()
	var tongues: Array[Vector3] = [
		Vector3(0, 15, 1.7),
		Vector3(-2, 10, 1.0),
		Vector3(2, 9, 1.0),
		Vector3(-4, 6, 0.75),
		Vector3(4, 5, 0.7),
	]
	for tongue: Vector3 in tongues:
		var flick: float = 0.62 + 0.38 * sin(t * (5.5 + absf(tongue.x) * 0.7) + tongue.x * 1.9)
		var h: int = maxi(1, int(tongue.y * flick))
		for y in h:
			var k: float = float(y) / maxf(1.0, h - 1.0)
			var half: int = int((1.0 - k) * tongue.z * 1.35)
			for x in range(-half, half + 1):
				var col: Color
				if k > 0.88:
					col = FIRE[3]
				elif k > 0.60:
					col = FIRE[2]
				elif k > 0.30:
					col = FIRE[1]
				else:
					col = FIRE[0]
				_put(camp.x + int(tongue.x) + x, camp.y - 1 - y, col)


func _draw_sparks(t: float) -> void:
	var camp := _camp_xy()
	for i in 9:
		var period := 1.5 + _hash01(i, 16.1) * 1.9
		var u := fmod(t / period + _hash01(i, 17.3), 1.0)
		var x := camp.x + int((_hash01(i, 18.7) - 0.5) * 8.0 * u)
		var y := camp.y - 5 - int(u * 24.0)
		var col := _mix(EMBER, FIRE[0], u)
		_put(x, y, _mix(GROUND, col, 1.0 - u * 0.6))


func _draw_bar(t: float) -> void:
	var bar := _bar_rect()
	_rect(bar.position.x - 2, bar.position.y - 2, bar.end.x + 1, bar.end.y + 1, BAR_EDGE_DARK)
	_rect(bar.position.x - 1, bar.position.y - 1, bar.end.x, bar.end.y, BAR_EDGE)
	for yy in range(bar.position.y, bar.end.y):
		var k: float = float(yy - bar.position.y) / float(maxi(1, bar.size.y - 1))
		_rect(bar.position.x, yy, bar.end.x - 1, yy, _mix(BAR_TROUGH_HI, BAR_TROUGH, k))

	var fill_w := int((bar.size.x - 2) * clampf(progress, 0.0, 1.0))
	for i in fill_w:
		var base: Color = _mix(FILL_A, FILL_B, float(i) / float(maxi(1, bar.size.x - 3)))
		for yy in range(bar.position.y + 1, bar.end.y - 1):
			var v: float = float(yy - bar.position.y - 1) / float(maxi(1, bar.size.y - 3))
			_put(bar.position.x + 1 + i, yy, _mix(base, Color.WHITE, 0.20 * pow(1.0 - v, 2)))
	if fill_w > 8:
		var phase := int(fmod(t * 34.0, fill_w + 16.0)) - 8
		for off in 5:
			var bx := bar.position.x + 1 + phase - off
			if bx >= bar.position.x + 1 and bx < bar.position.x + 1 + fill_w:
				for yy in range(bar.position.y + 1, bar.end.y - 1):
					_put(bx, yy, _mix(FILL_HI, FILL_A, off / 5.0))
	if fill_w > 0 and fill_w < bar.size.x - 2:
		for yy in range(bar.position.y + 1, bar.end.y - 1):
			_put(bar.position.x + 1 + fill_w, yy, FILL_HI)


func _draw_runner(t: float) -> void:
	var bar := _bar_rect()
	var fill_w := int((bar.size.x - 2) * clampf(progress, 0.0, 1.0))
	var moving := progress < 0.999
	# 12 кадров в секунду: цикл бега целиком проходится за 0.5 с
	var index := int(t * 12.0) % RUNNER_FRAMES if moving else 0
	# не даём герою выйти за полоску и за экран на финише
	var px0 := clampi(bar.position.x + 1 + fill_w - RUNNER_W / 2, 2, GRID_WIDTH - RUNNER_W - 2)
	var py0 := bar.position.y - RUNNER_H + 1
	var index := int(t * 12.0) % _runner_count if moving else 0
	# не даём герою выйти за полоску и за экран на финише
	var px0 := clampi(bar.position.x + 1 + fill_w - _runner_w / 2, 2, GRID_WIDTH - _runner_w - 2)
	var py0 := bar.position.y - _runner_h + 1

	# пыль из-под ног
	for i in 4:
		var k := _hash01(int(t * 12.0) + i, 23.1)
		_put(px0 - 1 - i * 2 - int(k * 3.0), bar.position.y - 1 - int(k * 2.0),
			_mix(GROUND, DUST, 0.5 - i * 0.1))

	if _runner_frames.is_empty():
		return
	var sprite: Image = _runner_frames[mini(index, _runner_frames.size() - 1)]
	_image.blend_rect(sprite, Rect2i(0, 0, RUNNER_W, RUNNER_H), Vector2i(px0, py0))
	_image.blend_rect(sprite, Rect2i(0, 0, _runner_w, _runner_h), Vector2i(px0, py0))


func _draw_vignette() -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var dx := absf(x - GRID_WIDTH / 2.0) / (GRID_WIDTH / 2.0)
			var dy := absf(y - GRID_HEIGHT / 2.0) / (GRID_HEIGHT / 2.0)
			var d := minf(1.0, pow(dx * dx * 0.55 + dy * dy * 0.45, 1.4))
			if d < 0.6:
				continue
			_put(x, y, _mix(_at(x, y), Color8(2, 3, 7), (d - 0.6) / 0.4 * 0.5))


# --- отрисовка на экране -------------------------------------------------

func _maybe_capture() -> void:
	if OS.get_environment("BOOT_CAPTURE") != "1":
		return
	# три момента цикла бега — по ним видно, что кадры сменяются
	const CAPTURE_AT := [38, 42, 46]
	var shot := CAPTURE_AT.find(_diag_frames)
	if shot < 0:
		return
	var base := OS.get_environment("BOOT_CAPTURE_PATH")
	if base.is_empty():
		base = "user://boot_capture.png"
	var path := base
	if shot > 0:
		path = base.get_basename() + "_%d.png" % shot
	var err := _image.save_png(path)
	print("pixel_scene: снимок %d -> %s (%d)" % [shot, path, err])


func _draw() -> void:
	if _texture == null:
		return
	var view := get_viewport_rect().size
	# целочисленный масштаб: пиксели остаются пикселями, без мыла.
	# Если сетка больше экрана (широкий ландшафт на маленьком экране),
	# разрешаем дробный масштаб, иначе картинка не влезет.
	var scale := floorf(minf(view.x / GRID_WIDTH, view.y / GRID_HEIGHT))
	if scale < 1.0:
		scale = minf(view.x / GRID_WIDTH, view.y / GRID_HEIGHT)
	var drawn := Vector2(GRID_WIDTH * scale, GRID_HEIGHT * scale)
	var offset := ((view - drawn) / 2.0).floor()
	draw_texture_rect(_texture, Rect2(offset, drawn), false)
