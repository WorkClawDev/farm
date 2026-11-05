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
## 铁壶及以上。每次仍扣 5，所以是 40 次。旧档没有这个字段时保持铜壶 20 次。
const WATERING_CAN_IRON_MAX_WATER := 200
const WATERING_CAN_WATER_PER_USE := 5

## --debug-crops plants tomato here and green bean on the next cell.
## Both are on the north ridge, which opening debris skips.
const DEBUG_FIRST_RIDGE := Vector2i(0, 0)
const DEBUG_SECOND_RIDGE := Vector2i(1, 0)

## 开局杂物。只铺在不挡路的田外圈（避开北侧小路和东出口）。有杂物时不能翻地、不能播种。
const DEBRIS_WEED := "weed"
const DEBRIS_STONE := "stone"
const DEBRIS_TWIG := "twig"
const DEBRIS_STUMP := "stump"
const OPENING_DEBRIS_COUNT := 20
const STUMP_HITS_TO_CLEAR := 3
const TOOL_SICKLE := "sickle"
const TOOL_PICKAXE := "pickaxe"
const TOOL_AXE := "axe"
const DEAD_CROP_SPRITE := "res://assets/sprites/crops/crop_dead.png"

const DEBRIS_DROP := {
	"weed": "fiber",
	"stone": "stone",
	"twig": "wood",
	"stump": "wood",
}
const DEBRIS_TOOL := {
	"weed": "sickle",
	"stone": "pickaxe",
	"twig": "axe",
	"stump": "axe",
}

enum WaterResult { WATERED_OK, NOT_TILLED, ALREADY_WATERED, CAN_EMPTY }

var _cells: Dictionary = {}
var _watering_can_max_water: int = WATERING_CAN_MAX_WATER
var _watering_can_water: int = WATERING_CAN_MAX_WATER
## advance_day 刚处理过的活作物数。-1 表示还没有过夜结算在等着被取走。
var _overnight_crop_count: int = -1


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
	_seed_opening_debris()
	_watering_can_max_water = WATERING_CAN_MAX_WATER
	_watering_can_water = -1
	set_watering_can_water(WATERING_CAN_MAX_WATER)
	_overnight_crop_count = -1
	farm_reset.emit()


func has_cell(coord: Vector2i) -> bool:
	return _cells.has(_key(coord))


func get_cell(coord: Vector2i) -> Dictionary:
	return _cells.get(_key(coord), {}).duplicate(true)


func is_field_edge(coord: Vector2i) -> bool:
	return coord.x == 0 or coord.y == 0 or coord.x == GRID_WIDTH - 1 or coord.y == GRID_HEIGHT - 1


## 北侧整行压在农场小路上；东侧第 3、4 行对着通往村庄的出口。开局杂物不放这里。
func is_opening_blocked_cell(coord: Vector2i) -> bool:
	if coord.y == 0:
		return true
	return coord.x == GRID_WIDTH - 1 and (coord.y == 3 or coord.y == 4)


func get_debris(coord: Vector2i) -> String:
	var kind := str(get_cell(coord).get("debris", ""))
	if not _is_debris_kind(kind):
		return ""
	return kind


func count_debris() -> int:
	var count := 0
	for key in _cells.keys():
		if _is_debris_kind(str(_cells[key].get("debris", ""))):
			count += 1
	return count


func debris_variant_count(kind: String) -> int:
	match kind:
		DEBRIS_WEED:
			return 3
		DEBRIS_STONE:
			return 7
		DEBRIS_TWIG:
			return 2
		DEBRIS_STUMP:
			return 1
		_:
			return 1


func debris_display_name(kind: String) -> String:
	match kind:
		DEBRIS_WEED:
			return "杂草"
		DEBRIS_STONE:
			return "石头"
		DEBRIS_TWIG:
			return "树枝"
		DEBRIS_STUMP:
			return "树桩"
		_:
			return "杂物"


func tool_for_debris(kind: String) -> String:
	return str(DEBRIS_TOOL.get(kind, ""))


func debris_wrong_tool_message(kind: String) -> String:
	var tool_name := "合适的工具"
	match tool_for_debris(kind):
		TOOL_SICKLE:
			tool_name = "镰刀"
		TOOL_PICKAXE:
			tool_name = "镐子"
		TOOL_AXE:
			tool_name = "斧头"
	return "%s要用%s清除" % [debris_display_name(kind), tool_name]


