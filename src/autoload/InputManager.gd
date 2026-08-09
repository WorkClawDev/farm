extends Node

## InputManager - 输入管理器
## 负责处理玩家输入，支持键盘和手柄

signal input_device_changed(device_type: int)
signal bindings_changed(action: StringName)
signal remap_rejected(action: StringName, conflicting_action: StringName)

enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD
}

var current_device: DeviceType = DeviceType.KEYBOARD_MOUSE
var _deadzone: float = 0.2

const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"interact", &"inventory", &"journal", &"pause",
	&"tool_previous", &"tool_next",
]

const ACTION_NAMES := {
	"move_left": "向左移动",
	"move_right": "向右移动",
	"move_up": "向上移动",
	"move_down": "向下移动",
	"interact": "互动 / 使用",
	"inventory": "背包",
	"journal": "农场手册",
	"pause": "暂停 / 返回",
	"tool_previous": "上一个工具",
	"tool_next": "下一个工具",
}

const JOYPAD_GLYPHS := {
	JOY_BUTTON_A: "Ⓐ",
	JOY_BUTTON_B: "Ⓑ",
	JOY_BUTTON_X: "Ⓧ",
	JOY_BUTTON_Y: "Ⓨ",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_START: "Menu",
}

func _ready() -> void:
	_ensure_core_actions()
	print("[InputManager] Initialized")

func _ensure_core_actions() -> void:
	var bindings := {
		"hotbar_next": KEY_TAB,
		"journal": KEY_J,
		"toggle_hud": KEY_H,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
	# 检测输入设备类型
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_device != DeviceType.GAMEPAD:
			current_device = DeviceType.GAMEPAD
			input_device_changed.emit(DeviceType.GAMEPAD)
	elif event is InputEventKey or event is InputEventMouse:
		if current_device != DeviceType.KEYBOARD_MOUSE:
			current_device = DeviceType.KEYBOARD_MOUSE
			input_device_changed.emit(DeviceType.KEYBOARD_MOUSE)

func get_movement_vector() -> Vector2:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# 应用死区
	if input_vector.length() < _deadzone:
		input_vector = Vector2.ZERO
	
	return input_vector.normalized() if input_vector.length() > 1.0 else input_vector

func is_moving() -> bool:
	return get_movement_vector() != Vector2.ZERO

func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)

func is_action_just_released(action: String) -> bool:
	return Input.is_action_just_released(action)

func get_current_device() -> DeviceType:
	return current_device

func is_using_gamepad() -> bool:
	return current_device == DeviceType.GAMEPAD

func set_deadzone(value: float) -> void:
	_deadzone = clamp(value, 0.0, 1.0)

func vibrate_gamepad(weak_magnitude: float, strong_magnitude: float, duration: float = 0.5) -> void:
	if current_device == DeviceType.GAMEPAD:
		Input.start_joy_vibration(0, weak_magnitude, strong_magnitude, duration)


func get_action_display_name(action: StringName) -> String:
	return str(ACTION_NAMES.get(str(action), str(action).capitalize()))


func get_action_prompt(action: StringName, device := -1) -> String:
	var use_gamepad := is_using_gamepad() if device < 0 else device == DeviceType.GAMEPAD
	var events := InputMap.action_get_events(action)
	for event in events:
		if use_gamepad and event is InputEventJoypadButton:
			return str(JOYPAD_GLYPHS.get(event.button_index, "Button %d" % event.button_index))
		if not use_gamepad and event is InputEventKey:
			return _key_event_label(event)
		if not use_gamepad and event is InputEventMouseButton:
			return "鼠标%d" % event.button_index
	return "—"


func get_action_icon_id(action: StringName) -> String:
	var prefix := "gamepad" if is_using_gamepad() else "keyboard"
	return "%s/%s" % [prefix, str(action)]


func find_binding_conflict(action: StringName, event: InputEvent) -> StringName:
	for other in REMAPPABLE_ACTIONS:
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if existing.is_match(event):
				return other
	return &""


func remap_action(action: StringName, event: InputEvent) -> bool:
	if action not in REMAPPABLE_ACTIONS or not _is_supported_binding(event):
		return false
	var conflict := find_binding_conflict(action, event)
	if not conflict.is_empty():
		remap_rejected.emit(action, conflict)
		return false
	var preserved: Array[InputEvent] = []
	var replacement_family := _binding_family(event)
	for existing in InputMap.action_get_events(action):
		if _binding_family(existing) != replacement_family:
			preserved.append(existing)
	InputMap.action_erase_events(action)
	for existing in preserved:
		InputMap.action_add_event(action, existing)
	InputMap.action_add_event(action, event)
	bindings_changed.emit(action)
	return true


func serialize_bindings() -> Dictionary:
	var result := {}
	for action in REMAPPABLE_ACTIONS:
		var serialized: Array[Dictionary] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				serialized.append({
					"type": "key",
					"physical_keycode": event.physical_keycode,
					"keycode": event.keycode,
				})
			elif event is InputEventJoypadButton:
				serialized.append({
					"type": "joy_button",
					"button_index": event.button_index,
				})
			elif event is InputEventMouseButton:
				serialized.append({
					"type": "mouse_button",
					"button_index": event.button_index,
				})
		result[str(action)] = serialized
	return result


func apply_serialized_bindings(data: Dictionary) -> void:
	for action_name in data:
		var action := StringName(action_name)
		if action not in REMAPPABLE_ACTIONS or not data[action_name] is Array:
			continue
		var decoded: Array[InputEvent] = []
		for entry in data[action_name]:
			if not entry is Dictionary:
				continue
			var event := _deserialize_event(entry)
			if event:
				decoded.append(event)
		if decoded.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event in decoded:
			InputMap.action_add_event(action, event)


func _deserialize_event(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = int(data.get("physical_keycode", 0))
			event.keycode = int(data.get("keycode", 0))
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.button_index = int(data.get("button_index", 0))
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = int(data.get("button_index", 0))
			return event
	return null


func _is_supported_binding(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton


func _binding_family(event: InputEvent) -> StringName:
	if event is InputEventKey:
		return &"keyboard"
	if event is InputEventJoypadButton:
		return &"gamepad"
	if event is InputEventMouseButton:
		return &"mouse"
	return &"unsupported"


func _key_event_label(event: InputEventKey) -> String:
	var code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var label := OS.get_keycode_string(code)
	if event.ctrl_pressed:
		label = "Ctrl+" + label
	if event.shift_pressed:
		label = "Shift+" + label
	if event.alt_pressed:
		label = "Alt+" + label
	return label
