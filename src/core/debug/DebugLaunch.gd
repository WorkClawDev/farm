extends RefCounted

## Debug-only boot switches from OS.get_cmdline_user_args().
## Ignored unless OS.is_debug_build() (release exports never apply these).
##
##   godot --path . -- --load-slot=3 --spawn=village_west
##   godot --path . -- --new-game
##
## --load-slot=N uses the menu number N (1..3). The save file is slot N-1.
## --spawn= selects an entry in SPAWNS and is applied after that save loads.
## --new-game starts a new game. Saves go to DEBUG_NEW_GAME_SAVE_DIR via
## SaveManager.save_dir, never to user://saves/.

## Debug --new-game writes here. Assigned to SaveManager.save_dir; real saves stay put.
const DEBUG_NEW_GAME_SAVE_DIR := "user://debug_tmp_saves/"

const SPAWNS := {
	# West road, just east of ToFarmArea. Same spot Village uses for from_farm,
	# outside the exit trigger (the trigger's right edge is about x=120).
	"village_west": {
		"scene": "res://src/world/maps/Village.tscn",
		"spawn_point": "village_west",
		"position": Vector2(150, 300),
	},
}


static func from_cmdline() -> Dictionary:
	return parse(OS.get_cmdline_user_args(), OS.is_debug_build())


static func apply_debug_new_game_save_dir() -> void:
	SaveManager.save_dir = DEBUG_NEW_GAME_SAVE_DIR


static func parse(args: PackedStringArray, debug_build: bool) -> Dictionary:
	var result := {"slot": -1, "spawn": "", "new_game": false}
	if not debug_build:
		return result
	for arg in args:
		var text := str(arg).strip_edges()
		if text == "--new-game":
			result["new_game"] = true
		elif text.begins_with("--load-slot="):
			var raw := text.substr("--load-slot=".length())
			if raw.is_valid_int():
				var ui_slot := int(raw)
				if ui_slot >= 1 and ui_slot <= 3:
					result["slot"] = ui_slot - 1
		elif text.begins_with("--spawn="):
			var spawn_id := text.substr("--spawn=".length())
			if SPAWNS.has(spawn_id):
				result["spawn"] = spawn_id
	return result


static func spawn_spec(spawn_id: String) -> Dictionary:
	if not SPAWNS.has(spawn_id):
		return {}
	return SPAWNS[spawn_id]
