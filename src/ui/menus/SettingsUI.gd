extends Control
class_name SettingsUI

signal settings_closed()

@onready var close_button: Button = $Panel/VBox/CloseRow/CloseBtn
@onready var main_volume_slider: HSlider = $Panel/VBox/MainVolumeRow/Slider
@onready var music_volume_slider: HSlider = $Panel/VBox/MusicVolumeRow/Slider
@onready var sfx_volume_slider: HSlider = $Panel/VBox/SFXVolumeRow/Slider

func _ready() -> void:
	hide()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if main_volume_slider:
		main_volume_slider.value_changed.connect(_on_main_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	_populate_sliders()

func _populate_sliders() -> void:
	if main_volume_slider:
		main_volume_slider.value = 1.0
	if music_volume_slider:
		music_volume_slider.value = 0.8
	if sfx_volume_slider:
		sfx_volume_slider.value = 1.0

func open() -> void:
	show()
	_populate_sliders()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = false
	settings_closed.emit()

func _on_close_pressed() -> void:
	close()

func _on_main_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_master_volume"):
		AudioManager.set_master_volume(value)
	print("[Settings] Master volume: %.0f%%" % (value * 100))

func _on_music_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_music_volume"):
		AudioManager.set_music_volume(value)
	print("[Settings] Music volume: %.0f%%" % (value * 100))

func _on_sfx_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_sfx_volume"):
		AudioManager.set_sfx_volume(value)
	print("[Settings] SFX volume: %.0f%%" % (value * 100))
