extends Node

## StaminaManager - 体力管理器
## 负责玩家的体力值管理

signal stamina_changed(current: float, maximum: float)
signal stamina_depleted()
signal stamina_critical()  # 体力低于20%

var current_stamina: float = 100.0
var max_stamina: float = 100.0

const CRITICAL_THRESHOLD: float = 0.2  # 20% 以下为危险

func _ready() -> void:
	print("[StaminaManager] Initialized")

func use_stamina(amount: float) -> bool:
	if amount <= 0:
		return true  # 不消耗体力
	
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		
		if current_stamina <= 0:
			stamina_depleted.emit()
			current_stamina = 0
			stamina_changed.emit(current_stamina, max_stamina)
		elif current_stamina / max_stamina <= CRITICAL_THRESHOLD:
			stamina_critical.emit()
		
		return true
	else:
		push_warning("[StaminaManager] Not enough stamina: need %.1f, have %.1f" % [amount, current_stamina])
		return false

func restore_stamina(amount: float) -> void:
	if amount <= 0:
		return
	
	current_stamina = min(current_stamina + amount, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

func set_stamina(value: float) -> void:
	current_stamina = clamp(value, 0, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

func set_max_stamina(value: float) -> void:
	if value <= 0:
		push_warning("[StaminaManager] set_max_stamina called with non-positive value: %f" % value)
		return
	max_stamina = value
	current_stamina = min(current_stamina, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

func get_stamina_percent() -> float:
	if max_stamina <= 0:
		return 0.0
	return current_stamina / max_stamina

func is_critical() -> bool:
	return get_stamina_percent() <= CRITICAL_THRESHOLD

func save_state() -> Dictionary:
	return {"current": current_stamina, "maximum": max_stamina}

func load_state(data: Dictionary) -> void:
	current_stamina = data.get("current", 100.0)
	max_stamina = data.get("maximum", 100.0)
	print("[StaminaManager] Loaded stamina: %.1f / %.1f" % [current_stamina, max_stamina])
