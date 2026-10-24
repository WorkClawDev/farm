extends Node

## Game Flow Integration Test
## Runs as a normal project scene so autoloads are initialized before scenes compile.

const SCENES := [
	{"name": "主菜单", "path": "res://src/ui/menus/MainMenu.tscn"},
	{"name": "农场", "path": "res://src/world/maps/Farm.tscn"},
	{"name": "玩家房屋", "path": "res://src/world/maps/PlayerHouse.tscn"},
	{"name": "村庄", "path": "res://src/world/maps/Village.tscn"},
	{"name": "森林", "path": "res://src/world/maps/Forest.tscn"},
	{"name": "海滩", "path": "res://src/world/maps/Beach.tscn"},
	{"name": "矿洞", "path": "res://src/world/maps/Mine.tscn"},
]

const DATA_FILES := [
	"res://data/items.json",
	"res://data/crops.json",
	"res://data/npcs.json",
	"res://data/quests.json",
	"res://data/recipes.json",
]

const REQUIRED_AUTOLOADS := [
	"GameManager",
	"TimeManager",
	"SaveManager",
	"Inventory",
	"FarmState",
]

var _total := 0
var _passed := 0
var _failures: Array[String] = []


func _ready() -> void:
	print("============================================================")
	print("田园物语 - 游戏流程集成测试")
	print("============================================================")
	await get_tree().process_frame

	for autoload_name in REQUIRED_AUTOLOADS:
		_record(
			"AutoLoad %s 已初始化" % autoload_name,
			get_node_or_null("/root/" + autoload_name) != null
		)

	for path in DATA_FILES:
		_record("%s 数据有效" % path.get_file(), _is_valid_json(path))

	for scene_info in SCENES:
		await _exercise_scene(str(scene_info.name), str(scene_info.path))

	await _exercise_actor_collisions()
	await _exercise_golden_path()
	await _exercise_watering_can()
	await _exercise_tool_vs_hotbar_dispatch()
	await _exercise_tool_selection_across_scenes()
	await _exercise_json_save_compatibility()
	await _exercise_npc_dialogue_reentrancy()
	await _exercise_morning_npcs()
	await _exercise_npc_go_home()
	await _exercise_dialogue_close_real_keys()
	await _exercise_map_menu_keys()
	await _exercise_idle_breathing()
	await _exercise_interact_prompt()
	await _exercise_hoe_facing_and_swing_lock()
	await _exercise_npc_crowd_squeeze()
	_finish()


func _exercise_scene(scene_name: String, scene_path: String) -> void:
	_record("%s场景存在" % scene_name, ResourceLoader.exists(scene_path))
	if not ResourceLoader.exists(scene_path):
		return

	var packed := load(scene_path) as PackedScene
	_record("%s场景可加载" % scene_name, packed != null)
	if packed == null:
		return

	var instance := packed.instantiate()
	_record("%s场景可实例化" % scene_name, instance != null)
	if instance == null:
		return

	_record("%s根脚本已加载" % scene_name, instance.get_script() != null)
	add_child(instance)
	await get_tree().process_frame
	await get_tree().physics_frame
	_record("%s场景可运行" % scene_name, is_instance_valid(instance) and instance.is_inside_tree())
	if scene_name != "主菜单":
		_record("%s包含可控制玩家" % scene_name, instance.find_child("Player", true, false) is Player)

	if scene_path in [
		"res://src/world/maps/PlayerHouse.tscn",
		"res://src/world/maps/Village.tscn",
		"res://src/world/maps/Forest.tscn",
		"res://src/world/maps/Beach.tscn",
		"res://src/world/maps/Mine.tscn",
	]:
		var content_name := "%sMap" % scene_path.get_file().get_basename()
		var authored_map := instance.get_node_or_null(content_name) as EditableMap2D
		var illustrated_backdrop := authored_map.get_node_or_null("Decoration/IllustratedBackdrop") if authored_map else null
		var ground := authored_map.get_layer(&"ground") if authored_map else null
		_record(
			"%s 使用正式绘本地图" % scene_name,
			illustrated_backdrop != null and illustrated_backdrop.get_script() != null
		)
		_record(
			"%s 不再显示占位图块" % scene_name,
			instance.get_node_or_null("TileMap") == null and ground is TileMapLayer
		)
		_record("%s 使用统一 HUD" % scene_name, instance.get_node_or_null("HUD") != null)

	if scene_path == "res://src/world/maps/Village.tscn":
		var sample_npc := instance.get_node_or_null("NPCs/MayorThomas")
		var mayor_sprite := sample_npc.get_node_or_null("Sprite2D") as Sprite2D if sample_npc else null
		_record("村民使用 Ninja 精灵表（无矢量插画）", sample_npc != null and sample_npc.get_node_or_null("VillagerIllustration") == null
			and mayor_sprite != null and mayor_sprite.visible and mayor_sprite.hframes >= 8
			and mayor_sprite.texture != null and mayor_sprite.texture.get_width() == 512)
	elif scene_path == "res://src/world/maps/Forest.tscn":
		var forage_points := instance.get_node_or_null("ForagePoints")
		var sample_forage := (
			forage_points.get_child(0)
			if forage_points and forage_points.get_child_count() > 0
			else null
		)
		_record("采集物使用透明矢量图标", sample_forage != null and sample_forage.get_node_or_null("ForageIllustration") != null)
	elif scene_path == "res://src/world/maps/Mine.tscn":
		var ores := instance.get_node_or_null("Ores")
		var sample_ore := ores.get_child(0) if ores and ores.get_child_count() > 0 else null
		_record("矿石使用无毛边矢量图标", sample_ore != null and sample_ore.get_node_or_null("OreIllustration") != null)
		_record("矿石血条默认隐藏", sample_ore != null and not sample_ore.get_node("HealthBar").visible)
		_record("矿石包含实体碰撞", sample_ore != null and sample_ore.get_node_or_null("SolidBody") is StaticBody2D)

	match scene_name:
		"农场":
			var layout_root := instance.get_node_or_null("FarmMap/Objects")
			var farm_tile_map := instance.get_node_or_null("FarmMap/Ground") as TileMapLayer
			var terrain_overlay := instance.get_node_or_null("FarmMap/TerrainOverlay") as TileMapLayer
			var farm_map := instance.get_node_or_null("FarmMap") as EditableMap2D
			var farm_player := instance.find_child("Player", true, false) as Player
			var farm_camera := farm_player.get_node_or_null("Camera2D") as Camera2D if farm_player != null else null
			_record(
				"农场摄像机被限制在 50x35 地图边缘内",
				farm_map != null and farm_map.camera_limits_match(farm_camera)
			)
			_record("农场加载全部8个布局对象", layout_root != null and layout_root.get_child_count() == 8)
			_record("农场房屋入口可用", instance.get_node_or_null("HouseEntrance") is Area2D)
			_record("农场村庄出口可用", instance.get_node_or_null("VillageExit") is Area2D)
			_record(
				"农场使用原生64px图块且不再放大占位图",
				farm_tile_map != null
					and farm_tile_map.scale == Vector2.ONE
					and farm_tile_map.tile_set.tile_size == Vector2i(64, 64)
			)
			var pond_tile_data := (
				terrain_overlay.get_cell_tile_data(Vector2i(3, 7))
				if terrain_overlay != null else null
			)
			_record(
				"池塘图块具备实体碰撞",
				pond_tile_data != null
					and pond_tile_data.get_collision_polygons_count(0) > 0
			)
			var barn := layout_root.get_node_or_null("Barn") as Barn if layout_root else null
			var barn_image := (
				barn.sprite.texture.get_image()
				if barn != null and barn.sprite != null and barn.sprite.texture != null
				else null
			)
			_record(
				"谷仓素材已去除方形背景",
				barn_image != null and barn_image.get_pixel(0, 0).a < 0.06
			)
		"玩家房屋":
			_record("房屋返回农场出口存在", instance.get_node_or_null("ExitArea") is Area2D)
			_record("房屋厨房交互点存在", instance.get_node_or_null("InteractionZones/Kitchen") is Kitchen)
		"村庄":
			var shopkeeper := instance.get_node_or_null("NPCs/Maria") as ShopNPC
			var mayor := instance.get_node_or_null("NPCs/MayorThomas") as NPC
			_record("种子商店NPC可交互", shopkeeper != null)
			for exit_name in ["ToFarmArea", "ToPlayerHouseArea", "ToBeachArea", "ToForestArea", "ToMineArea"]:
				_record("村庄出口%s存在" % exit_name, instance.get_node_or_null("TransitionAreas/" + exit_name) is Area2D)
			GameManager.is_game_active = true
			GameManager.current_state = GameManager.GameState.PLAYING
			TimeManager.current_time = 10.0
			if mayor.schedule:
				mayor.schedule.update(10.0, TimeManager.current_day, TimeManager.current_season)
			if shopkeeper.schedule:
				shopkeeper.schedule.update(10.0, TimeManager.current_day, TimeManager.current_season)
			_record("白天NPC允许交互", mayor.can_interact() and shopkeeper.can_interact())
			mayor.interact()
			await get_tree().process_frame
			_record("NPC交互会打开真实对话框", DialogueManager.is_in_dialogue())
			DialogueManager.force_end_dialogue()
			_record("关闭对话后恢复玩家控制", GameManager.current_state == GameManager.GameState.PLAYING)
			shopkeeper.interact()
			await get_tree().process_frame
			_record("店主交互会打开种子商店", shopkeeper.shop_ui != null and shopkeeper.shop_ui.visible)
			if shopkeeper.shop_ui:
				_record("种子商店全部货架商品可显示", shopkeeper.shop_ui.item_list.item_count == 10)
				shopkeeper.shop_ui._on_close_button_pressed()
			_record("关闭商店后恢复玩家控制", GameManager.current_state == GameManager.GameState.PLAYING)
			GameManager.is_game_active = false
		"森林":
			_record("森林返回村庄出口存在", instance.get_node_or_null("TransitionAreas/ToFarmArea") is Area2D)
		"海滩":
			_record("海滩返回村庄出口存在", instance.get_node_or_null("ExitToVillage") is Area2D)
		"矿洞":
			_record("矿洞返回地面出口存在", instance.get_node_or_null("Ladders/LadderUp") is Area2D)
	await _exercise_collision(instance, scene_path)
	instance.queue_free()
	await get_tree().process_frame


