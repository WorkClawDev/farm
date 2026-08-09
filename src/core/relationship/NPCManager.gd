extends Node

## NPCManager - NPC管理器
## 管理所有NPC的生成、位置调度和状态同步

signal npc_spawned(npc_id: String, npc: NPC)
signal npc_despawned(npc_id: String)
signal npc_location_changed(npc_id: String, location_id: String)

# NPC场景
const NPC_SCENE = preload("res://src/entities/npc/NPC.tscn")

# NPC数据缓存
var _npc_data: Dictionary = {}

# 当前场景中的NPC实例
var _spawned_npcs: Dictionary = {}

# 场景引用
var _current_scene: Node2D = null

# NPC父节点
var _npc_parent: Node2D = null

func _ready() -> void:
	print("[NPCManager] Initialized")
	_load_npc_data()
	_connect_signals()

## 加载NPC数据
func _load_npc_data() -> void:
	var file = FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if not file:
		push_warning("[NPCManager] Failed to load npcs.json")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("[NPCManager] Failed to parse npcs.json")
		return
	
	var data = json.get_data()
	if data.has("npcs"):
		for npc_data in data["npcs"]:
			var npc_id = npc_data.get("id", "")
			if npc_id != "":
				_npc_data[npc_id] = npc_data
	
	print("[NPCManager] Loaded ", _npc_data.size(), " NPCs")

## 连接信号
func _connect_signals() -> void:
	# 监听场景切换
	if EventBus:
		get_node("/root/EventBus").game.scene_transition_completed.connect(_on_scene_transition_completed)

## 设置当前场景
func set_current_scene(scene: Node2D) -> void:
	_current_scene = scene
	
	# 创建NPC父节点
	if _current_scene:
		_npc_parent = _current_scene.get_node_or_null("NPCs")
		if not _npc_parent:
			_npc_parent = Node2D.new()
			_npc_parent.name = "NPCs"
			_current_scene.add_child(_npc_parent)
	
	# 根据场景生成NPC
	_spawn_npcs_for_scene()

## 根据当前场景生成NPC
func _spawn_npcs_for_scene() -> void:
	if not _current_scene:
		return
	
	# 获取场景名称
	var scene_name = _current_scene.name
	
	# 清除现有NPC
	_despawn_all_npcs()
	
	# 根据场景生成对应的NPC
	for npc_id in _npc_data.keys():
		var npc_data = _npc_data[npc_id]
		var default_location = npc_data.get("default_location", "")
		
		# 检查NPC是否应该在这个场景
		if _should_npc_be_in_scene(npc_id, scene_name):
			_spawn_npc(npc_id, npc_data)

## 检查NPC是否应该在当前场景
func _should_npc_be_in_scene(npc_id: String, scene_name: String) -> bool:
	var npc_data = _npc_data.get(npc_id, {})
	var default_location = npc_data.get("default_location", "")
	
	# 简单的场景匹配逻辑
	match scene_name.to_lower():
		"farm":
			return default_location == "farm" or npc_id == "farmer_joe"
		"village":
			return default_location == "village"
		"beach":
			return default_location == "beach" or npc_id == "fisherman_old_jack"
		"mine":
			return false  # 矿洞通常没有常驻NPC
		_:
			return false

## 生成NPC
func _spawn_npc(npc_id: String, npc_data: Dictionary) -> NPC:
	if _spawned_npcs.has(npc_id):
		return _spawned_npcs[npc_id]
	
	if not NPC_SCENE:
		push_error("[NPCManager] NPC scene not loaded")
		return null
	
	var npc = NPC_SCENE.instantiate()
	npc.npc_id = npc_id
	npc.npc_name = npc_data.get("name", npc_id)
	
	# 设置初始位置
	var spawn_pos = _get_spawn_position(npc_id, npc_data)
	npc.global_position = spawn_pos
	
	# 添加到场景
	if _npc_parent:
		_npc_parent.add_child(npc)
	
	_spawned_npcs[npc_id] = npc
	npc_spawned.emit(npc_id, npc)
	
	print("[NPCManager] Spawned NPC: ", npc_id, " at ", spawn_pos)
	return npc

## 获取NPC生成位置
func _get_spawn_position(npc_id: String, npc_data: Dictionary) -> Vector2:
	# 从日程中获取当前时间的位置
	if TimeManager and npc_data.has("schedule"):
		var schedule = npc_data["schedule"]
		var current_time = get_node("/root/TimeManager").current_time
		
		for entry in schedule:
			var start_time = entry.get("start_time", 0.0)
			var end_time = entry.get("end_time", 24.0)
			
			# 处理跨午夜的情况
			if end_time < start_time:
				if current_time >= start_time or current_time < end_time:
					var pos = entry.get("location_position", {})
					return Vector2(pos.get("x", 400), pos.get("y", 300))
			else:
				if current_time >= start_time and current_time < end_time:
					var pos = entry.get("location_position", {})
					return Vector2(pos.get("x", 400), pos.get("y", 300))
	
	# 默认位置
	return Vector2(400 + randi() % 200, 300 + randi() % 200)

## 移除NPC
func _despawn_npc(npc_id: String) -> void:
	if _spawned_npcs.has(npc_id):
		var npc = _spawned_npcs[npc_id]
		_spawned_npcs.erase(npc_id)
		npc.queue_free()
		npc_despawned.emit(npc_id)
		print("[NPCManager] Despawned NPC: ", npc_id)

## 移除所有NPC
func _despawn_all_npcs() -> void:
	for npc_id in _spawned_npcs.keys():
		var npc = _spawned_npcs[npc_id]
		npc.queue_free()
	_spawned_npcs.clear()
	print("[NPCManager] Despawned all NPCs")

## 获取NPC实例
func get_npc(npc_id: String) -> NPC:
	return _spawned_npcs.get(npc_id, null)

## 获取所有生成的NPC
func get_all_spawned_npcs() -> Dictionary:
	return _spawned_npcs.duplicate()

## 场景切换完成回调
func _on_scene_transition_completed() -> void:
	# 获取当前场景
	var current_scene = get_tree().current_scene
	if current_scene:
		set_current_scene(current_scene)

## 更新所有NPC位置（时间变化时调用）
func update_npc_positions() -> void:
	if not TimeManager:
		return
	
	var current_time = get_node("/root/TimeManager").current_time
	
	for npc_id in _spawned_npcs.keys():
		var npc = _spawned_npcs[npc_id]
		var npc_data = _npc_data.get(npc_id, {})
		
		if npc_data.has("schedule"):
			var new_pos = _get_spawn_position(npc_id, npc_data)
			if npc.global_position.distance_to(new_pos) > 10.0:
				npc.move_to(new_pos)

## 保存所有NPC状态
func save_state() -> Dictionary:
	var state = {}
	for npc_id in _spawned_npcs.keys():
		var npc = _spawned_npcs[npc_id]
		state[npc_id] = npc.save_state()
	return state

## 加载NPC状态
func load_state(state: Dictionary) -> void:
	for npc_id in state.keys():
		if _spawned_npcs.has(npc_id):
			_spawned_npcs[npc_id].load_state(state[npc_id])


func reset() -> void:
	_despawn_all_npcs()
	_current_scene = null
	_npc_parent = null
