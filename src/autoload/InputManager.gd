extends Node

## InputManager - 输入管理器
## 负责处理玩家输入，支持键盘和手柄

signal input_device_changed(device_type: int)

enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD
}

var current_device: DeviceType = DeviceType.KEYBOARD_MOUSE
var _deadzone: float = 0.2

func _ready() -> void:
	print("[InputManager] Initialized")

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