## 这一下如果会清掉杂物，返回将掉落的物品 id；树桩前两下不掉东西。
func peek_debris_drop(coord: Vector2i) -> String:
	var cell := get_cell(coord)
	var kind := str(cell.get("debris", ""))
	if not _is_debris_kind(kind):
		return ""
	if kind == DEBRIS_STUMP and int(cell.get("debris_hits", 0)) + 1 < STUMP_HITS_TO_CLEAR:
		return ""
	return str(DEBRIS_DROP.get(kind, ""))


## 用对了工具才调用。树桩要打满 3 下才清除并掉木头。不改背包。
func strike_debris(coord: Vector2i) -> Dictionary:
	var cell := _cell_ref(coord)
	if cell.is_empty():
		return {}
	var kind := str(cell.get("debris", ""))
	if not _is_debris_kind(kind):
		return {}
	var needed := STUMP_HITS_TO_CLEAR if kind == DEBRIS_STUMP else 1
	var hits := int(cell.get("debris_hits", 0)) + 1
	if hits < needed:
		cell.debris_hits = hits
		_emit_changed(coord)
		return {
			"cleared": false,
			"kind": kind,
			"item_id": "",
			"quantity": 0,
			"hits": hits,
			"hits_needed": needed,
		}
	var item_id := str(DEBRIS_DROP.get(kind, ""))
	cell.debris = ""
	cell.debris_hits = 0
	cell.debris_variant = 0
	_emit_changed(coord)
	return {
		"cleared": true,
		"kind": kind,
		"item_id": item_id,
		"quantity": 1 if item_id != "" else 0,
		"hits": hits,
		"hits_needed": needed,
	}


func till(coord: Vector2i) -> bool:
	var cell := _cell_ref(coord)
	if cell.is_empty() or _is_debris_kind(str(cell.get("debris", ""))) or int(cell.state) != UNTILLED:
		return false
	cell.state = TILLED
	_emit_changed(coord)
	return true


func plant(coord: Vector2i, seed_id: String) -> bool:
	var cell := _cell_ref(coord)
	if cell.is_empty() or _is_debris_kind(str(cell.get("debris", ""))) or int(cell.state) == UNTILLED or not cell.crop.is_empty():
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
		"dead": false,
	}
	if not Inventory.remove_item(seed_id, 1):
		cell.crop = {}
		return false
	_emit_changed(coord)
	return true


## One watered night from mature. Stage sits on the last growth_days entry with
## days_in_stage = required - 1, so the next watered advance_day sets mature.
static func progress_one_day_before_mature(growth_days) -> Dictionary:
	if growth_days.is_empty():
		return {}
	var stage: int = int(growth_days.size()) - 1
	var days_in_stage: int = maxi(0, int(growth_days[stage]) - 1)
	var total: int = days_in_stage
	for i in stage:
		total += int(growth_days[i])
	return {
		"stage": stage,
		"days_in_stage": days_in_stage,
		"total_days": total,
	}


## Debug only. Tills coord, clears debris, waters, and plants crop_id one day
## before mature. Does not take a seed or watering-can water.
func place_debug_crop_before_mature(crop_id: String, coord: Vector2i = DEBUG_FIRST_RIDGE) -> bool:
	var crop_data = GrowthSystem.get_crop_data(crop_id)
	if crop_data == null or crop_data.growth_days.is_empty():
		return false
	var progress := progress_one_day_before_mature(crop_data.growth_days)
	if progress.is_empty():
		return false
	var cell := _cell_ref(coord)
	if cell.is_empty():
		return false
	cell.debris = ""
	cell.debris_hits = 0
	cell.debris_variant = 0
	cell.state = WATERED
	cell.moisture = 100
	cell.crop = {
		"crop_id": crop_id,
		"stage": int(progress["stage"]),
		"days_in_stage": int(progress["days_in_stage"]),
		"total_days": int(progress["total_days"]),
		"watered": true,
		"quality": CropData.Quality.NORMAL,
		"mature": false,
		"dead": false,
	}
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
	return _watering_can_max_water


