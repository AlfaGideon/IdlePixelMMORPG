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
const TENT := Color8(40, 36, 60)
const TENT_SHADE := Color8(24, 21, 38)
const GUARD := Color8(36, 44, 70)
const GUARD_LIT := Color8(168, 96, 44)
const BAR_TROUGH := Color8(13, 17, 32)
const BAR_TROUGH_HI := Color8(21, 27, 48)
const BAR_EDGE := Color8(74, 92, 132)
const BAR_EDGE_DARK := Color8(26, 33, 52)
const FILL_A := Color8(92, 226, 146)
const FILL_B := Color8(52, 178, 166)
const FILL_HI := Color8(198, 255, 216)
const CLOAK := Color8(44, 164, 116)
const CLOAK_DARK := Color8(26, 104, 78)
const CLOAK_LIT := Color8(120, 226, 172)
const SKIN := Color8(233, 191, 150)
const SKIN_SHADE := Color8(188, 140, 104)
const BOOT_HI := Color8(74, 82, 104)
const OUTLINE := Color8(4, 6, 10)
const DUST := Color8(96, 124, 164)

const BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

# --- спрайты -------------------------------------------------------------
const RUNNER_FRAMES := [
	[
		"...DDDD.....",
		"..DDDDDD....",
		"..DDSSDD....",
		"..DDSSDD....",
		"...DDDD.....",
		"..CCCCCC....",
		".CCCCCCCC...",
		".CCCCCCCCL..",
		".CCCCCCCCL..",
		"..CCCCCCC...",
		"..CCCCCC....",
		"..CC..CC....",
		".BBB..BBB...",
		".BB....BB...",
	],
	[
		"...DDDD.....",
		"..DDDDDD....",
		"..DDSSDD....",
		"..DDSSDD....",
		"...DDDD.....",
		"..CCCCCC....",
		".CCCCCCCC...",
		".CCCCCCCCL..",
		".CCCCCCCCL..",
		"..CCCCCCC...",
		"..CCCCCC....",
		"...CCCC.....",
		"...BBBB.....",
		"..BB..BB....",
	],
	[
		"...DDDD.....",
		"..DDDDDD....",
		"..DDSSDD....",
		"..DDSSDD....",
		"...DDDD.....",
		"..CCCCCC....",
		".CCCCCCCC...",
		"LCCCCCCCC...",
		"LCCCCCCCC...",
		"..CCCCCCC...",
		"..CCCCCC....",
		"..CC..CC....",
		".BBB..BBB...",
		"..BB..BB....",
	],
	[
		"...DDDD.....",
		"..DDDDDD....",
		"..DDSSDD....",
		"..DDSSDD....",
		"...DDDD.....",
		"..CCCCCC....",
		".CCCCCCCC...",
		".CCCCCCCCL..",
		".CCCCCCCCL..",
		"..CCCCCCC...",
		"..CCCCCC....",
		"..CC.CC.....",
		".BBB.BBB....",
		".BB...BB....",
	],
]

const GUARD_FRAME := [
	"..####..",
	".#....#.",
	".#.##.#.",
	".#....#.",
	"..####..",
	".######.",
	"########",
	"########",
	"########",
	".######.",
	"..####..",
	"..#..#..",
	".##..##.",
]

const TENT_W := 15
const TENT_H := 9

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
var _time := 0.0
var _done_at := -1.0
var _frame := 0
var _elapsed_since_frame := 0.0


var _diag_frames := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_image = Image.create_empty(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGB8)
	_texture = ImageTexture.create_from_image(_image)
	_generate_stars()
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
	_image.set_pixel(x, y, color)


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
	_draw_ridges()
	_draw_treeline()
	_draw_ground()
	_draw_camp_light(t)
	_draw_camp(t)
	_draw_fireflies(t)
	_draw_fire(t)
	_draw_sparks(t)
	_draw_bar(t)
	_draw_runner(t)
	_draw_vignette()
	_maybe_capture()


func _draw_sky() -> void:
	_gradient(0, _horizon(), SKY)


