extends GutTest


func test_project_smoke() -> void:
	var player_scene: PackedScene = load("res://src/entities/player/Player.tscn")
	assert_not_null(player_scene, "Player scene should load under GUT")