func get_watering_can_uses_left() -> int:
	return _watering_can_water / WATERING_CAN_WATER_PER_USE


func get_watering_can_max_uses() -> int:
	return _watering_can_max_water / WATERING_CAN_WATER_PER_USE


func has_watering_charge() -> bool:
	return _watering_can_water >= WATERING_CAN_WATER_PER_USE


func set_watering_can_max_water(maximum: int) -> void:
	var next := maxi(WATERING_CAN_WATER_PER_USE, maximum)
	if next == _watering_can_max_water:
		return
	_watering_can_max_water = next
	if _watering_can_water > _watering_can_max_water:
		_watering_can_water = _watering_can_max_water
	watering_can_changed.emit(_watering_can_water, _watering_can_max_water)


func set_watering_can_water(value: int) -> void:
	var clamped := clampi(value, 0, _watering_can_max_water)
	if clamped == _watering_can_water:
		return
	_watering_can_water = clamped
	watering_can_changed.emit(_watering_can_water, _watering_can_max_water)


## 装满水壶；返回 false 表示本来就是满的。
func refill_watering_can() -> bool:
	if _watering_can_water >= _watering_can_max_water:
		return false
	set_watering_can_water(_watering_can_max_water)
	return true


## 铜是 0。铁及以上用铁壶容量。
func watering_can_max_water_for_tier(tier: int) -> int:
	if tier <= 0:
		return WATERING_CAN_MAX_WATER
	return WATERING_CAN_IRON_MAX_WATER


## 升级成功后立刻提高上限并灌满。
func apply_watering_can_upgrade(tier: int) -> void:
	var maximum := watering_can_max_water_for_tier(tier)
	set_watering_can_max_water(maximum)
	set_watering_can_water(maximum)


func can_harvest(coord: Vector2i) -> bool:
	var cell := _cell_ref(coord)
	if cell.is_empty() or cell.crop.is_empty() or bool(cell.crop.get("dead", false)):
		return false
	return bool(cell.crop.get("mature", false))


func is_crop_dead(coord: Vector2i) -> bool:
	var cell := _cell_ref(coord)
	return not cell.is_empty() and not cell.crop.is_empty() and bool(cell.crop.get("dead", false))


## 镰刀或锄头清掉枯死株。活着的作物不动。清完可以再翻、再种。
func clear_dead_crop(coord: Vector2i) -> bool:
	if not is_crop_dead(coord):
		return false
	var cell := _cell_ref(coord)
	cell.crop = {}
	_emit_changed(coord)
	return true


## 优先 res://assets/sprites/crops/{crop_id}_stagedead.png，没有则用通用枯死图。
static func dead_crop_sprite_path(crop_id: String) -> String:
	var specific := "res://assets/sprites/crops/%s_stagedead.png" % crop_id
	if crop_id != "" and ResourceLoader.exists(specific):
		return specific
	return DEAD_CROP_SPRITE


## stage 0 优先用 {crop_id}_stage0.png（文件在才用）。
## 数据表若从 stage1 起跳，后面的阶段仍按原列表对齐，不跳过下一张。
## 没有 stage0 时再试种子/物品图标，否则保持列表里的那张。
static func crop_stage_sprite_path(crop_id: String, stage: int, stage_sprites: Array) -> String:
	var stage0 := "res://assets/sprites/crops/%s_stage0.png" % crop_id
	var has_stage0 := crop_id != "" and ResourceLoader.exists(stage0)
	var starts_with_stage0 := false
	if not stage_sprites.is_empty():
		starts_with_stage0 = str(stage_sprites[0]) == stage0
	if stage <= 0:
		if has_stage0:
			return stage0
		var icon := _planted_seed_icon_path(crop_id)
		if icon != "":
			return icon
		if not stage_sprites.is_empty():
			return str(stage_sprites[0])
		return ""
	if stage_sprites.is_empty():
		return ""
	var index := stage
	if has_stage0 and not starts_with_stage0:
		index = stage - 1
	index = clampi(index, 0, stage_sprites.size() - 1)
	return str(stage_sprites[index])


