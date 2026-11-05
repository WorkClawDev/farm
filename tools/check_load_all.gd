extends SceneTree

## Loads every .gd and .tscn under res://src and reports anything that fails to
## parse, compile or instantiate. Also flags class_name declarations that the
## global class cache does not know yet (a fresh tree run without an editor
## rescan would then fail with "Identifier ... not declared", see BUG-29).
## Usage: godot --headless --path . --script res://tools/check_load_all.gd

const ROOT := "res://src"

var _failures: Array[String] = []
var _scripts := 0
var _scenes := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var files: Array[String] = []
	_collect(ROOT, files)
	files.sort()
	var cached := {}
	for entry in ProjectSettings.get_global_class_list():
		cached[String(entry.get("class", ""))] = String(entry.get("path", ""))
	for path in files:
		if path.ends_with(".gd"):
			_check_script(path, cached)
		elif path.ends_with(".tscn"):
			_check_scene(path)
	for failure in _failures:
		print("[LOAD FAIL] %s" % failure)
	print("LOAD CHECK: %d scripts, %d scenes, %d failures" % [_scripts, _scenes, _failures.size()])
	print("LOAD CHECK PASSED" if _failures.is_empty() else "LOAD CHECK FAILED")
	quit(0 if _failures.is_empty() else 1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_failures.append("cannot open %s" % dir_path)
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir_path.path_join(file))


func _check_script(path: String, cached: Dictionary) -> void:
	_scripts += 1
	var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if script == null:
		_failures.append("%s: failed to load" % path)
		return
	if not script.can_instantiate() and not script.is_abstract():
		_failures.append("%s: script does not compile" % path)
	var source := FileAccess.get_file_as_string(path)
	var regex := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var found := regex.search(source)
	if found:
		var name := found.get_string(1)
		if cached.get(name, "") != path:
			_failures.append("%s: class_name %s missing from the global class cache (run godot --headless --import)" % [path, name])


func _check_scene(path: String) -> void:
	_scenes += 1
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed == null:
		_failures.append("%s: failed to load" % path)
		return
	if not packed.can_instantiate():
		_failures.append("%s: cannot instantiate" % path)
		return
	var node := packed.instantiate()
	if node == null:
		_failures.append("%s: instantiate() returned null" % path)
		return
	node.free()
