extends Node
class_name EventBusSocial

## EventBusSocial - 社交/NPC系统事件

signal npc_interacted(npc: Node)
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal friendship_changed(npc_id: String, hearts: int)
signal gift_given(npc_id: String, item_id: String, reaction: int)
signal npc_activity_changed(npc_id: String, activity: Dictionary)
signal npc_location_changed(npc_id: String, location_id: String)
signal npc_spawned(npc_id: String, npc: Node)