func _exercise_collision(instance: Node, scene_path: String) -> void:
	var player := instance.find_child("Player", true, false) as CharacterBody2D
	if player == null:
		return

	_record("玩家碰撞遮罩包含世界实体", (player.collision_mask & 1) != 0)
	_record("玩家碰撞遮罩包含 NPC", (player.collision_mask & 4) != 0)

	var content_name := "%sMap" % scene_path.get_file().get_basename()
	var authored_map := instance.get_node_or_null(content_name) as EditableMap2D
	var layout := authored_map.get_layer(&"collision") if authored_map else null
	_record(
		"场景包含实体碰撞布局",
		layout != null and layout.get_child_count() > 0
	)

	var start := Vector2.ZERO
	var motion := Vector2.ZERO
	var label := ""
	match scene_path:
		"res://src/world/maps/Farm.tscn":
			var shipping_bin := instance.find_child("ShippingBin", true, false) as Node2D
			_record(
				"出货箱包含实体碰撞",
				shipping_bin != null and shipping_bin.get_node_or_null("SolidBody") is StaticBody2D
			)
			var workbench := instance.find_child("Workbench", true, false) as Node2D
			_record(
				"工作台包含实体碰撞",
				workbench != null and workbench.get_node_or_null("SolidBody") is StaticBody2D
			)
			if shipping_bin:
				start = shipping_bin.global_position + Vector2(0, 100)
				motion = Vector2(0, -150)
				label = "玩家不能穿过出货箱"
		"res://src/world/maps/PlayerHouse.tscn":
			start = Vector2(400, 300)
			motion = Vector2(0, -180)
			label = "玩家不能穿过室内桌子"
		"res://src/world/maps/Village.tscn":
			start = Vector2(420, 500)
			motion = Vector2(0, -250)
			label = "玩家不能穿过村庄水井"
		"res://src/world/maps/Forest.tscn":
			start = Vector2(600, 200)
			motion = Vector2(300, 0)
			label = "玩家不能从非桥梁位置穿过河流"
		"res://src/world/maps/Beach.tscn":
			start = Vector2(0, 40)
			motion = Vector2(0, 160)
			label = "玩家不能走入海水"
		"res://src/world/maps/Mine.tscn":
			start = Vector2(400, 650)
			motion = Vector2(-600, 0)
			label = "玩家不能穿过矿洞边界"

	if not label.is_empty():
		player.global_position = start
		player.velocity = Vector2.ZERO
		var collision := player.move_and_collide(motion)
		_record(label, collision != null)

	if scene_path == "res://src/world/maps/Village.tscn":
		var mayor := instance.get_node_or_null("NPCs/MayorThomas") as CharacterBody2D
		if mayor:
			player.global_position = mayor.global_position + Vector2(80, 0)
			var npc_collision := player.move_and_collide(Vector2(-120, 0))
			_record("玩家不能穿过村民", npc_collision != null and npc_collision.get_collider() == mayor)
			player.global_position = mayor.global_position + Vector2(40, 0)
			await get_tree().physics_frame
			await get_tree().physics_frame
			_record("碰撞不会阻断村民交互", player.get("npc_in_range") == mayor)
	elif scene_path == "res://src/world/maps/Farm.tscn":
		var boundary_cases := [
			{"name": "NorthBoundary", "start": Vector2(2500, 48), "motion": Vector2(0, -128)},
			{"name": "SouthBoundary", "start": Vector2(2500, 2192), "motion": Vector2(0, 128)},
			{"name": "WestBoundary", "start": Vector2(48, 1800), "motion": Vector2(-128, 0)},
			{"name": "EastBoundary", "start": Vector2(3152, 1800), "motion": Vector2(128, 0)},
		]
		for boundary_case in boundary_cases:
			player.global_position = boundary_case.start
			var boundary_collision := player.move_and_collide(boundary_case.motion)
			var expected_boundary := instance.get_node_or_null("FarmMap/Collision/" + boundary_case.name)
			_record(
				"玩家不能穿过农场%s" % boundary_case.name,
				boundary_collision != null and boundary_collision.get_collider() == expected_boundary
			)
		var barn := instance.find_child("Barn", true, false) as Node2D
		if barn:
			var barn_visual_center := (
				barn.global_position
				- Vector2(0, float(barn.call("get_depth_anchor_offset")))
			)
			player.global_position = barn_visual_center + Vector2(0, 104)
			await get_tree().physics_frame
			await get_tree().physics_frame
			_record("谷仓实体碰撞外仍可交互", player.get("building_in_range") == barn)
		var workbench := instance.find_child("Workbench", true, false) as Node2D
		if workbench:
			var workbench_visual_center := (
				workbench.global_position
				- Vector2(0, float(workbench.call("get_depth_anchor_offset")))
			)
			player.global_position = workbench_visual_center + Vector2(0, 48)
			await get_tree().physics_frame
			await get_tree().physics_frame
			_record("工作台实体碰撞外仍可交互", bool(workbench.get("_player_in_range")))
		var house := instance.find_child("PlayerHouseExterior", true, false) as HouseExterior
		var house_entrance := instance.get_node_or_null("HouseEntrance") as Area2D
		if house and house_entrance:
			var house_shape := house.get_node("CollisionShape2D").shape as RectangleShape2D
			var layout_root := instance.get_node_or_null("FarmMap/Objects") as Node2D
			_record(
				"Farm world and layout objects share Y depth sorting",
				layout_root != null
					and layout_root.y_sort_enabled
					and player.z_index == 0
					and house.get_node("Sprite2D").z_index == 0
			)
			var depth_sorted_objects := [
				instance.find_child("ShippingBin", true, false),
				instance.find_child("Workbench", true, false),
				instance.find_child("Coop", true, false),
				instance.find_child("Barn", true, false),
			]
			var all_objects_use_ground_depth := true
			for world_object in depth_sorted_objects:
				if (
					world_object == null
					or world_object.get_node_or_null("Sprite2D") == null
					or world_object.get_node("Sprite2D").z_index != 0
					or float(world_object.call("get_depth_anchor_offset")) <= 0.0
				):
					all_objects_use_ground_depth = false
					break
			_record(
				"Farm buildings and stations use ground depth anchors",
				all_objects_use_ground_depth
			)
			_record(
				"Farm house depth anchor uses the illustrated foundation",
				house.get_depth_anchor_offset()
					>= house.get_display_size().y * HouseExterior.FOOTPRINT_Y_RATIO
					and absf(
						house.global_position.y
							- house.get_visual_center_global_position().y
							- house.get_depth_anchor_offset()
					) < 0.1
			)
			_record(
				"Farm house footprint covers the illustrated foundation",
				house_shape != null
					and house_shape.size.x >= house.get_display_size().x * 0.85
					and house_shape.size.y <= house.get_display_size().y * 0.2
			)
			_record(
				"Farm house entrance is aligned to the illustrated door",
				house_entrance.global_position.distance_to(house.get_door_global_position()) < 0.1
					and house_entrance.global_position.x < house.global_position.x - 30.0
			)
			var entrance_cs := house_entrance.get_node("CollisionShape2D") as CollisionShape2D
			var entrance_rect := Rect2(
				entrance_cs.global_position - (entrance_cs.shape as RectangleShape2D).size * 0.5,
				(entrance_cs.shape as RectangleShape2D).size
			)
			_record(
				"BUG-59 farm house entrance only covers the porch steps",
				entrance_rect.size.x <= 48.0 and entrance_rect.end.y <= house.get_door_global_position().y + 0.1
			)
			# BUG-59: standing on the steps while walking west must not enter the house.
			player.global_position = house.get_door_global_position() + Vector2(0, -2)
			player.current_direction = Player.Direction.LEFT
			player.is_walking = true
			await get_tree().physics_frame
			await get_tree().physics_frame
			_record(
				"BUG-59 walking past the door along the road does not enter the house",
				not bool(instance.get("_entering_house"))
			)
			player.is_walking = false
			player.current_direction = Player.Direction.DOWN
			player.global_position = house.get_door_global_position() + Vector2(0, 72)
			await get_tree().physics_frame
			if ResourceLoader.exists("res://assets/private/topdown_farm/buildings/x4/Houses_x4.png"):
				for building_name in ["Coop", "Barn"]:
					var building := instance.find_child(building_name, true, false) as Node2D
					var building_shape := (
						building.get_node("CollisionShape2D").shape as RectangleShape2D
						if building else null
					)
					var building_sprite := building.get_node("Sprite2D") as Sprite2D if building else null
					var drawn_width := (
						building_sprite.texture.get_size().x * building_sprite.scale.x
						if building_sprite and building_sprite.texture else 0.0
					)
					_record(
						"BUG-58 %s footprint spans the CraftPix walls" % building_name,
						building_shape != null and building_shape.size.x >= drawn_width * 0.85
					)
			house_entrance.set_deferred("monitoring", false)
			await get_tree().physics_frame
			var house_center := house.get_visual_center_global_position()
			for side_offset in [-80.0, 80.0]:
				player.global_position = house_center + Vector2(side_offset, 130)
				var house_collision := player.move_and_collide(Vector2(0, -200))
				_record(
					"Player cannot enter the farm house through its %s wall"
						% ("left" if side_offset < 0.0 else "right"),
					house_collision != null and house_collision.get_collider() == house
				)
			player.global_position = house_center + Vector2(125, 130)
			var outside_house_collision := player.move_and_collide(Vector2(0, -200))
			_record(
				"Farm house collision does not extend beyond the artwork",
				outside_house_collision == null
			)
			house_entrance.set_deferred("monitoring", true)

		player.global_position = Vector2(520, 460)
		var pond_collision := player.move_and_collide(Vector2(-220, 0))
		_record(
			"Player cannot walk through the farm pond",
			pond_collision != null and pond_collision.get_collider() == instance.get_node("FarmMap/TerrainOverlay")
		)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var pond_fishing_spot := instance.find_child("FishingSpot", true, false)
		_record(
			"Farm pond remains fishable from the shoreline",
			pond_fishing_spot != null and bool(pond_fishing_spot.get("is_player_in_range"))
		)
		# BUG-55: debug F9 spawner puts one of each animal on free farm ground.
		player.global_position = Vector2(300, 140)
		await get_tree().physics_frame
		var debug_animals: Array = instance.call("debug_spawn_animals")
		await get_tree().physics_frame
		await get_tree().physics_frame
		_record("Debug F9 spawns chicken/pig/cow/sheep/horse on the farm", debug_animals.size() == 5)
		var actor_layer := instance.get_node_or_null("Actors") as Node2D
		var same_sort_layer := actor_layer != null and actor_layer.y_sort_enabled and actor_layer.z_index == player.z_index
		for debug_animal in debug_animals:
			same_sort_layer = same_sort_layer and (debug_animal as Node).get_parent() == actor_layer
		_record("Farm animals Y-sort with the player in one Actors layer", same_sort_layer)
		var debug_clear := not debug_animals.is_empty()
		var debug_types: Array[String] = []
		for debug_animal in debug_animals:
			debug_types.append(str(debug_animal.animal_type))
			if debug_animal.test_move(debug_animal.global_transform, Vector2.ZERO):
				debug_clear = false
		_record("Debug-spawned animals are not stuck in collision", debug_clear)
		_record(
			"Debug spawner covers every animal type",
			debug_types.has("chicken") and debug_types.has("pig") and debug_types.has("cow")
				and debug_types.has("sheep") and debug_types.has("horse")
		)
		for debug_animal in debug_animals:
			debug_animal.queue_free()
		await get_tree().physics_frame
	elif scene_path == "res://src/world/maps/PlayerHouse.tscn":
		var kitchen := instance.get_node_or_null("InteractionZones/Kitchen")
		if kitchen:
			player.global_position = kitchen.global_position
			await get_tree().physics_frame
			await get_tree().physics_frame
			_record("炉灶实体碰撞外仍可烹饪", bool(kitchen.get("is_player_in_range")))
	elif scene_path == "res://src/world/maps/Forest.tscn":
		player.global_position = Vector2(650, 365)
		var bridge_collision := player.move_and_collide(Vector2(300, 0))
		_record("森林桥梁保持可通行", bridge_collision == null)
	elif scene_path == "res://src/world/maps/Beach.tscn":
		player.global_position = Vector2(0, 40)
		player.move_and_collide(Vector2(0, 100))
		await get_tree().physics_frame
		await get_tree().physics_frame
		var fishing_spot := instance.get_node_or_null("FishingSpots/FishingSpot2")
		_record("海水碰撞外仍可在岸边钓鱼", fishing_spot != null and bool(fishing_spot.get("is_player_in_range")))
	elif scene_path == "res://src/world/maps/Mine.tscn":
		var ores := instance.get_node_or_null("Ores")
		var sample_ore: Node2D = null
		if ores and ores.get_child_count() > 0:
			sample_ore = ores.get_child(0) as Node2D
		if sample_ore:
			player.global_position = sample_ore.global_position + Vector2(80, 0)
			var ore_collision := player.move_and_collide(Vector2(-120, 0))
			_record(
				"玩家不能穿过矿石",
				ore_collision != null
					and ore_collision.get_collider() is StaticBody2D
					and ore_collision.get_collider().get_parent() is Ore
			)



