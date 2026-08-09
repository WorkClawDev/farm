extends RefCounted
class_name ForestConstants


const MAP_TILES_X: int = 50
const MAP_TILES_Y: int = 40
const BORDER_THICKNESS: int = 2

const HORIZONTAL_PATH_Y: int = 18
const HORIZONTAL_PATH_X_MIN: int = 4
const HORIZONTAL_PATH_X_MAX: int = 45

const VERTICAL_PATH_X: int = 12
const VERTICAL_PATH_Y_MIN: int = 8
const VERTICAL_PATH_Y_MAX: int = 29

const TREE_STEP: int = 2
const TREE_EDGE_INSET_X: int = 1
const TREE_EDGE_INSET_Y: int = 1

const STUMP_POSITIONS: Array[Vector2i] = [
	Vector2i(8, 12),
	Vector2i(19, 27),
	Vector2i(31, 10),
	Vector2i(38, 25),
]

const FLOWER_POSITIONS: Array[Vector2i] = [
	Vector2i(15, 14),
	Vector2i(26, 8),
	Vector2i(34, 19),
	Vector2i(42, 29),
]

const FORAGE_SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(200, 200),
	Vector2(400, 150),
	Vector2(600, 200),
	Vector2(250, 400),
	Vector2(450, 350),
	Vector2(650, 400),
	Vector2(150, 300),
	Vector2(750, 300),
	Vector2(350, 500),
]
