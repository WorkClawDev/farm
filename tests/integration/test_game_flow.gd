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
	await _exercise_json_save_compatibility()
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
		_record("村民使用无毛边矢量角色", sample_npc != null and sample_npc.get_node_or_null("VillagerIllustration") != null)
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
			start = Vector2(0, 100)
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
		player.global_position = Vector2(0, 100)
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
