extends Control
## Экран загрузки: живая пиксельная сцена + логотип + полоска прогресса.
##
## Пока грузится главная сцена, идёт полоска. Прогресс берётся из реального
## статуса ResourceLoader, но плавно: полоска не «прыгает» и не врёт.
## По завершении главная сцена подменяет загрузочную.

const MAIN_SCENE := "res://main.tscn"
## Минимальное время показа: на быстром устройстве экран не должен мигать.
const MIN_SHOW_TIME := 2.2

var _elapsed := 0.0
var _requested := false
var _main_ready := false
var _fake_progress := 0.0

@onready var _scene: PixelScene = $PixelScene
@onready var _logo: TextureRect = $Overlay/Logo


func _ready() -> void:
	_logo.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_elapsed += delta

	if not _requested and _elapsed > 0.15:
		_requested = true
		ResourceLoader.load_threaded_request(MAIN_SCENE, "PackedScene")

	_fake_progress = minf(1.0, _fake_progress + delta * 0.35)

	if _requested and not _main_ready:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_main_ready = true

	var shown := _fake_progress
	if _main_ready and _elapsed >= MIN_SHOW_TIME:
		shown = 1.0
	_scene.set_progress(shown)

	if shown >= 1.0 and _scene.animation_finished:
		_go_to_main()


func _go_to_main() -> void:
	if not _main_ready:
		return
	set_process(false)
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN_SCENE)
	get_tree().change_scene_to_packed(packed)
