extends CanvasModulate

## Outdoor day/night tint that follows TimeManager (round 7: the village was fully
## lit at midnight). Add it to an outdoor map scene; UI on CanvasLayers is not tinted.

const DAY := Color(1, 1, 1)
const DUSK := Color(1.0, 0.86, 0.74)
const NIGHT := Color(0.42, 0.47, 0.72)

## [hour, colour] keys, interpolated in between; hours are 0-24.
const KEYS := [
	[0.0, NIGHT], [5.0, NIGHT], [6.5, DAY], [17.0, DAY],
	[18.5, DUSK], [20.5, NIGHT], [24.0, NIGHT],
]


func _ready() -> void:
	name = "DayNightTint"
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.time_changed.connect(_on_time_changed)
		_on_time_changed(time_manager.current_time)


func _on_time_changed(time: float) -> void:
	color = color_for_time(time)


## TimeManager runs on past midnight up to 26.0 (2:00 AM).
static func color_for_time(time: float) -> Color:
	var t := fposmod(time, 24.0)
	for i in range(1, KEYS.size()):
		if t <= KEYS[i][0]:
			var a: Array = KEYS[i - 1]
			var b: Array = KEYS[i]
			return (a[1] as Color).lerp(b[1], inverse_lerp(a[0], b[0], t))
	return NIGHT
