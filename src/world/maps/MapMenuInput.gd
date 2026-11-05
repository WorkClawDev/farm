extends Node
## Esc (pause menu) and J / I (journal) for maps without their own handlers
## (Forest, Beach, Mine, PlayerHouse). Same behaviour as Village.gd / Farm.gd.
## Add it as a child of the map's HUD; it puts the pause menu next to itself.

const PauseMenuScene = preload("res://src/ui/menus/PauseMenu.tscn")

var pause_menu: PauseMenu


func _ready() -> void:
	name = "MapMenuInput"
	pause_menu = PauseMenuScene.instantiate()
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.quit_to_menu_requested.connect(GameManager.return_to_menu)
	pause_menu.quit_game_requested.connect(GameManager.quit_game)
	get_parent().add_child.call_deferred(pause_menu)


func _unhandled_input(event: InputEvent) -> void:
	# Not while a dialogue/shop owns the game state (pause_game() would be a no-op there).
	var playing := GameManager.current_state == GameManager.GameState.PLAYING
	if (event.is_action_pressed("inventory") or event.is_action_pressed("journal")) and playing:
		var context := {}
		if event.is_action_pressed("inventory"):
			context["tab"] = "inventory"
		UIManager.open_screen("journal", context)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if UIManager.has_open_modal():
			return
		if GameManager.is_paused():
			_close_pause_menu()
		elif playing:
			GameManager.pause_game()
			pause_menu.visible = true
		get_viewport().set_input_as_handled()


func _close_pause_menu() -> void:
	pause_menu.visible = false
	GameManager.resume_game()