func _assert_animal_private_art(animal: Animal, animal_label: String) -> void:
	var sheet_animals := ["Chicken", "Pig", "Cow", "Sheep"]
	var sprite := animal.get_node_or_null("Sprite2D") as Sprite2D
	var has_private := ResourceLoader.exists("res://assets/private/topdown_farm/animals/x4/chicken_sheet_x4.png")
	if animal_label in sheet_animals:
		if has_private:
			_record("%s anim_sprite present with private art" % animal_label, animal.anim_sprite != null)
			if animal.anim_sprite != null:
				var frames: SpriteFrames = animal.anim_sprite.sprite_frames
				_record("%s has 8 directional animations" % animal_label, frames != null and frames.get_animation_names().size() >= 8)
				if frames != null and frames.has_animation("idle_down"):
					_record("%s idle speed is 10 FPS" % animal_label, is_equal_approx(frames.get_animation_speed("idle_down"), 10.0))
					var expect_idle := 6 if animal_label == "Chicken" else 4
					_record("%s idle_down frame count" % animal_label, frames.get_frame_count("idle_down") == expect_idle)
				_record("%s Sprite2D hidden when animated" % animal_label, sprite != null and sprite.visible == false)
				var expect_scale := 0.8 if animal_label in ["Pig", "Cow", "Sheep"] else 1.0
				_record(
					"%s private sprite scale is %.1f" % [animal_label, expect_scale],
					animal.anim_sprite.scale.is_equal_approx(Vector2.ONE * expect_scale)
				)
		else:
			_record("%s anim_sprite null without private art" % animal_label, animal.anim_sprite == null)
			_record("%s Sprite2D visible without private art" % animal_label, sprite != null and sprite.visible == true)
			if sprite and sprite.texture:
				_record(
					"%s fallback texture is public sprites" % animal_label,
					str(sprite.texture.resource_path).begins_with("res://assets/sprites/animals/")
				)
	else:
		_record("%s leaves anim_sprite unset" % animal_label, animal.anim_sprite == null)
		_record("%s Sprite2D remains visible" % animal_label, sprite != null and sprite.visible == true)


