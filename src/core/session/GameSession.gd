extends Node

## Owns mutable systems whose lifetime is one play session.
## New session-scoped systems should be added here instead of becoming Autoloads.

const SeasonSystemScript := preload("res://src/core/time/SeasonSystem.gd")
const WeatherSystemScript := preload("res://src/core/weather/WeatherSystem.gd")

var season: Node
var weather: Node


func _enter_tree() -> void:
	season = SeasonSystemScript.new()
	season.name = "SeasonSystem"
	add_child(season)

	weather = WeatherSystemScript.new()
	weather.name = "WeatherSystem"
	add_child(weather)


func _ready() -> void:
	print("[GameSession] Initialized")


func reset() -> void:
	season.reset()
	weather.reset()


func save_state() -> Dictionary:
	return {
		"season": season.save_state(),
		"weather": weather.save_state(),
	}


func load_state(data: Dictionary) -> void:
	season.load_state(data.get("season", {}))
	weather.load_state(data.get("weather", {}))
