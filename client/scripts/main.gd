extends Control
## Точка входа клиента IdlePixelMMORPG.
##
## Что делает этот скелет:
##   * собирает HUD из контейнеров (без ручных координат);
##   * сам переключает раскладку портрет ⇄ ландшафт по размеру окна;
##   * учитывает безопасную область экрана (вырез, «остров», жесты);
##   * печатает состояние раскладки — это проверка dynamic orientation.
##
## Дальше сюда придёт роутинг экранов (camp / hero / battle / map / market / chat)
## и сетевой слой, см. docs/PLAN.md §4.

const BASE_MARGIN := 16

var _margin: MarginContainer
var _columns: BoxContainer
var _mode: Label
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _build() -> void:
	var background := ColorRect.new()
	background.color = UIKit.COLOR_BG
	add_child(background)
	UIKit.stretch(background)

	_margin = MarginContainer.new()
	add_child(_margin)
	UIKit.stretch(_margin)

	# Внутри MarginContainer координаты считает контейнер, якоря не нужны.
	_columns = UIKit.box(20)
	_margin.add_child(_columns)

	var card := UIKit.panel(UIKit.COLOR_CARD, 18, 28)
	_columns.add_child(UIKit.expand(card))

	var card_stack := UIKit.vbox(16)
	card.add_child(card_stack)

	card_stack.add_child(UIKit.label("IdlePixelMMORPG", 56, UIKit.COLOR_TEXT))
	card_stack.add_child(UIKit.label("Godot 4 skeleton", 28, UIKit.COLOR_MUTED))
	card_stack.add_child(UIKit.label(
		"Классы, монстры и уровни — следующий шаг", 24, UIKit.COLOR_MUTED))

	_mode = UIKit.label("ПОРТРЕТ", 26, UIKit.COLOR_ACCENT)
	card_stack.add_child(_mode)

	var status_panel := UIKit.panel(UIKit.COLOR_CARD, 14, 16)
	_columns.add_child(UIKit.fill_horizontal(status_panel))

	_status = UIKit.label("", 24, UIKit.COLOR_MUTED)
	status_panel.add_child(_status)


func _relayout() -> void:
	var viewport_size := get_viewport_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	_columns.vertical = portrait

	var insets := _safe_insets()
	_margin.add_theme_constant_override("margin_left", maxi(BASE_MARGIN, insets.x))
	_margin.add_theme_constant_override("margin_top", maxi(BASE_MARGIN, insets.y))
	_margin.add_theme_constant_override("margin_right", maxi(BASE_MARGIN, insets.z))
	_margin.add_theme_constant_override("margin_bottom", maxi(BASE_MARGIN, insets.w))

	_mode.text = "ПОРТРЕТ" if portrait else "ЛАНДШАФТ"
	_status.text = "%s · %d×%d · отступы l%d t%d r%d b%d" % [
		"portrait" if portrait else "landscape",
		int(viewport_size.x), int(viewport_size.y),
		insets.x, insets.y, insets.z, insets.w,
	]

	print("[main] %s %dx%d insets=%s" % [
		"portrait" if portrait else "landscape",
		int(viewport_size.x), int(viewport_size.y), str(insets)])


## Безопасные отступы в единицах дизайна (left, top, right, bottom).
## DisplayServer отдаёт их в физических пикселях экрана, поэтому масштабируем
## под текущий stretch-коэффициент вьюпорта.
func _safe_insets() -> Vector4i:
	if not OS.has_feature("mobile"):
		return Vector4i.ZERO

	var window_size := DisplayServer.window_get_size()
	var viewport_size := get_viewport_rect().size
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector4i.ZERO

	var safe_area := DisplayServer.get_display_safe_area()
	var scale_x := viewport_size.x / float(window_size.x)
	var scale_y := viewport_size.y / float(window_size.y)

	return Vector4i(
		int(maxf(safe_area.position.x, 0.0) * scale_x),
		int(maxf(safe_area.position.y, 0.0) * scale_y),
		int(maxf(window_size.x - safe_area.end.x, 0.0) * scale_x),
		int(maxf(window_size.y - safe_area.end.y, 0.0) * scale_y),
	)
