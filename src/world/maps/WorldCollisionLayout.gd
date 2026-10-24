extends Node2D
class_name WorldCollisionLayout

## Static collision geometry matching IllustratedMapBackdrop.
## All solid geometry lives on layer 1; players and NPCs collide with it.

var map_style: String = ""
var collision_count: int = 0


func setup(style: String) -> void:
	map_style = style
	name = "WorldCollisionLayout"
	match style:
		"farm":
			_build_farm()
		"village":
			_build_village()
		"forest":
			_build_forest()
		"beach":
			_build_beach()
		"mine":
			_build_mine()
		"house":
			_build_house()


func _build_farm() -> void:
	# The authored farm map is 30 x 20 native 64px tiles.
	_add_world_bounds(Rect2(0, 0, 1920, 1280))
	_add_rect("FarmSignpost", Rect2(704, 144, 32, 32))


func _build_village() -> void:
	_add_world_bounds(Rect2(-120, -120, 1320, 1040))
	_add_rect("BuildingNorthWest", Rect2(70, 15, 250, 175))
	_add_rect("BuildingNorthEast", Rect2(520, 5, 270, 185))
	_add_rect("BuildingSouthEast", Rect2(760, 405, 250, 175))
	_add_rect("BuildingSouthWest", Rect2(35, 640, 275, 175))
	_add_circle("VillageWell", Vector2(420, 320), 28.0)

	var tree_positions := [
		Vector2(-40, 40), Vector2(-30, 245), Vector2(-20, 520), Vector2(-40, 800),
		Vector2(1080, 40), Vector2(1100, 245), Vector2(1090, 520), Vector2(1110, 800),
		Vector2(192, -65), Vector2(900, -70), Vector2(640, 671), Vector2(760, 850),
	]
	for index in range(tree_positions.size()):
		_add_rect(
			"VillageTree%02d" % index,
			Rect2(tree_positions[index] + Vector2(-14, 0), Vector2(28, 62))
		)


func _build_forest() -> void:
	_add_world_bounds(Rect2(-80, -100, 1200, 1000))

	# The stream is solid except for the bridge around y=365.
	_add_rect("StreamNorth", Rect2(690, -300, 145, 625))
	_add_rect("StreamSouth", Rect2(760, 425, 155, 620))
	_add_rect("FallenLog", Rect2(560, 494, 88, 30), -0.32)
	_add_circle("ForestRock", Vector2(930, 610), 30.0)

	var tree_positions: Array[Vector2] = []
	for x in range(-100, 1150, 115):
		tree_positions.append(Vector2(x, 15 + (x % 3) * 25))
		tree_positions.append(Vector2(x + 45, 815 - (x % 4) * 22))
	for y in range(120, 790, 125):
		tree_positions.append(Vector2(5 + (y % 3) * 18, y))
		tree_positions.append(Vector2(1055 - (y % 4) * 16, y))
	for index in range(tree_positions.size()):
		_add_rect(
			"ForestTree%02d" % index,
			Rect2(tree_positions[index] + Vector2(-15, 0), Vector2(30, 64))
		)


func _build_beach() -> void:
	# Painted water starts at y=80: the shore row is the pool-top tiles at y=64,
	# and their first 4 source pixels (x4) are sand. Fishing circles sit in the
	# water and still reach a player standing on that sand.
	_add_rect("Ocean", Rect2(-1400, 80, 4200, 2035))
	_add_rect("BeachNorthBoundary", Rect2(-950, -760, 1900, 50))
	_add_rect("BeachWestBoundary", Rect2(-980, -760, 50, 960))
	_add_rect("BeachEastBoundary", Rect2(930, -760, 50, 960))
	_add_rect("Driftwood", Rect2(-590, 65, 90, 26), 0.30)


func _build_mine() -> void:
	_add_world_bounds(Rect2(-105, 20, 1010, 690))


func _build_house() -> void:
	# Interior walls. The bottom wall leaves a doorway matching ExitArea.
	_add_rect("HouseTopWall", Rect2(45, 50, 710, 38))
	_add_rect("HouseLeftWall", Rect2(45, 50, 25, 440))
	_add_rect("HouseRightWall", Rect2(730, 50, 25, 440))
	_add_rect("HouseBottomWallLeft", Rect2(45, 458, 320, 32))
	_add_rect("HouseBottomWallRight", Rect2(435, 458, 320, 32))

	_add_rect("Bed", Rect2(125, 120, 150, 92))
	_add_rect("Table", Rect2(355, 125, 140, 64))
	_add_rect("Chest", Rect2(595, 120, 105, 82))
	_add_rect("Stove", Rect2(145, 315, 105, 98))
	_add_rect("Fireplace", Rect2(590, 300, 115, 125))


func _add_world_bounds(rect: Rect2) -> void:
	const THICKNESS := 48.0
	_add_rect("NorthBoundary", Rect2(rect.position.x, rect.position.y - THICKNESS, rect.size.x, THICKNESS))
	_add_rect("SouthBoundary", Rect2(rect.position.x, rect.end.y, rect.size.x, THICKNESS))
	_add_rect("WestBoundary", Rect2(rect.position.x - THICKNESS, rect.position.y, THICKNESS, rect.size.y))
	_add_rect("EastBoundary", Rect2(rect.end.x, rect.position.y, THICKNESS, rect.size.y))


func _add_rect(body_name: String, rect: Rect2, rotation := 0.0) -> StaticBody2D:
	var body := _new_body(body_name)
	body.position = rect.get_center()
	body.rotation = rotation
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_circle(body_name: String, center: Vector2, radius: float) -> StaticBody2D:
	var body := _new_body(body_name)
	body.position = center
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	return body


func _new_body(body_name: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	collision_count += 1
	return body