func _draw_moon() -> void:
	var cx := int(GRID_WIDTH * 0.815)
	var cy := int(GRID_HEIGHT * 0.163)
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

	# палатка слева: сплошной полог, вход в тени
	var tx := camp.x - 30
	var ty := camp.y - TENT_H + 2
	for j in TENT_H:
		var u := float(j) / float(TENT_H - 1)
		var half := int(u * (TENT_W * 0.5))
		for i in range(-half, half + 1):
			var col: Color = TENT
			if i <= -half + 2:
				col = TENT_SHADE
			elif i >= half - 1:
				col = _mix(TENT, Color8(150, 120, 96), 0.20)
			_put(tx + TENT_W / 2 + i, ty + j, col)
	for j in range(TENT_H - 5, TENT_H):
		for i in range(-1, 2):
			_put(tx + TENT_W / 2 + i, ty + j, _mix(TENT_SHADE, OUTLINE, 0.45))
	_put(tx + TENT_W / 2, ty - 1, _mix(TENT, LOG_DARK, 0.5))

	# камни
	for dx in [-9, -7, -5, 5, 7, 9]:
		_put(camp.x + dx, camp.y + 2, STONE)
		if absi(dx) <= 7:
			_put(camp.x + dx, camp.y + 1, _mix(STONE, GROUND, 0.35))

	# поленья
	for i in range(-5, 6):
		var log_col: Color = LOG_COL if i % 3 else _mix(LOG_COL, Color8(255, 150, 60), 0.15)
		_put(camp.x + i, camp.y, log_col)
		_put(camp.x - i, camp.y - 1, LOG_COL)
	for i in [-6, 6]:
		_put(camp.x + i, camp.y - 1, LOG_DARK)
		_put(camp.x + i, camp.y, LOG_DARK)

	# страж справа
	var bob := 1 if sin(t * 1.4) > 0.7 else 0
	var hx := camp.x + 11
	var hy := camp.y - GUARD_FRAME.size() + 3 + bob
	for j in GUARD_FRAME.size():
		var row: String = GUARD_FRAME[j]
		for i in row.length():
			if row[i] != "#":
				continue
			var col: Color = GUARD
			if i <= 2:
				col = _mix(GUARD, GUARD_LIT, 0.5)
			elif i > 4:
				col = _mix(GUARD, OUTLINE, 0.5)
			_put(hx + i, hy + j, col)
	var spear_x := hx + GUARD_FRAME[0].length() + 1
	for j in range(-2, GUARD_FRAME.size() + 2):
		_put(spear_x, hy + j, Color8(92, 104, 138))
	_put(spear_x, hy - 3, _mix(GUARD, Color8(206, 216, 236), 0.7))


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


func _draw_fireflies(t: float) -> void:
	var gl := _ground_line()
	for i in 10:
		var bx := int(GRID_WIDTH * (0.06 + _hash01(i, 19.3) * 0.88))
		var by := gl + int(_hash01(i, 20.9) * (GRID_HEIGHT - gl) * 0.42)
		var x := bx + int(sin(t * (0.6 + _hash01(i, 21.7)) + i) * 6.0)
		var y := by + int(cos(t * (0.45 + _hash01(i, 22.3)) + i * 1.7) * 3.0)
		var k := 0.2 + 0.8 * (0.5 + 0.5 * sin(t * 1.7 + i * 1.31))
		_put(x, y, _mix(GROUND, FLY, k))
		if k > 0.82:
			_put(x, y - 1, _mix(GROUND, FLY, k * 0.3))


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
	var frame := int(t * 9.0) % 4 if moving else 0
	var sprite: Array = RUNNER_FRAMES[frame]
	var sw: int = sprite[0].length()
	var sh: int = sprite.size()
	var bob := 1 if (moving and (frame == 0 or frame == 2)) else 0
	# не даём герою выйти за полоску и за экран на финише
	var px0 := clampi(bar.position.x + 1 + fill_w - sw / 2, 2, GRID_WIDTH - sw - 2)
	var py0 := bar.position.y - sh + 2 + bob

	for i in 3:
		var k := _hash01(int(t * 9.0) + i, 23.1)
		_put(px0 - 2 - i * 2 - int(k * 3.0), bar.position.y - 1 - int(k * 2.0),
			_mix(GROUND, DUST, 0.45 - i * 0.1))

	# обводка, чтобы силуэт отделялся от земли
	for j in sh:
		var row: String = sprite[j]
		for i in row.length():
			if row[i] == ".":
				continue
			_put(px0 + i, py0 + j - 1, OUTLINE)
			_put(px0 + i, py0 + j + 1, OUTLINE)
			_put(px0 + i - 1, py0 + j, OUTLINE)
			_put(px0 + i + 1, py0 + j, OUTLINE)

	for j in sh:
		var row: String = sprite[j]
		for i in row.length():
			var ch := row[i]
			if ch == ".":
				continue
			var col: Color
			match ch:
				"D":
					col = CLOAK_DARK
				"S":
					col = SKIN
				"C":
					col = CLOAK_LIT if i <= 4 else CLOAK
				"L":
					col = SKIN_SHADE
				_:
					col = BOOT_HI
			_put(px0 + i, py0 + j, col)


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
	if OS.get_environment("BOOT_CAPTURE") != "1" or _diag_frames != 45:
		return
	var path := OS.get_environment("BOOT_CAPTURE_PATH")
	if path.is_empty():
		path = "user://boot_capture.png"
	var err := _image.save_png(path)
	print("pixel_scene: снимок кадра -> %s (%d)" % [path, err])


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