static func _planted_seed_icon_path(crop_id: String) -> String:
	if crop_id == "":
		return ""
	for item_id in [crop_id + "_seed", crop_id]:
		var icon := str(ItemDatabase.get_icon_path(item_id))
		if icon != "" and ResourceLoader.exists(icon):
			return icon
	return ""


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
		# 再成熟只看 regrow_days，不再用 growth_days[stage]。
		cell.crop.regrow_days_left = int(crop_data.regrow_days)
	else:
		cell.crop = {}
	_emit_changed(coord)
	return result


## 雨天和暴风雨：已翻地，以及还种着作物的格子，都变成浇过水。空的未翻地不动。
func water_from_rain() -> int:
	var changed := 0
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		var has_crop: bool = not bool(cell.crop.is_empty())
		var state := int(cell.state)
		if state == UNTILLED and not has_crop:
			continue
		var already := state == WATERED and int(cell.get("moisture", 0)) >= 100
		if has_crop:
			already = already and bool(cell.crop.get("watered", false))
		if already:
			continue
		cell.state = WATERED
		cell.moisture = 100
		if has_crop:
			cell.crop.watered = true
		changed += 1
		_emit_changed(Vector2i(int(cell.x), int(cell.y)))
	return changed


func advance_day() -> void:
	# GameManager 先长田，再让 TimeManager 进入下一天。今天已是季末时，这一夜会换季。
	var season_changes := _season_changes_tonight()
	var next_season := _next_season_name()
	var updated := 0
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		var coord := Vector2i(int(cell.x), int(cell.y))
		if not cell.crop.is_empty():
			if not bool(cell.crop.get("dead", false)):
				updated += 1
			_advance_crop(cell.crop)
			if season_changes and _should_wilt(cell.crop, next_season):
				_mark_crop_dead(cell.crop)
		if int(cell.state) != UNTILLED:
			cell.state = TILLED
			cell.moisture = 0
		_emit_changed(coord)
	_overnight_crop_count = updated
	day_advanced.emit()



## GrowthSystem 在 day_changed 里取走。取完回到 -1，避免下一次日历重置报成旧的数。
func consume_overnight_crop_count() -> int:
	var count := _overnight_crop_count
	_overnight_crop_count = -1
	return count


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
		"watering_can_max_water": _watering_can_max_water,
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
	var saved_max := int(data.get("watering_can_max_water", WATERING_CAN_MAX_WATER))
	_watering_can_max_water = maxi(WATERING_CAN_WATER_PER_USE, saved_max)
	_watering_can_water = -1
	set_watering_can_water(int(data.get("watering_can_water", _watering_can_max_water)))
	_overnight_crop_count = -1
	farm_reset.emit()
	return true


func _advance_crop(crop: Dictionary) -> void:
	if bool(crop.get("dead", false)):
		crop.watered = false
		crop.mature = false
		return
	if bool(crop.get("mature", false)):
		crop.watered = false
		return
	var crop_data = GrowthSystem.get_crop_data(str(crop.get("crop_id", "")))
	if crop_data == null:
		return
	if _is_regrowing(crop, crop_data):
		_advance_regrow(crop, crop_data)
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


## 季末这一夜 TimeManager 还停在旧日期。下一天会换季。
func _season_changes_tonight() -> bool:
	if TimeManager == null:
		return false
	return int(TimeManager.current_day) >= int(TimeManager.DAYS_PER_SEASON)


func _next_season_name() -> String:
	if TimeManager == null:
		return ""
	var seasons: Array = TimeManager.SEASONS
	if seasons.is_empty():
		return ""
	var index := posmod(int(TimeManager.current_season) + 1, seasons.size())
	return str(seasons[index])


## dies_out_of_season 且下一季不在作物季节里才标枯死。跨季作物（玉米夏秋）留着。土地仍是已翻。
func _should_wilt(crop: Dictionary, next_season: String) -> bool:
	if crop.is_empty() or next_season == "":
		return false
	var crop_data = GrowthSystem.get_crop_data(str(crop.get("crop_id", "")))
	if crop_data == null or not crop_data.dies_out_of_season:
		return false
	return not crop_data.can_grow_in_season(next_season)


## 换季枯死留着 crop_id，只是不能再长、不能收。清掉之后格子才变回空作物。
func _mark_crop_dead(crop: Dictionary) -> void:
	crop.dead = true
	crop.mature = false
	crop.watered = false


