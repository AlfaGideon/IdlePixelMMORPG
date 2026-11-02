class_name UIKit
extends RefCounted
## Минимальный набор хелперов для UI.
##
## В Godot раскладку считают контейнеры (BoxContainer, MarginContainer,
## PanelContainer), поэтому здесь только фабрики узлов с единым стилем.
## Экраны описываются как деревья контейнеров — это и есть замена
## самописной layout-библиотеке, которая была бы нужна в других движках.

const FONT_PATH := "res://assets/fonts/SourceSansPro-Semibold.ttf"

const COLOR_BG := Color("#0d0f1c")
const COLOR_CARD := Color("#1c2233")
const COLOR_TEXT := Color("#f2e8d8")
const COLOR_MUTED := Color("#8fa3bf")
const COLOR_ACCENT := Color("#6ee7a8")


static func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	var font: Font = load(FONT_PATH) as Font
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func panel(bg_color: Color, radius: int, padding: int) -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	node.add_theme_stylebox_override("panel", style)
	return node


static func box(separation: int) -> BoxContainer:
	var node := BoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.alignment = BoxContainer.ALIGNMENT_CENTER
	return node


static func vbox(separation: int) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.alignment = BoxContainer.ALIGNMENT_CENTER
	return node


static func spacer(min_size: Vector2) -> Control:
	var node := Control.new()
	node.custom_minimum_size = min_size
	return node


static func expand(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control


static func fill_horizontal(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


static func stretch(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control