func _exercise_actor_collisions() -> void:
	print("------------------------------------------------------------")
	print("Actor collision matrix: player <-> animals / enemies")

	var arena := Node2D.new()
	arena.name = "ActorCollisionArena"
	add_child(arena)

	var player_scene := load("res://src/entities/player/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as Player if player_scene else null
	_record("Player scene available for actor collision tests", player != null)
	if player == null:
		arena.queue_free()
		return
	arena.add_child(player)
	player.set_physics_process(false)
	await get_tree().physics_frame
	_record("Player collision mask includes actor layer", (player.collision_mask & 4) != 0)

	var animal_paths := [
		"res://src/entities/animals/Chicken.tscn",
		"res://src/entities/animals/Cow.tscn",
		"res://src/entities/animals/Horse.tscn",
		"res://src/entities/animals/Pig.tscn",
		"res://src/entities/animals/Sheep.tscn",
	]
	for path in animal_paths:
		var packed := load(path) as PackedScene
		var animal := packed.instantiate() as Animal if packed else null
		var animal_label: String = str(path).get_file().get_basename()
		_record("%s can instantiate" % animal_label, animal != null)
		if animal == null:
			continue
		arena.add_child(animal)
		animal.set_physics_process(false)
		animal.global_position = Vector2.ZERO
		player.global_position = Vector2(100, 0)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame

		_assert_animal_private_art(animal, animal_label)

		var body_shape := animal.get_node("CollisionShape2D").shape as CircleShape2D
		var interaction_shape := (
			animal.get_node("InteractionArea/CollisionShape2D").shape as CircleShape2D
		)
		_record(
			"%s interaction remains reachable outside its solid body" % animal_label,
			body_shape != null
				and interaction_shape != null
				and interaction_shape.radius > body_shape.radius + 24.0
		)

		var collision := player.move_and_collide(Vector2(-160, 0))
		_record(
			"Player cannot pass through %s" % animal_label,
			collision != null and collision.get_collider() == animal
		)
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.call("_refresh_nearest_animal")
		_record(
			"Player can still interact with %s after collision" % animal_label,
			player.animal_in_range == animal
		)

		player.global_position = Vector2(300, 0)
		animal.queue_free()
		await get_tree().physics_frame

	var enemy_paths := [
		"res://src/entities/enemies/Slime.tscn",
		"res://src/entities/enemies/Bat.tscn",
	]
	for path in enemy_paths:
		var packed := load(path) as PackedScene
		var enemy := packed.instantiate() as Enemy if packed else null
		var enemy_label: String = str(path).get_file().get_basename()
		_record("%s can instantiate" % enemy_label, enemy != null)
		if enemy == null:
			continue
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.global_position = Vector2.ZERO
		player.global_position = Vector2(100, 0)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
		var collision := player.move_and_collide(Vector2(-160, 0))
		_record(
			"Player cannot pass through %s" % enemy_label,
			collision != null and collision.get_collider() == enemy
		)
		player.global_position = Vector2(300, 0)
		enemy.queue_free()
		await get_tree().physics_frame

	arena.queue_free()
	await get_tree().process_frame


func _exercise_golden_path() -> void:
	print("------------------------------------------------------------")
	print("黄金路径：新档 -> 耕种 -> 生长 -> 收获 -> 出货 -> 结算")
	TimeManager.reset()
	MoneySystem.reset()
	Inventory.reset_with_starter_items()
	ShippingSystem.reset()
	FarmState.reset()
	QuestSystem.reset()
	QuestSystem.start_tutorial()

	_record("新档有15包萝卜种子", Inventory.get_item_count("turnip_seed") == 15)
	_record("首日种植任务自动接取", QuestSystem.get_quest_state("tutorial_farming") == QuestSystem.QuestState.ACTIVE)
	_record("首日村庄任务自动接取", QuestSystem.get_quest_state("village_introduction") == QuestSystem.QuestState.ACTIVE)

	var coords := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	for coord in coords:
		_record("耕地%s" % coord, FarmState.till(coord))
		_record("播种%s" % coord, FarmState.plant(coord, "turnip_seed"))

	for day in range(4):
		for coord in coords:
			_record("第%d天浇水%s" % [day + 1, coord], FarmState.water(coord))
		FarmState.advance_day()

	for coord in coords:
		_record("作物%s成熟" % coord, FarmState.can_harvest(coord))

	var harvested := 0
	for coord in coords:
		var result := FarmState.harvest(coord)
		_record("收获%s成功" % coord, not result.is_empty())
		if not result.is_empty():
			var quantity := int(result.get("quantity", 0))
			harvested += quantity
			EventBus.farm.crop_harvested.emit(
				str(result.get("crop_id", "")),
				int(result.get("quality", 0)),
				quantity
			)

	_record("收获物进入背包", harvested >= 3 and Inventory.get_item_count("turnip") == harvested)
	_record("种植教学目标完成", QuestSystem.get_quest_state("tutorial_farming") == QuestSystem.QuestState.COMPLETED)
	_record("收获物可放入出货箱", ShippingSystem.deposit_from_inventory("turnip", harvested))
	var money_before := MoneySystem.get_money()
	var shipment := ShippingSystem.process_shipment()
	_record("次日出货成功结算", bool(shipment.get("success", false)))
	_record("出货增加金钱", MoneySystem.get_money() > money_before)
	_record("出货箱结算后清空", ShippingSystem.get_total_items() == 0)

	var farm_snapshot := FarmState.get_save_state()
	var inventory_snapshot := Inventory.save_state()
	var money_snapshot := MoneySystem.save_state()
	FarmState.reset()
	Inventory.reset_with_starter_items()
	MoneySystem.reset()
	_record("农场状态可恢复", FarmState.load_save_state(farm_snapshot))
	Inventory.load_state(inventory_snapshot)
	MoneySystem.load_state(money_snapshot)
	_record("背包状态可恢复", Inventory.get_item_count("turnip") == 0)
	_record("金钱状态可恢复", MoneySystem.get_money() > money_before)


func _spawn_farm() -> Node:
	var farm := (load("res://src/world/maps/Farm.tscn") as PackedScene).instantiate()
	add_child(farm)
	await get_tree().process_frame
	await get_tree().physics_frame
	return farm


func _exercise_watering_can() -> void:
	print("------------------------------------------------------------")
	print("BUG-12 水壶：按次扣水、空了不浇不扣体力、跨场景保留、水边装满")
	TimeManager.reset()
	Inventory.reset_with_starter_items()
	FarmState.reset()
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	var farm = await _spawn_farm()
	var player := farm.find_child("Player", true, false) as Player
	_record("水壶场景有玩家", player != null)
	if player == null:
		farm.queue_free()
		return
	player.tool_manager.equip_tool(ToolManager.ToolType.WATERING_CAN)
	# 快捷栏选一个空格子，只测浇水（选种子时的行为见 BUG-14 用例）。
	Inventory.set_selected_hotbar_index(Inventory.HOTBAR_SIZE - 1)
	var can_type := ToolManager.ToolType.WATERING_CAN
	var max_uses := FarmState.get_watering_can_max_uses()
	_record("新档水壶是满的(%d次)" % max_uses, max_uses > 0 and FarmState.get_watering_can_uses_left() == max_uses)
	var can_node = player.tool_manager.tools.get(can_type)
	_record("WateringCan 节点水量与 FarmState 一致", can_node != null and can_node.current_water == FarmState.get_watering_can_water())

	var coords: Array[Vector2i] = []
	for i in range(max_uses + 1):
		var coord := Vector2i(i % FarmState.GRID_WIDTH, i / FarmState.GRID_WIDTH)
		FarmState.till(coord)
		coords.append(coord)

	var stamina := StaminaManager.current_stamina
	farm.perform_farm_action(Vector2i(FarmState.GRID_WIDTH - 1, FarmState.GRID_HEIGHT - 1), can_type)
	_record("浇未翻的地不扣水不扣体力",
		FarmState.get_watering_can_uses_left() == max_uses and StaminaManager.current_stamina == stamina)

	player.tool_manager.use_tool(null)
	_record("对着空地用水壶不扣水", FarmState.get_watering_can_uses_left() == max_uses)

	var decreased_each_time := true
	for i in range(max_uses):
		farm.perform_farm_action(coords[i], can_type)
		decreased_each_time = decreased_each_time and FarmState.get_watering_can_uses_left() == max_uses - i - 1 \
			and int(FarmState.get_cell(coords[i]).state) == FarmState.WATERED
	_record("每浇一格水壶少一次", decreased_each_time)
	_record("浇满%d格后水壶空了" % max_uses, FarmState.get_watering_can_uses_left() == 0 and not FarmState.has_watering_charge())
	_record("成功浇水才扣体力", is_equal_approx(StaminaManager.current_stamina, stamina - 2.0 * max_uses))

	stamina = StaminaManager.current_stamina
	farm.perform_farm_action(coords[max_uses], can_type)
	_record("空水壶不浇水", int(FarmState.get_cell(coords[max_uses]).state) == FarmState.TILLED)
	_record("空水壶不扣体力", StaminaManager.current_stamina == stamina)

	FarmState.refill_watering_can()
	farm.perform_farm_action(coords[0], can_type)
	_record("已浇过的格子再浇不扣水不扣体力",
		FarmState.get_watering_can_uses_left() == max_uses and StaminaManager.current_stamina == stamina)
	FarmState.set_watering_can_water(0)

	farm.queue_free()
	await get_tree().process_frame
	farm = await _spawn_farm()
	player = farm.find_child("Player", true, false) as Player
	_record("切场景后水壶不会被重新灌满", FarmState.get_watering_can_uses_left() == 0)

	var spot := farm.find_child("FishingSpot", true, false) as FishingSpot
	_record("农场池塘有水源", spot != null)
	if spot != null and player != null:
		player.tool_manager.equip_tool(ToolManager.ToolType.WATERING_CAN)
		spot.current_player = player
		spot.is_player_in_range = true
		spot._start_fishing()
		spot.is_player_in_range = false
		spot.current_player = null
	_record("拿水壶在池塘边可装满", FarmState.get_watering_can_uses_left() == max_uses)
	farm.perform_farm_action(coords[max_uses], can_type)
	_record("装满后可以继续浇水", int(FarmState.get_cell(coords[max_uses]).state) == FarmState.WATERED
		and FarmState.get_watering_can_uses_left() == max_uses - 1)

	var snapshot := FarmState.get_save_state()
	FarmState.reset()
	FarmState.load_save_state(_json_round_trip(snapshot))
	_record("水壶水量随存档恢复", FarmState.get_watering_can_uses_left() == max_uses - 1)
	_record("旧存档没有水量字段时按满水", (func():
		var legacy := snapshot.duplicate(true)
		legacy.erase("watering_can_water")
		FarmState.set_watering_can_water(0)
		FarmState.load_save_state(legacy)
		return FarmState.get_watering_can_uses_left() == max_uses).call())

	farm.queue_free()
	await get_tree().process_frame
	FarmState.reset()
	Inventory.reset_with_starter_items()
	StaminaManager.set_stamina(StaminaManager.max_stamina)


func _find_hotkey_bar(node: Node) -> HotkeyBar:
	if node is HotkeyBar:
		return node
	for child in node.get_children():
		var found := _find_hotkey_bar(child)
		if found:
			return found
	return null


func _exercise_tool_vs_hotbar_dispatch() -> void:
	print("------------------------------------------------------------")
	print("BUG-14 拿着工具只用工具；按数字键选种子才播种")
	TimeManager.reset()
	Inventory.reset_with_starter_items()
	FarmState.reset()
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	var farm = await _spawn_farm()
	var player := farm.find_child("Player", true, false) as Player
	var hotbar := _find_hotkey_bar(farm)
	_record("调度用例有玩家和快捷栏", player != null and hotbar != null)
	if player == null or hotbar == null:
		farm.queue_free()
		return
	var tm: ToolManager = player.tool_manager
	var hoe := ToolManager.ToolType.HOE
	var seeds := Inventory.get_item_count("turnip_seed")
	_record("开局拿锄头且快捷栏选着种子",
		tm.get_current_tool_type() == hoe and Inventory.get_selected_item_id() == "turnip_seed")

	var a := Vector2i(0, 0)
	farm.perform_farm_action(a, tm.get_current_tool_type())
	_record("锄头翻地", int(FarmState.get_cell(a).state) == FarmState.TILLED)
	var stamina := StaminaManager.current_stamina
	for i in range(3):
		farm.perform_farm_action(a, tm.get_current_tool_type())
	_record("选着种子时锄头对耕地按空格不播种",
		Dictionary(FarmState.get_cell(a).crop).is_empty() and Inventory.get_item_count("turnip_seed") == seeds)
	_record("锄头对已翻的地不扣体力", StaminaManager.current_stamina == stamina)

	tm.equip_tool(ToolManager.ToolType.WATERING_CAN)
	farm.perform_farm_action(a, tm.get_current_tool_type())
	_record("选着种子时水壶只浇水不播种",
		int(FarmState.get_cell(a).state) == FarmState.WATERED
			and Dictionary(FarmState.get_cell(a).crop).is_empty()
			and Inventory.get_item_count("turnip_seed") == seeds)

	hotbar._select(0)
	_record("按数字键选种子会收起工具", tm.get_current_tool_type() == ToolManager.ToolType.NONE)
	farm.perform_farm_action(a, tm.get_current_tool_type())
	_record("手持种子对耕地播种",
		not Dictionary(FarmState.get_cell(a).crop).is_empty() and Inventory.get_item_count("turnip_seed") == seeds - 1)
	var b := Vector2i(1, 0)
	farm.perform_farm_action(b, tm.get_current_tool_type())
	_record("手持种子不能在未翻的地上播种",
		Dictionary(FarmState.get_cell(b).crop).is_empty() and Inventory.get_item_count("turnip_seed") == seeds - 1)

	tm.next_tool()
	_record("收起工具后按 R 拿回上次的工具(水壶)", tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN)
	hotbar._select(0)
	tm.previous_tool()
	_record("收起工具后按 Q 也拿回上次的工具", tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN)

	farm.queue_free()
	await get_tree().process_frame
	FarmState.reset()
	Inventory.reset_with_starter_items()
	StaminaManager.set_stamina(StaminaManager.max_stamina)


func _exercise_tool_selection_across_scenes() -> void:
	print("------------------------------------------------------------")
	print("BUG-15 切换场景后保留手上的工具 / 手持物品")
	Inventory.reset_with_starter_items()
	FarmState.reset()
	var farm = await _spawn_farm()
	var player := farm.find_child("Player", true, false) as Player
	_record("BUG-15 用例有玩家", player != null)
	if player == null:
		farm.queue_free()
		return
	_record("新游戏默认拿锄头", player.tool_manager.get_current_tool_type() == ToolManager.ToolType.HOE)
	player.tool_manager.equip_tool(ToolManager.ToolType.WATERING_CAN)

	farm.queue_free()
	await get_tree().process_frame
	farm = await _spawn_farm()
	player = farm.find_child("Player", true, false) as Player
	var tm: ToolManager = player.tool_manager
	_record("切场景后仍拿着水壶", tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN)
	_record("切场景后只显示水壶节点", (func():
		for tool_type in tm.tools.keys():
			if tm.tools[tool_type].visible != (tool_type == ToolManager.ToolType.WATERING_CAN):
				return false
		return true).call())

	var hotbar := _find_hotkey_bar(farm)
	if hotbar:
		hotbar._select(0)
	else:
		Inventory.set_selected_hotbar_index(0)
		tm.put_away_tool()
	_record("选种子后手持物品", tm.get_current_tool_type() == ToolManager.ToolType.NONE)

	farm.queue_free()
	await get_tree().process_frame
	farm = await _spawn_farm()
	player = farm.find_child("Player", true, false) as Player
	tm = player.tool_manager
	_record("切场景后仍手持快捷栏物品(种子)",
		tm.get_current_tool_type() == ToolManager.ToolType.NONE and Inventory.get_selected_item_id() == "turnip_seed")
	tm.next_tool()
	_record("切场景后按 R 回到上次的工具(水壶)", tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN)

	tm.equip_tool(ToolManager.ToolType.AXE)
	var inventory_snapshot := Inventory.save_state()
	Inventory.reset_with_starter_items()
	_record("新游戏重置回锄头", Inventory.get_equipped_tool() == ToolManager.ToolType.HOE)
	Inventory.load_state(_json_round_trip(inventory_snapshot))
	_record("手上工具随存档恢复", Inventory.get_equipped_tool() == ToolManager.ToolType.AXE
		and Inventory.get_last_tool() == ToolManager.ToolType.AXE)

	farm.queue_free()
	await get_tree().process_frame
	FarmState.reset()
	Inventory.reset_with_starter_items()


func _exercise_json_save_compatibility() -> void:
	print("------------------------------------------------------------")
	print("Save compatibility: untyped JSON arrays -> typed runtime arrays")

	var quest_snapshot := QuestSystem.save_state()
	var quest_save := _json_round_trip({
		"progress": {
			"tutorial_farming": {
				"state": QuestSystem.QuestState.ACTIVE,
				"objective_progress": [1, 2, -5],
				"start_day": 1,
				"start_season": 0,
				"start_year": 1,
			},
		},
		"active_quests": ["tutorial_farming", "tutorial_farming"],
		"completed_quests": [],
		"player_xp": 12,
		"player_level": 1,
	})
	QuestSystem.load_state(quest_save)
	var quest_progress = QuestSystem.get_quest_progress("tutorial_farming")
	_record("JSON任务进度数组可加载", quest_progress != null)
	_record(
		"JSON任务进度按目标数量修正",
		quest_progress != null
			and quest_progress.objective_progress.size() == 2
			and quest_progress.objective_progress == [1, 2]
	)
	QuestSystem.load_state(quest_snapshot)

	var inventory_manager := InventoryManager.new()
	add_child(inventory_manager)
	inventory_manager.load_state(_json_round_trip({
		"inventory": [
			{"item_id": "stone", "quantity": 9},
			{"item_id": "", "quantity": 3},
			"malformed",
		],
	}))
	_record("JSON背包数组可加载并过滤坏槽位", inventory_manager.get_item_quantity("stone") == 9)
	inventory_manager.queue_free()

	var price_manager := PriceManager.new()
	add_child(price_manager)
	price_manager.load_state(_json_round_trip({
		"prices": {},
		"current_event": {
			"type": PriceManager.MarketEventType.BOOM,
			"name": "Test event",
			"remaining_days": 2,
			"price_modifier": 1.2,
			"affected_categories": ["crops", "fish"],
		},
		"event_history": [{"name": "Previous event"}, "malformed"],
		"price_history": {},
	}))
	var market_event = price_manager.get_current_event()
	_record(
		"JSON市场事件分类数组可加载",
		market_event != null and market_event.affected_categories == ["crops", "fish"]
	)
	price_manager.queue_free()

	var fishing_snapshot := FishingSystem.save_state()
	FishingSystem.load_state(_json_round_trip({
		"total_fish_caught": 1,
		"total_fish_caught_by_location": {"beach": 1},
		"fish_caught_history": [
			{"fish_id": "sardine", "location": "beach"},
			"malformed",
		],
	}))
	_record(
		"JSON钓鱼历史数组可加载并过滤坏记录",
		FishingSystem.get_catch_history().size() == 1
			and FishingSystem.get_catch_history()[0].get("fish_id") == "sardine"
	)
	FishingSystem.load_state(fishing_snapshot)

	var achievement_snapshot := AchievementSystem.save_state()
	AchievementSystem.load_state(_json_round_trip({
		"unlocked": ["first_harvest", "first_harvest", "removed_achievement"],
		"stats": {
			"crops_harvested": 3,
			"fish_caught": 0,
			"money_earned": 0,
			"items_crafted": 0,
			"npcs_talked": ["mayor"],
			"levels_explored": [],
			"seeds_planted": 3,
			"days_played": 1,
		},
	}))
	_record(
		"JSON成就数组可加载并去重",
		AchievementSystem.get_unlocked_achievements() == ["first_harvest"]
	)
	AchievementSystem.load_state(achievement_snapshot)

	var inventory_snapshot := Inventory.save_state()
	var shipping_snapshot := ShippingSystem.save_state()
	Inventory.clear_inventory()
	ShippingSystem.clear_bin()
	Inventory.add_item("turnip", 3)
	var deposited := ShippingSystem.deposit_from_inventory("turnip", 2)
	var withdrawn := ShippingSystem.withdraw_to_inventory("turnip", 1)
	_record(
		"出货箱存入与取回保持物品守恒",
		deposited and withdrawn
			and Inventory.get_item_count("turnip") == 2
			and ShippingSystem.get_total_items() == 1
	)
	_record(
		"出货箱拒绝超量取回且不丢物品",
		not ShippingSystem.withdraw_to_inventory("turnip", 99)
			and Inventory.get_item_count("turnip") == 2
			and ShippingSystem.get_total_items() == 1
	)
	Inventory.load_state(inventory_snapshot)
	ShippingSystem.load_state(shipping_snapshot)

	var full_snapshot_value: Variant = SaveManager.call("_gather_snapshot")
	var full_snapshot: Dictionary = (
		full_snapshot_value if full_snapshot_value is Dictionary else {}
	)
	_record(
		"完整JSON全局快照可恢复",
		not full_snapshot.is_empty()
			and SaveManager.apply_global_snapshot(_json_round_trip(full_snapshot))
	)
	await get_tree().process_frame


func _json_round_trip(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _is_valid_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	return json.parse(file.get_as_text()) == OK


func _press_action(action: StringName, frames := 3) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	for i in frames:
		await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	for i in 2:
		await get_tree().physics_frame


## BUG-20: talking to the mayor recursed start_dialogue <-> EventBus.dialogue_started
## until the stack overflowed (the dialogue box cleared the NPC's shared line array).
func _exercise_npc_dialogue_reentrancy() -> void:
	print("------------------------------------------------------------")
	print("BUG-20 村长对话不递归、能正常结束、结束后不重开、Esc/J 可用")
	DialogueManager.reset()
	TimeManager.reset()
	TimeManager.current_time = 10.0
	var started := [0]
	var bus_started := [0]
	var on_started := func(_id: String): started[0] += 1
	var on_bus := func(_id: String): bus_started[0] += 1
	DialogueManager.dialogue_started.connect(on_started)
	EventBus.social.dialogue_started.connect(on_bus)

	# Direct guard checks: an empty dialogue is refused, an echo while talking is ignored.
	DialogueManager._dialogue_data["bug20_empty"] = {"only": {"id": "bug20_empty", "priority": 0, "conditions": [], "lines": []}}
	_record("空对话不会开始（不递归）", DialogueManager.start_dialogue("bug20_empty") == false and not DialogueManager.is_in_dialogue() and started[0] == 0)
	DialogueManager._dialogue_data.erase("bug20_empty")

	var village := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := village.find_child("Player", true, false) as Player
	var mayor := village.get_node_or_null("NPCs/MayorThomas") as NPC
	var box: DialogueBox = DialogueManager._dialogue_box
	_record("对话用例有玩家、村长和对话框", player != null and mayor != null and box != null)
	if player == null or mayor == null or box == null:
		village.queue_free()
		return
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	if mayor.schedule:
		mayor.schedule.update(10.0, TimeManager.current_day, TimeManager.current_season)
	var mayor_lines: Array = DialogueManager._dialogue_data["mayor"]["first_meeting"]["lines"]
	var line_count := mayor_lines.size()
	player.global_position = mayor.global_position + Vector2(0, 36)
	player.register_nearby_npc(mayor)

	await _press_action(&"interact")
	_record("按交互键开始村长对话一次", DialogueManager.is_in_dialogue() and started[0] == 1 and bus_started[0] <= 2)
	EventBus.social.dialogue_started.emit(mayor.npc_id)
	_record("对话中重复的开始事件被忽略", started[0] == 1 and DialogueManager.is_in_dialogue())

	var blank_pages := 0
	var steps := 0
	while box.visible and steps < 30:
		steps += 1
		box._finish_typewriter()
		if box.text_label.text.strip_edges().is_empty():
			blank_pages += 1
		await _press_action(&"interact")
	_record("村长对话能正常结束", not box.visible and not DialogueManager.is_in_dialogue() and steps < 30)
	_record("对话里没有空白页", blank_pages == 0)
	_record("对话数据没有被清空", mayor_lines.size() == line_count and line_count > 0)
	_record("选项分支生效（已认识村长）", bool(DialogueManager._player_flags.get("met_mayor", false)))
	_record("对话结束后恢复玩家控制", GameManager.current_state == GameManager.GameState.PLAYING)
	for i in 4:
		await get_tree().physics_frame
	_record("结束对话的那次按键不会重新开始对话/打开商店", started[0] == 1 and not DialogueManager.is_in_dialogue() and not UIManager.is_screen_open("shop"))

	# BUG-26 residual: one more press right after closing is still "closing", not "talk again".
	await _press_action(&"interact")
	_record("刚关闭对话马上再按 E 不会重新开始对话", started[0] == 1 and not DialogueManager.is_in_dialogue())
	await _wait_retalk_cooldown()
	await _press_action(&"interact")
	_record("再次交互能开始新对话且有内容", DialogueManager.is_in_dialogue() and started[0] == 2 and box.visible and not box.dialogue_lines.is_empty())
	DialogueManager.force_end_dialogue()
	await get_tree().physics_frame

	await _press_action(&"pause")
	var village_pause := village.get("pause_menu") as Control
	_record("对话后 Esc 能打开暂停菜单", GameManager.is_paused() and village_pause != null and village_pause.visible)
	await _press_action(&"pause")
	_record("再按 Esc 关闭暂停菜单", not GameManager.is_paused() and not get_tree().paused)
	await _press_action(&"journal")
	_record("对话后 J 能打开手册", UIManager.is_screen_open("journal"))
	UIManager.close_all()
	await get_tree().process_frame

	DialogueManager.dialogue_started.disconnect(on_started)
	EventBus.social.dialogue_started.disconnect(on_bus)
	player.unregister_nearby_npc(mayor)
	village.queue_free()
	await get_tree().process_frame
	DialogueManager.reset()
	GameManager.is_game_active = false


## BUG-31: from the 6:00 day start until ~9:00 the schedules said "sleep" while the NPCs
## stand in the village, so E did nothing (no dialogue, no shop).
func _exercise_morning_npcs() -> void:
	print("------------------------------------------------------------")
	print("BUG-31 早上 6:00-9:00 NPC 可以对话、商人可以开店；夜里按 E 有提示")
	DialogueManager.reset()
	TimeManager.reset()
	var village := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().physics_frame
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var player := village.find_child("Player", true, false) as Player
	var npcs: Array = village.get_node("NPCs").get_children().filter(func(n): return n is NPC)
	for hour in [6.0, 6.5, 7.25, 8.5]:
		var blocked: Array[String] = []
		for npc in npcs:
			if npc.schedule:
				npc.schedule.update(hour, TimeManager.current_day, TimeManager.current_season)
			if not npc.can_interact():
				blocked.append(npc.npc_name)
		_record("%.2f 点村里 %d 个 NPC 都能交互%s" % [hour, npcs.size(), "" if blocked.is_empty() else "（不能：%s）" % ", ".join(blocked)], blocked.is_empty() and npcs.size() >= 5)

	TimeManager.current_time = 6.5
	var mayor := village.get_node("NPCs/MayorThomas") as NPC
	var shop := village.get_node("NPCs/Maria") as NPC
	var started := [0]
	var on_started := func(_id: String): started[0] += 1
	DialogueManager.dialogue_started.connect(on_started)
	player.global_position = mayor.global_position + Vector2(0, 36)
	player.register_nearby_npc(mayor)
	await _press_action(&"interact")
	_record("6:30 按 E 和村长对话", DialogueManager.is_in_dialogue() and started[0] == 1)
	DialogueManager.force_end_dialogue()
	player.unregister_nearby_npc(mayor)
	for i in 4:
		await get_tree().physics_frame
	player.global_position = shop.global_position + Vector2(0, 36)
	player.register_nearby_npc(shop)
	await _wait_retalk_cooldown()
	await _press_action(&"interact")
	_record("6:30 按 E 商人打开商店", UIManager.is_screen_open("shop"))
	UIManager.close_all()
	shop.end_interaction()
	player.unregister_nearby_npc(shop)
	for i in 4:
		await get_tree().physics_frame

	# Night: still asleep by schedule, but E now explains instead of doing nothing.
	TimeManager.current_time = 23.0
	mayor.schedule.update(23.0, TimeManager.current_day, TimeManager.current_season)
	player.global_position = mayor.global_position + Vector2(0, 36)
	player.register_nearby_npc(mayor)
	await _wait_retalk_cooldown()
	await _press_action(&"interact")
	var rest_toast := false
	if UIManager._toast_root:
		for toast in UIManager._toast_root.get_children():
			rest_toast = rest_toast or str(toast.get_meta("toast_text", "")).contains("正在休息")
	_record("23:00 村长在休息：按 E 不开对话但有提示", not DialogueManager.is_in_dialogue() and started[0] == 1 and rest_toast)
	player.unregister_nearby_npc(mayor)
	DialogueManager.dialogue_started.disconnect(on_started)
	village.queue_free()
	await get_tree().process_frame
	DialogueManager.reset()
	TimeManager.reset()
	GameManager.is_game_active = false


## Evening sleep: walk to the own door, then rest hidden (no collision / interaction /
## prompt); entering during sleep time spawns them hidden; at wake-up they reappear at the door.
func _exercise_npc_go_home() -> void:
	print("------------------------------------------------------------")
	print("NPC 晚上回家：走到自家门口后隐藏，进村时已在睡觉则直接隐藏，起床在门口出现")
	DialogueManager.reset()
	TimeManager.reset()
	TimeManager.current_time = 19.9
	var village := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().physics_frame
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var player := village.find_child("Player", true, false) as Player
	player.global_position = Vector2(1100, 800)  # out of the way
	var walkers := {
		"Iron": Vector2(600, 350),   # blacksmith_tom, tavern until 20:00
		"John": Vector2(600, 350),   # farmer_joe, tavern until 20:00
		"Lily": Vector2(180, 520),   # doctor_mary, west side until 20:00
	}
	var npcs := {}
	for node_name in walkers:
		var npc := village.get_node("NPCs/%s" % node_name) as NPC
		npc.global_position = walkers[node_name]
		npcs[node_name] = npc
	await get_tree().physics_frame
	_record("19:54 三人都在村里、可见、未休息", npcs.values().all(func(n): return n.visible and not n.is_resting and not n.is_going_home))

	TimeManager.current_time = 20.0
	var start_distance := {}
	for node_name in npcs:
		var door: Dictionary = npcs[node_name]._door_here()
		start_distance[node_name] = npcs[node_name].global_position.distance_to(door["position"])
	for i in 30:
		await get_tree().physics_frame
	var walking_home := true
	for node_name in npcs:
		var npc: NPC = npcs[node_name]
		walking_home = walking_home and npc.is_going_home and npc.visible and npc.is_walking
	_record("20:00 汤姆、乔、玛丽开始走回家（仍可见）", walking_home)

	# The walk home is a slow stroll (~15-30 s, round 8): run the clock 4x for it.
	Engine.time_scale = 4.0
	var frames := 0
	while frames < 1200 and not npcs.values().all(func(n): return n.is_resting):
		frames += 1
		await get_tree().physics_frame
	await get_tree().physics_frame
	Engine.time_scale = 1.0
	for node_name in npcs:
		var npc: NPC = npcs[node_name]
		var door: Vector2 = npc._door_here()["position"]
		var at_door := npc.global_position.distance_to(door) < 8.0
		_record("%s 走到门口 %s 后休息：隐藏、无碰撞、不检测玩家（%.1f 秒）" % [npc.npc_name, door, frames * 4.0 / Engine.physics_ticks_per_second],
			npc.is_resting and at_door and not npc.visible and npc.collision_shape.disabled and not npc.interaction_area.monitoring)

	# E does nothing on a resting NPC (even if the player still had it registered)
	var tom: NPC = npcs["Iron"]
	var started := [0]
	var on_started := func(_id: String): started[0] += 1
	DialogueManager.dialogue_started.connect(on_started)
	player.global_position = tom.global_position + Vector2(40, 0)  # beside the door (below it is the mine exit)
	player.register_nearby_npc(tom)
	await _press_action(&"interact")
	var toast := false
	if UIManager._toast_root:
		for t in UIManager._toast_root.get_children():
			toast = toast or str(t.get_meta("toast_text", "")).contains(tom.npc_name)
	var prompt = tom.get_node("InteractPrompt")
	_record("休息中的 NPC：按 E 没反应（无对话、无提示），气泡不显示", started[0] == 0 and not DialogueManager.is_in_dialogue() and not toast and InteractPrompt.current() != prompt and not prompt.is_visible_in_tree())
	player.unregister_nearby_npc(tom)
	DialogueManager.dialogue_started.disconnect(on_started)

	# Wake up at 6:00 next morning: back at the door, solid and talkable again.
	player.global_position = Vector2(1100, 800)
	TimeManager.current_time = 6.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var woke := true
	for node_name in npcs:
		var npc: NPC = npcs[node_name]
		var door: Vector2 = npc._door_here()["position"]
		woke = woke and not npc.is_resting and npc.visible and npc.global_position.distance_to(door) < 6.0 and not npc.collision_shape.disabled and npc.interaction_area.monitoring and npc.can_interact()
	_record("6:00 起床：在自家门口重新出现，可碰撞、可交互", woke)
	village.queue_free()
	await get_tree().process_frame

	# Entering the village while everyone is asleep: hidden from the first frame.
	TimeManager.current_time = 23.0
	var night := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(night)
	await get_tree().process_frame
	var all_npcs: Array = night.get_node("NPCs").get_children().filter(func(n): return n is NPC)
	var hidden := all_npcs.filter(func(n): return n.is_resting and not n.visible)
	var at_doors := all_npcs.filter(func(n): return n._door_here().is_empty() or n.global_position.distance_to(n._door_here()["position"]) < 1.0)
	_record("23:00 进村：%d/%d 个 NPC 直接在家休息（隐藏，位置在门口）" % [hidden.size(), all_npcs.size()], all_npcs.size() >= 5 and hidden.size() == all_npcs.size() and at_doors.size() == all_npcs.size())
	night.queue_free()
	await get_tree().process_frame
	TimeManager.reset()
	GameManager.is_game_active = false


## BUG-26: the real E/Space key press that closes a dialogue restarted it. xdotool-style
## taps deliver press and release in the same frame, so "wait until released" never saw
## the key held and the player still got is_action_just_pressed. Drive real key events.
func _exercise_dialogue_close_real_keys() -> void:
	print("------------------------------------------------------------")
	print("BUG-26 真实按键（E / Space，按下松开同帧/隔帧/长按）结束对话不会重新开始对话")
	DialogueManager.reset()
	TimeManager.reset()
	TimeManager.current_time = 10.0
	var village := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := village.find_child("Player", true, false) as Player
	var mayor := village.get_node_or_null("NPCs/MayorThomas") as NPC
	var box: DialogueBox = DialogueManager._dialogue_box
	_record("真实按键用例有玩家、村长和对话框", player != null and mayor != null and box != null)
	if player == null or mayor == null or box == null:
		village.queue_free()
		return
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	if mayor.schedule:
		mayor.schedule.update(10.0, TimeManager.current_day, TimeManager.current_season)
	# Only the mayor takes part: park the other villagers (the shopkeeper wandering by
	# would otherwise open the shop and pause the game).
	for npc in village.get_node("NPCs").get_children():
		if npc != mayor and npc is Node2D:
			npc.process_mode = Node.PROCESS_MODE_DISABLED
			(npc as Node2D).global_position += Vector2(4000, 4000)
	var started := [0]
	var on_started := func(_id: String): started[0] += 1
	DialogueManager.dialogue_started.connect(on_started)
	for key in [KEY_E, KEY_SPACE]:
		for hold in [0, 1, 6]:  # 0 = press and release in the same frame
			player.global_position = mayor.global_position + Vector2(0, 36)
			player.register_nearby_npc(mayor)
			UIManager.close_all()
			get_tree().paused = false
			GameManager.current_state = GameManager.GameState.PLAYING
			started[0] = 0
			await _wait_retalk_cooldown()
			await _tap_key(key, hold)
			var opened := DialogueManager.is_in_dialogue()
			var presses := 0
			while (box.visible or DialogueManager.is_in_dialogue()) and presses < 40:
				presses += 1
				box._finish_typewriter()
				await get_tree().process_frame
				await _tap_key(key, hold)
			for i in 8:
				await get_tree().physics_frame
			var label := "%s 按住 %d 帧" % [OS.get_keycode_string(key), hold]
			_record("%s：对话开始且关闭一次，只开始 1 次（实际 %d 次）" % [label, started[0]],
				opened and started[0] == 1 and not DialogueManager.is_in_dialogue() and not box.visible
				and GameManager.current_state == GameManager.GameState.PLAYING)
			DialogueManager.force_end_dialogue()
			await get_tree().physics_frame
	DialogueManager.dialogue_started.disconnect(on_started)
	# BUG-27: the dialogue box speaker must match the NPC's own name (data/npcs.json).
	var mismatched: Array[String] = []
	for npc in village.get_node("NPCs").get_children():
		if npc is NPC:
			var dialogue_id: String = DialogueManager.DIALOGUE_ID_ALIASES.get(npc.npc_id, npc.npc_id)
			if DialogueManager._npc_data.has(dialogue_id) and DialogueManager._get_npc_name(dialogue_id) != npc.npc_name:
				mismatched.append("%s≠%s" % [npc.npc_name, DialogueManager._get_npc_name(dialogue_id)])
	_record("对话框里的 NPC 名字和 NPC 本身一致 %s" % [mismatched], mismatched.is_empty())
	player.unregister_nearby_npc(mayor)
	village.queue_free()
	await get_tree().process_frame
	DialogueManager.reset()
	GameManager.is_game_active = false


## Esc / J did nothing outside Farm and Village (tester round 3 follow-up).
func _exercise_map_menu_keys() -> void:
	print("------------------------------------------------------------")
	print("森林/海滩/矿洞/玩家房屋：Esc 打开/关闭暂停菜单，J 打开手册")
	for path in ["res://src/world/maps/Forest.tscn", "res://src/world/maps/Beach.tscn", "res://src/world/maps/Mine.tscn", "res://src/world/maps/PlayerHouse.tscn"]:
		var map := (load(path) as PackedScene).instantiate()
		add_child(map)
		await get_tree().process_frame
		await get_tree().process_frame
		GameManager.is_game_active = true
		GameManager.current_state = GameManager.GameState.PLAYING
		get_tree().paused = false
		var label: String = (path as String).get_file().get_basename()
		var handler := map.find_child("MapMenuInput", true, false)
		var menu: Control = handler.get("pause_menu") if handler else null
		await _press_action(&"pause")
		_record("%s：Esc 打开暂停菜单" % label, GameManager.is_paused() and menu != null and menu.visible)
		await _press_action(&"pause")
		_record("%s：再按 Esc 关闭暂停菜单" % label, not GameManager.is_paused() and not get_tree().paused and menu != null and not menu.visible)
		await _press_action(&"journal")
		_record("%s：J 打开手册" % label, UIManager.is_screen_open("journal"))
		UIManager.close_all()
		await get_tree().process_frame
		map.queue_free()
		await get_tree().process_frame
	GameManager.is_game_active = false


## Idle breathing is visual only: feet stay anchored, body/collision don't move,
## and it stops cleanly when walking, swinging a tool or in a dialogue.
func _exercise_idle_breathing() -> void:
	print("------------------------------------------------------------")
	print("玩家站立呼吸动画：只动贴图、脚不离地，走路/挥工具/对话时停止复原")
	TimeManager.reset()
	Inventory.reset_with_starter_items()
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	UserSettings.set_value("accessibility", "reduce_motion", false)
	var farm = await _spawn_farm()
	var player := farm.find_child("Player", true, false) as Player
	_record("呼吸用例有玩家", player != null)
	if player == null:
		farm.queue_free()
		return
	GameManager.current_state = GameManager.GameState.PLAYING
	var body_pos := player.global_position
	var shape := player.get_node("CollisionShape2D") as CollisionShape2D
	var shape_pos := shape.position
	var max_k := 0.0
	var feet_ok := true
	var t_end := Time.get_ticks_msec() + 1300
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		var k := player.sprite.scale.y / Player.SPRITE_BASE_SCALE.y - 1.0
		max_k = maxf(max_k, k)
		var feet := player.sprite.position.y + Player.SPRITE_FEET_Y * player.sprite.scale.y
		feet_ok = feet_ok and absf(feet - Player.SPRITE_FEET_Y * Player.SPRITE_BASE_SCALE.y) < 0.01 and player.sprite.scale.x == Player.SPRITE_BASE_SCALE.x
	_record("站着不动时有呼吸（最大拉伸 %.3f）" % max_k, player.is_breathing() and max_k > 0.015 and max_k <= Player.BREATH_AMOUNT + 0.0001)
	_record("呼吸时脚底位置不变、只拉高不变宽", feet_ok)
	_record("呼吸不移动角色本体和碰撞体", player.global_position.distance_to(body_pos) < 0.01 and shape.position == shape_pos)
	await _hold_action(&"move_right", 1)
	Input.action_press(&"move_right")
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	_record("走路时呼吸停止并复原", not player.is_breathing() and player.sprite.scale == Player.SPRITE_BASE_SCALE and player.sprite.position == Vector2.ZERO)
	Input.action_release(&"move_right")
	for i in 4:
		await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout
	_record("停下后呼吸恢复", player.is_breathing())
	player.tool_manager.equip_tool(ToolManager.ToolType.HOE)
	Inventory.set_selected_hotbar_index(Inventory.HOTBAR_SIZE - 1)
	await _press_action(&"interact", 1)
	_record("挥工具时不呼吸（挥动动画接管贴图）", not player.is_breathing())
	await _wait_swing_over(player)
	await get_tree().process_frame
	await get_tree().process_frame
	_record("挥完贴图回到原样再继续呼吸", absf(player.sprite.position.x) < 0.01 and player.sprite.scale.x == Player.SPRITE_BASE_SCALE.x)
	GameManager.current_state = GameManager.GameState.DIALOGUE
	await get_tree().process_frame
	await get_tree().process_frame
	_record("对话时呼吸停止并复原", not player.is_breathing() and player.sprite.scale == Player.SPRITE_BASE_SCALE and player.sprite.position == Vector2.ZERO)
	GameManager.current_state = GameManager.GameState.PLAYING
	UserSettings.set_value("accessibility", "reduce_motion", true)
	await get_tree().process_frame
	await get_tree().process_frame
	_record("减少动态时不呼吸", not player.is_breathing() and player.sprite.scale == Player.SPRITE_BASE_SCALE)
	UserSettings.set_value("accessibility", "reduce_motion", false)
	FarmState.reset()
	farm.queue_free()
	await get_tree().process_frame


func _visible_prompts() -> Array:
	var out := []
	for prompt in get_tree().root.find_children("InteractPrompt", "Node2D", true, false):
		if (prompt as Node2D).is_visible_in_tree():
			out.append(prompt)
	return out


## Interaction prompt bubble: shows above the one target E would act on, hides on
## leave / dialogue / pause, follows the theme and the current key binding.
func _exercise_interact_prompt() -> void:
	print("------------------------------------------------------------")
	print("交互提示气泡：进入范围显示、离开隐藏、对话/暂停时隐藏、只显示一个、跟随主题和按键")
	DialogueManager.reset()
	TimeManager.reset()
	TimeManager.current_time = 10.0
	var village := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := village.find_child("Player", true, false) as Player
	var mayor := village.get_node_or_null("NPCs/MayorThomas") as NPC
	var farmer := village.get_node_or_null("NPCs/John") as NPC
	_record("气泡用例有玩家、村长、农夫", player != null and mayor != null and farmer != null)
	if player == null or mayor == null or farmer == null:
		village.queue_free()
		return
	for npc in village.get_node("NPCs").get_children():
		if npc is Node2D:
			npc.process_mode = Node.PROCESS_MODE_DISABLED
			if npc != mayor and npc != farmer:
				(npc as Node2D).global_position += Vector2(4000, 4000)
	mayor.process_mode = Node.PROCESS_MODE_INHERIT
	mayor.set_physics_process(false)
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var prompt := mayor.get_node_or_null("InteractPrompt") as InteractPrompt
	_record("村长身上的 E 标签换成了交互气泡", prompt != null and mayor.get_node_or_null("InteractionLabel") == null)
	if prompt == null:
		village.queue_free()
		return
	# Out of the 128 px interaction box but clear of the village exits (one sits 380 px below).
	var far := mayor.global_position + Vector2(180, 0)
	farmer.global_position = mayor.global_position + Vector2(2000, 0)
	player.global_position = far
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	_record("不在范围内时不显示气泡", not prompt.visible and _visible_prompts().is_empty())
	player.global_position = mayor.global_position + Vector2(0, 40)
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	_record("走进村长交互范围显示气泡", prompt.visible and player.npc_in_range == mayor)
	_record("气泡显示当前交互键（E）", prompt.key_label.text == InputManager.get_action_short_prompt(&"interact") and prompt.key_label.text == "E")
	_record("气泡在村长头顶上方", prompt.global_position.y < mayor.global_position.y - 30.0 and absf(prompt.global_position.x - mayor.global_position.x) < 1.0)
	# Two NPCs in range: only the one E would talk to (the nearest) shows its bubble.
	farmer.global_position = player.global_position + Vector2(56, 0)
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	player._refresh_nearest_npc()
	var farmer_prompt := farmer.get_node("InteractPrompt") as InteractPrompt
	var shown := _visible_prompts()
	_record("两个 NPC 都在范围内时只显示一个气泡（%d 个）" % shown.size(), shown.size() == 1)
	_record("显示的气泡属于按 E 会交谈的那个 NPC", shown.size() == 1 and (shown[0] as Node).get_parent() == player.npc_in_range)
	farmer.global_position = mayor.global_position + Vector2(2000, 0)
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	# Theme follow
	_record("气泡使用当前主题", prompt.bubble.theme == UIStyles.active_theme())
	UserSettings.set_value("accessibility", "high_contrast", true)
	await get_tree().process_frame
	_record("切到高对比时气泡跟随主题", prompt.bubble.theme == UIStyles.active_theme() and prompt.bubble.theme != load("res://src/ui/theme/GameTheme.tres"))
	UserSettings.set_value("accessibility", "high_contrast", false)
	await get_tree().process_frame
	_record("切回普通主题时气泡跟随", prompt.bubble.theme == load("res://src/ui/theme/GameTheme.tres"))
	# Remapped key
	var saved_bindings := InputManager.serialize_bindings()
	var f_key := InputEventKey.new()
	f_key.physical_keycode = KEY_F
	var remapped := InputManager.remap_action(&"interact", f_key)
	await get_tree().process_frame
	_record("改键后气泡显示新按键（%s）" % prompt.key_label.text, remapped and prompt.key_label.text == "F")
	InputManager.apply_serialized_bindings(saved_bindings)
	prompt._refresh_key()
	_record("恢复按键后气泡回到 E", prompt.key_label.text == "E")
	# Dialogue hides it; it comes back afterwards.
	var box: DialogueBox = DialogueManager._dialogue_box
	await _press_action(&"interact")
	await get_tree().process_frame
	_record("对话中隐藏气泡", DialogueManager.is_in_dialogue() and not prompt.visible and _visible_prompts().is_empty())
	var steps := 0
	while box.visible and steps < 30:
		steps += 1
		box._finish_typewriter()
		await _press_action(&"interact")
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	_record("对话结束后气泡重新出现", not DialogueManager.is_in_dialogue() and prompt.visible)
	GameManager.pause_game()
	await get_tree().process_frame
	_record("暂停时隐藏气泡", not prompt.visible or not prompt.is_visible_in_tree() or InteractPrompt.current() == null)
	GameManager.resume_game()
	UIManager.open_screen("journal", {})
	await get_tree().process_frame
	await get_tree().process_frame
	_record("打开手册时隐藏气泡", InteractPrompt.current() == null)
	UIManager.close_all()
	await get_tree().process_frame
	await get_tree().process_frame
	player.global_position = far
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	_record("离开范围后隐藏气泡", not prompt.visible)
	village.queue_free()
	await get_tree().process_frame
	DialogueManager.reset()

	# Farm objects get the same bubble (shipping bin, workbench, coop, barn).
	var farm = await _spawn_farm()
	var farm_player := farm.find_child("Player", true, false) as Player
	GameManager.current_state = GameManager.GameState.PLAYING
	for target_name in ["ShippingBin", "Workbench", "Coop", "Barn"]:
		var target := farm.find_child(target_name, true, false) as Node2D
		var target_prompt := target.get_node_or_null("InteractPrompt") as InteractPrompt if target else null
		var area_shape: CollisionShape2D = null
		var area: Area2D = target if target is Area2D else target.get_node_or_null("InteractionArea") as Area2D if target else null
		if area:
			for child in area.get_children():
				if child is CollisionShape2D:
					area_shape = child
					break
		var ok := target_prompt != null and area_shape != null
		if ok:
			farm_player.global_position = area_shape.global_position
			for i in 4:
				await get_tree().physics_frame
			await get_tree().process_frame
			ok = target_prompt.visible and _visible_prompts().size() == 1 and target_prompt.global_position.y < target.global_position.y + 8.0
			farm_player.global_position = area_shape.global_position + Vector2(0, 600)
			for i in 4:
				await get_tree().physics_frame
			await get_tree().process_frame
			ok = ok and not target_prompt.visible
		_record("%s 走近显示气泡（%s）、离开隐藏" % [target_name, target_prompt.text_label.text if target_prompt else "-"], ok)
	# Fishing spot: the bubble is always there (BUG-38); its verb follows the tool
	# ("装水" with the watering can, "钓鱼" otherwise; E explains the rod).
	var spot := farm.find_child("FishingSpot", true, false) as Node2D
	var spot_prompt := spot.get_node_or_null("InteractPrompt") as InteractPrompt if spot else null
	if spot_prompt:
		farm_player.global_position = spot.global_position
		farm_player.tool_manager.equip_tool(ToolManager.ToolType.WATERING_CAN)
		for i in 4:
			await get_tree().physics_frame
		await get_tree().process_frame
		var with_can := spot_prompt.visible and spot_prompt.text_label.text == "装水"
		farm_player.tool_manager.equip_tool(ToolManager.ToolType.HOE)
		await get_tree().process_frame
		await get_tree().process_frame
		_record("钓鱼点：拿水壶显示“装水”气泡，拿锄头显示“钓鱼”", with_can and spot_prompt.visible and spot_prompt.text_label.text == "钓鱼")
		farm_player.global_position = spot.global_position + Vector2(0, 600)
	else:
		_record("钓鱼点有交互气泡", false)
	FarmState.reset()
	farm.queue_free()
	await get_tree().process_frame
	# Player house kitchen
	var house := (load("res://src/world/maps/PlayerHouse.tscn") as PackedScene).instantiate()
	add_child(house)
	await get_tree().process_frame
	await get_tree().physics_frame
	GameManager.current_state = GameManager.GameState.PLAYING
	var house_player := house.find_child("Player", true, false) as Player
	var kitchen: Node2D = null
	for node in house.find_children("*", "Area2D", true, false):
		if node is Kitchen:
			kitchen = node
			break
	var kitchen_prompt := kitchen.get_node_or_null("InteractPrompt") as InteractPrompt if kitchen else null
	var kitchen_ok := kitchen_prompt != null and house_player != null
	if kitchen_ok:
		house_player.global_position = kitchen.global_position
		for i in 4:
			await get_tree().physics_frame
		await get_tree().process_frame
		kitchen_ok = kitchen_prompt.visible and kitchen_prompt.text_label.text == "烹饪"
	_record("厨房走近显示“烹饪”气泡", kitchen_ok)
	house.queue_free()
	await get_tree().process_frame
	GameManager.is_game_active = false


func _tap_key(keycode: Key, hold_frames: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	for i in hold_frames:
		await get_tree().process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	for i in 6:
		await get_tree().physics_frame


## A new talk right after a dialogue closed is ignored for a moment (Player.DIALOGUE_RETALK_COOLDOWN_MS).
func _wait_retalk_cooldown() -> void:
	await get_tree().create_timer(0.65).timeout


func _hold_action(action: StringName, frames: int) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	for i in frames:
		await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	for i in 2:
		await get_tree().physics_frame


## BUG-21: villagers crowding the player by the fountain made WASD look dead.
## A villager still blocks a single step, but pushing into one lets the player squeeze past.
func _exercise_npc_crowd_squeeze() -> void:
	print("------------------------------------------------------------")
	print("BUG-21 村民挡路：一步撞上会挡住，持续推挤能挤过去，分开后恢复碰撞；村民按 Y 排序")
	TimeManager.reset()
	TimeManager.current_time = 10.0
	var village := (load("res://src/world/maps/Village.tscn") as PackedScene).instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := village.find_child("Player", true, false) as Player
	var mayor := village.get_node_or_null("NPCs/MayorThomas") as NPC
	_record("挤过村民用例有玩家和村长", player != null and mayor != null)
	if player == null or mayor == null:
		village.queue_free()
		return
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var npcs := village.get_node("NPCs") as Node2D
	_record("村民和玩家同层按 Y 排序（村民 z=%d，玩家 z=%d）" % [mayor.z_index, player.z_index],
		npcs.y_sort_enabled and village.y_sort_enabled and mayor.z_index == player.z_index)
	mayor.set_physics_process(false)  # hold the mayor still so only the player moves
	player.global_position = mayor.global_position + Vector2(40, 4)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await _hold_action(&"move_left", 6)
	_record("短按 A 撞上村长会被挡住（x 差 %.0f）" % (player.global_position.x - mayor.global_position.x),
		player.global_position.x - mayor.global_position.x > 15.0)
	await _hold_action(&"move_left", 50)
	_record("持续按 A 能从村长身边挤过去（x 差 %.0f）" % (player.global_position.x - mayor.global_position.x),
		player.global_position.x < mayor.global_position.x - 20.0)
	await _hold_action(&"move_left", 20)
	var far_ok := player.global_position.distance_to(mayor.global_position) > Player.NPC_SQUEEZE_CLEAR_DISTANCE
	_record("走开后恢复对村长的碰撞", far_ok and not player.get_collision_exceptions().has(mayor))
	player.velocity = Vector2.ZERO
	player.global_position = mayor.global_position + Vector2(-60, 4)
	var npc_collision := player.move_and_collide(Vector2(100, 0))
	_record("恢复后再撞村长仍被挡住", npc_collision != null and npc_collision.get_collider() == mayor)
	village.queue_free()
	await get_tree().process_frame


func _tilled_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in FarmState.GRID_HEIGHT:
		for x in FarmState.GRID_WIDTH:
			var c := Vector2i(x, y)
			if int(FarmState.get_cell(c).get("state", FarmState.UNTILLED)) != FarmState.UNTILLED:
				out.append(c)
	return out


func _wait_swing_over(player: Player) -> void:
	var guard := 0
	while player.is_tool_locked() and guard < 120:
		await get_tree().physics_frame
		guard += 1


## Hoe target tile: one press per direction must till the 4 neighbouring plots
## (it used to till the player's own plot twice from a plot's top-left area, and
## nothing from a plot centre). Then: no walking during the swing, walking right after.
func _exercise_hoe_facing_and_swing_lock() -> void:
	print("------------------------------------------------------------")
	print("锄头四个方向各锄一次 = 四块相邻的地；挥锄时站定，挥完能走")
	TimeManager.reset()
	Inventory.reset_with_starter_items()
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	var farm = await _spawn_farm()
	var player := farm.find_child("Player", true, false) as Player
	_record("锄地场景有玩家", player != null)
	if player == null:
		farm.queue_free()
		return
	player.tool_manager.equip_tool(ToolManager.ToolType.HOE)
	Inventory.set_selected_hotbar_index(Inventory.HOTBAR_SIZE - 1)
	var centre := Vector2i(4, 3)
	var expected: Array[Vector2i] = [centre + Vector2i.UP, centre + Vector2i.DOWN, centre + Vector2i.LEFT, centre + Vector2i.RIGHT]
	var plot_centre: Vector2 = farm.global_position + farm.PLOT_ORIGIN + Vector2(centre) * farm.PLOT_SPACING
	var dirs := [Player.Direction.UP, Player.Direction.RIGHT, Player.Direction.DOWN, Player.Direction.LEFT]
	for offset in [Vector2(-10, -10), Vector2.ZERO, Vector2(12, 14), Vector2(-20, 18)]:
		FarmState.reset()
		StaminaManager.set_stamina(StaminaManager.max_stamina)
		player.global_position = plot_centre + offset
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
		for d in dirs:
			player.current_direction = d
			await _press_action(&"interact", 2)
			await _wait_swing_over(player)
		var tilled := _tilled_coords()
		var ok := tilled.size() == 4
		for c in expected:
			ok = ok and tilled.has(c)
		_record("站在地块 %s 偏移 %s：四向各锄一次锄出四块相邻地（实际 %s）" % [centre, offset, tilled], ok)

	# Swing lock: hold right, press interact; no movement during the swing, then walks on.
	FarmState.reset()
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	player.global_position = plot_centre
	player.current_direction = Player.Direction.RIGHT
	await get_tree().physics_frame
	var hold := InputEventAction.new()
	hold.action = &"move_right"
	hold.pressed = true
	var tap := InputEventAction.new()
	tap.action = &"interact"
	tap.pressed = true
	Input.parse_input_event(tap)
	Input.parse_input_event(hold)
	var wait := 0
	while not player.is_tool_locked() and wait < 5:
		await get_tree().physics_frame
		wait += 1
	var locked_at := player.global_position
	_record("按下锄头后进入挥动锁定", player.is_tool_locked())
	var tap_up := InputEventAction.new()
	tap_up.action = &"interact"
	tap_up.pressed = false
	Input.parse_input_event(tap_up)
	for i in 8:
		await get_tree().physics_frame
	_record("挥锄期间按住 D 不移动（%.1fpx）" % player.global_position.distance_to(locked_at),
		player.is_tool_locked() and player.global_position.distance_to(locked_at) < 0.5)
	await _wait_swing_over(player)
	var after_lock := player.global_position
	for i in 15:
		await get_tree().physics_frame
	_record("挥完锄头继续按住 D 立刻能走（%.1fpx）" % (player.global_position.x - after_lock.x),
		player.global_position.x - after_lock.x > 20.0)
	var hold_up := InputEventAction.new()
	hold_up.action = &"move_right"
	hold_up.pressed = false
	Input.parse_input_event(hold_up)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stop_at := player.global_position
	await _press_action(&"move_up", 12)
	_record("挥锄后其它方向键正常（上移 %.1fpx）" % (stop_at.y - player.global_position.y),
		stop_at.y - player.global_position.y > 15.0)
	await _wait_swing_over(player)
	var tilled_count := _tilled_coords().size()
	await _press_action(&"interact", 2)
	_record("挥完再按 E 还能锄地", _tilled_coords().size() == tilled_count + 1)
	await _wait_swing_over(player)
	FarmState.reset()
	farm.queue_free()
	await get_tree().process_frame


func _record(name: String, condition: bool) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [PASS] ", name)
	else:
		_failures.append(name)
		print("  [FAIL] ", name)


func _finish() -> void:
	print("============================================================")
	print("RESULTS: %d/%d passed" % [_passed, _total])
	if _failures.is_empty():
		print("ALL INTEGRATION TESTS PASSED")
		call_deferred("_quit_after_cleanup", 0)
		return

	for failure in _failures:
		print("  - ", failure)
	print("INTEGRATION TESTS FAILED")
	call_deferred("_quit_after_cleanup", 1)


func _quit_after_cleanup(exit_code: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)
