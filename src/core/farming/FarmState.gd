extends Node

## FarmState - 农场唯一状态源。
## 场景只渲染这些格子；跨场景和存档时状态不会丢失。

signal farm_reset
signal cell_changed(coord: Vector2i)
signal day_advanced
signal watering_can_changed(current: int, maximum: int)

const GRID_WIDTH := 10
const GRID_HEIGHT := 8
const UNTILLED := 0
const TILLED := 1
const WATERED := 2

## 水壶水量也存在这里（唯一来源）：玩家/工具节点每个场景都会重建，
## 如果水量只放在 WateringCan 节点上，切场景就会被重置成满水。
const WATERING_CAN_MAX_WATER := 100
const WATERING_CAN_WATER_PER_USE := 5

enum WaterResult { WATERED_OK, NOT_TILLED, ALREADY_WATERED, CAN_EMPTY }

var _cells: Dictionary = {}
var _watering_can_water: int = WATERING_CAN_MAX_WATER


func _ready() -> void:
	if _cells.is_empty():
		reset()
	print("[FarmState] Initialized")


func reset() -> void:
	_cells.clear()
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var coord := Vector2i(x, y)
			_cells[_key(coord)] = _new_cell(coord)
	set_watering_can_water(WATERING_CAN_MAX_WATER)
	farm_reset.emit()


func has_cell(coord: Vector2i) -> bool:
	return _cells.has(_key(coord))


func get_cell(coord: Vector2i) -> Dictionary:
	return _cells.get(_key(coord), {}).duplicate(true)


func till(coord: Vector2i) -> bool:
	var cell := _cell_ref(coord)
	if cell.is_empty() or int(cell.state) != UNTILLED:
		return false
	cell.state = TILLED
	_emit_changed(coord)
	return true


func plant(coord: Vector2i, seed_id: String) -> bool:
	var cell := _cell_ref(coord)
	if cell.is_empty() or int(cell.state) == UNTILLED or not cell.crop.is_empty():
		return false

	var item_data = ItemDatabase.get_item(seed_id)
	if item_data == null or item_data.type != ItemDatabase.ItemType.SEED:
		return false
	var crop_id: String = item_data.crop_id
	var crop_data = GrowthSystem.get_crop_data(crop_id)
	if crop_data == null or not crop_data.can_grow_in_season(TimeManager.get_season_name()):
		return false
	if not Inventory.has_item(seed_id, 1):
		return false

	cell.crop = {
		"crop_id": crop_id,
		"stage": 0,
		"days_in_stage": 0,
		"total_days": 0,
		"watered": false,
		"quality": CropData.Quality.NORMAL,
		"mature": false,
	}
	if not Inventory.remove_item(seed_id, 1):
		cell.crop = {}
		return false
	_emit_changed(coord)
	return true


func water(coord: Vector2i) -> bool:
	var cell := _cell_ref(coord)
	if cell.is_empty() or int(cell.state) == UNTILLED:
		return false
	cell.state = WATERED
	cell.moisture = 100
	if not cell.crop.is_empty():
		cell.crop.watered = true
	_emit_changed(coord)
	return true


## 用水壶浇一格地：先判断这格能不能浇，再判断水够不够；只有真正浇上水才扣水。
## 已经浇过的格子不扣水（体力也由调用方按结果决定不扣）。
func water_with_can(coord: Vector2i) -> int:
	var cell := _cell_ref(coord)
	if cell.is_empty() or int(cell.state) == UNTILLED:
		return WaterResult.NOT_TILLED
	if int(cell.state) == WATERED:
		return WaterResult.ALREADY_WATERED
	if not has_watering_charge():
		return WaterResult.CAN_EMPTY
	if not water(coord):
		return WaterResult.NOT_TILLED
	set_watering_can_water(_watering_can_water - WATERING_CAN_WATER_PER_USE)
	return WaterResult.WATERED_OK


func get_watering_can_water() -> int:
	return _watering_can_water


func get_watering_can_max_water() -> int:
	return WATERING_CAN_MAX_WATER


func get_watering_can_uses_left() -> int:
	return _watering_can_water / WATERING_CAN_WATER_PER_USE


func get_watering_can_max_uses() -> int:
	return WATERING_CAN_MAX_WATER / WATERING_CAN_WATER_PER_USE


func has_watering_charge() -> bool:
	return _watering_can_water >= WATERING_CAN_WATER_PER_USE


func set_watering_can_water(value: int) -> void:
	var clamped := clampi(value, 0, WATERING_CAN_MAX_WATER)
	if clamped == _watering_can_water:
		return
	_watering_can_water = clamped
	watering_can_changed.emit(_watering_can_water, WATERING_CAN_MAX_WATER)


