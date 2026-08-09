extends RefCounted
class_name PhysicsLayers

const WORLD := 1 << 0
const PLAYER := 1 << 1
const NPC := 1 << 2
const ITEMS := 1 << 3
const CROPS := 1 << 4

const PLAYER_MOVEMENT_MASK := WORLD | NPC
const NPC_MOVEMENT_MASK := WORLD | PLAYER
const PLAYER_INTERACTION_MASK := NPC | ITEMS | CROPS