## 已收过的再生作物走倒计时。旧存档没有 regrow_days_left：第一次长成后 total_days 已经走完。
func _is_regrowing(crop: Dictionary, crop_data) -> bool:
	if not bool(crop_data.regrow):
		return false
	if crop.has("regrow_days_left"):
		return true
	return int(crop.get("total_days", 0)) >= crop_data.get_total_growth_days()


func _advance_regrow(crop: Dictionary, crop_data) -> void:
	if not crop.has("regrow_days_left"):
		crop.regrow_days_left = int(crop_data.regrow_days)
	var watered := bool(crop.get("watered", false))
	crop.watered = false
	if crop_data.requires_water and not watered:
		return
	var left := int(crop.regrow_days_left) - 1
	crop.regrow_days_left = left
	if left <= 0:
		crop.regrow_days_left = 0
		crop.mature = true
		if crop_data.growth_days.size() > 0:
			crop.stage = crop_data.growth_days.size() - 1


func _seed_opening_debris() -> void:
	var outer: Array[Vector2i] = []
	var inner: Array[Vector2i] = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var coord := Vector2i(x, y)
			if is_opening_blocked_cell(coord):
				continue
			if is_field_edge(coord):
				outer.append(coord)
			else:
				inner.append(coord)
	outer.shuffle()
	inner.shuffle()
	var picks: Array[Vector2i] = []
	for coord in outer:
		if picks.size() >= OPENING_DEBRIS_COUNT:
			break
		picks.append(coord)
	for coord in inner:
		if picks.size() >= OPENING_DEBRIS_COUNT:
			break
		picks.append(coord)
	var kinds: Array[String] = [DEBRIS_WEED, DEBRIS_STONE, DEBRIS_TWIG, DEBRIS_STUMP]
	for i in picks.size():
		var kind := kinds[i] if i < kinds.size() else kinds[randi() % kinds.size()]
		var cell: Dictionary = _cell_ref(picks[i])
		cell.debris = kind
		cell.debris_hits = 0
		cell.debris_variant = randi() % debris_variant_count(kind)


func _new_cell(coord: Vector2i) -> Dictionary:
	return {
		"x": coord.x,
		"y": coord.y,
		"state": UNTILLED,
		"moisture": 0,
		"fertilizer": 0,
		"crop": {},
		"debris": "",
		"debris_hits": 0,
		"debris_variant": 0,
	}


func _sanitize_cell(raw: Dictionary, coord: Vector2i) -> Dictionary:
	var cell := _new_cell(coord)
	cell.state = clampi(int(raw.get("state", UNTILLED)), UNTILLED, WATERED)
	cell.moisture = clampi(int(raw.get("moisture", 0)), 0, 100)
	cell.fertilizer = maxi(0, int(raw.get("fertilizer", 0)))
	var crop = raw.get("crop", {})
	cell.crop = crop.duplicate(true) if crop is Dictionary else {}
	if not cell.crop.is_empty():
		cell.crop["dead"] = bool(cell.crop.get("dead", false))
		if bool(cell.crop["dead"]):
			cell.crop["mature"] = false
	# 旧存档没有 debris 字段：视为这格没有杂物。
	var debris := str(raw.get("debris", ""))
	if not _is_debris_kind(debris):
		debris = ""
	cell.debris = debris
	if debris == DEBRIS_STUMP:
		cell.debris_hits = clampi(int(raw.get("debris_hits", 0)), 0, STUMP_HITS_TO_CLEAR - 1)
	else:
		cell.debris_hits = 0
	cell.debris_variant = posmod(int(raw.get("debris_variant", 0)), debris_variant_count(debris if debris != "" else DEBRIS_WEED))
	if debris == "":
		cell.debris_variant = 0
	return cell


func _is_debris_kind(kind: String) -> bool:
	return kind == DEBRIS_WEED or kind == DEBRIS_STONE or kind == DEBRIS_TWIG or kind == DEBRIS_STUMP


func _cell_ref(coord: Vector2i) -> Dictionary:
	return _cells.get(_key(coord), {})


func _key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func _emit_changed(coord: Vector2i) -> void:
	cell_changed.emit(coord)