## 装满水壶；返回 false 表示本来就是满的。
func refill_watering_can() -> bool:
	if _watering_can_water >= WATERING_CAN_MAX_WATER:
		return false
	set_watering_can_water(WATERING_CAN_MAX_WATER)
	return true


func can_harvest(coord: Vector2i) -> bool:
	var cell := _cell_ref(coord)
	return not cell.is_empty() and not cell.crop.is_empty() and bool(cell.crop.get("mature", false))


func harvest(coord: Vector2i) -> Dictionary:
	var cell := _cell_ref(coord)
	if cell.is_empty() or not can_harvest(coord):
		return {}

	var crop_data = GrowthSystem.get_crop_data(str(cell.crop.crop_id))
	if crop_data == null:
		return {}
	var quantity := randi_range(crop_data.min_harvest, crop_data.max_harvest)
	if not Inventory.can_add_item(str(cell.crop.crop_id), quantity):
		return {}
	if not Inventory.add_item(str(cell.crop.crop_id), quantity):
		return {}

	var result := {
		"crop_id": str(cell.crop.crop_id),
		"quantity": quantity,
		"quality": int(cell.crop.get("quality", CropData.Quality.NORMAL)),
	}
	if crop_data.regrow:
		cell.crop.stage = maxi(0, crop_data.growth_days.size() - 2)
		cell.crop.days_in_stage = 0
		cell.crop.mature = false
		cell.crop.watered = false
	else:
		cell.crop = {}
	_emit_changed(coord)
	return result


func advance_day() -> void:
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		var coord := Vector2i(int(cell.x), int(cell.y))
		if not cell.crop.is_empty():
			_advance_crop(cell.crop)
		if int(cell.state) != UNTILLED:
			cell.state = TILLED
			cell.moisture = 0
		_emit_changed(coord)
	day_advanced.emit()


func get_save_state() -> Dictionary:
	var cells: Array = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			cells.append(get_cell(Vector2i(x, y)))
	return {
		"width": GRID_WIDTH,
		"height": GRID_HEIGHT,
		"cells": cells,
		"watering_can_water": _watering_can_water,
	}


func load_save_state(data: Dictionary) -> bool:
	var cells_data = data.get("cells", [])
	if not cells_data is Array or cells_data.size() != GRID_WIDTH * GRID_HEIGHT:
		return false
	var restored: Dictionary = {}
	for raw_cell in cells_data:
		if not raw_cell is Dictionary:
			return false
		var coord := Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
		if coord.x < 0 or coord.x >= GRID_WIDTH or coord.y < 0 or coord.y >= GRID_HEIGHT:
			return false
		restored[_key(coord)] = _sanitize_cell(raw_cell, coord)
	_cells = restored
	set_watering_can_water(int(data.get("watering_can_water", WATERING_CAN_MAX_WATER)))
	farm_reset.emit()
	return true


func _advance_crop(crop: Dictionary) -> void:
	if bool(crop.get("mature", false)):
		crop.watered = false
		return
	var crop_data = GrowthSystem.get_crop_data(str(crop.get("crop_id", "")))
	if crop_data == null:
		return
	if crop_data.requires_water and not bool(crop.get("watered", false)):
		return
	crop.total_days = int(crop.get("total_days", 0)) + 1
	crop.days_in_stage = int(crop.get("days_in_stage", 0)) + 1
	var stage := int(crop.get("stage", 0))
	var required_days := int(crop_data.growth_days[mini(stage, crop_data.growth_days.size() - 1)])
	if int(crop.days_in_stage) >= required_days:
		crop.days_in_stage = 0
		if stage < crop_data.growth_days.size() - 1:
			crop.stage = stage + 1
		else:
			crop.mature = true
	crop.watered = false


func _new_cell(coord: Vector2i) -> Dictionary:
	return {
		"x": coord.x,
		"y": coord.y,
		"state": UNTILLED,
		"moisture": 0,
		"fertilizer": 0,
		"crop": {},
	}


func _sanitize_cell(raw: Dictionary, coord: Vector2i) -> Dictionary:
	var cell := _new_cell(coord)
	cell.state = clampi(int(raw.get("state", UNTILLED)), UNTILLED, WATERED)
	cell.moisture = clampi(int(raw.get("moisture", 0)), 0, 100)
	cell.fertilizer = maxi(0, int(raw.get("fertilizer", 0)))
	var crop = raw.get("crop", {})
	cell.crop = crop.duplicate(true) if crop is Dictionary else {}
	return cell


func _cell_ref(coord: Vector2i) -> Dictionary:
	return _cells.get(_key(coord), {})


func _key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func _emit_changed(coord: Vector2i) -> void:
	cell_changed.emit(coord)

