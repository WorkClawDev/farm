extends SceneTree

const API_SCRIPT := preload("res://tools/map_editor/MapAgentAPI.gd")
const PREVIEW_SCRIPT := preload("res://tools/map_editor/MapAgentPreview.gd")
const RESULT_PREFIX := "MAP_AGENT_RESULT="


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if args.is_empty():
		_finish({"ok": false, "errors": ["Missing command. Use schema, inspect, validate, create, apply, or render."]})
		return
	var command: String = str(args.pop_front())
	var api = API_SCRIPT.new()
	var result: Dictionary
	match command:
		"schema":
			result = {"ok": true, "api_version": API_SCRIPT.API_VERSION, "schema": api.schema()}
		"inspect":
			result = api.inspect_map(args[0]) if args.size() >= 1 else _usage_error("inspect <map.tscn>")
		"validate":
			result = api.validate_map(args[0]) if args.size() >= 1 else _usage_error("validate <map.tscn>")
		"create":
			result = _create_command(api, args)
		"apply":
			result = _apply_command(api, args)
		"render":
			result = _render_command(args)
		_:
			result = {"ok": false, "errors": ["Unknown command: %s" % command]}
	_finish(result)


func _apply_command(api: RefCounted, args: Array) -> Dictionary:
	if args.size() < 2:
		return _usage_error("apply <map.tscn> <recipe.json> [output.tscn] [--dry-run]")
	var recipe := _load_json(args[1])
	if not recipe.ok:
		return recipe
	var output_path := ""
	var dry_run := false
	for argument in args.slice(2):
		if argument == "--dry-run":
			dry_run = true
		elif output_path.is_empty():
			output_path = argument
		else:
			return {"ok": false, "errors": ["Unexpected argument: %s" % argument]}
	return api.apply_recipe(args[0], recipe.data, output_path, dry_run)


func _create_command(api: RefCounted, args: Array) -> Dictionary:
	if args.size() < 3:
		return _usage_error("create <profile.tres> <output.tscn> <map_id> [display_name] [--force]")
	var display_name := ""
	var overwrite := false
	for argument in args.slice(3):
		if argument == "--force":
			overwrite = true
		elif display_name.is_empty():
			display_name = str(argument)
		else:
			return {"ok": false, "errors": ["Unexpected argument: %s" % argument]}
	return api.create_map(str(args[0]), str(args[1]), StringName(str(args[2])), display_name, overwrite)


func _render_command(args: Array) -> Dictionary:
	if args.size() < 2:
		return _usage_error("render <map.tscn> <preview.png> [width] [height]")
	var width := clampi(int(args[2]) if args.size() >= 3 else 1280, 64, 4096)
	var height := clampi(int(args[3]) if args.size() >= 4 else 896, 64, 4096)
	return PREVIEW_SCRIPT.new().render_map(str(args[0]), str(args[1]), width, height)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "errors": ["Cannot open recipe: %s" % path]}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		return {"ok": false, "errors": ["Recipe JSON error at line %d: %s" % [json.get_error_line(), json.get_error_message()]]}
	if not json.data is Dictionary:
		return {"ok": false, "errors": ["Recipe root must be an object"]}
	return {"ok": true, "data": json.data}


func _usage_error(usage: String) -> Dictionary:
	return {"ok": false, "errors": ["Usage: %s" % usage]}


func _finish(result: Dictionary) -> void:
	print(RESULT_PREFIX + JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)
